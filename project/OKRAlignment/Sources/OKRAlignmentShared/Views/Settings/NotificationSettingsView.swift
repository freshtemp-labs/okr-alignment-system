// OKRAlignmentShared/Views/Settings/NotificationSettingsView.swift

import SwiftUI
import UserNotifications

/// 通知设置视图
///
/// 提供通知功能的开关和配置界面，包括：
/// - 通知总开关
/// - 进度里程碑通知开关
/// - 周期到期提醒开关
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

    /// 授权状态
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Initialization

    public init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    // MARK: - Body

    public var body: some View {
        Form {
            // 通知权限状态
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

            // 通知开关
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
                    .onChange(of: progressMilestoneEnabled) { _, newValue in
                        saveSettings()
                    }

                    Toggle(isOn: $cycleExpirationEnabled) {
                        Label("周期到期提醒", systemImage: "clock.badge.exclamationmark")
                    }
                    .onChange(of: cycleExpirationEnabled) { _, newValue in
                        saveSettings()
                    }

                    Toggle(isOn: $cycleEndingSoonEnabled) {
                        Label("周期即将结束提醒", systemImage: "clock.badge")
                    }
                    .onChange(of: cycleEndingSoonEnabled) { _, newValue in
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
        .formStyle(.grouped)
        .task {
            await loadAuthorizationStatus()
            loadSettings()
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
    }

    /// 保存设置
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(progressMilestoneEnabled, forKey: "okr_notification_progress_milestone")
        defaults.set(cycleExpirationEnabled, forKey: "okr_notification_cycle_expiration")
        defaults.set(cycleEndingSoonEnabled, forKey: "okr_notification_cycle_ending_soon")
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
