// OKRAlignmentShared/Services/NotificationService.swift

import Foundation
import UserNotifications

/// OKR 通知服务
///
/// 管理 OKR 系统相关的本地通知，包括：
/// - KR 进度里程碑通知（达到 80%、100%）
/// - OKR 周期到期提醒通知
/// - 周期即将结束提醒
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
/// try await notificationService.scheduleProgressNotification(for: node)
/// // 周期到期提醒
/// try await notificationService.scheduleCycleExpirationReminder(for: cycle)
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
    }

    /// 进度里程碑阈值（百分比）
    public static let progressThresholds: [Double] = [80.0, 100.0]

    /// 周期即将到期的提前天数
    public static let cycleEndingSoonDays = 7

    /// 用户信息中存储节点 ID 的键
    private static let nodeIdKey = "node_id"
    /// 用户信息中存储周期 ID 的键
    private static let cycleIdKey = "cycle_id"

    // MARK: - Properties

    /// 通知中心
    private let notificationCenter = UNUserNotificationCenter.current()

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

                // 立即发送
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                try await notificationCenter.add(request)
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

        notificationCenter.setNotificationCategories([
            progressCategory,
            expirationCategory,
            endingSoonCategory
        ])
    }

    // MARK: - Private Helpers

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
            NotificationService.nodeIdKey: node.id.uuidString
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
            NotificationService.cycleIdKey: cycle.id.uuidString
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
            NotificationService.cycleIdKey: cycle.id.uuidString
        ]
        return content
    }
}
