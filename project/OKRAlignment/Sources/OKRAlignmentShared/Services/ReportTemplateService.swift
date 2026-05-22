// OKRAlignmentShared/Services/ReportTemplateService.swift

import Foundation
import SwiftUI

/// 报表模板服务
///
/// 提供自定义报表模板管理和报表配置功能：
/// - 预设报表模板
/// - 自定义报表模板创建与保存
/// - 时间范围筛选
/// - 按 Owner/状态/进度筛选
/// - 报表配置保存与加载
///
/// ## 使用示例
/// ```swift
/// let template = ReportTemplateService.builtInTemplates[0]
/// let config = ReportFilterConfig(timeRange: .thisMonth, statusFilter: [.atRisk])
/// let preview = ReportTemplateService.generateFilteredPreview(...)
/// ```
@MainActor
public final class ReportTemplateService: ObservableObject {

    // MARK: - Singleton

    public static let shared = ReportTemplateService()

    // MARK: - Published Properties

    /// 用户保存的自定义模板
    @Published public var savedTemplates: [ReportTemplate] = [] {
        didSet { saveTemplates() }
    }

    /// 用户保存的报表配置
    @Published public var savedConfigs: [SavedReportConfig] = [] {
        didSet { saveConfigs() }
    }

    // MARK: - Initialization

    private init() {
        loadTemplates()
        loadConfigs()
    }

    // MARK: - Built-in Templates

    /// 内置报表模板
    public static let builtInTemplates: [ReportTemplate] = [
        ReportTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "周报摘要",
            description: "本周 OKR 进度概要，适合周会汇报",
            icon: "doc.text",
            defaultConfig: ReportFilterConfig(
                timeRange: .thisWeek,
                includeStatistics: true,
                includeStatusDistribution: true,
                includeOwnerRankings: true,
                includeNodeDetails: false
            ),
            isBuiltIn: true
        ),
        ReportTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "月度报告",
            description: "月度详细报告，含所有图表和明细",
            icon: "chart.bar.doc.horizontal",
            defaultConfig: ReportFilterConfig(
                timeRange: .thisMonth,
                includeStatistics: true,
                includeStatusDistribution: true,
                includeOwnerRankings: true,
                includeNodeDetails: true,
                includeTrendChart: true
            ),
            isBuiltIn: true
        ),
        ReportTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "季度回顾",
            description: "季度全面回顾报告，含趋势和对比分析",
            icon: "calendar",
            defaultConfig: ReportFilterConfig(
                timeRange: .thisQuarter,
                includeStatistics: true,
                includeStatusDistribution: true,
                includeOwnerRankings: true,
                includeNodeDetails: true,
                includeTrendChart: true,
                includeProgressDistribution: true
            ),
            isBuiltIn: true
        ),
        ReportTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "风险预警",
            description: "仅显示有风险和滞后的 KR",
            icon: "exclamationmark.triangle",
            defaultConfig: ReportFilterConfig(
                timeRange: .all,
                statusFilter: [.atRisk, .notStarted],
                includeStatistics: true,
                includeNodeDetails: true
            ),
            isBuiltIn: true
        ),
        ReportTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "团队概览",
            description: "按负责人分组的团队进度概览",
            icon: "person.3",
            defaultConfig: ReportFilterConfig(
                timeRange: .all,
                includeStatistics: true,
                includeOwnerRankings: true,
                includeNodeDetails: true
            ),
            isBuiltIn: true
        )
    ]

    // MARK: - Template Management

    /// 保存自定义模板
    public func saveTemplate(_ template: ReportTemplate) {
        savedTemplates.append(template)
    }

    /// 删除自定义模板
    public func deleteTemplate(id: UUID) {
        savedTemplates.removeAll { $0.id == id }
    }

    /// 保存报表配置
    public func saveConfig(name: String, config: ReportFilterConfig) {
        let saved = SavedReportConfig(id: UUID(), name: name, config: config, createdAt: Date())
        savedConfigs.append(saved)
    }

    /// 删除报表配置
    public func deleteConfig(id: UUID) {
        savedConfigs.removeAll { $0.id == id }
    }

    // MARK: - Persistence

    private func saveTemplates() {
        guard let data = try? JSONEncoder().encode(savedTemplates) else { return }
        UserDefaults.standard.set(data, forKey: "okr_saved_report_templates")
    }

    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: "okr_saved_report_templates"),
              let templates = try? JSONDecoder().decode([ReportTemplate].self, from: data) else { return }
        savedTemplates = templates
    }

    private func saveConfigs() {
        guard let data = try? JSONEncoder().encode(savedConfigs) else { return }
        UserDefaults.standard.set(data, forKey: "okr_saved_report_configs")
    }

    private func loadConfigs() {
        guard let data = UserDefaults.standard.data(forKey: "okr_saved_report_configs"),
              let configs = try? JSONDecoder().decode([SavedReportConfig].self, from: data) else { return }
        savedConfigs = configs
    }
}

// MARK: - Report Template

/// 报表模板
public struct ReportTemplate: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let icon: String
    public let defaultConfig: ReportFilterConfig
    public let isBuiltIn: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        icon: String,
        defaultConfig: ReportFilterConfig,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.defaultConfig = defaultConfig
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Saved Report Config

/// 保存的报表配置
public struct SavedReportConfig: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let config: ReportFilterConfig
    public let createdAt: Date
}

// MARK: - Report Filter Config

/// 报表筛选配置
public struct ReportFilterConfig: Codable, Sendable {
    /// 时间范围
    public var timeRange: ReportTimeRange
    /// 状态筛选
    public var statusFilter: Set<NodeStatus>
    /// Owner 筛选
    public var ownerFilter: Set<String>
    /// 最低进度筛选
    public var minProgress: Double?
    /// 最高进度筛选
    public var maxProgress: Double?
    /// 是否包含统计概要
    public var includeStatistics: Bool
    /// 是否包含状态分布
    public var includeStatusDistribution: Bool
    /// 是否包含负责人排名
    public var includeOwnerRankings: Bool
    /// 是否包含节点明细
    public var includeNodeDetails: Bool
    /// 是否包含趋势图
    public var includeTrendChart: Bool
    /// 是否包含进度分布
    public var includeProgressDistribution: Bool

    public init(
        timeRange: ReportTimeRange = .all,
        statusFilter: Set<NodeStatus> = [],
        ownerFilter: Set<String> = [],
        minProgress: Double? = nil,
        maxProgress: Double? = nil,
        includeStatistics: Bool = true,
        includeStatusDistribution: Bool = true,
        includeOwnerRankings: Bool = false,
        includeNodeDetails: Bool = false,
        includeTrendChart: Bool = false,
        includeProgressDistribution: Bool = false
    ) {
        self.timeRange = timeRange
        self.statusFilter = statusFilter
        self.ownerFilter = ownerFilter
        self.minProgress = minProgress
        self.maxProgress = maxProgress
        self.includeStatistics = includeStatistics
        self.includeStatusDistribution = includeStatusDistribution
        self.includeOwnerRankings = includeOwnerRankings
        self.includeNodeDetails = includeNodeDetails
        self.includeTrendChart = includeTrendChart
        self.includeProgressDistribution = includeProgressDistribution
    }

    /// 是否有任何筛选条件
    public var hasFilters: Bool {
        timeRange != .all || !statusFilter.isEmpty || !ownerFilter.isEmpty || minProgress != nil || maxProgress != nil
    }
}

// MARK: - Time Range

/// 报表时间范围
public enum ReportTimeRange: String, CaseIterable, Codable, Sendable {
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case thisQuarter = "this_quarter"
    case lastWeek = "last_week"
    case lastMonth = "last_month"
    case lastQuarter = "last_quarter"
    case custom = "custom"
    case all = "all"

    public var displayName: String {
        switch self {
        case .thisWeek: return "本周"
        case .thisMonth: return "本月"
        case .thisQuarter: return "本季度"
        case .lastWeek: return "上周"
        case .lastMonth: return "上月"
        case .lastQuarter: return "上季度"
        case .custom: return "自定义"
        case .all: return "全部"
        }
    }

    public var icon: String {
        switch self {
        case .thisWeek, .lastWeek: return "calendar.badge.clock"
        case .thisMonth, .lastMonth: return "calendar"
        case .thisQuarter, .lastQuarter: return "calendar.circle"
        case .custom: return "slider.horizontal.3"
        case .all: return "infinity"
        }
    }

    /// 计算时间范围的起止日期
    public func dateRange(customStart: Date? = nil, customEnd: Date? = nil) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (start, now)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (start, now)
        case .thisQuarter:
            let start = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
            return (start, now)
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            let start = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.start ?? lastWeek
            let end = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.end ?? now
            return (start, end)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let start = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? lastMonth
            let end = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
            return (start, end)
        case .lastQuarter:
            let lastQuarter = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            let start = calendar.dateInterval(of: .quarter, for: lastQuarter)?.start ?? lastQuarter
            let end = calendar.dateInterval(of: .quarter, for: lastQuarter)?.end ?? now
            return (start, end)
        case .custom:
            return (customStart ?? calendar.date(byAdding: .month, value: -1, to: now) ?? now, customEnd ?? now)
        case .all:
            let distantPast = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            return (distantPast, now)
        }
    }
}
