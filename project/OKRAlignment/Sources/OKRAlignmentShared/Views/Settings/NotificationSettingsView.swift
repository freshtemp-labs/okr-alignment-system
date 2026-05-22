// OKRAlignmentShared/Views/Settings/NotificationSettingsView.swift

import SwiftUI
import UserNotifications

/// 通知设置视图
///
/// 提供通知功能的完整配置界面，包括：
/// - 通知总开关
/// - 进度里程碑通知开关
/// - 周期到期提醒开关
/// - 自定义通知时间（每日/每周提醒）
/// - 通知分组设置
/// - 通知历史记录
/// - 通知统计信息
///
/// ## 使用示例
/// ```swift
/// NotificationSettingsView(notificationService: NotificationService())
/// ```
public struct NotificationSettingsView: View {

    // MARK: - Properties

    /// 通知服务
    private let notificationService: NotificationService

    /// 通知总开关
    @State private var notificationsEnabled = false
    /// 进度里程碑通知开关
    @State private var progressMilestoneEnabled = true
    /// 周期到期提醒开关
    @State private var cycleExpirationEnabled = true
    /// 周期即将结束提醒开关
    @State private var cycleEndingSoonEnabled = true

    /// 每日提醒开关
    @State private var dailyReminderEnabled = false
    /// 每日提醒时间
    @State private var dailyReminderTime = Date()
    /// 每周提醒开关
    @State private var weeklyReminderEnabled = false
    /// 每周提醒时间
    @State private var weeklyReminderTime = Date()
    /// 每周提醒的星期几
    @State private var weeklyReminderWeekday = 2

    /// 通知分组方式
    @State private var groupMode: NotificationService.NotificationGroup = .none

    /// 免打扰时间
    @State private var quietHoursEnabled = false
    @State private var quietStartTime = Date()
    @State private var quietEndTime = Date()

    /// 授权状态
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// 通知历史
    @State private var notificationHistory: [NotificationService.NotificationRecord] = []
    /// 通知统计
    @State private var statistics: NotificationService.NotificationStatistics?

    /// 是否显示历史记录
    @State private var showHistory = false
    /// 是否显示通知仪表盘
    @State private var showDashboard = false

    // MARK: - Initialization

    public init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    // MARK: - Body

    public var body: some View {
        Form {
            // 通知权限状态
            notificationPermissionSection

            // 通知开关
            notificationToggleSection

            // 自定义通知时间
            if notificationsEnabled {
                customScheduleSection
            }

            // 通知分组
            if notificationsEnabled {
                notificationGroupSection
            }

            // 免打扰时间
            if notificationsEnabled {
                quietHoursSection
            }

            // 通知统计
            if notificationsEnabled {
                notificationStatsSection
            }

            // 通知历史
            if notificationsEnabled {
                notificationHistorySection
            }
        }
        .formStyle(.grouped)
        .task {
            await loadAuthorizationStatus()
            loadSettings()
            loadStatistics()
            loadHistory()
        }
    }

    // MARK: - Sections

    /// 通知权限状态区域
    private var notificationPermissionSection: some View {
        Section {
            HStack {
                Image(systemName: statusIconName)
                    .foregroundColor(statusColor)
                Text("通知状态")
                Spacer()
                Text(statusText)
                    .foregroundColor(.secondary)
            }

            if authorizationStatus == .denied {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("请在系统设置中允许通知权限")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        } header: {
            Text("权限状态")
        }
    }

    /// 通知开关区域
    private var notificationToggleSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                Label("启用通知", systemImage: "bell.fill")
            }
            .onChange(of: notificationsEnabled) { _, newValue in
                if newValue {
                    Task {
                        await requestAuthorizationIfNeeded()
                    }
                }
            }

            if notificationsEnabled {
                Toggle(isOn: $progressMilestoneEnabled) {
                    Label("进度里程碑通知", systemImage: "chart.line.uptrend.xyaxis")
                }
                .onChange(of: progressMilestoneEnabled) { _, _ in
                    saveSettings()
                }

                Toggle(isOn: $cycleExpirationEnabled) {
                    Label("周期到期提醒", systemImage: "clock.badge.exclamationmark")
                }
                .onChange(of: cycleExpirationEnabled) { _, _ in
                    saveSettings()
                }

                Toggle(isOn: $cycleEndingSoonEnabled) {
                    Label("周期即将结束提醒", systemImage: "clock.badge")
                }
                .onChange(of: cycleEndingSoonEnabled) { _, _ in
                    saveSettings()
                }
            }
        } header: {
            Text("通知设置")
        } footer: {
            if notificationsEnabled {
                Text("进度里程碑通知会在 KR 达到 80% 和 100% 时发送。周期提醒会在周期结束前 7 天和到期时发送。")
                    .font(.caption)
            }
        }
    }

    /// 自定义通知时间区域
    private var customScheduleSection: some View {
        Section {
            // 每日提醒
            Toggle(isOn: $dailyReminderEnabled) {
                Label("每日提醒", systemImage: "sunrise.fill")
            }
            .onChange(of: dailyReminderEnabled) { _, newValue in
                if newValue {
                    let calendar = Calendar.current
                    let hour = calendar.component(.hour, from: dailyReminderTime)
                    let minute = calendar.component(.minute, from: dailyReminderTime)
                    notificationService.setDailyReminder(hour: hour, minute: minute)
                } else {
                    notificationService.cancelDailyReminder()
                }
            }

            if dailyReminderEnabled {
                DatePicker("提醒时间", selection: $dailyReminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: dailyReminderTime) { _, newValue in
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: newValue)
                        let minute = calendar.component(.minute, from: newValue)
                        notificationService.setDailyReminder(hour: hour, minute: minute)
                    }
            }

            // 每周提醒
            Toggle(isOn: $weeklyReminderEnabled) {
                Label("每周提醒", systemImage: "calendar")
            }
            .onChange(of: weeklyReminderEnabled) { _, newValue in
                if newValue {
                    let calendar = Calendar.current
                    let hour = calendar.component(.hour, from: weeklyReminderTime)
                    let minute = calendar.component(.minute, from: weeklyReminderTime)
                    notificationService.setWeeklyReminder(
                        weekday: weeklyReminderWeekday,
                        hour: hour,
                        minute: minute
                    )
                } else {
                    notificationService.cancelWeeklyReminder()
                }
            }

            if weeklyReminderEnabled {
                Picker("提醒星期", selection: $weeklyReminderWeekday) {
                    Text("周日").tag(1)
                    Text("周一").tag(2)
                    Text("周二").tag(3)
                    Text("周三").tag(4)
                    Text("周四").tag(5)
                    Text("周五").tag(6)
                    Text("周六").tag(7)
                }
                .onChange(of: weeklyReminderWeekday) { _, newValue in
                    let calendar = Calendar.current
                    let hour = calendar.component(.hour, from: weeklyReminderTime)
                    let minute = calendar.component(.minute, from: weeklyReminderTime)
                    notificationService.setWeeklyReminder(
                        weekday: newValue,
                        hour: hour,
                        minute: minute
                    )
                }

                DatePicker("提醒时间", selection: $weeklyReminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: weeklyReminderTime) { _, newValue in
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: newValue)
                        let minute = calendar.component(.minute, from: newValue)
                        notificationService.setWeeklyReminder(
                            weekday: weeklyReminderWeekday,
                            hour: hour,
                            minute: minute
                        )
                    }
            }
        } header: {
            Text("自定义通知时间")
        } footer: {
            Text("设置固定的通知时间，帮助养成定期回顾 OKR 的习惯。")
                .font(.caption)
        }
    }

    /// 通知分组设置区域
    private var notificationGroupSection: some View {
        Section {
            Picker("通知分组", selection: $groupMode) {
                ForEach(NotificationService.NotificationGroup.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .onChange(of: groupMode) { _, newValue in
                notificationService.groupMode = newValue
            }
        } header: {
            Text("通知分组")
        } footer: {
            Text("设置通知在通知中心的分组方式。")
                .font(.caption)
        }
    }

    /// 免打扰时间设置区域
    private var quietHoursSection: some View {
        Section {
            Toggle(isOn: $quietHoursEnabled) {
                Label("免打扰时间", systemImage: "moon.fill")
            }
            .onChange(of: quietHoursEnabled) { _, newValue in
                saveQuietHours()
            }

            if quietHoursEnabled {
                DatePicker("开始时间", selection: $quietStartTime, displayedComponents: .hourAndMinute)
                    .onChange(of: quietStartTime) { _, _ in
                        saveQuietHours()
                    }

                DatePicker("结束时间", selection: $quietEndTime, displayedComponents: .hourAndMinute)
                    .onChange(of: quietEndTime) { _, _ in
                        saveQuietHours()
                    }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("免打扰期间收到的通知将在时间结束后自动发送。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("免打扰时间")
        } footer: {
            if quietHoursEnabled {
                Text("免打扰时段: \(formatQuietTimeRange())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 通知统计区域
    private var notificationStatsSection: some View {
        Section {
            if let stats = statistics {
                HStack {
                    Text("总发送数")
                    Spacer()
                    Text("\(stats.totalSent)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("未读通知")
                    Spacer()
                    Text("\(stats.unreadCount)")
                        .foregroundColor(stats.unreadCount > 0 ? .orange : .secondary)
                }

                if let lastDate = stats.lastNotificationDate {
                    HStack {
                        Text("最近通知")
                        Spacer()
                        Text(lastDate, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }

                // 按类型统计
                ForEach(NotificationService.NotificationType.allCases, id: \.self) { type in
                    let count = stats.byType[type] ?? 0
                    if count > 0 {
                        HStack {
                            Label(type.displayName, systemImage: type.iconName)
                                .font(.caption)
                            Spacer()
                            Text("\(count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }

                // 最近 7 天趋势
                if !stats.last7Days.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最近 7 天")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(Array(stats.last7Days.sorted(by: { $0.key < $1.key })), id: \.key) { day, count in
                                VStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue.opacity(0.6))
                                        .frame(height: max(4, CGFloat(count) * 8))

                                    Text(day)
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 60)
                    }
                }

                // 通知仪表盘入口
                Button {
                    showDashboard = true
                } label: {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.bottom.fill")
                            .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                            .frame(width: 20)
                        Text("通知仪表盘")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("详细分析")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Text("暂无统计数据")
                        .foregroundColor(.secondary)
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            }
        } header: {
            Text("通知统计")
        }
    }

    /// 通知历史区域
    private var notificationHistorySection: some View {
        Section {
            if notificationHistory.isEmpty {
                HStack {
                    Text("暂无通知记录")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(notificationHistory.prefix(10)) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: record.type.iconName)
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(record.title)
                                .font(.subheadline)
                                .fontWeight(record.isRead ? .regular : .medium)
                            Spacer()
                            if !record.isRead {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Text(record.body)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        Text(record.sentAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }

                if notificationHistory.count > 10 {
                    Button("查看全部 \(notificationHistory.count) 条记录") {
                        showHistory = true
                    }
                    .font(.caption)
                }

                HStack {
                    Button("全部标为已读") {
                        notificationService.markAllNotificationsAsRead()
                        loadHistory()
                    }
                    .font(.caption)
                    .disabled(notificationHistory.allSatisfy { $0.isRead })

                    Spacer()

                    Button("清除历史", role: .destructive) {
                        notificationService.clearNotificationHistory()
                        loadHistory()
                        loadStatistics()
                    }
                    .font(.caption)
                }
            }
        } header: {
            Text("通知历史")
        }
        .sheet(isPresented: $showHistory) {
            NotificationHistoryView(notificationService: notificationService)
        }
        .sheet(isPresented: $showDashboard) {
            NavigationStack {
                NotificationDashboardView(notificationService: notificationService)
            }
        }
    }

    // MARK: - Private Helpers

    /// 加载通知授权状态
    private func loadAuthorizationStatus() async {
        authorizationStatus = await notificationService.authorizationStatus()
        notificationsEnabled = authorizationStatus == .authorized
    }

    /// 请求通知权限（如需要）
    private func requestAuthorizationIfNeeded() async {
        guard authorizationStatus == .notDetermined else { return }
        do {
            let granted = try await notificationService.requestAuthorization()
            authorizationStatus = granted ? .authorized : .denied
            if !granted {
                notificationsEnabled = false
            }
        } catch {
            notificationsEnabled = false
        }
    }

    /// 加载设置
    private func loadSettings() {
        let defaults = UserDefaults.standard
        progressMilestoneEnabled = defaults.bool(forKey: "okr_notification_progress_milestone")
        cycleExpirationEnabled = defaults.bool(forKey: "okr_notification_cycle_expiration")
        cycleEndingSoonEnabled = defaults.bool(forKey: "okr_notification_cycle_ending_soon")

        // 加载自定义通知时间配置
        let schedule = notificationService.getSchedule()
        dailyReminderEnabled = schedule.dailyReminderEnabled
        weeklyReminderEnabled = schedule.weeklyReminderEnabled
        weeklyReminderWeekday = schedule.weeklyReminderWeekday

        let calendar = Calendar.current
        var dailyComponents = DateComponents()
        dailyComponents.hour = schedule.dailyReminderHour
        dailyComponents.minute = schedule.dailyReminderMinute
        dailyReminderTime = calendar.date(from: dailyComponents) ?? Date()

        var weeklyComponents = DateComponents()
        weeklyComponents.hour = schedule.weeklyReminderHour
        weeklyComponents.minute = schedule.weeklyReminderMinute
        weeklyReminderTime = calendar.date(from: weeklyComponents) ?? Date()

        groupMode = notificationService.groupMode

        // 加载免打扰时间配置
        let qh = notificationService.quietHours
        quietHoursEnabled = qh.enabled
        let calendar2 = Calendar.current
        var qStartComponents = DateComponents()
        qStartComponents.hour = qh.startHour
        qStartComponents.minute = qh.startMinute
        quietStartTime = calendar2.date(from: qStartComponents) ?? Date()
        var qEndComponents = DateComponents()
        qEndComponents.hour = qh.endHour
        qEndComponents.minute = qh.endMinute
        quietEndTime = calendar2.date(from: qEndComponents) ?? Date()
    }

    /// 保存设置
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(progressMilestoneEnabled, forKey: "okr_notification_progress_milestone")
        defaults.set(cycleExpirationEnabled, forKey: "okr_notification_cycle_expiration")
        defaults.set(cycleEndingSoonEnabled, forKey: "okr_notification_cycle_ending_soon")
    }

    /// 加载统计数据
    private func loadStatistics() {
        statistics = notificationService.getNotificationStatistics()
    }

    /// 加载历史记录
    private func loadHistory() {
        notificationHistory = notificationService.getNotificationHistory(limit: 20)
    }

    /// 保存免打扰时间配置
    private func saveQuietHours() {
        let calendar = Calendar.current
        var config = notificationService.quietHours
        config.enabled = quietHoursEnabled
        config.startHour = calendar.component(.hour, from: quietStartTime)
        config.startMinute = calendar.component(.minute, from: quietStartTime)
        config.endHour = calendar.component(.hour, from: quietEndTime)
        config.endMinute = calendar.component(.minute, from: quietEndTime)
        notificationService.quietHours = config
    }

    /// 格式化免打扰时间范围
    private func formatQuietTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: quietStartTime)
        let end = formatter.string(from: quietEndTime)
        return "\(start) - \(end)"
    }

    /// 状态图标名称
    private var statusIconName: String {
        switch authorizationStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied, .ephemeral:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .provisional:
            return "bell.badge.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    /// 状态颜色
    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized:
            return .green
        case .denied, .ephemeral:
            return .red
        case .notDetermined:
            return .gray
        case .provisional:
            return .orange
        @unknown default:
            return .gray
        }
    }

    /// 状态文本
    private var statusText: String {
        switch authorizationStatus {
        case .authorized:
            return "已授权"
        case .denied:
            return "已拒绝"
        case .notDetermined:
            return "未确定"
        case .provisional:
            return "临时授权"
        case .ephemeral:
            return "临时"
        @unknown default:
            return "未知"
        }
    }
}

// MARK: - Notification History View

/// 通知历史详情视图
private struct NotificationHistoryView: View {

    let notificationService: NotificationService

    @State private var records: [NotificationService.NotificationRecord] = []
    @State private var selectedGroup: NotificationService.NotificationGroup = .none
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // 分组选择
                Section {
                    Picker("分组方式", selection: $selectedGroup) {
                        ForEach(NotificationService.NotificationGroup.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .onChange(of: selectedGroup) { _, _ in
                        loadRecords()
                    }
                }

                // 记录列表
                if selectedGroup == .none {
                    ForEach(records) { record in
                        notificationRow(record)
                    }
                } else {
                    let grouped = notificationService.getNotificationHistory(
                        groupedBy: selectedGroup,
                        limit: 50
                    )
                    ForEach(Array(grouped.keys.sorted()), id: \.self) { key in
                        Section(key) {
                            ForEach(grouped[key] ?? []) { record in
                                notificationRow(record)
                            }
                        }
                    }
                }
            }
            .navigationTitle("通知历史")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("清除") {
                        notificationService.clearNotificationHistory()
                        loadRecords()
                    }
                }
            }
            .onAppear {
                loadRecords()
            }
        }
    }

    @ViewBuilder
    private func notificationRow(_ record: NotificationService.NotificationRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: record.type.iconName)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(record.title)
                    .font(.subheadline)
                    .fontWeight(record.isRead ? .regular : .semibold)
                Spacer()
                if !record.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }

            Text(record.body)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            HStack {
                Text(record.type.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)

                Spacer()

                Text(record.sentAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .onTapGesture {
            notificationService.markNotificationAsRead(recordId: record.id)
            loadRecords()
        }
    }

    private func loadRecords() {
        records = notificationService.getNotificationHistory(limit: 100)
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        NotificationSettingsView(notificationService: NotificationService())
    }
    .preferredColorScheme(.dark)
}
#endif
