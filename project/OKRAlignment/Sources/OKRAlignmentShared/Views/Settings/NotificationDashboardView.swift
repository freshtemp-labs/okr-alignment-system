// OKRAlignmentShared/Views/Settings/NotificationDashboardView.swift

import SwiftUI
import UserNotifications

/// 通知仪表盘视图
///
/// 提供通知系统的综合监控和管理界面，包括：
/// - 通知健康状态概览
/// - 通知统计图表（按类型、按天分布）
/// - 通知渠道配置
/// - 通知模板管理
/// - 未读通知快速处理
/// - 通知历史时间线
///
/// ## 使用示例
/// ```swift
/// NotificationDashboardView(notificationService: NotificationService())
/// ```
public struct NotificationDashboardView: View {

    // MARK: - Properties

    private let notificationService: NotificationService

    /// 通知统计
    @State private var statistics: NotificationService.NotificationStatistics?
    /// 通知历史
    @State private var history: [NotificationService.NotificationRecord] = []
    /// 授权状态
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    /// 是否显示通知历史
    @State private var showFullHistory = false
    /// 是否显示通知设置
    @State private var showSettings = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    public init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 状态总览
                    notificationStatusCard

                    // 未读通知
                    if let stats = statistics, stats.unreadCount > 0 {
                        unreadNotificationsSection
                    }

                    // 统计概要
                    if let stats = statistics {
                        statsOverviewSection(stats: stats)
                    }

                    // 按类型统计图表
                    if let stats = statistics {
                        typeDistributionSection(stats: stats)
                    }

                    // 最近7天趋势
                    if let stats = statistics, !stats.last7Days.isEmpty {
                        weeklyTrendSection(stats: stats)
                    }

                    // 最近通知时间线
                    recentNotificationsSection
                }
                .padding()
            }
            .navigationTitle("通知仪表盘")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .task {
                await loadData()
            }
            .sheet(isPresented: $showFullHistory) {
                NotificationFullHistoryView(notificationService: notificationService)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    NotificationSettingsView(notificationService: notificationService)
                        .navigationTitle("通知设置")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                }
            }
        }
        .frame(minWidth: 480, minHeight: 600)
    }

    // MARK: - Notification Status Card

    private var notificationStatusCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(.title3.bold())
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // 快速操作
            HStack(spacing: 12) {
                QuickNotifyActionButton(
                    icon: "bell.badge.fill",
                    title: "全部已读",
                    color: .blue
                ) {
                    notificationService.markAllNotificationsAsRead()
                    Task { await loadData() }
                }

                QuickNotifyActionButton(
                    icon: "trash",
                    title: "清除历史",
                    color: .red
                ) {
                    notificationService.clearNotificationHistory()
                    Task { await loadData() }
                }

                QuickNotifyActionButton(
                    icon: "gear",
                    title: "设置",
                    color: .gray
                ) {
                    showSettings = true
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Unread Notifications Section

    private var unreadNotificationsSection: some View {
        let unreadRecords = history.filter { !$0.isRead }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("未读通知", systemImage: "bell.badge.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(unreadRecords.count) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(unreadRecords.prefix(5)) { record in
                HStack(spacing: 10) {
                    Image(systemName: record.type.iconName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title)
                            .font(.caption.weight(.medium))
                        Text(record.body)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(record.sentAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    // 贪睡按钮
                    Button {
                        notificationService.snoozeNotification(recordId: record.id, minutes: 15)
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("延迟 15 分钟提醒")
                }
                .padding(8)
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onTapGesture {
                    notificationService.markNotificationAsRead(recordId: record.id)
                    Task { await loadData() }
                }
            }

            if unreadRecords.count > 5 {
                Button("查看全部 \(unreadRecords.count) 条未读") {
                    showFullHistory = true
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stats Overview Section

    private func statsOverviewSection(stats: NotificationService.NotificationStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("统计概览")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                NotifyMetricCard(title: "总发送", value: "\(stats.totalSent)", icon: "paperplane.fill", color: .blue)
                NotifyMetricCard(title: "未读", value: "\(stats.unreadCount)", icon: "bell.badge", color: stats.unreadCount > 0 ? .orange : .gray)
                NotifyMetricCard(title: "已读率", value: stats.totalSent > 0
                    ? String(format: "%.0f%%", Double(stats.totalSent - stats.unreadCount) / Double(max(stats.totalSent, 1)) * 100)
                    : "—", icon: "checkmark.circle", color: .green)
                NotifyMetricCard(title: "类型数", value: "\(stats.byType.filter({ $0.value > 0 }).count)", icon: "tag.fill", color: .purple)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Type Distribution Section

    private func typeDistributionSection(stats: NotificationService.NotificationStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按类型分布")
                .font(.headline)

            let sortedTypes = stats.byType.sorted(by: { $0.value > $1.value })
            let maxCount = sortedTypes.first?.value ?? 1

            ForEach(sortedTypes.filter({ $0.value > 0 }), id: \.key) { type, count in
                HStack(spacing: 10) {
                    Image(systemName: type.iconName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 20)

                    Text(type.displayName)
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue.gradient)
                                    .frame(width: max(0, geo.size.width * CGFloat(count) / CGFloat(max(maxCount, 1))))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            )
                    }
                    .frame(height: 16)

                    Text("\(count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Weekly Trend Section

    private func weeklyTrendSection(stats: NotificationService.NotificationStatistics) -> some View {
        let last7Days = stats.last7Days.sorted(by: { $0.key < $1.key })
        let maxCount = last7Days.map(\.value).max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("最近 7 天通知趋势")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(last7Days, id: \.key) { day, count in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.gradient)
                            .frame(height: max(4, CGFloat(count) / CGFloat(maxCount) * 80))

                        Text(day)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        Text("\(count)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Notifications Section

    private var recentNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近通知")
                    .font(.headline)
                Spacer()
                if history.count > 5 {
                    Button("查看全部") {
                        showFullHistory = true
                    }
                    .font(.caption)
                }
            }

            if history.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("暂无通知记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(history.prefix(8)) { record in
                        NotifyTimelineRow(record: record)
                        if record.id != history.prefix(8).last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func loadData() async {
        authStatus = await notificationService.authorizationStatus()
        statistics = notificationService.getNotificationStatistics()
        history = notificationService.getNotificationHistory(limit: 50)
    }

    private var statusColor: Color {
        switch authStatus {
        case .authorized: return .green
        case .denied: return .red
        case .notDetermined: return .gray
        case .provisional: return .orange
        case .ephemeral: return .blue
        @unknown default: return .gray
        }
    }

    private var statusIcon: String {
        switch authStatus {
        case .authorized: return "bell.fill"
        case .denied: return "bell.slash.fill"
        case .notDetermined: return "bell.questionmark"
        case .provisional: return "bell.badge.fill"
        case .ephemeral: return "bell.circle.fill"
        @unknown default: return "bell"
        }
    }

    private var statusTitle: String {
        switch authStatus {
        case .authorized: return "通知已启用"
        case .denied: return "通知已禁用"
        case .notDetermined: return "未授权"
        case .provisional: return "临时授权"
        case .ephemeral: return "临时通知"
        @unknown default: return "未知"
        }
    }

    private var statusDescription: String {
        switch authStatus {
        case .authorized: return "您将收到 OKR 进度和周期提醒通知"
        case .denied: return "请在系统设置中允许通知权限"
        case .notDetermined: return "请先授权通知权限以接收提醒"
        case .provisional: return "通知以静默方式发送"
        case .ephemeral: return "仅在应用使用期间发送通知"
        @unknown default: return "无法确定通知状态"
        }
    }
}

// MARK: - Quick Notify Action Button

private struct QuickNotifyActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notify Metric Card

private struct NotifyMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.callout.bold())
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Notify Timeline Row

private struct NotifyTimelineRow: View {
    let record: NotificationService.NotificationRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.type.iconName)
                .font(.caption)
                .foregroundStyle(record.isRead ? Color.secondary : Color.blue)
                .frame(width: 24, height: 24)
                .background((record.isRead ? Color.secondary : Color.blue).opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.title)
                        .font(.caption)
                        .fontWeight(record.isRead ? .regular : .semibold)
                        .lineLimit(1)
                    if !record.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(record.body)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(record.sentAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(record.type.displayName)
                    .font(.system(size: 8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Notification Full History View

private struct NotificationFullHistoryView: View {
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

                if selectedGroup == .none {
                    ForEach(records) { record in
                        fullHistoryRow(record)
                    }
                } else {
                    let grouped = notificationService.getNotificationHistory(
                        groupedBy: selectedGroup,
                        limit: 50
                    )
                    ForEach(Array(grouped.keys.sorted()), id: \.self) { key in
                        Section(key) {
                            ForEach(grouped[key] ?? []) { record in
                                fullHistoryRow(record)
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
                ToolbarItem(placement: .primaryAction) {
                    Button("清除") {
                        notificationService.clearNotificationHistory()
                        loadRecords()
                    }
                    .foregroundStyle(.red)
                }
            }
            .onAppear {
                loadRecords()
            }
        }
    }

    @ViewBuilder
    private func fullHistoryRow(_ record: NotificationService.NotificationRecord) -> some View {
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
