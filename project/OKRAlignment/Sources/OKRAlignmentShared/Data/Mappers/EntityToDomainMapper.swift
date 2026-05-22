// OKRAlignmentShared/Data/Mappers/EntityToDomainMapper.swift

import CoreData
import Foundation

/// Core Data实体到领域模型的映射器
///
/// 负责将`OKRNodeEntity`和`OKRCycleEntity`转换为对应的领域模型
/// `OKRNode`和`OKRCycle`。此类为纯静态工具类，无实例状态。
///
/// ## 映射规则
/// - `OKRNodeEntity.children`（`NSOrderedSet`）递归映射为`OKRNode.children`（`[OKRNode]`）
/// - 枚举类型通过原始值字符串进行安全转换，无效值降级为默认值
/// - 可选字段（`nodeDescription`、`unit`、`parentId`、`cycleId`）正确解包
enum EntityToDomainMapper {
    
    // MARK: - Errors
    
    /// 实体映射过程中可能发生的错误
    enum MappingError: LocalizedError {
        /// 无法识别的枚举原始值
        case invalidEnumValue(String, expectedType: String)
        /// 必需的关联对象缺失
        case missingRelationship(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidEnumValue(let value, let type):
                return "无法将值 '\(value)' 转换为枚举类型 \(type)"
            case .missingRelationship(let name):
                return "必需的关联对象缺失: \(name)"
            }
        }
    }
    
    // MARK: - OKRNodeEntity Mapping
    
    /// 将`OKRNodeEntity`及其完整子树映射为领域模型`OKRNode`
    ///
    /// 此方法递归遍历`entity.children`，构建完整的树形结构。
    /// 所有枚举字段（`NodeType`、`Scope`、`NodeStatus`）均通过原始值安全转换。
    ///
    /// - Parameter entity: Core Data实体对象
    /// - Returns: 完整的领域模型节点（含子树）
    /// - Throws: `MappingError` 当遇到无法识别的枚举值时
    static func map(entity: OKRNodeEntity) throws -> OKRNode {
        // 安全转换枚举类型，无效时使用默认值
        guard let nodeType = NodeType(rawValue: entity.nodeType) else {
            throw MappingError.invalidEnumValue(entity.nodeType, expectedType: "NodeType")
        }
        
        guard let scope = Scope(rawValue: entity.scope) else {
            throw MappingError.invalidEnumValue(entity.scope, expectedType: "Scope")
        }
        
        guard let status = NodeStatus(rawValue: entity.status) else {
            throw MappingError.invalidEnumValue(entity.status, expectedType: "NodeStatus")
        }
        
        // 递归映射子节点
        let childEntities = entity.children?.array as? [OKRNodeEntity] ?? []
        let mappedChildren = try childEntities.map { try map(entity: $0) }
        
        // 提取父节点ID和周期ID
        let parentId = entity.parent?.id
        let cycleId = entity.cycle?.id
        
        return OKRNode(
            id: entity.id,
            title: entity.title,
            nodeDescription: entity.nodeDescription,
            nodeType: nodeType,
            scope: scope,
            currentValue: entity.currentValue,
            targetValue: entity.targetValue,
            unit: entity.unit,
            progress: entity.progress,
            status: status,
            ownerName: entity.ownerName,
            sortOrder: Int(entity.sortOrder),
            parentId: parentId,
            children: mappedChildren,
            cycleId: cycleId,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }
    
    /// 将`OKRCycleEntity`映射为领域模型`OKRCycle`
    ///
    /// - Parameter entity: Core Data周期实体
    /// - Returns: 领域模型周期
    static func map(entity: OKRCycleEntity) -> OKRCycle {
        OKRCycle(
            id: entity.id,
            name: entity.name,
            startDate: entity.startDate,
            endDate: entity.endDate,
            isActive: entity.isActive,
            isArchived: entity.isArchived
        )
    }
    
    // MARK: - Array Mapping
    
    /// 批量映射实体数组为领域模型数组
    ///
    /// - Parameter entities: Core Data实体数组
    /// - Returns: 领域模型数组
    /// - Throws: 任一实体映射失败时抛出错误
    static func map(entities: [OKRNodeEntity]) throws -> [OKRNode] {
        try entities.map { try map(entity: $0) }
    }
    
    /// 批量映射周期实体数组为周期领域模型数组
    ///
    /// - Parameter entities: 周期实体数组
    /// - Returns: 周期领域模型数组
    static func map(cycleEntities: [OKRCycleEntity]) -> [OKRCycle] {
        cycleEntities.map { map(entity: $0) }
    }
}
