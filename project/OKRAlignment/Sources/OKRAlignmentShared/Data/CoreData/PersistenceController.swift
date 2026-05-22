import Foundation
@preconcurrency import CoreData
import os

// Concurrency-safe merge policy wrapper for Swift 6 strict concurrency
nonisolated(unsafe) private let _propertyObjectTrumpMergePolicy = NSMergeByPropertyObjectTrumpMergePolicy as! NSMergePolicy

#if canImport(CloudKit)
import CloudKit
#endif

/// Core Data 持久化控制器
/// 管理整个应用的Core Data栈，包括持久化容器、上下文和数据迁移
/// 支持两种模式：
/// - 本地SQLite持久化（生产环境）
/// - 内存存储（SwiftUI预览和单元测试）
/// - 可选的CloudKit同步（通过NSPersistentCloudKitContainer）
///
/// ## 数据迁移策略
/// 本控制器使用程序化模型定义（`createManagedObjectModel()`）而非.xcdatamodeld文件。
/// 当需要添加新属性时，遵循以下迁移策略：
///
/// ### 轻量级迁移（Lightweight Migration）
/// 已通过 `NSMigratePersistentStoresAutomaticallyOption` 和
/// `NSInferMappingModelAutomaticallyOption` 启用自动轻量级迁移。
/// 适用于以下变更：
/// - 添加新的可选属性（isOptional = true 或有 defaultValue）
/// - 添加新的实体
/// - 重命名属性（需提供版本化模型和 rename mapping）
///
/// ### 需要自定义迁移的场景
/// 以下变更需要创建 `NSMappingModel` 或使用 `NSEntityMigrationPolicy`：
/// - 删除属性
/// - 更改属性类型
/// - 拆分/合并属性
/// - 复杂的数据重组
///
/// ### 如何添加新属性（示例）
/// 1. 在 `createManagedObjectModel()` 中添加新的 `NSAttributeDescription`
/// 2. 确保属性有 `defaultValue` 或 `isOptional = true`（轻量级迁移要求）
/// 3. 将属性添加到 `nodeEntity.properties` 数组
/// 4. 在 `OKRNodeEntity+Extensions` 中添加对应的 `@NSManaged` 属性
/// 5. 更新 `EntityToDomainMapper` 和 `DomainToEntityMapper` 处理映射
/// 6. 测试轻量级迁移是否成功（旧数据库 → 新模型）
///
/// 线程安全说明：
/// 所有Core Data操作必须在正确的队列上执行。
/// viewContext仅用于主线程/UI操作，
/// 后台任务使用newBackgroundContext()获取私有上下文。
///
/// 使用示例：
/// ```swift
/// // 在主视图中注入
/// @main
/// struct MyApp: App {
///     let persistenceController = PersistenceController.shared
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environment(\.managedObjectContext, persistenceController.viewContext)
///         }
///     }
/// }
/// ```
public final class PersistenceController: @unchecked Sendable {

    // MARK: - Shared Instance

    /// 共享单例实例，使用本地SQLite持久化
    /// 在整个应用生命周期中保持一致
    public static let shared = PersistenceController()

    /// 预览专用实例，使用内存存储
    /// 用于SwiftUI预览，数据不会持久化
    public static let preview = PersistenceController(inMemory: true)

    // MARK: - Properties

    /// Core Data持久化容器
    /// 根据配置可能是NSPersistentContainer或NSPersistentCloudKitContainer
    public let container: NSPersistentContainer

    /// 主线程上下文，用于UI绑定
    /// 该上下文与主线程队列关联，可直接用于SwiftUI的@FetchRequest
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// 是否使用内存存储
    private let isInMemory: Bool

    /// iCloud 同步是否已启用
    /// 读取用户偏好设置，决定是否使用 CloudKit 容器
    public static var isCloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "okr_icloud_sync_enabled")
    }

    /// 当前容器是否为 CloudKit 容器
    public var isCloudKitContainer: Bool {
        container is NSPersistentCloudKitContainer
    }

    /// iCloud 容器标识符
    /// 在实际部署时需要替换为开发者真实的 iCloud Container ID
    public static let cloudKitContainerIdentifier = "iCloud.com.okralignment.system"

    // MARK: - Initialization

    /// 创建持久化控制器
    /// - Parameter inMemory: 是否使用内存存储（预览和测试时使用）
    private init(inMemory: Bool = false) {
        self.isInMemory = inMemory

        // 使用程序化的数据模型定义
        // Swift Package中没有.xcdatamodeld文件，需要在代码中定义模型
        let model = PersistenceController.createManagedObjectModel()

        // 根据用户偏好选择容器类型
        // CloudKit同步启用时使用 NSPersistentCloudKitContainer
        // 关闭时使用普通 NSPersistentContainer
        #if canImport(CloudKit)
        if Self.isCloudSyncEnabled && !inMemory {
            let cloudContainer = NSPersistentCloudKitContainer(
                name: "OKRAlignment",
                managedObjectModel: model
            )
            // 配置 CloudKit 容器选项
            if let storeDescription = cloudContainer.persistentStoreDescriptions.first {
                let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: Self.cloudKitContainerIdentifier
                )
                // Last-Write-Wins 冲突解决策略已在 mergePolicy 中配置
                storeDescription.cloudKitContainerOptions = cloudKitOptions
                Logger.app.info("CloudKit 同步已启用，容器ID: \(Self.cloudKitContainerIdentifier)")
            }
            self.container = cloudContainer
        } else {
            self.container = NSPersistentContainer(
                name: "OKRAlignment",
                managedObjectModel: model
            )
            if !inMemory {
                Logger.app.info("CloudKit 同步已禁用，使用本地存储")
            }
        }
        #else
        self.container = NSPersistentContainer(
            name: "OKRAlignment",
            managedObjectModel: model
        )
        #endif

        // 配置持久化存储
        configureStore(inMemory: inMemory)

        // 加载持久化存储
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                // 加载失败时记录错误详情
                // 可能的原因：存储文件损坏、迁移失败、权限不足
                Logger.app.error("Core Data持久化存储加载失败: \(error), \(error.userInfo)")
                // CloudKit 不可用时回退到本地存储
                #if canImport(CloudKit)
                if Self.isCloudSyncEnabled {
                    Logger.app.warning("CloudKit 加载失败，请检查 iCloud 账户状态")
                }
                #endif
            }
            self?.setupContainer()
            #if canImport(CloudKit)
            // 注册 CloudKit 同步通知
            if self?.isCloudKitContainer == true && !inMemory {
                self?.registerCloudKitNotifications()
            }
            #endif

            // 启动自动备份检查（仅生产环境）
            if !inMemory {
                AutoBackupManager.shared.checkAndAutoBackupIfNeeded()
            }
        }
    }

    #if canImport(CloudKit)
    /// 注册 CloudKit 远程变更通知
    /// 当其他设备通过 iCloud 同步了数据变更时，自动合并到本地上下文
    private func registerCloudKitNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] notification in
            Logger.app.info("收到 iCloud 远程数据变更通知，正在同步...")
            // viewContext 已配置 automaticallyMergesChangesFromParent
            // 会自动处理远程变更的合并
        }
    }
    #endif

    // MARK: - Store Configuration

    /// 配置持久化存储描述
    /// 根据是否内存模式设置不同的存储类型
    private func configureStore(inMemory: Bool) {
        if inMemory {
            // 内存存储模式：设置存储类型为NSInMemoryStoreType
            // 数据仅在应用运行期间存在，退出后自动清除
            container.persistentStoreDescriptions.first?.url = URL(
                fileURLWithPath: "/dev/null"
            )
            container.persistentStoreDescriptions.first?.type = NSInMemoryStoreType
        } else {
            // SQLite持久化模式：配置WAL模式和自动迁移
            let description = container.persistentStoreDescriptions.first
            description?.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )
            description?.setOption(
                true as NSNumber,
                forKey: NSPersistentHistoryTrackingKey
            )
            // 启用轻量级迁移
            description?.setOption(
                true as NSNumber,
                forKey: NSMigratePersistentStoresAutomaticallyOption
            )
            description?.setOption(
                true as NSNumber,
                forKey: NSInferMappingModelAutomaticallyOption
            )
            #if os(iOS)
            // 数据加密：根据用户设置配置文件保护级别
            let encryptionManager = DataEncryptionManager.shared
            let protectionLevel = encryptionManager.fileProtectionOption()
            description?.setOption(
                protectionLevel as NSString,
                forKey: NSPersistentStoreFileProtectionKey
            )
            Logger.app.info("CoreData 文件保护级别: \(protectionLevel)")
            #endif
        }
    }

    /// 设置容器的默认行为
    /// 包括自动合并变更、合并策略等
    private func setupContainer() {
        // 自动合并来自父上下文的变更
        viewContext.automaticallyMergesChangesFromParent = true

        // 合并策略：优先使用外部变更（来自CloudKit或其他上下文）
        viewContext.mergePolicy = _propertyObjectTrumpMergePolicy

        // 未保存变更的撤销支持
        viewContext.undoManager = nil
    }

    // MARK: - Background Operations

    /// 创建新的后台上下文
    /// 用于执行耗时的Core Data操作，避免阻塞主线程
    /// - Returns: 新的私有队列上下文
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = _propertyObjectTrumpMergePolicy
        return context
    }

    /// 在后台上下文中执行操作
    /// - Parameter block: 在后台上下文中执行的代码块
    /// 代码块完成后会自动保存上下文
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            block(context)
            // 尝试保存后台上下文的变更
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    // 记录保存错误但不中断执行流程
                    // 调用方可以通过block自行处理错误
                    Logger.app.error("后台上下文保存失败: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }

    // MARK: - Save

    /// 保存viewContext中的未提交变更
    /// 应在主线程上调用
    /// - Throws: Core Data保存错误
    public func save() throws {
        let context = container.viewContext
        // 仅在存在变更时才执行保存，避免不必要的I/O
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Managed Object Model

    /// 程序化创建ManagedObjectModel
    /// Swift Package中无法使用.xcdatamodeld文件，需在代码中定义完整的数据模型
    /// - Returns: 配置好的NSManagedObjectModel实例
    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // MARK: OKRNodeEntity
        let nodeEntity = NSEntityDescription()
        nodeEntity.name = "OKRNodeEntity"
        nodeEntity.managedObjectClassName = "OKRAlignmentShared.OKRNodeEntity"

        // 节点基本属性
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false

        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false

        let nodeDescriptionAttr = NSAttributeDescription()
        nodeDescriptionAttr.name = "nodeDescription"
        nodeDescriptionAttr.attributeType = .stringAttributeType
        nodeDescriptionAttr.isOptional = true

        let nodeTypeAttr = NSAttributeDescription()
        nodeTypeAttr.name = "nodeType"
        nodeTypeAttr.attributeType = .stringAttributeType
        nodeTypeAttr.isOptional = false

        let scopeAttr = NSAttributeDescription()
        scopeAttr.name = "scope"
        scopeAttr.attributeType = .stringAttributeType
        scopeAttr.isOptional = false

        let currentValueAttr = NSAttributeDescription()
        currentValueAttr.name = "currentValue"
        currentValueAttr.attributeType = .doubleAttributeType
        currentValueAttr.isOptional = false
        currentValueAttr.defaultValue = 0.0

        let targetValueAttr = NSAttributeDescription()
        targetValueAttr.name = "targetValue"
        targetValueAttr.attributeType = .doubleAttributeType
        targetValueAttr.isOptional = false
        targetValueAttr.defaultValue = 0.0

        let unitAttr = NSAttributeDescription()
        unitAttr.name = "unit"
        unitAttr.attributeType = .stringAttributeType
        unitAttr.isOptional = true

        let progressAttr = NSAttributeDescription()
        progressAttr.name = "progress"
        progressAttr.attributeType = .doubleAttributeType
        progressAttr.isOptional = false
        progressAttr.defaultValue = 0.0

        let statusAttr = NSAttributeDescription()
        statusAttr.name = "status"
        statusAttr.attributeType = .stringAttributeType
        statusAttr.isOptional = false
        statusAttr.defaultValue = "not_started"

        let ownerNameAttr = NSAttributeDescription()
        ownerNameAttr.name = "ownerName"
        ownerNameAttr.attributeType = .stringAttributeType
        ownerNameAttr.isOptional = false

        let sortOrderAttr = NSAttributeDescription()
        sortOrderAttr.name = "sortOrder"
        sortOrderAttr.attributeType = .integer64AttributeType
        sortOrderAttr.isOptional = false
        sortOrderAttr.defaultValue = Int64(0)

        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        createdAtAttr.defaultValue = Date()

        let updatedAtAttr = NSAttributeDescription()
        updatedAtAttr.name = "updatedAt"
        updatedAtAttr.attributeType = .dateAttributeType
        updatedAtAttr.isOptional = false
        updatedAtAttr.defaultValue = Date()

        let nodeCycleIdAttr = NSAttributeDescription()
        nodeCycleIdAttr.name = "cycleId"
        nodeCycleIdAttr.attributeType = .UUIDAttributeType
        nodeCycleIdAttr.isOptional = true

        let parentIdAttr = NSAttributeDescription()
        parentIdAttr.name = "parentId"
        parentIdAttr.attributeType = .UUIDAttributeType
        parentIdAttr.isOptional = true

        let weightAttr = NSAttributeDescription()
        weightAttr.name = "weight"
        weightAttr.attributeType = .doubleAttributeType
        weightAttr.isOptional = false
        weightAttr.defaultValue = 1.0

        let versionAttr = NSAttributeDescription()
        versionAttr.name = "version"
        versionAttr.attributeType = .integer64AttributeType
        versionAttr.isOptional = false
        versionAttr.defaultValue = Int64(0)

        // MARK: OKRCycleEntity (declared early so relationships can reference it)
        let cycleEntity = NSEntityDescription()
        cycleEntity.name = "OKRCycleEntity"
        cycleEntity.managedObjectClassName = "OKRAlignmentShared.OKRCycleEntity"

        let cycleIdAttr = NSAttributeDescription()
        cycleIdAttr.name = "id"
        cycleIdAttr.attributeType = .UUIDAttributeType
        cycleIdAttr.isOptional = false

        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = false

        let startDateAttr = NSAttributeDescription()
        startDateAttr.name = "startDate"
        startDateAttr.attributeType = .dateAttributeType
        startDateAttr.isOptional = false

        let endDateAttr = NSAttributeDescription()
        endDateAttr.name = "endDate"
        endDateAttr.attributeType = .dateAttributeType
        endDateAttr.isOptional = false

        let isActiveAttr = NSAttributeDescription()
        isActiveAttr.name = "isActive"
        isActiveAttr.attributeType = .booleanAttributeType
        isActiveAttr.isOptional = false
        isActiveAttr.defaultValue = false

        let isArchivedAttr = NSAttributeDescription()
        isArchivedAttr.name = "isArchived"
        isArchivedAttr.attributeType = .booleanAttributeType
        isArchivedAttr.isOptional = false
        isArchivedAttr.defaultValue = false

        // ── Relationships ──

        // parent ↔ children  (self-referencing, ordered to-many)
        let childrenRel = NSRelationshipDescription()
        childrenRel.name = "children"
        childrenRel.destinationEntity = nodeEntity
        childrenRel.minCount = 0
        childrenRel.maxCount = 0          // to-many
        childrenRel.isOrdered = true
        childrenRel.deleteRule = .cascadeDeleteRule

        let parentRel = NSRelationshipDescription()
        parentRel.name = "parent"
        parentRel.destinationEntity = nodeEntity
        parentRel.minCount = 0
        parentRel.maxCount = 1
        parentRel.deleteRule = .nullifyDeleteRule

        childrenRel.inverseRelationship = parentRel
        parentRel.inverseRelationship = childrenRel

        // cycle ↔ nodes
        let cycleRel = NSRelationshipDescription()
        cycleRel.name = "cycle"
        cycleRel.destinationEntity = cycleEntity
        cycleRel.minCount = 0
        cycleRel.maxCount = 1
        cycleRel.deleteRule = .nullifyDeleteRule

        let nodesRel = NSRelationshipDescription()
        nodesRel.name = "nodes"
        nodesRel.destinationEntity = nodeEntity
        nodesRel.minCount = 0
        nodesRel.maxCount = 0
        nodesRel.deleteRule = .nullifyDeleteRule

        cycleRel.inverseRelationship = nodesRel
        nodesRel.inverseRelationship = cycleRel

        nodeEntity.properties = [
            idAttr, titleAttr, nodeDescriptionAttr,
            nodeTypeAttr, scopeAttr,
            currentValueAttr, targetValueAttr, unitAttr,
            progressAttr, statusAttr,
            ownerNameAttr, sortOrderAttr,
            createdAtAttr, updatedAtAttr,
            nodeCycleIdAttr, parentIdAttr,
            weightAttr, versionAttr,
            childrenRel, parentRel, cycleRel
        ]

        cycleEntity.properties = [
            cycleIdAttr, nameAttr,
            startDateAttr, endDateAttr,
            isActiveAttr, isArchivedAttr,
            nodesRel
        ]

        // MARK: CommentEntity
        let commentEntity = NSEntityDescription()
        commentEntity.name = "CommentEntity"
        commentEntity.managedObjectClassName = "OKRAlignmentShared.CommentEntity"

        let commentIdAttr = NSAttributeDescription()
        commentIdAttr.name = "id"
        commentIdAttr.attributeType = .UUIDAttributeType
        commentIdAttr.isOptional = false

        let commentNodeIdAttr = NSAttributeDescription()
        commentNodeIdAttr.name = "nodeId"
        commentNodeIdAttr.attributeType = .UUIDAttributeType
        commentNodeIdAttr.isOptional = false

        let commentContentAttr = NSAttributeDescription()
        commentContentAttr.name = "content"
        commentContentAttr.attributeType = .stringAttributeType
        commentContentAttr.isOptional = false

        let commentAuthorAttr = NSAttributeDescription()
        commentAuthorAttr.name = "authorName"
        commentAuthorAttr.attributeType = .stringAttributeType
        commentAuthorAttr.isOptional = false

        let commentMentionsAttr = NSAttributeDescription()
        commentMentionsAttr.name = "mentionedUsers"
        commentMentionsAttr.attributeType = .stringAttributeType
        commentMentionsAttr.isOptional = true

        let commentCreatedAtAttr = NSAttributeDescription()
        commentCreatedAtAttr.name = "createdAt"
        commentCreatedAtAttr.attributeType = .dateAttributeType
        commentCreatedAtAttr.isOptional = false
        commentCreatedAtAttr.defaultValue = Date()

        let commentEditedAtAttr = NSAttributeDescription()
        commentEditedAtAttr.name = "editedAt"
        commentEditedAtAttr.attributeType = .dateAttributeType
        commentEditedAtAttr.isOptional = true

        let commentIsDeletedAttr = NSAttributeDescription()
        commentIsDeletedAttr.name = "softDeleted"
        commentIsDeletedAttr.attributeType = .booleanAttributeType
        commentIsDeletedAttr.isOptional = false
        commentIsDeletedAttr.defaultValue = false

        let commentParentCommentIdAttr = NSAttributeDescription()
        commentParentCommentIdAttr.name = "parentCommentId"
        commentParentCommentIdAttr.attributeType = .UUIDAttributeType
        commentParentCommentIdAttr.isOptional = true

        // Comment ↔ Node relationship
        let commentNodeRel = NSRelationshipDescription()
        commentNodeRel.name = "node"
        commentNodeRel.destinationEntity = nodeEntity
        commentNodeRel.minCount = 0
        commentNodeRel.maxCount = 1
        commentNodeRel.deleteRule = .nullifyDeleteRule

        let nodeCommentsRel = NSRelationshipDescription()
        nodeCommentsRel.name = "comments"
        nodeCommentsRel.destinationEntity = commentEntity
        nodeCommentsRel.minCount = 0
        nodeCommentsRel.maxCount = 0
        nodeCommentsRel.deleteRule = .cascadeDeleteRule

        commentNodeRel.inverseRelationship = nodeCommentsRel
        nodeCommentsRel.inverseRelationship = commentNodeRel

        commentEntity.properties = [
            commentIdAttr, commentNodeIdAttr,
            commentContentAttr, commentAuthorAttr, commentMentionsAttr,
            commentCreatedAtAttr, commentEditedAtAttr,
            commentIsDeletedAttr, commentParentCommentIdAttr,
            commentNodeRel
        ]

        // Add comments relationship to nodeEntity
        nodeEntity.properties.append(nodeCommentsRel)

        // 组装模型
        model.entities = [nodeEntity, cycleEntity, commentEntity]
        return model
    }

    // MARK: - Sample Data

    #if DEBUG
    /// 检查数据库是否为空，如果为空则加载示例数据
    /// 仅在 DEBUG 模式下执行，生产环境不会触发
    /// 应在应用启动后、首次加载视图时调用
    public func loadSampleDataIfNeeded() {
        let context = container.viewContext

        // 检查是否已有数据（检查是否有周期存在）
        let cycleRequest = NSFetchRequest<OKRCycleEntity>(entityName: "OKRCycleEntity")
        cycleRequest.fetchLimit = 1

        do {
            let count = try context.count(for: cycleRequest)
            guard count == 0 else {
                // 数据库已有数据，跳过加载
                Logger.app.info("数据库已有数据，跳过示例数据加载")
                return
            }
        } catch {
            Logger.app.error("检查数据库状态失败: \(error.localizedDescription)")
            return
        }

        Logger.app.info("数据库为空，开始加载示例数据...")
        loadSampleData()
    }

    /// 加载一套完整的企业 OKR 示例数据
    /// 创建一个活跃周期，并构建包含企业级 O→KR→个人级 O→个人级 KR 的完整树结构
    private func loadSampleData() {
        let context = container.viewContext
        let now = Date()
        let calendar = Calendar.current

        // MARK: - 创建示例周期
        guard let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 31))
        else { return }

        let cycle = OKRCycleEntity(context: context)
        cycle.id = UUID()
        cycle.name = "2026 Q1"
        cycle.startDate = startDate
        cycle.endDate = endDate
        cycle.isActive = true
        cycle.isArchived = false

        // MARK: - 企业级 Objective（根节点）
        let rootO = createNodeEntity(
            in: context,
            title: "成为行业领先的AI解决方案提供商",
            description: "通过技术创新和市场拓展，在2026年确立公司在AI解决方案领域的领导地位",
            nodeType: .objective,
            scope: .enterprise,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 0, // 由子节点汇总计算
            status: .inProgress,
            ownerName: "CEO 王明",
            sortOrder: 0,
            parent: nil,
            cycle: cycle,
            createdAt: now
        )

        // MARK: - 企业级 KR（3个）

        // 企业 KR 1：营收增长
        let ekr1 = createNodeEntity(
            in: context,
            title: "年度营收增长50%，达到1.2亿元",
            description: "通过新客户获取和老客户增购实现营收目标",
            nodeType: .keyResult,
            scope: .enterprise,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 45,
            status: .inProgress,
            ownerName: "CFO 李华",
            sortOrder: 0,
            parent: rootO,
            cycle: cycle,
            createdAt: now
        )

        // 企业 KR 2：用户增长
        let ekr2 = createNodeEntity(
            in: context,
            title: "企业客户数量从200增长到500家",
            description: "扩大市场覆盖面，重点拓展金融、医疗、制造三大行业",
            nodeType: .keyResult,
            scope: .enterprise,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 35,
            status: .atRisk,
            ownerName: "CMO 张丽",
            sortOrder: 1,
            parent: rootO,
            cycle: cycle,
            createdAt: now
        )

        // 企业 KR 3：技术领先
        let ekr3 = createNodeEntity(
            in: context,
            title: "核心AI模型准确率达到行业Top 3水平",
            description: "持续投入研发，在NLP和CV领域保持技术竞争力",
            nodeType: .keyResult,
            scope: .enterprise,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 60,
            status: .inProgress,
            ownerName: "CTO 刘强",
            sortOrder: 2,
            parent: rootO,
            cycle: cycle,
            createdAt: now
        )

        // MARK: - 企业 KR1 下的个人 Objective（3个）

        // 个人 O 1-1
        let po1_1 = createNodeEntity(
            in: context,
            title: "提升新客户转化率",
            description: "优化销售漏斗，缩短销售周期，提升从线索到签约的转化率",
            nodeType: .objective,
            scope: .personal,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 50,
            status: .inProgress,
            ownerName: "销售总监 赵磊",
            sortOrder: 0,
            parent: ekr1,
            cycle: cycle,
            createdAt: now
        )

        // 个人 O 1-2
        let po1_2 = createNodeEntity(
            in: context,
            title: "提升老客户续约率与增购额",
            description: "通过客户成功体系建设，提高客户满意度和续约意愿",
            nodeType: .objective,
            scope: .personal,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 55,
            status: .inProgress,
            ownerName: "客户成功总监 陈静",
            sortOrder: 1,
            parent: ekr1,
            cycle: cycle,
            createdAt: now
        )

        // 个人 O 1-3
        let po1_3 = createNodeEntity(
            in: context,
            title: "拓展新行业客户渠道",
            description: "建立金融和医疗行业的销售渠道和合作伙伴网络",
            nodeType: .objective,
            scope: .personal,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 30,
            status: .atRisk,
            ownerName: "渠道经理 周宇",
            sortOrder: 2,
            parent: ekr1,
            cycle: cycle,
            createdAt: now
        )

        // MARK: - 企业 KR2 下的个人 Objective（2个）

        let po2_1 = createNodeEntity(
            in: context,
            title: "建立高效的获客增长引擎",
            description: "构建内容营销+SEO+SEM组合拳的自动化获客体系",
            nodeType: .objective,
            scope: .personal,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 40,
            status: .inProgress,
            ownerName: "增长负责人 孙悦",
            sortOrder: 0,
            parent: ekr2,
            cycle: cycle,
            createdAt: now
        )

        let po2_2 = createNodeEntity(
            in: context,
            title: "打造标杆客户案例库",
            description: "在金融、医疗、制造三大行业各产出3个以上标杆案例",
            nodeType: .objective,
            scope: .personal,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 25,
            status: .atRisk,
            ownerName: "市场经理 吴婷",
            sortOrder: 1,
            parent: ekr2,
            cycle: cycle,
            createdAt: now
        )

        // MARK: - 企业 KR3 下的个人 Objective（2个）

        let po3_1 = createNodeEntity(
            in: context,
            title: "提升NLP模型性能与准确率",
            description: "优化模型架构和训练流程，在主流benchmark上达到SOTA水平",
            nodeType: .objective,
            scope: .personal,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 65,
            status: .inProgress,
            ownerName: "NLP技术负责人 黄伟",
            sortOrder: 0,
            parent: ekr3,
            cycle: cycle,
            createdAt: now
        )

        let po3_2 = createNodeEntity(
            in: context,
            title: "构建可扩展的AI平台基础设施",
            description: "搭建统一的模型训练和推理平台，支撑业务快速迭代",
            nodeType: .objective,
            scope: .personal,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 55,
            status: .inProgress,
            ownerName: "架构师 林峰",
            sortOrder: 1,
            parent: ekr3,
            cycle: cycle,
            createdAt: now
        )

        // MARK: - 叶子 KR（个人级，有 current/target 值）

        // --- 个人 O 1-1 的叶子 KR ---
        createNodeEntity(
            in: context,
            title: "线索到签约转化率从8%提升到15%",
            description: "优化销售流程，加强需求挖掘和方案匹配",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 11,
            targetValue: 15,
            unit: "%",
            progress: 73,
            status: .inProgress,
            ownerName: "销售代表 马超",
            sortOrder: 0,
            parent: po1_1,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "平均销售周期从45天缩短到30天",
            description: "精简审批流程，提供标准化解决方案模板",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 38,
            targetValue: 30,
            unit: "天",
            progress: 47,
            status: .atRisk,
            ownerName: "销售运营 钱进",
            sortOrder: 1,
            parent: po1_1,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "每月新增合格线索从50个提升到120个",
            description: "通过内容营销和行业活动扩大线索来源",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 75,
            targetValue: 120,
            unit: "个",
            progress: 63,
            status: .inProgress,
            ownerName: "市场专员 朱琳",
            sortOrder: 2,
            parent: po1_1,
            cycle: cycle,
            createdAt: now
        )

        // --- 个人 O 1-2 的叶子 KR ---
        createNodeEntity(
            in: context,
            title: "老客户续约率从75%提升到90%",
            description: "建立客户健康评分体系，提前预警流失风险",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 82,
            targetValue: 90,
            unit: "%",
            progress: 91,
            status: .inProgress,
            ownerName: "客户成功经理 杨帆",
            sortOrder: 0,
            parent: po1_2,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "客户增购额占比从15%提升到30%",
            description: "推出增值服务包和升级方案，提升客户生命周期价值",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 20,
            targetValue: 30,
            unit: "%",
            progress: 67,
            status: .inProgress,
            ownerName: "客户成功经理 方芳",
            sortOrder: 1,
            parent: po1_2,
            cycle: cycle,
            createdAt: now
        )

        // --- 个人 O 1-3 的叶子 KR ---
        createNodeEntity(
            in: context,
            title: "金融行业新签约客户从5家增长到15家",
            description: "建立银行和券商的直销渠道",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 7,
            targetValue: 15,
            unit: "家",
            progress: 47,
            status: .atRisk,
            ownerName: "金融行业销售 郑凯",
            sortOrder: 0,
            parent: po1_3,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "医疗行业新签约客户从2家增长到10家",
            description: "联合合作伙伴开拓医院和药企市场",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 3,
            targetValue: 10,
            unit: "家",
            progress: 30,
            status: .atRisk,
            ownerName: "医疗行业销售 韩梅",
            sortOrder: 1,
            parent: po1_3,
            cycle: cycle,
            createdAt: now
        )

        // --- 个人 O 2-1 的叶子 KR ---
        createNodeEntity(
            in: context,
            title: "官网月均自然流量从5000提升到15000",
            description: "通过SEO优化和内容营销提升搜索排名",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 8000,
            targetValue: 15000,
            unit: "次",
            progress: 53,
            status: .inProgress,
            ownerName: "SEO专员 徐航",
            sortOrder: 0,
            parent: po2_1,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "MQL到SQL转化率从20%提升到35%",
            description: "优化线索评分模型，提升线索质量",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 25,
            targetValue: 35,
            unit: "%",
            progress: 71,
            status: .inProgress,
            ownerName: "营销运营 何欣",
            sortOrder: 1,
            parent: po2_1,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "SEM获客成本从800元降低到500元",
            description: "优化关键词投放策略，提升广告ROI",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 650,
            targetValue: 500,
            unit: "元",
            progress: 30,
            status: .atRisk,
            ownerName: "SEM专员 罗勇",
            sortOrder: 2,
            parent: po2_1,
            cycle: cycle,
            createdAt: now
        )

        // --- 个人 O 2-2 的叶子 KR ---
        createNodeEntity(
            in: context,
            title: "金融行业产出标杆案例3个",
            description: "联合头部银行和券商打造行业标杆",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 1,
            targetValue: 3,
            unit: "个",
            progress: 33,
            status: .atRisk,
            ownerName: "内容运营 邓超",
            sortOrder: 0,
            parent: po2_2,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "医疗行业产出标杆案例3个",
            description: "展示AI在医疗影像和药物研发领域的应用成果",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 1,
            targetValue: 3,
            unit: "个",
            progress: 33,
            status: .atRisk,
            ownerName: "内容运营 唐敏",
            sortOrder: 1,
            parent: po2_2,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "制造业产出标杆案例3个",
            description: "聚焦智能制造和质检场景打造标杆",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 2,
            targetValue: 3,
            unit: "个",
            progress: 67,
            status: .inProgress,
            ownerName: "行业解决方案 谢峰",
            sortOrder: 2,
            parent: po2_2,
            cycle: cycle,
            createdAt: now
        )

        // --- 个人 O 3-1 的叶子 KR ---
        createNodeEntity(
            in: context,
            title: "NLP基准测试F1分数从85提升到92",
            description: "优化模型架构，引入最新的预训练技术",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 88,
            targetValue: 92,
            unit: "分",
            progress: 75,
            status: .inProgress,
            ownerName: "算法工程师 曹亮",
            sortOrder: 0,
            parent: po3_1,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "模型推理延迟从200ms降低到100ms",
            description: "通过模型蒸馏和量化技术优化推理性能",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 150,
            targetValue: 100,
            unit: "ms",
            progress: 50,
            status: .inProgress,
            ownerName: "性能优化工程师 高明",
            sortOrder: 1,
            parent: po3_1,
            cycle: cycle,
            createdAt: now
        )

        // --- 个人 O 3-2 的叶子 KR ---
        createNodeEntity(
            in: context,
            title: "GPU集群利用率从40%提升到75%",
            description: "优化资源调度算法，实现训练任务智能排队",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 55,
            targetValue: 75,
            unit: "%",
            progress: 73,
            status: .inProgress,
            ownerName: "DevOps工程师 许涛",
            sortOrder: 0,
            parent: po3_2,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "模型部署时间从2天缩短到2小时",
            description: "构建自动化CI/CD流水线和一键部署工具",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 8,
            targetValue: 2,
            unit: "小时",
            progress: 25,
            status: .atRisk,
            ownerName: "平台工程师 冯杰",
            sortOrder: 1,
            parent: po3_2,
            cycle: cycle,
            createdAt: now
        )

        createNodeEntity(
            in: context,
            title: "平台可用性从99.5%提升到99.95%",
            description: "建立完善的监控告警和故障自动恢复机制",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 99.7,
            targetValue: 99.95,
            unit: "%",
            progress: 80,
            status: .inProgress,
            ownerName: "SRE工程师 彭辉",
            sortOrder: 2,
            parent: po3_2,
            cycle: cycle,
            createdAt: now
        )

        // MARK: - 保存上下文
        do {
            try context.save()
            Logger.app.info("示例数据加载成功：1个周期，1个企业O，3个企业KR，7个个人O，19个叶子KR")
        } catch {
            Logger.app.error("示例数据保存失败: \(error.localizedDescription)")
        }
    }

    /// 创建一个 OKRNodeEntity 并设置所有属性
    private func createNodeEntity(
        in context: NSManagedObjectContext,
        title: String,
        description: String?,
        nodeType: NodeType,
        scope: Scope,
        currentValue: Double = 0,
        targetValue: Double = 0,
        unit: String? = nil,
        progress: Double,
        status: NodeStatus,
        ownerName: String,
        sortOrder: Int,
        parent: OKRNodeEntity?,
        cycle: OKRCycleEntity,
        createdAt: Date
    ) -> OKRNodeEntity {
        let entity = OKRNodeEntity(context: context)
        entity.id = UUID()
        entity.title = title
        entity.nodeDescription = description
        entity.nodeType = nodeType.rawValue
        entity.scope = scope.rawValue
        entity.currentValue = currentValue
        entity.targetValue = targetValue
        entity.unit = unit
        entity.progress = progress
        entity.status = status.rawValue
        entity.ownerName = ownerName
        entity.sortOrder = Int64(sortOrder)
        entity.weight = 1.0
        entity.version = 0
        entity.createdAt = createdAt
        entity.updatedAt = createdAt
        entity.parentId = parent?.id
        entity.cycleId = cycle.id
        entity.parent = parent
        entity.cycle = cycle
        return entity
    }
    #endif
}

// MARK: - CloudKit Container Helper

#if canImport(CloudKit)
extension NSPersistentCloudKitContainer {
    /// 工厂方法：尝试创建CloudKit容器
    /// 如果CloudKit不可用则返回nil，调用方将回退到普通容器
    fileprivate static func persistentCloudKitContainer(
        name: String,
        managedObjectModel: NSManagedObjectModel,
        inMemory: Bool
    ) -> NSPersistentCloudKitContainer? {
        // 检查iCloud容器是否可用
        // 如果未配置iCloud则返回nil
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return nil
        }
        return NSPersistentCloudKitContainer(
            name: name,
            managedObjectModel: managedObjectModel
        )
    }
}
#endif
