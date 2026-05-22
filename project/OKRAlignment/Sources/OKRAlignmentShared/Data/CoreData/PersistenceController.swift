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

    // MARK: - Initialization

    /// 创建持久化控制器
    /// - Parameter inMemory: 是否使用内存存储（预览和测试时使用）
    private init(inMemory: Bool = false) {
        self.isInMemory = inMemory

        // 使用程序化的数据模型定义
        // Swift Package中没有.xcdatamodeld文件，需要在代码中定义模型
        let model = PersistenceController.createManagedObjectModel()

        // 根据是否需要CloudKit选择容器类型
        // 注意：CloudKit需要有效的iCloud容器配置
        #if canImport(CloudKit)
        // 尝试使用CloudKit容器
        if let cloudKitContainer = NSPersistentCloudKitContainer.persistentCloudKitContainer(
            name: "OKRAlignment",
            managedObjectModel: model,
            inMemory: inMemory
        ) {
            self.container = cloudKitContainer
        } else {
            self.container = NSPersistentContainer(
                name: "OKRAlignment",
                managedObjectModel: model
            )
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
                fatalError("Core Data持久化存储加载失败: \(error), \(error.userInfo)")
            }
            self?.setupContainer()
        }
    }

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

        // 组装模型
        model.entities = [nodeEntity, cycleEntity]
        return model
    }
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
