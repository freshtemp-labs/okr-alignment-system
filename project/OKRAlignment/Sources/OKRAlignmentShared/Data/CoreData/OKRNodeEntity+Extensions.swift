import Foundation
import CoreData

/// OKRNode Core Data实体类
/// 对应数据库中的OKR节点存储，提供与领域模型OKRNode的双向转换
/// 所有属性均为@NSManaged，由Core Data运行时管理生命周期
@objc(OKRNodeEntity)
public final class OKRNodeEntity: NSManagedObject {

    // MARK: - Properties

    /// 节点唯一标识符
    @NSManaged public var id: UUID

    /// 节点标题
    @NSManaged public var title: String

    /// 节点详细描述
    @NSManaged public var nodeDescription: String?

    /// 节点类型字符串（存储为rawValue）
    @NSManaged public var nodeType: String

    /// 范围字符串（存储为rawValue）
    @NSManaged public var scope: String

    /// 当前实际值
    @NSManaged public var currentValue: Double

    /// 目标值
    @NSManaged public var targetValue: Double

    /// 计量单位
    @NSManaged public var unit: String?

    /// 进度百分比（0.0 - 100.0）
    @NSManaged public var progress: Double

    /// 状态字符串（存储为rawValue）
    @NSManaged public var status: String

    /// 负责人姓名
    @NSManaged public var ownerName: String

    /// 同级排序索引
    @NSManaged public var sortOrder: Int64

    /// 创建时间
    @NSManaged public var createdAt: Date

    /// 最后更新时间
    @NSManaged public var updatedAt: Date

    /// 所属周期ID（可选）
    @NSManaged public var cycleId: UUID?

    /// 父节点ID（可选，nil表示根节点）
    /// 通过parentId建立树状结构关系
    @NSManaged public var parentId: UUID?

    /// Ordered to-many relationship to child nodes
    @NSManaged public var children: NSOrderedSet?

    /// To-one relationship to parent node (inverse of children)
    @NSManaged public var parent: OKRNodeEntity?

    /// To-one relationship to the owning cycle
    @NSManaged public var cycle: OKRCycleEntity?

    // MARK: - Fetch Request

    /// 创建默认的Fetch Request
    /// 用于@FetchRequest包装器获取所有OKR节点
    @nonobjc public class func fetchRequest() -> NSFetchRequest<OKRNodeEntity> {
        let request = NSFetchRequest<OKRNodeEntity>(entityName: "OKRNodeEntity")
        // 默认按排序索引和创建时间排序
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \OKRNodeEntity.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \OKRNodeEntity.createdAt, ascending: true)
        ]
        return request
    }
}

// MARK: - Type Conversions

extension OKRNodeEntity {

    /// 节点类型枚举值
    /// 从存储的字符串转换为NodeType枚举
    public var nodeTypeEnum: NodeType {
        get {
            NodeType(rawValue: nodeType) ?? .objective
        }
        set {
            nodeType = newValue.rawValue
        }
    }

    /// 范围枚举值
    /// 从存储的字符串转换为Scope枚举
    public var scopeEnum: Scope {
        get {
            Scope(rawValue: scope) ?? .enterprise
        }
        set {
            scope = newValue.rawValue
        }
    }

    /// 状态枚举值
    /// 从存储的字符串转换为NodeStatus枚举
    public var statusEnum: NodeStatus {
        get {
            NodeStatus(rawValue: status) ?? .notStarted
        }
        set {
            status = newValue.rawValue
        }
    }

    /// 是否为叶子节点（无子节点且类型为KR）
    /// 叶子节点是进度追踪的最小单位
    public var isLeaf: Bool {
        // 由于Core Data没有直接存储children数组
        // 需要通过查询来判断是否有子节点
        nodeTypeEnum == .keyResult && parentId != nil
    }
}

// MARK: - Domain Model Conversion

extension OKRNodeEntity {

    /// 从领域模型转换为Core Data实体
    /// 如果不存在则创建新实体，如果已存在则更新属性
    /// - Parameters:
    ///   - domainModel: OKRNode领域模型
    ///   - context: Core Data上下文（用于创建新实体）
    public func fromDomainModel(_ domainModel: OKRNode) {
        // 仅在id不匹配时更新（创建场景）
        // 编辑场景下id应保持不变
        if id != domainModel.id {
            id = domainModel.id
        }

        // 更新基础属性
        title = domainModel.title
        nodeDescription = domainModel.nodeDescription
        nodeType = domainModel.nodeType.rawValue
        scope = domainModel.scope.rawValue
        currentValue = domainModel.currentValue
        targetValue = domainModel.targetValue
        unit = domainModel.unit
        progress = domainModel.progress
        status = domainModel.status.rawValue
        ownerName = domainModel.ownerName
        sortOrder = Int64(domainModel.sortOrder)
        parentId = domainModel.parentId
        cycleId = domainModel.cycleId

        // 创建时间只在首次创建时设置
        if createdAt == Date(timeIntervalSince1970: 0) {
            createdAt = domainModel.createdAt
        }
        // 更新时间总是设置为当前时间
        updatedAt = Date()
    }

    /// 转换为领域模型
    /// - Returns: OKRNode领域模型实例
    public func toDomainModel() -> OKRNode {
        OKRNode(
            id: id,
            title: title,
            nodeDescription: nodeDescription,
            nodeType: nodeTypeEnum,
            scope: scopeEnum,
            currentValue: currentValue,
            targetValue: targetValue,
            unit: unit,
            progress: progress,
            status: statusEnum,
            ownerName: ownerName,
            sortOrder: Int(sortOrder),
            parentId: parentId,
            children: [],  // 子节点需要通过单独查询组装
            cycleId: cycleId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Fetch Helpers

extension OKRNodeEntity {

    /// 获取指定周期的所有根节点（无父节点的顶级Objective）
    /// - Parameters:
    ///   - cycleId: 周期ID
    ///   - context: Core Data上下文
    /// - Returns: 根节点实体数组
    public static func fetchRootNodes(
        inCycle cycleId: UUID,
        context: NSManagedObjectContext
    ) throws -> [OKRNodeEntity] {
        let request = fetchRequest()
        // 筛选指定周期且无父节点的顶级Objective
        request.predicate = NSPredicate(
            format: "cycleId == %@ AND parentId == nil",
            cycleId as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \OKRNodeEntity.sortOrder, ascending: true)
        ]
        return try context.fetch(request)
    }

    /// 获取指定父节点的所有子节点
    /// - Parameters:
    ///   - parentId: 父节点ID
    ///   - context: Core Data上下文
    /// - Returns: 子节点实体数组
    public static func fetchChildren(
        ofParent parentId: UUID,
        context: NSManagedObjectContext
    ) throws -> [OKRNodeEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "parentId == %@",
            parentId as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \OKRNodeEntity.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \OKRNodeEntity.createdAt, ascending: true)
        ]
        return try context.fetch(request)
    }

    /// 根据ID获取单个节点
    /// - Parameters:
    ///   - id: 节点ID
    ///   - context: Core Data上下文
    /// - Returns: 节点实体，未找到返回nil
    public static func fetchById(
        _ id: UUID,
        context: NSManagedObjectContext
    ) throws -> OKRNodeEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        let results = try context.fetch(request)
        return results.first
    }

    /// 获取指定周期的所有节点（扁平列表）
    /// - Parameters:
    ///   - cycleId: 周期ID
    ///   - context: Core Data上下文
    /// - Returns: 该周期下的所有节点
    public static func fetchAllInCycle(
        _ cycleId: UUID,
        context: NSManagedObjectContext
    ) throws -> [OKRNodeEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "cycleId == %@",
            cycleId as CVarArg
        )
        return try context.fetch(request)
    }

    /// 删除指定节点及其所有后代
    /// 级联删除操作，会递归删除所有子节点
    /// - Parameters:
    ///   - id: 要删除的节点ID
    ///   - context: Core Data上下文
    public static func deleteNodeAndDescendants(
        _ id: UUID,
        context: NSManagedObjectContext
    ) throws {
        // 首先获取该节点
        guard let node = try fetchById(id, context: context) else { return }

        // 递归删除所有子节点
        // 先获取所有子节点
        let children = try fetchChildren(ofParent: id, context: context)
        for child in children {
            try deleteNodeAndDescendants(child.id, context: context)
        }

        // 最后删除当前节点
        context.delete(node)
    }
}

// MARK: - Tree Assembly

extension OKRNodeEntity {

    /// 将扁平的实体数组组装为树状结构
    /// 通过递归查询构建完整的父子关系
    /// - Parameters:
    ///   - entities: 扁平的节点实体数组
    ///   - context: Core Data上下文（用于查询子节点）
    /// - Returns: 组装好的树状结构（仅包含根节点，children已填充）
    public static func assembleTree(
        from entities: [OKRNodeEntity],
        context: NSManagedObjectContext
    ) -> [OKRNode] {
        // 获取所有根节点（无父节点）
        let rootEntities = entities.filter { $0.parentId == nil }

        // 递归构建每棵子树
        return rootEntities.map { root in
            assembleSubtree(rootEntity: root, allEntities: entities)
        }
    }

    /// 递归构建子树
    /// - Parameters:
    ///   - rootEntity: 当前子树的根实体
    ///   - allEntities: 所有实体数组（用于查找子节点）
    /// - Returns: 组装好的OKRNode（包含children）
    private static func assembleSubtree(
        rootEntity: OKRNodeEntity,
        allEntities: [OKRNodeEntity]
    ) -> OKRNode {
        // 查找当前节点的所有子节点
        let childEntities = allEntities.filter { $0.parentId == rootEntity.id }

        // 递归转换为领域模型
        var domainNode = rootEntity.toDomainModel()

        // 递归组装子节点
        domainNode.children = childEntities.map {
            assembleSubtree(rootEntity: $0, allEntities: allEntities)
        }

        return domainNode
    }
}
