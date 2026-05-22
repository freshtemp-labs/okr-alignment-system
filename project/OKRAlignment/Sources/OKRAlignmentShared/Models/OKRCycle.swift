import Foundation

/// OKR周期模型
/// 代表一个OKR执行周期，如"2026年第一季度"
/// 所有OKR节点必须关联到一个周期，周期之间互相独立
/// 支持归档功能，已归档的周期为只读状态
public struct OKRCycle: Identifiable, Equatable, Hashable, Sendable {

    // MARK: - Properties

    /// 周期唯一标识符
    public let id: UUID

    /// 周期名称（如"2026 Q1"、"2026年上半年"等）
    public var name: String

    /// 周期开始日期
    public var startDate: Date

    /// 周期结束日期
    public var endDate: Date

    /// 是否为当前活跃周期
    /// 同一时间通常只有一个活跃周期
    public var isActive: Bool

    /// 是否已归档
    /// 归档后的周期为只读，不可编辑其中的OKR
    public var isArchived: Bool

    // MARK: - Computed Properties

    /// 周期持续天数
    public var durationInDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return components.day ?? 0
    }

    /// 周期是否已过期（当前日期超过结束日期）
    public var isExpired: Bool {
        Date() > endDate
    }

    /// 周期是否即将开始（当前日期在开始日期之前）
    public var isUpcoming: Bool {
        Date() < startDate
    }

    /// 周期是否正在进行中
    public var isInProgress: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    /// 周期进度百分比（0.0 - 100.0）
    /// 基于已过去天数占总天数的比例
    public var timeProgressPercentage: Double {
        let totalDays = durationInDays
        guard totalDays > 0 else { return 0 }

        let calendar = Calendar.current
        let now = Date()

        // 如果尚未开始，进度为0
        if now < startDate { return 0 }
        // 如果已结束，进度为100
        if now > endDate { return 100 }

        let elapsedComponents = calendar.dateComponents([.day], from: startDate, to: now)
        let elapsedDays = elapsedComponents.day ?? 0
        return min(100, max(0, (Double(elapsedDays) / Double(totalDays)) * 100))
    }

    /// 格式化后的日期范围字符串
    /// 示例："2026/1/1 - 2026/3/31"
    public var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        formatter.locale = Locale(identifier: "zh_CN")
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    // MARK: - Initializer

    /// 创建新的OKR周期
    /// - Parameters:
    ///   - id: 唯一标识符（默认自动生成）
    ///   - name: 周期名称
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - isActive: 是否为活跃周期（默认false）
    ///   - isArchived: 是否已归档（默认false）
    public init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        isActive: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.isArchived = isArchived
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: OKRCycle, rhs: OKRCycle) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data

extension OKRCycle {
    /// 创建示例OKR周期
    /// 用于SwiftUI预览和单元测试
    public static func sampleCycle() -> OKRCycle {
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 31))
        else {
            return OKRCycle(name: "2026 Q1", startDate: Date(), endDate: Date(), isActive: true, isArchived: false)
        }
        return OKRCycle(
            name: "2026 Q1",
            startDate: startDate,
            endDate: endDate,
            isActive: true,
            isArchived: false
        )
    }

    /// 创建示例已归档周期
    public static func sampleArchivedCycle() -> OKRCycle {
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: 2025, month: 10, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))
        else {
            return OKRCycle(name: "2025 Q4", startDate: Date(), endDate: Date(), isActive: false, isArchived: true)
        }
        return OKRCycle(
            name: "2025 Q4",
            startDate: startDate,
            endDate: endDate,
            isActive: false,
            isArchived: true
        )
    }
}
