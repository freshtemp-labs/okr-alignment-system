// OKRAlignmentShared/Data/Repository/CoreDataOKRRepository.swift

import CoreData
import Foundation

// MARK: - Errors

/// Core Data Repository 专用错误类型
///
/// 封装了所有可能在数据访问层发生的错误，将底层Core Data错误和验证错误
/// 转换为应用特定的、用户友好的错误信息。
public enum OKRRepositoryError: LocalizedError, Equatable {
    /// 找不到指定ID的节点
    case nodeNotFound(UUID)
    /// 找不到指定ID的周期
    case cycleNotFound(UUID)
    /// 操作需要叶子节点，但目标不是叶子
    case notALeafNode(UUID)
    /// 非级联删除时节点存在子节点
    case hasChildren(UUID)
    /// 节点ID冲突（创建时）
    case duplicateNodeId(UUID)
    /// 周期ID冲突（创建时）
    case duplicateCycleId(UUID)
    /// Core Data底层错误
    case coreDataError(String)
    /// 映射错误
    case mappingError(String)
    /// 未知错误
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .nodeNotFound(let id):
            return "找不到ID为 \(id) 的节点"
        case .cycleNotFound(let id):
            return "找不到ID为 \(id) 的周期"
        case .notALeafNode(let id):
            return "节点 \(id) 不是叶子节点，无法直接更新数值"
        case .hasChildren(let id):
            return "节点 \(id) 存在子节点，请先删除子节点或使用级联删除"
        case .duplicateNodeId(let id):
            return "已存在ID为 \(id) 的节点"
        case .duplicateCycleId(let id):
            return "已存在ID为 \(id) 的周期"
        case .coreDataError(let message):
            return "数据库错误: \(message)"
        case .mappingError(let message):
            return "数据映射错误: \(message)"
        case .unknown:
            return "未知的数据访问错误"
        }
    }
    
    public static func == (lhs: OKRRepositoryError, rhs: OKRRepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.nodeNotFound(let a), .nodeNotFound(let b)): return a == b
        case (.cycleNotFound(let a), .cycleNotFound(let b)): return a == b
        case (.notALeafNode(let a), .notALeafNode(let b)): return a == b
        case (.hasChildren(let a), .hasChildren(let b)): return a == b
        case (.duplicateNodeId(let a), .duplicateNodeId(let b)): return a == b
        case (.duplicateCycleId(let a), .duplicateCycleId(let b)): return a == b
        case (.coreDataError(let a), .coreDataError(let b)): return a == b
        case (.mappingError(let a), .mappingError(let b)): return a == b
        case (.unknown, .unknown): return true
        default: return false
        }
    }
}

// MARK: - Repository Implementation

/// Core Data实现的OKR数据仓库
///
/// `CoreDataOKRRepository`是`OKRRepositoryProtocol`的具体实现，使用`NSPersistentContainer`
/// 管理Core Data持久化存储。所有Core Data操作均在正确的`NSManagedObjectContext`线程中
/// 通过`context.perform`执行，确保线程安全。
///
/// ## 线程安全
/// - 本类标记为`@unchecked Sendable`，因为`NSPersistentContainer`由Apple保证线程安全
/// - 每个写操作使用独立的background context并通过`perform`执行
/// - 读操作同样使用`perform`确保与Core Data线程模型兼容
///
/// ## 级联进度重算
/// 当调用`updateLeafValue`时，会自动向上遍历所有父节点，根据子节点进度的平均值
/// 重新计算每个父节点的总进度。
///
/// ## 使用示例
/// ```swift
/// let container: NSPersistentContainer = /* 已配置的容器 */
/// let repository = CoreDataOKRRepository(container: container)
/// let rootNodes = try await repository.fetchRootNodes(cycleId: myCycleId)
/// ```
public final class CoreDataOKRRepository: OKRRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Core Data持久化容器
    private let container: NSPersistentContainer
    
    // MARK: - Initialization
    
    /// 创建仓库实例
    ///
    /// - Parameter container: 已加载持久化存储的`NSPersistentContainer`
    public init(container: NSPersistentContainer) {
        self.container = container
    }
    
    // MARK: - Context Factory
    
    /// 创建新的后台上下文用于写操作
    ///
    /// 每个写操作使用独立的后台上下文，避免并发冲突。
    private func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - Node Queries
    
    /// 获取指定周期的所有根节点（无父节点的Objective）
    ///
    /// 查询条件：
    /// - `parent == nil`（无父节点）
    /// - `cycle.id == cycleId`（属于指定周期）
    /// - 按`sortOrder`升序排列
    ///
    /// - Parameter cycleId: 周期ID
    /// - Returns: 根节点数组
    /// - Throws: `OKRRepositoryError.coreDataError` 当查询失败时
    public func fetchRootNodes(cycleId: UUID?) async throws -> [OKRNode] {
        let context = container.newBackgroundContext()
        
        return try await context.perform {
            let request = NSFetchRequest<OKRNodeEntity>(entityName: "OKRNodeEntity")
            
            var predicates: [NSPredicate] = [
                NSPredicate(format: "parent == nil")
            ]
            
            if let cycleId = cycleId {
                predicates.append(NSPredicate(format: "cycle.id == %@", cycleId as CVarArg))
            } else {
                predicates.append(NSPredicate(format: "cycle == nil"))
            }
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \OKRNodeEntity.sortOrder, ascending: true)]
            
            // 预抓取子节点关系，减少后续查询
            request.relationshipKeyPathsForPrefetching = ["children", "cycle"]
            
            do {
                let entities = try context.fetch(request)
                return try entities.map { try EntityToDomainMapper.map(entity: $0) }
            } catch let error as OKRRepositoryError {
                throw error
            } catch {
                throw OKRRepositoryError.coreDataError(error.localizedDescription)
            }
        }
    }
    
    /// 根据ID获取单个节点（包含完整子树）
    ///
    /// 此方法通过`relationshipKeyPathsForPrefetching`预抓取所有子节点关系，
    /// 然后递归映射为完整的领域模型树。
    ///
    /// - Parameter id: 节点ID
    /// - Returns: 完整的`OKRNode`（含子树），若不存在则返回`nil`
    /// - Throws: `OKRRepositoryError.coreDataError` 当查询失败时
    public func fetchNode(id: UUID) async throws -> OKRNode? {
        let context = container.newBackgroundContext()
        
        return try await context.perform {
            guard let entity = try self.fetchNodeEntity(id: id, in: context) else {
                return nil
            }
            
            // 预抓取子节点关系以加载完整树
            self.prefetchChildrenRecursively(entity: entity, in: context)
            
            do {
                return try EntityToDomainMapper.map(entity: entity)
            } catch {
                throw OKRRepositoryError.mappingError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Node Mutations
    
    /// 创建新节点
    ///
    /// 如果节点指定了`parentId`，会自动建立父子关系。如果指定了`cycleId`，
    /// 会自动关联到对应周期。
    ///
    /// - Parameter node: 要创建的领域模型节点
    /// - Returns: 创建后的节点
    /// - Throws: `OKRRepositoryError.duplicateNodeId` 当ID已存在时
    public func createNode(_ node: OKRNode) async throws -> OKRNode {
        let context = newBackgroundContext()
        
        return try await context.perform {
            // 检查ID是否已存在
            let existing = try self.fetchNodeEntity(id: node.id, in: context)
            guard existing == nil else {
                throw OKRRepositoryError.duplicateNodeId(node.id)
            }
            
            do {
                let entity = try DomainToEntityMapper.map(domain: node, context: context)
                try context.save()
                return try EntityToDomainMapper.map(entity: entity)
            } catch let error as OKRRepositoryError {
                throw error
            } catch {
                throw OKRRepositoryError.coreDataError(error.localizedDescription)
            }
        }
    }
    
    /// 更新现有节点
    ///
    /// 通过ID查找现有节点并更新其所有属性。会递归更新子节点树。
    ///
    /// - Parameter node: 包含更新数据的节点
    /// - Returns: 更新后的节点
    /// - Throws: `OKRRepositoryError.nodeNotFound` 当节点不存在时
    public func updateNode(_ node: OKRNode) async throws -> OKRNode {
        let context = newBackgroundContext()
        
        return try await context.perform {
            guard let existingEntity = try self.fetchNodeEntity(id: node.id, in: context) else {
                throw OKRRepositoryError.nodeNotFound(node.id)
            }
            
            // 删除旧实体以便完全重建（确保关系一致性）
            context.delete(existingEntity)
            
            do {
                let entity = try DomainToEntityMapper.map(domain: node, context: context)
                try context.save()
                return try EntityToDomainMapper.map(entity: entity)
            } catch let error as OKRRepositoryError {
                throw error
            } catch {
                throw OKRRepositoryError.coreDataError(error.localizedDescription)
            }
        }
    }
    
    /// 删除节点
    ///
    /// 根据`cascade`参数决定是否级联删除子节点。
    ///
    /// - Parameters:
    ///   - id: 要删除的节点ID
    ///   - cascade: 是否级联删除子节点
    /// - Throws:
    ///   - `OKRRepositoryError.nodeNotFound` 当节点不存在
    ///   - `OKRRepositoryError.hasChildren` 当非级联删除但存在子节点
    public func deleteNode(id: UUID, cascade: Bool) async throws {
        let context = newBackgroundContext()
        
        try await context.perform {
            guard let entity = try self.fetchNodeEntity(id: id, in: context) else {
                throw OKRRepositoryError.nodeNotFound(id)
            }
            
            // 检查子节点
            let hasChildren = (entity.children?.count ?? 0) > 0
            if hasChildren && !cascade {
                throw OKRRepositoryError.hasChildren(id)
            }
            
            // 级联删除子节点
            if cascade && hasChildren {
                self.deleteNodeEntityCascade(entity: entity, in: context)
            }
            
            context.delete(entity)
            
            do {
                try context.save()
            } catch {
                throw OKRRepositoryError.coreDataError(error.localizedDescription)
            }
        }
    }
    
    /// 更新叶子KR的当前值并触发级联进度重算
    ///
    /// 此方法执行以下步骤：
    /// 1. 验证目标节点是叶子KR
    /// 2. 更新`currentValue`并重新计算该节点的`progress`
    /// 3. 向上遍历所有父节点，按子节点进度的平均值重新计算`progress`
    /// 4. 根据新的进度更新每个受影响节点的状态
    ///
    /// - Parameters:
    ///   - nodeId: 叶子KR节点ID
    ///   - newValue: 新的当前值
    /// - Returns: 更新后的叶子节点
    /// - Throws:
    ///   - `OKRRepositoryError.nodeNotFound` 当节点不存在
    ///   - `OKRRepositoryError.notALeafNode` 当节点不是叶子
    public func updateLeafValue(nodeId: UUID, newValue: Double) async throws -> OKRNode {
        let context = newBackgroundContext()
        
        return try await context.perform {
            guard let entity = try self.fetchNodeEntity(id: nodeId, in: context) else {
                throw OKRRepositoryError.nodeNotFound(nodeId)
            }
            
            // 验证是叶子节点
            let childCount = entity.children?.count ?? 0
            guard childCount == 0, entity.nodeType == NodeType.keyResult.rawValue else {
                throw OKRRepositoryError.notALeafNode(nodeId)
            }
            
            // 更新当前值和进度
            entity.currentValue = newValue
            entity.progress = self.calculateProgress(current: newValue, target: entity.targetValue)
            entity.status = self.inferStatus(from: entity.progress).rawValue
            entity.updatedAt = Date()
            
            // 级联向上更新父节点进度
            self.cascadeProgressUpdate(entity: entity, in: context)
            
            do {
                try context.save()
                return try EntityToDomainMapper.map(entity: entity)
            } catch {
                throw OKRRepositoryError.coreDataError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Cycle Queries
    
    /// 获取所有周期
    ///
    /// 结果按开始日期降序排列（最近的周期在前）。
    ///
    /// - Returns: 所有周期数组
    /// - Throws: `OKRRepositoryError.coreDataError` 当查询失败时
    public func fetchCycles() async throws -> [OKRCycle] {
        let context = container.newBackgroundContext()
        
        return try await context.perform {
            let request = NSFetchRequest<OKRCycleEntity>(entityName: "OKRCycleEntity")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \OKRCycleEntity.startDate, ascending: false)]
            
            do {
                let entities = try context.fetch(request)
                return EntityToDomainMapper.map(cycleEntities: entities)
            } catch {
                throw OKRRepositoryError.coreDataError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Cycle Mutations
    
    /// 创建新周期
    ///
    /// - Parameter cycle: 要创建的周期领域模型
    /// - Returns: 创建后的周期
    /// - Throws: `OKRRepositoryError.duplicateCycleId` 当ID已存在时
    public func createCycle(_ cycle: OKRCycle) async throws -> OKRCycle {
        let context = newBackgroundContext()
        
        return try await context.perform {
            // 检查ID是否已存在
            let request = NSFetchRequest<OKRCycleEntity>(entityName: "OKRCycleEntity")
            request.predicate = NSPredicate(format: "id == %@", cycle.id as CVarArg)
            request.fetchLimit = 1
            
            let count = try context.count(for: request)
            guard count == 0 else {
                throw OKRRepositoryError.duplicateCycleId(cycle.id)
            }
            
            do {
                let entity = try DomainToEntityMapper.map(domain: cycle, context: context)
                try context.save()
                return EntityToDomainMapper.map(entity: entity)
            } catch let error as OKRRepositoryError {
                throw error
            } catch {
                throw OKRRepositoryError.coreDataError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Persistence
    
    /// 保存所有未保存的更改到持久化存储
    ///
    /// 此方法使用`NSPersistentContainer.viewContext`进行保存。
    /// 通常在所有后台操作完成后调用以确保所有更改持久化。
    ///
    /// - Throws: `OKRRepositoryError.coreDataError` 当保存失败时
    public func save() async throws {
        try await container.viewContext.perform {
            guard self.container.viewContext.hasChanges else { return }
            do {
                try self.container.viewContext.save()
            } catch {
                throw OKRRepositoryError.coreDataError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// 在指定上下文中根据ID获取节点实体
    ///
    /// - Parameters:
    ///   - id: 节点唯一标识符
    ///   - context: 托管对象上下文
    /// - Returns: 找到的实体，若不存在则返回`nil`
    private func fetchNodeEntity(id: UUID, in context: NSManagedObjectContext) throws -> OKRNodeEntity? {
        let request = NSFetchRequest<OKRNodeEntity>(entityName: "OKRNodeEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    
    /// 递归预抓取实体的所有子节点
    ///
    /// 通过遍历关系触发Core Data的fault填充，确保后续映射时
    /// 所有子节点数据已在内存中。
    ///
    /// - Parameters:
    ///   - entity: 要预抓取的根实体
    ///   - context: 托管对象上下文
    private func prefetchChildrenRecursively(entity: OKRNodeEntity, in context: NSManagedObjectContext) {
        guard let children = entity.children?.array as? [OKRNodeEntity] else { return }
        for child in children {
            prefetchChildrenRecursively(entity: child, in: context)
        }
    }
    
    /// 级联删除节点及其所有子节点
    ///
    /// 递归遍历并删除所有后代节点。
    ///
    /// - Parameters:
    ///   - entity: 要删除的节点实体
    ///   - context: 托管对象上下文
    private func deleteNodeEntityCascade(entity: OKRNodeEntity, in context: NSManagedObjectContext) {
        guard let children = entity.children?.array as? [OKRNodeEntity] else { return }
        for child in children {
            deleteNodeEntityCascade(entity: child, in: context)
            context.delete(child)
        }
    }
    
    /// 向上级联更新父节点的进度
    ///
    /// 从指定节点开始向上遍历，对每个父节点根据其所有直接子节点的进度
    /// 重新计算平均值作为新的总进度，并同步更新状态和更新时间。
    ///
    /// - Parameters:
    ///   - entity: 起始节点（已更新的叶子或子节点）
    ///   - context: 托管对象上下文
    private func cascadeProgressUpdate(entity: OKRNodeEntity, in context: NSManagedObjectContext) {
        var currentParent = entity.parent
        
        while let parent = currentParent {
            guard let children = parent.children?.array as? [OKRNodeEntity], !children.isEmpty else {
                currentParent = parent.parent
                continue
            }
            
            // 计算子节点进度的平均值
            let averageProgress = children.map(\.progress).reduce(0.0, +) / Double(children.count)
            parent.progress = averageProgress
            parent.status = inferStatus(from: averageProgress).rawValue
            parent.updatedAt = Date()
            
            currentParent = parent.parent
        }
    }
    
    /// 根据当前值和目标值计算进度百分比
    ///
    /// - Parameters:
    ///   - current: 当前值
    ///   - target: 目标值
    /// - Returns: 进度值，范围`[0.0, 100.0]`。目标为0时返回0
    private func calculateProgress(current: Double, target: Double) -> Double {
        guard target != 0 else { return 0.0 }
        return min(100.0, max(0.0, (current / target) * 100.0))
    }
    
    /// 根据进度值推断节点状态
    ///
    /// 进度映射规则（进度范围 0-100）：
    /// - `progress <= 0.0` → `.notStarted`
    /// - `progress >= 100.0` → `.completed`
    /// - `0.0 < progress < 30.0` → `.atRisk`
    /// - 其他 → `.inProgress`
    ///
    /// - Parameter progress: 进度值（0-100）
    /// - Returns: 推断的节点状态
    private func inferStatus(from progress: Double) -> NodeStatus {
        if progress <= 0.0 {
            return .notStarted
        } else if progress >= 100.0 {
            return .completed
        } else if progress < 30.0 {
            return .atRisk
        } else {
            return .inProgress
        }
    }
}
