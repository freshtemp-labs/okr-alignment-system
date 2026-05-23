// OKRAlignmentShared/Data/Mappers/DomainToEntityMapper.swift

import CoreData
import Foundation

/// 领域模型到Core Data实体的映射器
///
/// 负责将领域模型`OKRNode`和`OKRCycle`转换为Core Data实体。
/// 支持"查找或创建"（find-or-create）语义：若已存在相同ID的实体则更新，
/// 否则插入新实体。此类为纯静态工具类，无实例状态。
///
/// ## 设计原则
/// - **幂等性**：相同领域模型多次映射产生一致的实体状态
/// - **关系完整性**：正确处理`parent-children`和`node-cycle`双向关系
/// - **批量优化**：使用`NSFetchRequest`批量检查现有实体，减少数据库往返
enum DomainToEntityMapper {
    
    // MARK: - Errors
    
    /// 领域模型映射过程中可能发生的错误
    enum MappingError: LocalizedError {
        /// 无法从上下文中获取实体描述
        case entityDescriptionNotFound(String)
        /// 无法在上下文中找到指定的父实体
        case parentNotFound(UUID)
        /// 无法在上下文中找到指定的周期实体
        case cycleNotFound(UUID)
        
        var errorDescription: String? {
            switch self {
            case .entityDescriptionNotFound(let name):
                return "无法在上下文中找到实体描述: \(name)"
            case .parentNotFound(let id):
                return "无法在上下文中找到父节点: \(id)"
            case .cycleNotFound(let id):
                return "无法在上下文中找到周期: \(id)"
            }
        }
    }
    
    // MARK: - OKRNode Mapping
    
    /// 将领域模型`OKRNode`映射为Core Data实体
    ///
    /// 此方法实现"查找或创建"语义：首先查询上下文中是否已存在相同ID的实体，
    /// 若存在则更新其属性，否则创建新实体。会递归处理所有子节点，建立完整的
    /// `parent-children`关系树。
    ///
    /// - Parameters:
    ///   - domain: 要映射的领域模型节点
    ///   - context: Core Data托管对象上下文，所有操作在此上下文中执行
    /// - Returns: 映射后的Core Data实体（已附加到指定上下文）
    /// - Throws: `MappingError` 当实体描述缺失、关联对象无法找到时
    static func map(domain: OKRNode, context: NSManagedObjectContext) throws -> OKRNodeEntity {
        let entity: OKRNodeEntity = try findOrCreateEntity(
            id: domain.id,
            entityName: "OKRNodeEntity",
            context: context
        )
        
        // 同步基本属性
        entity.id = domain.id
        entity.title = domain.title
        entity.nodeDescription = domain.nodeDescription
        entity.nodeType = domain.nodeType.rawValue
        entity.scope = domain.scope.rawValue
        entity.currentValue = domain.currentValue
        entity.targetValue = domain.targetValue
        entity.unit = domain.unit
        entity.progress = domain.progress
        entity.status = domain.status.rawValue
        entity.ownerName = domain.ownerName
        entity.createdAt = domain.createdAt
        entity.updatedAt = domain.updatedAt
        entity.sortOrder = Int64(domain.sortOrder)
        entity.weight = domain.weight
        entity.version = Int64(domain.version)
        
        // 同步 cycleId 属性与 cycle 关系
        entity.cycleId = domain.cycleId
        
        // 关联周期（如果指定了cycleId）
        if let cycleId = domain.cycleId {
            let cycleFetchRequest: NSFetchRequest<OKRCycleEntity> = OKRCycleEntity.fetchRequest()
            cycleFetchRequest.predicate = NSPredicate(format: "id == %@", cycleId as CVarArg)
            cycleFetchRequest.fetchLimit = 1
            
            guard let cycleEntity = try context.fetch(cycleFetchRequest).first else {
                throw MappingError.cycleNotFound(cycleId)
            }
            entity.cycle = cycleEntity
        } else {
            entity.cycle = nil
        }
        
        // 同步 parentId 属性与 parent 关系
        entity.parentId = domain.parentId
        
        // 关联父节点（如果指定了parentId）
        if let parentId = domain.parentId, parentId != domain.id {
            let parentFetchRequest: NSFetchRequest<OKRNodeEntity> = OKRNodeEntity.fetchRequest()
            parentFetchRequest.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
            parentFetchRequest.fetchLimit = 1
            
            guard let parentEntity = try context.fetch(parentFetchRequest).first else {
                throw MappingError.parentNotFound(parentId)
            }
            entity.parent = parentEntity
        } else {
            entity.parent = nil
        }
        
        // 递归处理子节点
        // 先收集现有子节点，以便处理删除
        let existingChildren = entity.children?.mutableCopy() as? NSMutableOrderedSet ?? NSMutableOrderedSet()
        let newChildren = NSMutableOrderedSet()
        
        for childDomain in domain.children {
            let childEntity = try map(domain: childDomain, context: context)
            newChildren.add(childEntity)
        }
        
        // 移除不再存在的子节点
        for case let existingChild as OKRNodeEntity in existingChildren {
            if !domain.children.contains(where: { $0.id == existingChild.id }) {
                // 从父节点移除但不删除（删除由调用方控制）
                existingChild.parent = nil
            }
        }
        
        entity.children = newChildren
        
        return entity
    }
    
    /// 将周期领域模型映射为Core Data实体
    ///
    /// - Parameters:
    ///   - domain: 要映射的周期领域模型
    ///   - context: Core Data托管对象上下文
    /// - Returns: 映射后的周期实体（已附加到指定上下文）
    /// - Throws: `MappingError` 当实体描述缺失时
    static func map(domain: OKRCycle, context: NSManagedObjectContext) throws -> OKRCycleEntity {
        let entity: OKRCycleEntity = try findOrCreateEntity(
            id: domain.id,
            entityName: "OKRCycleEntity",
            context: context
        )
        
        entity.id = domain.id
        entity.name = domain.name
        entity.startDate = domain.startDate
        entity.endDate = domain.endDate
        entity.isActive = domain.isActive
        entity.isArchived = domain.isArchived
        
        return entity
    }
    
    // MARK: - Private Helpers
    
    /// 查找或创建指定ID的托管对象实体
    ///
    /// - Parameters:
    ///   - id: 实体唯一标识符
    ///   - entityName: 实体描述名称
    ///   - context: 托管对象上下文
    /// - Returns: 找到的现有实体或新创建的实体
    /// - Throws: `MappingError.entityDescriptionNotFound` 当实体描述不存在时
    private static func findOrCreateEntity<T: NSManagedObject>(
        id: UUID,
        entityName: String,
        context: NSManagedObjectContext
    ) throws -> T {
        // 首先尝试查找现有实体
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        if let existingEntity = try context.fetch(fetchRequest).first {
            return existingEntity
        }
        
        // 不存在则创建新实体
        guard let entityDescription = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            throw MappingError.entityDescriptionNotFound(entityName)
        }
        
        return T(entity: entityDescription, insertInto: context)
    }
}
