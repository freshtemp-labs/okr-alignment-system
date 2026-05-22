// OKRAlignmentShared/Services/NotificationService.swift

import Foundation
@preconcurrency import UserNotifications

/// OKR 通知服务
///
/// 管理 OKR 系统相关的本地通知，包括：
/// - KR 进度里程碑通知（达到 80%、100%）
/// - OKR 周期到期提醒通知
/// - 周期即将结束提醒
/// - 自定义通知时间（每天/每周）
/// - 通知分组（按周期/按Owner）
/// - 通知历史记录
/// - 通知统计
///
/// ## 通知授权
/// 使用前需调用 `requestAuthorization()` 请求通知权限。
///
/// ## 使用示例
/// ```swift
/// let notificationService = NotificationService()
/// // 请求权限
/// let granted = try await notificationService.requestAuthorization()
/// // 进度里程碑通知
/// try await notificationService.checkAndNotifyProgressMilestone(for: node)
/// // 设置自定义通知时间
/// notificationService.setDailyReminder(hour: 9, minute: 0)
/// // 查看通知历史
/// let history = notificationService.getNotificationHistory()
/// ```
public final class NotificationService: @unchecked Sendable {

    // MARK: - Constants

    /// 通知类别标识符
    public enum Category {
        /// 进度里程碑通知
        static let progressMilestone = "OKR_PROGRESS_MILESTONE"
        /// 周期到期提醒
        static let cycleExpiration = "OKR_CYCLE_EXPIRATION"
        /// 周期即将结束提醒
        static let cycleEndingSoon = "OKR_CYCLE_ENDING_SOON"
        /// 每日提醒
        static let dailyReminder = "OKR_DAILY_REMINDER"
        /// 每周提醒
        static let weeklyReminder = "OKR_WEEKLY_REMINDER"
    }

    /// 进度里程碑阈值（百分比）
    public static let progressThresholds: [Double] = [80.0, 100.0]

    /// 周期即将到期的提前天数
    public static let cycleEndingSoonDays = 7

    /// 用户信息中存储节点 ID 的键
    private static let nodeIdKey = "node_id"
    /// 用户信息中存储周期 ID 的键
    private static let cycleIdKey = "cycle_id"
    /// 用户信息中存储通知分组的键
    private static let groupKey = "notification_group"
    /// 用户信息中存储通知类型的键
    private static let typeKey = "notification_type"

    // MARK: - Notification Schedule

    /// 自定义通知时间配置
    public struct NotificationSchedule: Codable, Sendable {
        /// 是否启用每日提醒
        public var dailyReminderEnabled: Bool
        /// 每日提醒时间（小时）
        public var dailyReminderHour: Int
        /// 每日提醒时间（分钟）
        public var dailyReminderMinute: Int
        /// 是否启用每周提醒
        public var weeklyReminderEnabled: Bool
        /// 每周提醒的星期几（1=周日, 2=周一, ..., 7=周六）
        public var weeklyReminderWeekday: Int
        /// 每周提醒时间（小时）
        public var weeklyReminderHour: Int
        /// 每周提醒时间（分钟）
        public var weeklyReminderMinute: Int

        public init(
            dailyReminderEnabled: Bool = false,
            dailyReminderHour: Int = 9,
            dailyReminderMinute: Int = 0,
            weeklyReminderEnabled: Bool = false,
            weeklyReminderWeekday: Int = 2,
            weeklyReminderHour: Int = 9,
            weeklyReminderMinute: Int = 0
        ) {
            self.dailyReminderEnabled = dailyReminderEnabled
            self.dailyReminderHour = dailyReminderHour
            self.dailyReminderMinute = dailyReminderMinute
            self.weeklyReminderEnabled = weeklyReminderEnabled
            self.weeklyReminderWeekday = weeklyReminderWeekday
            self.weeklyReminderHour = weeklyReminderHour
            self.weeklyReminderMinute = weeklyReminderMinute
        }
    }

    // MARK: - Quiet Hours

    /// 免打扰时间配置
    public struct QuietHours: Codable, Sendable {
        /// 是否启用免打扰
        public var enabled: Bool
        /// 免打扰开始时间（小时）
        public var startHour: Int
        /// 免打扰开始时间（分钟）
        public var startMinute: Int
        /// 免打扰结束时间（小时）
        public var endHour: Int
        /// 免打扰结束时间（分钟）
        public var endMinute: Int

        public init(
            enabled: Bool = false,
            startHour: Int = 22,
            startMinute: Int = 0,
            endHour: Int = 8,
            endMinute: Int = 0
        ) {
            self.enabled = enabled
            self.startHour = startHour
            self.startMinute = startMinute
            self.endHour = endHour
            self.endMinute = endMinute
        }

        /// 格式化开始时间
        public var formattedStart: String {
            String(format: "%02d:%02d", startHour, startMinute)
        }

        /// 格式化结束时间
        public var formattedEnd: String {
            String(format: "%02d:%02d", endHour, endMinute)
        }

        /// 检查指定时间是否在免打扰时间内
        public func isQuietTime(at date: Date = Date()) -> Bool {
            guard enabled else { return false }
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let currentMinutes = hour * 60 + minute
            let startMinutes = startHour * 60 + startMinute
            let endMinutes = endHour * 60 + endMinute

            if startMinutes <= endMinutes {
                return currentMinutes >= startMinutes && currentMinutes < endMinutes
            } else {
                // 跨午夜
                return currentMinutes >= startMinutes || currentMinutes < endMinutes
            }
        }
    }

    // MARK: - Notification Group

    /// 通知分组方式
    public enum NotificationGroup: String, CaseIterable, Sendable {
        /// 按周期分组
        case byCycle = "by_cycle"
        /// 按负责人分组
        case byOwner = "by_owner"
        /// 不分组
        case none = "none"

        /// 分组显示名称
        public var displayName: String {
            switch self {
            case .byCycle: return "按周期"
            case .byOwner: return "按负责人"
            case .none: return "不分组"
            }
        }
    }

    // MARK: - Notification History Record

    /// 通知历史记录
    public struct NotificationRecord: Identifiable, Codable, Sendable {
        /// 记录 ID
        public let id: UUID
        /// 通知标题
        public let title: String
        /// 通知内容
        public let body: String
        /// 通知类型
        public let type: NotificationType
        /// 关联的周期 ID
        public let cycleId: UUID?
        /// 关联的节点 ID
        public let nodeId: UUID?
        /// 分组标识
        public let group: String?
        /// 发送时间
        public let sentAt: Date
        /// 是否已读
        public var isRead: Bool

        public init(
            id: UUID = UUID(),
            title: String,
            body: String,
            type: NotificationType,
            cycleId: UUID? = nil,
            nodeId: UUID? = nil,
            group: String? = nil,
            sentAt: Date = Date(),
            isRead: Bool = false
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.type = type
            self.cycleId = cycleId
            self.nodeId = nodeId
            self.group = group
            self.sentAt = sentAt
            self.isRead = isRead
        }
    }

    /// 通知类型
    public enum NotificationType: String, CaseIterable, Codable, Sendable {
        case progressMilestone = "progress_milestone"
        case cycleExpiration = "cycle_expiration"
        case cycleEndingSoon = "cycle_ending_soon"
        case dailyReminder = "daily_reminder"
        case weeklyReminder = "weekly_reminder"

        /// 类型显示名称
        public var displayName: String {
            switch self {
            case .progressMilestone: return "进度里程碑"
            case .cycleExpiration: return "周期到期"
            case .cycleEndingSoon: return "周期即将结束"
            case .dailyReminder: return "每日提醒"
            case .weeklyReminder: return "每周提醒"
            }
        }

        /// 类型图标
        public var iconName: String {
            switch self {
            case .progressMilestone: return "chart.line.uptrend.xyaxis"
            case .cycleExpiration: return "clock.badge.exclamationmark"
            case .cycleEndingSoon: return "clock.badge"
            case .dailyReminder: return "sunrise.fill"
            case .weeklyReminder: return "calendar"
            }
        }
    }

    // MARK: - Notification Statistics

    /// 通知统计信息
    public struct NotificationStatistics: Sendable {
        /// 总发送数
        public let totalSent: Int
        /// 未读数
        public let unreadCount: Int
        /// 按类型统计
        public let byType: [NotificationType: Int]
        /// 按周期统计
        public let byCycle: [String: Int]
        /// 最近 7 天每天发送数
        public let last7Days: [String: Int]
        /// 最近一条通知时间
        public let lastNotificationDate: Date?
    }

    // MARK: - Properties

    /// 通知中心
    private let notificationCenter = UNUserNotificationCenter.current()

    /// 通知调度配置
    private var schedule: NotificationSchedule {
        get {
            if let data = UserDefaults.standard.data(forKey: "okr_notification_schedule"),
               let decoded = try? JSONDecoder().decode(NotificationSchedule.self, from: data) {
                return decoded
            }
            return NotificationSchedule()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "okr_notification_schedule")
            }
        }
    }

    /// 免打扰时间配置
    public var quietHours: QuietHours {
        get {
            if let data = UserDefaults.standard.data(forKey: "okr_notification_quiet_hours"),
               let decoded = try? JSONDecoder().decode(QuietHours.self, from: data) {
                return decoded
            }
            return QuietHours()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "okr_notification_quiet_hours")
            }
        }
    }

    /// 通知分组方式
    public var groupMode: NotificationGroup {
        get {
            let raw = UserDefaults.standard.string(forKey: "okr_notification_group_mode") ?? "none"
            return NotificationGroup(rawValue: raw) ?? .none
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "okr_notification_group_mode")
        }
    }

    /// 通知历史记录存储键
    private static let historyKey = "okr_notification_history"

    // MARK: - Initialization

    public init() {}

    // MARK: - Authorization

    /// 请求通知权限
    ///
    /// 首次调用时会弹出系统权限请求对话框。
    ///
    /// - Returns: 用户是否授权
    /// - Throws: 请求错误
    public func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        return try await notificationCenter.requestAuthorization(options: options)
    }

    /// 查询当前通知授权状态
    ///
    /// - Returns: 当前授权状态
    public func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Progress Milestone Notifications

    /// 检查并发送进度里程碑通知
    ///
    /// 当 KR 节点的进度达到阈值（80%、100%）时发送通知。
    /// 使用节点 ID 和阈值组合作为通知标识符，避免重复通知。
    ///
    /// - Parameter node: 要检查的 KR 节点
    /// - Throws: 通知发送错误
    public func checkAndNotifyProgressMilestone(for node: OKRNode) async throws {
        // 仅对 KR 节点发送进度通知
        guard node.nodeType == .keyResult else { return }

        for threshold in NotificationService.progressThresholds {
            if node.progress >= threshold {
                let identifier = progressNotificationIdentifier(nodeId: node.id, threshold: threshold)

                // 检查是否已发送过该阈值的通知
                let pendingRequests = await notificationCenter.pendingNotificationRequests()
                let deliveredNotifications = await notificationCenter.deliveredNotifications()
                let existingIdentifiers = Set(
                    pendingRequests.map(\.identifier) + deliveredNotifications.map { $0.request.identifier }
                )

                guard !existingIdentifiers.contains(identifier) else { continue }

                let content = createProgressNotificationContent(
                    node: node,
                    threshold: threshold
                )

                // 免打扰时间检查：延迟到免打扰结束后发送
                if quietHours.isQuietTime() {
                    // 计算到免打扰结束的时间间隔
                    let calendar = Calendar.current
                    let now = Date()
                    var endComponents = DateComponents()
                    endComponents.hour = quietHours.endHour
                    endComponents.minute = quietHours.endMinute
                    if let endDate = calendar.nextDate(after: now, matching: endComponents, matchingPolicy: .nextTime) {
                        let delay = endDate.timeIntervalSince(now)
                        let delayedTrigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
                        let delayedRequest = UNNotificationRequest(
                            identifier: identifier,
                            content: content,
                            trigger: delayedTrigger
                        )
                        try await notificationCenter.add(delayedRequest)
                    }
                } else {
                    // 立即发送
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: trigger
                    )

                    try await notificationCenter.add(request)
                }

                // 记录历史
                addNotificationRecord(
                    title: content.title,
                    body: content.body,
                    type: .progressMilestone,
                    cycleId: node.cycleId,
                    nodeId: node.id
                )
            }
        }
    }

    // MARK: - Cycle Expiration Notifications

    /// 安排周期到期提醒通知
    ///
    /// 在周期结束日期当天发送通知，提醒用户周期已结束。
    ///
    /// - Parameter cycle: 要提醒的周期
    /// - Throws: 通知安排错误
    public func scheduleCycleExpirationReminder(for cycle: OKRCycle) async throws {
        let identifier = cycleExpirationIdentifier(cycleId: cycle.id)

        // 如果周期已过期，不安排通知
        guard !cycle.isExpired else { return }

        let content = createCycleExpirationContent(cycle: cycle)

        // 在结束日期触发
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: cycle.endDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    /// 安排周期即将结束提醒通知
    ///
    /// 在周期结束前 N 天发送提醒，给用户充足时间完成 OKR。
    ///
    /// - Parameter cycle: 要提醒的周期
    /// - Throws: 通知安排错误
    public func scheduleCycleEndingSoonReminder(for cycle: OKRCycle) async throws {
        let identifier = cycleEndingSoonIdentifier(cycleId: cycle.id)

        // 计算提前提醒日期
        guard let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -NotificationService.cycleEndingSoonDays,
            to: cycle.endDate
        ) else { return }

        // 如果提醒日期已过，不安排通知
        guard reminderDate > Date() else { return }

        let content = createCycleEndingSoonContent(cycle: cycle)

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    // MARK: - Custom Schedule Notifications

    /// 设置每日提醒
    ///
    /// 在每天指定时间发送 OKR 进度概要提醒。
    ///
    /// - Parameters:
    ///   - hour: 小时 (0-23)
    ///   - minute: 分钟 (0-59)
    public func setDailyReminder(hour: Int, minute: Int) {
        var currentSchedule = schedule
        currentSchedule.dailyReminderEnabled = true
        currentSchedule.dailyReminderHour = hour
        currentSchedule.dailyReminderMinute = minute
        schedule = currentSchedule

        scheduleDailyReminder(hour: hour, minute: minute)
    }

    /// 取消每日提醒
    public func cancelDailyReminder() {
        var currentSchedule = schedule
        currentSchedule.dailyReminderEnabled = false
        schedule = currentSchedule

        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["okr_daily_reminder"]
        )
    }

    /// 设置每周提醒
    ///
    /// 在每周指定时间和星期几发送 OKR 周报提醒。
    ///
    /// - Parameters:
    ///   - weekday: 星期几 (1=周日, 2=周一, ..., 7=周六)
    ///   - hour: 小时 (0-23)
    ///   - minute: 分钟 (0-59)
    public func setWeeklyReminder(weekday: Int, hour: Int, minute: Int) {
        var currentSchedule = schedule
        currentSchedule.weeklyReminderEnabled = true
        currentSchedule.weeklyReminderWeekday = weekday
        currentSchedule.weeklyReminderHour = hour
        currentSchedule.weeklyReminderMinute = minute
        schedule = currentSchedule

        scheduleWeeklyReminder(weekday: weekday, hour: hour, minute: minute)
    }

    /// 取消每周提醒
    public func cancelWeeklyReminder() {
        var currentSchedule = schedule
        currentSchedule.weeklyReminderEnabled = false
        schedule = currentSchedule

        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["okr_weekly_reminder"]
        )
    }

    /// 获取当前通知调度配置
    public func getSchedule() -> NotificationSchedule {
        return schedule
    }

    /// 恢复所有自定义通知调度（App 启动时调用）
    public func restoreScheduledNotifications() {
        let currentSchedule = schedule

        if currentSchedule.dailyReminderEnabled {
            scheduleDailyReminder(
                hour: currentSchedule.dailyReminderHour,
                minute: currentSchedule.dailyReminderMinute
            )
        }

        if currentSchedule.weeklyReminderEnabled {
            scheduleWeeklyReminder(
                weekday: currentSchedule.weeklyReminderWeekday,
                hour: currentSchedule.weeklyReminderHour,
                minute: currentSchedule.weeklyReminderMinute
            )
        }
    }

    // MARK: - Cancel Notifications

    /// 取消指定节点的所有待发送通知
    ///
    /// - Parameter nodeId: 节点 ID
    public func cancelNotifications(for nodeId: UUID) {
        let prefix = "\(nodeId.uuidString)_"
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    /// 取消指定周期的所有待发送通知
    ///
    /// - Parameter cycleId: 周期 ID
    public func cancelCycleNotifications(for cycleId: UUID) {
        let identifiers = [
            cycleExpirationIdentifier(cycleId: cycleId),
            cycleEndingSoonIdentifier(cycleId: cycleId)
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// 取消所有待发送的 OKR 通知
    public func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Notification History

    /// 获取通知历史记录
    ///
    /// - Parameter limit: 返回记录数量限制（默认 100）
    /// - Returns: 通知历史记录数组，按时间降序排列
    public func getNotificationHistory(limit: Int = 100) -> [NotificationRecord] {
        guard let data = UserDefaults.standard.data(forKey: NotificationService.historyKey),
              let records = try? JSONDecoder().decode([NotificationRecord].self, from: data) else {
            return []
        }
        return Array(records.sorted { $0.sentAt > $1.sentAt }.prefix(limit))
    }

    /// 按分组获取通知历史
    ///
    /// - Parameters:
    ///   - group: 分组方式
    ///   - limit: 每组返回的记录数量限制
    /// - Returns: 按分组键组织的通知记录
    public func getNotificationHistory(
        groupedBy group: NotificationGroup,
        limit: Int = 50
    ) -> [String: [NotificationRecord]] {
        let allRecords = getNotificationHistory(limit: 500)

        switch group {
        case .byCycle:
            var grouped: [String: [NotificationRecord]] = [:]
            for record in allRecords {
                let key = record.cycleId?.uuidString ?? "未分类"
                grouped[key, default: []].append(record)
            }
            // 每组限制数量
            return grouped.mapValues { Array($0.prefix(limit)) }

        case .byOwner:
            // 按通知类型分组（因为通知记录不直接存储 owner）
            var grouped: [String: [NotificationRecord]] = [:]
            for record in allRecords {
                let key = record.type.displayName
                grouped[key, default: []].append(record)
            }
            return grouped.mapValues { Array($0.prefix(limit)) }

        case .none:
            return ["全部": Array(allRecords.prefix(limit))]
        }
    }

    /// 标记通知为已读
    ///
    /// - Parameter recordId: 通知记录 ID
    public func markNotificationAsRead(recordId: UUID) {
        guard var records = try? JSONDecoder().decode(
            [NotificationRecord].self,
            from: UserDefaults.standard.data(forKey: NotificationService.historyKey) ?? Data()
        ) else { return }

        if let index = records.firstIndex(where: { $0.id == recordId }) {
            let record = records[index]
            let updatedRecord = NotificationRecord(
                id: record.id,
                title: record.title,
                body: record.body,
                type: record.type,
                cycleId: record.cycleId,
                nodeId: record.nodeId,
                group: record.group,
                sentAt: record.sentAt,
                isRead: true
            )
            records[index] = updatedRecord

            if let data = try? JSONEncoder().encode(records) {
                UserDefaults.standard.set(data, forKey: NotificationService.historyKey)
            }
        }
    }

    /// 标记所有通知为已读
    public func markAllNotificationsAsRead() {
        guard var records = try? JSONDecoder().decode(
            [NotificationRecord].self,
            from: UserDefaults.standard.data(forKey: NotificationService.historyKey) ?? Data()
        ) else { return }

        records = records.map { record in
            NotificationRecord(
                id: record.id,
                title: record.title,
                body: record.body,
                type: record.type,
                cycleId: record.cycleId,
                nodeId: record.nodeId,
                group: record.group,
                sentAt: record.sentAt,
                isRead: true
            )
        }

        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: NotificationService.historyKey)
        }
    }

    /// 清除通知历史
    public func clearNotificationHistory() {
        UserDefaults.standard.removeObject(forKey: NotificationService.historyKey)
    }

    // MARK: - Notification Statistics

    /// 获取通知统计信息
    ///
    /// - Returns: 通知统计数据
    public func getNotificationStatistics() -> NotificationStatistics {
        let records = getNotificationHistory(limit: 1000)

        let totalSent = records.count
        let unreadCount = records.filter { !$0.isRead }.count

        // 按类型统计
        var byType: [NotificationType: Int] = [:]
        for type in NotificationType.allCases {
            byType[type] = records.filter { $0.type == type }.count
        }

        // 按周期统计
        var byCycle: [String: Int] = [:]
        for record in records {
            let key = record.cycleId?.uuidString ?? "未分类"
            byCycle[key, default: 0] += 1
        }

        // 最近 7 天每天发送数
        let calendar = Calendar.current
        let today = Date()
        var last7Days: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dateString = dateFormatter.string(from: date)
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            last7Days[dateString] = records.filter { $0.sentAt >= dayStart && $0.sentAt < dayEnd }.count
        }

        let lastNotificationDate = records.sorted { $0.sentAt > $1.sentAt }.first?.sentAt

        return NotificationStatistics(
            totalSent: totalSent,
            unreadCount: unreadCount,
            byType: byType,
            byCycle: byCycle,
            last7Days: last7Days,
            lastNotificationDate: lastNotificationDate
        )
    }

    // MARK: - Notification Settings

    /// 注册通知类别和操作
    ///
    /// 在 App 启动时调用，注册自定义通知类别和交互操作。
    public func registerNotificationCategories() {
        // 进度里程碑通知类别
        let progressCategory = UNNotificationCategory(
            identifier: Category.progressMilestone,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // 周期到期通知类别
        let expirationCategory = UNNotificationCategory(
            identifier: Category.cycleExpiration,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // 周期即将结束通知类别
        let endingSoonCategory = UNNotificationCategory(
            identifier: Category.cycleEndingSoon,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // 每日提醒通知类别
        let dailyCategory = UNNotificationCategory(
            identifier: Category.dailyReminder,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // 每周提醒通知类别
        let weeklyCategory = UNNotificationCategory(
            identifier: Category.weeklyReminder,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        notificationCenter.setNotificationCategories([
            progressCategory,
            expirationCategory,
            endingSoonCategory,
            dailyCategory,
            weeklyCategory
        ])
    }

    // MARK: - Private Helpers

    /// 安排每日提醒
    private func scheduleDailyReminder(hour: Int, minute: Int) {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.dailyReminder
        content.title = "📋 OKR 每日提醒"
        content.body = "新的一天开始了！查看你的 OKR 进度，保持目标推进。"
        content.sound = .default
        content.userInfo = [NotificationService.typeKey: NotificationType.dailyReminder.rawValue]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "okr_daily_reminder",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { [weak self] error in
            if error == nil {
                self?.addNotificationRecord(
                    title: content.title,
                    body: content.body,
                    type: .dailyReminder
                )
            }
        }
    }

    /// 安排每周提醒
    private func scheduleWeeklyReminder(weekday: Int, hour: Int, minute: Int) {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute

        let weekdayNames = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let weekdayName = weekday >= 1 && weekday <= 7 ? weekdayNames[weekday] : "周一"

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.weeklyReminder
        content.title = "📊 OKR 每周回顾"
        content.body = "又到了\(weekdayName)！回顾本周 OKR 完成情况，规划下周目标。"
        content.sound = .default
        content.userInfo = [NotificationService.typeKey: NotificationType.weeklyReminder.rawValue]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "okr_weekly_reminder",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { [weak self] error in
            if error == nil {
                self?.addNotificationRecord(
                    title: content.title,
                    body: content.body,
                    type: .weeklyReminder
                )
            }
        }
    }

    /// 添加通知历史记录
    private func addNotificationRecord(
        title: String,
        body: String,
        type: NotificationType,
        cycleId: UUID? = nil,
        nodeId: UUID? = nil
    ) {
        var records = getNotificationHistory(limit: 1000)
        let group: String? = {
            switch groupMode {
            case .byCycle: return cycleId?.uuidString
            case .byOwner: return nil
            case .none: return nil
            }
        }()

        let record = NotificationRecord(
            title: title,
            body: body,
            type: type,
            cycleId: cycleId,
            nodeId: nodeId,
            group: group,
            sentAt: Date(),
            isRead: false
        )

        records.insert(record, at: 0)

        // 保留最近 500 条记录
        if records.count > 500 {
            records = Array(records.prefix(500))
        }

        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: NotificationService.historyKey)
        }
    }

    /// 生成进度通知标识符
    private func progressNotificationIdentifier(nodeId: UUID, threshold: Double) -> String {
        "\(nodeId.uuidString)_progress_\(Int(threshold))"
    }

    /// 生成周期到期通知标识符
    private func cycleExpirationIdentifier(cycleId: UUID) -> String {
        "cycle_\(cycleId.uuidString)_expiration"
    }

    /// 生成周期即将结束通知标识符
    private func cycleEndingSoonIdentifier(cycleId: UUID) -> String {
        "cycle_\(cycleId.uuidString)_ending_soon"
    }

    /// 创建进度里程碑通知内容
    private func createProgressNotificationContent(
        node: OKRNode,
        threshold: Double
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.progressMilestone

        let thresholdText = String(format: "%.0f%%", threshold)
        if threshold >= 100 {
            content.title = "🎉 KR 已完成"
            content.body = "「\(node.title)」已达成 100% 目标！"
        } else {
            content.title = "📈 KR 进度更新"
            content.body = "「\(node.title)」进度已达到 \(thresholdText)，继续保持！"
        }

        content.sound = .default
        content.userInfo = [
            NotificationService.nodeIdKey: node.id.uuidString,
            NotificationService.typeKey: NotificationType.progressMilestone.rawValue
        ]

        return content
    }

    /// 创建周期到期通知内容
    private func createCycleExpirationContent(cycle: OKRCycle) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.cycleExpiration
        content.title = "⏰ OKR 周期已结束"
        content.body = "「\(cycle.name)」周期已到期，请查看最终进度并进行总结。"
        content.sound = .default
        content.userInfo = [
            NotificationService.cycleIdKey: cycle.id.uuidString,
            NotificationService.typeKey: NotificationType.cycleExpiration.rawValue
        ]
        return content
    }

    /// 创建周期即将结束通知内容
    private func createCycleEndingSoonContent(cycle: OKRCycle) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.cycleEndingSoon
        content.title = "⏳ OKR 周期即将结束"
        content.body = "「\(cycle.name)」将在 \(NotificationService.cycleEndingSoonDays) 天后结束，请抓紧完成剩余目标。"
        content.sound = .default
        content.userInfo = [
            NotificationService.cycleIdKey: cycle.id.uuidString,
            NotificationService.typeKey: NotificationType.cycleEndingSoon.rawValue
        ]
        return content
    }
}
