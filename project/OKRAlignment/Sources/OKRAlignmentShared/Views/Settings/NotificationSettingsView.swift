// OKRAlignmentShared/Views/Settings/NotificationSettingsView.swift

import SwiftUI

/// 通知设置视图（增强版）
/// ================
/// 提供完整的通知管理界面，包括：
/// - 自定义通知时间（每天/每周）
/// - 通知分组设置（按周期/按Owner/按类型）
/// - 通知历史记录
/// - 通知统计
/// - 免打扰时间设置
///
/// ## 使用示例
/// ```swift
/// NavigationLink {
///     NotificationSettingsView()
/// } label: {
///     Label("通知设置", systemImage: "bell.badge")
/// }
/// ```
public struct NotificationSettingsView: View {

    // MARK: - Properties

    /// 通知服务
    @State private var notificationService: NotificationService

    /// 每日提醒是否启用
    @State private var dailyReminderEnabled = false
    /// 每日提醒小时
    @State private var dailyReminderHour = 9
    /// 每日提醒分钟
    @State private var dailyReminderMinute = 0

    /// 每周提醒是否启用
    @State private var weeklyReminderEnabled = false
    /// 每周提醒星期几
    @State private var weeklyReminderWeekday = 2
    /// 每周提醒小时
    @State private var weeklyReminderHour = 9
    /// 每周提醒分钟
    @State private var weeklyReminderMinute = 0

    /// 通知分组方式
    @State private var groupMode: NotificationService.NotificationGroup = .none

    /// 免打扰时间是否启用
    @State private var quietHoursEnabled = false
    /// 免打扰开始小时
    @State private var quietStartHour = 22
    /// 免打扰开始分钟
    @State private var quietStartMinute = 0
    /// 免打扰结束小时
    @State private var quietEndHour = 8
    /// 免打扰结束分钟
    @State private var quietEndMinute = 0

    /// 通知统计
    @State private var statistics: NotificationService.NotificationStatistics?
    /// 通知历史记录
    @State private var notificationHistory: [NotificationService.NotificationRecord] = []
    /// 是否显示通知历史
    @State private var showNotificationHistory = false
    /// 授权状态
    @State private var authStatus: String = "检查中..."

    // MARK: - Body

    public init(notificationService: NotificationService = NotificationService()) {
        _notificationService = State(initialValue: notificationService)
    }

    public var body: some View {
        Form {
            // 授权状态
            authorizationSection

            // 每日提醒
            dailyReminderSection

            // 每周提醒
            weeklyReminderSection

            // 通知分组
            groupModeSection

            // 免打扰时间
            quietHoursSection

            // 通知统计
            notificationStatsSection

            // 通知历史
            notificationHistorySection
        }
        .formStyle(.grouped)
        .navigationTitle("通知设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadSettings()
        }
    }

    // MARK: - Authorization Section

    private var authorizationSection: some View {
        Section {
            HStack {
                Label("通知权限", systemImage: "bell.badge")
                Spacer()
                Text(authStatus)
                    .font(.caption)
                    .foregroundStyle(authStatus == "已授权" ? .green : .orange)
            }

            Button {
                Task {
                    _ = try? await notificationService.requestAuthorization()
                    await checkAuthorization()
                }
            } label: {
                Label("请求通知权限", systemImage: "bell")
            }
        } header: {
            Text("通知权限")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("需要通知权限才能发送提醒通知。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Daily Reminder Section

    private var dailyReminderSection: some View {
        Section {
            Toggle(isOn: $dailyReminderEnabled) {
                Label("每日提醒", systemImage: "sunrise.fill")
            }
            .onChange(of: dailyReminderEnabled) { _, newValue in
                if newValue {
                    notificationService.setDailyReminder(hour: dailyReminderHour, minute: dailyReminderMinute)
                } else {
                    notificationService.cancelDailyReminder()
                }
            }

            if dailyReminderEnabled {
                HStack {
                    Text("提醒时间")
                    Spacer()
                    Picker("小时", selection: $dailyReminderHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                    .onChange(of: dailyReminderHour) { _, newValue in
                        notificationService.setDailyReminder(hour: newValue, minute: dailyReminderMinute)
                    }

                    Text(":")

                    Picker("分钟", selection: $dailyReminderMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                    .onChange(of: dailyReminderMinute) { _, newValue in
                        notificationService.setDailyReminder(hour: dailyReminderHour, minute: newValue)
                    }
                }
            }
        } header: {
            Text("每日提醒")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("每天在指定时间发送 OKR 进度概要提醒。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Weekly Reminder Section

    private var weeklyReminderSection: some View {
        Section {
            Toggle(isOn: $weeklyReminderEnabled) {
                Label("每周提醒", systemImage: "calendar")
            }
            .onChange(of: weeklyReminderEnabled) { _, newValue in
                if newValue {
                    notificationService.setWeeklyReminder(
                        weekday: weeklyReminderWeekday,
                        hour: weeklyReminderHour,
                        minute: weeklyReminderMinute
                    )
                } else {
                    notificationService.cancelWeeklyReminder()
                }
            }

            if weeklyReminderEnabled {
                HStack {
                    Text("提醒日期")
                    Spacer()
                    Picker("星期", selection: $weeklyReminderWeekday) {
                        Text("周日").tag(1)
                        Text("周一").tag(2)
                        Text("周二").tag(3)
                        Text("周三").tag(4)
                        Text("周四").tag(5)
                        Text("周五").tag(6)
                        Text("周六").tag(7)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: weeklyReminderWeekday) { _, newValue in
                        notificationService.setWeeklyReminder(
                            weekday: newValue,
                            hour: weeklyReminderHour,
                            minute: weeklyReminderMinute
                        )
                    }
                }

                HStack {
                    Text("提醒时间")
                    Spacer()
                    Picker("小时", selection: $weeklyReminderHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                    .onChange(of: weeklyReminderHour) { _, newValue in
                        notificationService.setWeeklyReminder(
                            weekday: weeklyReminderWeekday,
                            hour: newValue,
                            minute: weeklyReminderMinute
                        )
                    }

                    Text(":")

                    Picker("分钟", selection: $weeklyReminderMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                    .onChange(of: weeklyReminderMinute) { _, newValue in
                        notificationService.setWeeklyReminder(
                            weekday: weeklyReminderWeekday,
                            hour: weeklyReminderHour,
                            minute: newValue
                        )
                    }
                }
            }
        } header: {
            Text("每周提醒")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("每周在指定时间和日期发送 OKR 周报提醒。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Group Mode Section

    private var groupModeSection: some View {
        Section {
            Picker("通知分组", selection: $groupMode) {
                ForEach(NotificationService.NotificationGroup.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: groupIcon(mode))
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: groupMode) { _, newValue in
                notificationService.groupMode = newValue
            }
        } header: {
            Text("通知分组")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("设置通知在通知中心的分组方式。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Quiet Hours Section

    private var quietHoursSection: some View {
        Section {
            Toggle(isOn: $quietHoursEnabled) {
                Label("免打扰", systemImage: "moon.fill")
            }
            .onChange(of: quietHoursEnabled) { _, newValue in
                updateQuietHours()
            }

            if quietHoursEnabled {
                HStack {
                    Text("开始时间")
                    Spacer()
                    Picker("小时", selection: $quietStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                    .onChange(of: quietStartHour) { _, _ in updateQuietHours() }

                    Text(":")

                    Picker("分钟", selection: $quietStartMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                    .onChange(of: quietStartMinute) { _, _ in updateQuietHours() }
                }

                HStack {
                    Text("结束时间")
                    Spacer()
                    Picker("小时", selection: $quietEndHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                    .onChange(of: quietEndHour) { _, _ in updateQuietHours() }

                    Text(":")

                    Picker("分钟", selection: $quietEndMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                    .onChange(of: quietEndMinute) { _, _ in updateQuietHours() }
                }
            }
        } header: {
            Text("免打扰时间")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("免打扰期间收到的通知将在结束后推送。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Notification Stats Section

    private var notificationStatsSection: some View {
        Section {
            if let stats = statistics {
                NotificationStatsOverview(stats: stats)
            } else {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("加载统计中...")
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                loadStatistics()
            } label: {
                Label("刷新统计", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("通知统计")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Notification History Section

    private var notificationHistorySection: some View {
        Section {
            if notificationHistory.isEmpty {
                Text("暂无通知记录")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notificationHistory.prefix(5)) { record in
                    NotificationHistoryRow(record: record)
                }

                if notificationHistory.count > 5 {
                    Button {
                        showNotificationHistory = true
                    } label: {
                        HStack {
                            Text("查看全部 \(notificationHistory.count) 条记录")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if !notificationHistory.isEmpty {
                Button(role: .destructive) {
                    notificationService.clearNotificationHistory()
                    notificationHistory = []
                } label: {
                    Label("清除通知历史", systemImage: "trash")
                }
            }
        } header: {
            Text("通知历史")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showNotificationHistory) {
            NotificationHistoryListView(
                notificationService: notificationService,
                records: notificationHistory
            )
        }
    }

    // MARK: - Helpers

    private func loadSettings() async {
        // 加载通知调度配置
        let schedule = notificationService.getSchedule()
        dailyReminderEnabled = schedule.dailyReminderEnabled
        dailyReminderHour = schedule.dailyReminderHour
        dailyReminderMinute = schedule.dailyReminderMinute
        weeklyReminderEnabled = schedule.weeklyReminderEnabled
        weeklyReminderWeekday = schedule.weeklyReminderWeekday
        weeklyReminderHour = schedule.weeklyReminderHour
        weeklyReminderMinute = schedule.weeklyReminderMinute

        // 加载分组设置
        groupMode = notificationService.groupMode

        // 加载免打扰设置
        let quietHours = notificationService.quietHours
        quietHoursEnabled = quietHours.enabled
        quietStartHour = quietHours.startHour
        quietStartMinute = quietHours.startMinute
        quietEndHour = quietHours.endHour
        quietEndMinute = quietHours.endMinute

        // 加载统计和历史
        loadStatistics()
        loadHistory()

        // 检查授权状态
        await checkAuthorization()
    }

    private func loadStatistics() {
        statistics = notificationService.getNotificationStatistics()
    }

    private func loadHistory() {
        notificationHistory = notificationService.getNotificationHistory(limit: 50)
    }

    private func checkAuthorization() async {
        let status = await notificationService.authorizationStatus()
        switch status {
        case .authorized:
            authStatus = "已授权"
        case .denied:
            authStatus = "已拒绝"
        case .notDetermined:
            authStatus = "未确定"
        case .provisional:
            authStatus = "临时授权"
        case .ephemeral:
            authStatus = "临时"
        @unknown default:
            authStatus = "未知"
        }
    }

    private func updateQuietHours() {
        notificationService.quietHours = NotificationService.QuietHours(
            enabled: quietHoursEnabled,
            startHour: quietStartHour,
            startMinute: quietStartMinute,
            endHour: quietEndHour,
            endMinute: quietEndMinute
        )
    }

    private func groupIcon(_ mode: NotificationService.NotificationGroup) -> String {
        switch mode {
        case .byCycle: return "calendar"
        case .byOwner: return "person.2"
        case .byType: return "tag"
        case .none: return "line.3.horizontal"
        }
    }
}

// MARK: - Notification Stats Overview

private struct NotificationStatsOverview: View {
    let stats: NotificationService.NotificationStatistics

    var body: some View {
        VStack(spacing: 12) {
            // 概要指标
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                NotifStatsMetric(title: "总发送", value: "\(stats.totalSent)")
                NotifStatsMetric(title: "未读", value: "\(stats.unreadCount)", color: stats.unreadCount > 0 ? .orange : .blue)
                NotifStatsMetric(title: "最近7天", value: "\(stats.last7Days.values.reduce(0, +))")
            }

            // 按类型统计
            if !stats.byType.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("按类型统计")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(NotificationService.NotificationType.allCases, id: \.self) { type in
                        let count = stats.byType[type] ?? 0
                        if count > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: type.iconName)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .frame(width: 16)
                                Text(type.displayName)
                                    .font(.caption2)
                                    .frame(width: 70, alignment: .leading)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.blue.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.blue)
                                                .frame(width: max(0, geo.size.width * CGFloat(count) / CGFloat(max(stats.totalSent, 1))))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        )
                                }
                                .frame(height: 10)
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            // 最近7天趋势
            if !stats.last7Days.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近 7 天")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(stats.last7Days.sorted(by: { $0.key < $1.key })), id: \.key) { day, count in
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(height: max(4, CGFloat(count) * 6))
                                Text(day)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 50)
                }
            }

            // 最近通知时间
            if let lastDate = stats.lastNotificationDate {
                HStack {
                    Text("最近通知")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lastDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Notif Stats Metric

private struct NotifStatsMetric: View {
    let title: String
    let value: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Notification History Row

private struct NotificationHistoryRow: View {
    let record: NotificationService.NotificationRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: record.type.iconName)
                .foregroundStyle(record.isRead ? Color.secondary : Color.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.caption)
                    .lineLimit(1)
                    .fontWeight(record.isRead ? .regular : .medium)
                Text(record.body)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(record.sentAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Notification History List View

private struct NotificationHistoryListView: View {
    let notificationService: NotificationService
    let records: [NotificationService.NotificationRecord]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGroup: NotificationService.NotificationGroup = .none
    @State private var displayRecords: [NotificationService.NotificationRecord] = []

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
                    .pickerStyle(.segmented)
                }

                // 通知记录
                if selectedGroup == .none {
                    Section {
                        ForEach(displayRecords) { record in
                            NotificationHistoryDetailRow(record: record)
                        }
                    }
                } else {
                    let grouped = notificationService.getNotificationHistory(groupedBy: selectedGroup)
                    ForEach(grouped.keys.sorted(), id: \.self) { groupKey in
                        Section(groupKey) {
                            ForEach(grouped[groupKey] ?? []) { record in
                                NotificationHistoryDetailRow(record: record)
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
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("全部已读") {
                        notificationService.markAllNotificationsAsRead()
                    }
                    .foregroundStyle(.blue)
                }
            }
            .onAppear {
                displayRecords = records
            }
            .onChange(of: selectedGroup) { _, _ in
                if selectedGroup == .none {
                    displayRecords = notificationService.getNotificationHistory(limit: 100)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

// MARK: - Notification History Detail Row

private struct NotificationHistoryDetailRow: View {
    let record: NotificationService.NotificationRecord

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(record.isRead ? Color.clear : Color.blue.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: record.type.iconName)
                    .font(.caption)
                    .foregroundStyle(record.isRead ? Color.secondary : Color.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.subheadline)
                    .fontWeight(record.isRead ? .regular : .semibold)
                    .lineLimit(1)
                Text(record.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(record.type.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(record.sentAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(record.sentAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if !record.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .preferredColorScheme(.dark)
}
#endif
