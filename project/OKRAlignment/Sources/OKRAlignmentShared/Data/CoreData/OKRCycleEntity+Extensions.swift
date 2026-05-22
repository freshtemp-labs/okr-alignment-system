import Foundation
import CoreData

/// OKRCycle Core Data实体类
/// 对应数据库中的OKR周期存储，提供与领域模型OKRCycle的双向转换
/// 周期用于组织和隔离不同时间段的OKR数据
@objc(OKRCycleEntity)
public final class OKRCycleEntity: NSManagedObject {

    // MARK: - Properties

    /// 周期唯一标识符
    @NSManaged public var id: UUID

    /// 周期名称（如"2026 Q1"）
    @NSManaged public var name: String

    /// 周期开始日期
    @NSManaged public var startDate: Date

    /// 周期结束日期
    @NSManaged public var endDate: Date

    /// 是否为当前活跃周期
    @NSManaged public var isActive: Bool

    /// 是否已归档
    @NSManaged public var isArchived: Bool

    /// To-many relationship to nodes belonging to this cycle
    @NSManaged public var nodes: NSSet?

    // MARK: - Fetch Request

    /// 创建默认的Fetch Request
    /// 用于@FetchRequest包装器获取所有OKR周期
    @nonobjc public class func fetchRequest() -> NSFetchRequest<OKRCycleEntity> {
        let request = NSFetchRequest<OKRCycleEntity>(entityName: "OKRCycleEntity")
        // 默认按开始日期降序排列，最新的周期在前
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \OKRCycleEntity.startDate, ascending: false)
        ]
        return request
    }
}

// MARK: - Domain Model Conversion

extension OKRCycleEntity {

    /// 从领域模型转换为Core Data实体
    /// 如果不存在则创建新实体，如果已存在则更新属性
    /// - Parameter domainModel: OKRCycle领域模型
    public func fromDomainModel(_ domainModel: OKRCycle) {
        // 仅在id不匹配时更新
        if id != domainModel.id {
            id = domainModel.id
        }

        // 更新所有属性
        name = domainModel.name
        startDate = domainModel.startDate
        endDate = domainModel.endDate
        isActive = domainModel.isActive
        isArchived = domainModel.isArchived
    }

    /// 转换为领域模型
    /// - Returns: OKRCycle领域模型实例
    public func toDomainModel() -> OKRCycle {
        OKRCycle(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            isActive: isActive,
            isArchived: isArchived
        )
    }
}

// MARK: - Fetch Helpers

extension OKRCycleEntity {

    /// 获取当前活跃周期
    /// - Parameter context: Core Data上下文
    /// - Returns: 活跃周期实体，未找到返回nil
    public static func fetchActiveCycle(
        context: NSManagedObjectContext
    ) throws -> OKRCycleEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.fetchLimit = 1
        let results = try context.fetch(request)
        return results.first
    }

    /// 获取所有未归档的周期
    /// - Parameter context: Core Data上下文
    /// - Returns: 未归档的周期实体数组
    public static func fetchActiveCycles(
        context: NSManagedObjectContext
    ) throws -> [OKRCycleEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == false")
        return try context.fetch(request)
    }

    /// 根据ID获取单个周期
    /// - Parameters:
    ///   - id: 周期ID
    ///   - context: Core Data上下文
    /// - Returns: 周期实体，未找到返回nil
    public static func fetchById(
        _ id: UUID,
        context: NSManagedObjectContext
    ) throws -> OKRCycleEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        let results = try context.fetch(request)
        return results.first
    }

    /// 获取所有已归档的周期
    /// - Parameter context: Core Data上下文
    /// - Returns: 已归档的周期实体数组
    public static func fetchArchivedCycles(
        context: NSManagedObjectContext
    ) throws -> [OKRCycleEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == true")
        return try context.fetch(request)
    }
}

// MARK: - Convenience Helpers

extension OKRCycleEntity {

    /// 周期是否已过期（当前日期超过结束日期）
    public var isExpired: Bool {
        Date() > endDate
    }

    /// 周期是否正在进行中
    public var isInProgress: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    /// 周期持续天数
    public var durationInDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return components.day ?? 0
    }

    /// 格式化后的日期范围字符串
    public var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        formatter.locale = Locale(identifier: "zh_CN")
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}
