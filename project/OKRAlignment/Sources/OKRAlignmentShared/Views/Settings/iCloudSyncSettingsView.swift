// OKRAlignmentShared/Views/Settings/iCloudSyncSettingsView.swift

import SwiftUI
#if canImport(CloudKit)
import CloudKit
#endif

/// iCloud 同步设置视图（增强版）
/// 提供 iCloud 同步的开关和状态展示
///
/// 功能说明：
/// - 开关控制是否启用 iCloud/CloudKit 数据同步
/// - 展示当前同步状态（已启用/未启用/不可用）
/// - 同步状态指示器（实时动画）
/// - 冲突解决策略选择
/// - 同步历史记录
/// - 同步详情展示
/// - 切换后需要重启应用生效
public struct iCloudSyncSettingsView: View {

    // MARK: - Properties

    /// iCloud 同步开关状态
    @State private var syncEnabled: Bool

    /// 同步状态描述
    @State private var syncStatus: SyncStatus = .unknown

    /// 是否显示重启提示
    @State private var showRestartAlert = false

    /// 同步管理器
    @StateObject private var syncManager = DataSyncManager.shared

    /// 是否显示同步历史
    @State private var showSyncHistory = false
    /// 是否显示同步仪表盘
    @State private var showSyncDashboard = false

    // MARK: - Initialization

    public init() {
        let isEnabled = UserDefaults.standard.bool(forKey: "okr_icloud_sync_enabled")
        _syncEnabled = State(initialValue: isEnabled)
    }

    // MARK: - Body

    public var body: some View {
        Form {
            // 同步开关
            Section {
                Toggle(isOn: $syncEnabled) {
                    Label {
                        Text("iCloud 同步")
                    } icon: {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                    }
                }
                .onChange(of: syncEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "okr_icloud_sync_enabled")
                    showRestartAlert = true
                }
            } header: {
                Text("同步设置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("启用后，您的 OKR 数据将通过 iCloud 在所有设备间同步。切换设置后需要重启应用生效。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 同步状态指示器
            if syncEnabled {
                Section {
                    // 实时同步状态
                    HStack(spacing: 12) {
                        // 状态动画指示器
                        ZStack {
                            Circle()
                                .fill(syncManager.syncState.color.opacity(0.2))
                                .frame(width: 40, height: 40)

                            if syncManager.syncState == .syncing {
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(syncManager.syncState.color, lineWidth: 2)
                                    .frame(width: 30, height: 30)
                                    .rotationEffect(.degrees(syncProgress ? 360 : 0))
                                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: syncProgress)
                            } else {
                                Image(systemName: syncManager.syncState.icon)
                                    .font(.body)
                                    .foregroundStyle(syncManager.syncState.color)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(syncManager.syncState.displayName)
                                .font(.body.weight(.medium))
                            if let lastDate = syncManager.lastSyncDate {
                                Text("上次同步: \(lastDate, style: .relative)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if syncManager.syncState == .idle || syncManager.syncState == .completed {
                            Button("立即同步") {
                                Task { await syncManager.startSync() }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    // 同步进度条
                    if syncManager.syncState == .syncing {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: syncManager.syncProgress)
                                .progressViewStyle(.linear)
                            Text("正在同步... \(Int(syncManager.syncProgress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 冲突提示
                    if syncManager.hasPendingConflicts {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(syncManager.pendingConflicts.count) 个冲突待解决")
                                .font(.callout.weight(.medium))
                            Spacer()
                            Button("查看") {
                                // Show conflicts
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                } header: {
                    Text("同步状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 冲突解决策略
                Section {
                    Picker("冲突解决策略", selection: $syncManager.conflictStrategy) {
                        ForEach(ConflictStrategy.allCases, id: \.self) { strategy in
                            Label(strategy.displayName, systemImage: strategy.icon)
                                .tag(strategy)
                        }
                    }
                    .pickerStyle(.menu)

                    // 当前策略说明
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text(syncManager.conflictStrategy.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("冲突解决")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("当多设备同时修改同一数据时，系统将按此策略处理冲突。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // 自动同步设置
                Section {
                    Toggle(isOn: $syncManager.autoSyncEnabled) {
                        Label("自动同步", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .onChange(of: syncManager.autoSyncEnabled) { _, newValue in
                        if newValue {
                            syncManager.startAutoSync()
                        } else {
                            syncManager.stopAutoSync()
                        }
                    }

                    if syncManager.autoSyncEnabled {
                        Picker("同步间隔", selection: $syncManager.autoSyncInterval) {
                            Text("每 1 分钟").tag(TimeInterval(60))
                            Text("每 5 分钟").tag(TimeInterval(300))
                            Text("每 15 分钟").tag(TimeInterval(900))
                            Text("每 30 分钟").tag(TimeInterval(1800))
                            Text("每 1 小时").tag(TimeInterval(3600))
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("自动同步")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } footer: {
                    if syncManager.autoSyncEnabled {
                        Text("应用将按设定间隔自动同步数据。")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // 同步信息
                Section {
                    statusRow(
                        icon: "icloud",
                        title: "同步状态",
                        value: syncStatus.displayName,
                        color: syncStatus.color
                    )

                    statusRow(
                        icon: "externaldrive.badge.icloud",
                        title: "容器标识",
                        value: PersistenceController.cloudKitContainerIdentifier,
                        color: .secondary
                    )

                    statusRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "冲突策略",
                        value: syncManager.conflictStrategy.displayName,
                        color: .blue
                    )

                    statusRow(
                        icon: "clock",
                        title: "最后同步",
                        value: syncManager.lastSyncDate.map { formatDate($0) } ?? "从未同步",
                        color: .secondary
                    )

                    // 同步历史按钮
                    Button {
                        showSyncHistory.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                                .frame(width: 20)
                            Text("同步历史")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(syncManager.syncHistory.count) 条记录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    // 同步仪表盘按钮
                    Button {
                        showSyncDashboard.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.bottom.fill")
                                .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                                .frame(width: 20)
                            Text("同步仪表盘")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("健康度 · 趋势")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("同步详情")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Last-Write-Wins 策略：当多设备同时修改同一数据时，最后写入的变更将被保留。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("iCloud 同步")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await checkSyncStatus()
        }
        .onAppear {
            syncProgress = true
        }
        .alert("需要重启", isPresented: $showRestartAlert) {
            Button("确定") {}
        } message: {
            Text("iCloud 同步设置已更改，请重启应用以使更改生效。")
        }
        .sheet(isPresented: $showSyncHistory) {
            SyncHistoryListView(syncManager: syncManager)
        }
        .sheet(isPresented: $showSyncDashboard) {
            SyncDashboardView(syncManager: syncManager)
        }
    }

    // MARK: - Subviews

    private func statusRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                .frame(width: 20)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(color)
        }
    }

    // MARK: - Helpers

    @State private var syncProgress = false

    /// 检查 iCloud 同步状态
    private func checkSyncStatus() async {
        #if canImport(CloudKit)
        guard syncEnabled else {
            syncStatus = .disabled
            return
        }

        do {
            let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
            let status = try await container.accountStatus()
            switch status {
            case .available:
                syncStatus = .available
            case .noAccount:
                syncStatus = .noAccount
            case .restricted:
                syncStatus = .restricted
            case .couldNotDetermine:
                syncStatus = .unknown
            case .temporarilyUnavailable:
                syncStatus = .temporarilyUnavailable
            @unknown default:
                syncStatus = .unknown
            }
        } catch {
            syncStatus = .error
        }
        #else
        syncStatus = .unsupported
        #endif
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Sync Status Enum

    private enum SyncStatus {
        case unknown
        case disabled
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case error
        case unsupported

        var displayName: String {
            switch self {
            case .unknown: return "检查中..."
            case .disabled: return "未启用"
            case .available: return "已就绪"
            case .noAccount: return "未登录 iCloud"
            case .restricted: return "受限"
            case .temporarilyUnavailable: return "暂时不可用"
            case .error: return "检查失败"
            case .unsupported: return "不支持"
            }
        }

        var color: Color {
            switch self {
            case .available: return .green
            case .disabled: return .gray
            case .noAccount, .restricted, .error, .temporarilyUnavailable: return .orange
            case .unknown, .unsupported: return .secondary
            }
        }
    }
}

// MARK: - Sync History List View

private struct SyncHistoryListView: View {
    @ObservedObject var syncManager: DataSyncManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if syncManager.syncHistory.isEmpty {
                    ContentUnavailableView(
                        "暂无同步记录",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("当您进行数据同步时，记录将显示在这里")
                    )
                } else {
                    List {
                        // 统计概要
                        Section {
                            let stats = syncManager.statistics
                            if stats.totalSyncs > 0 {
                                SyncStatsOverview(stats: stats)
                            }
                        }

                        // 历史记录
                        Section("同步记录") {
                            ForEach(syncManager.syncHistory) { entry in
                                SyncHistoryRow(entry: entry)
                            }
                        }
                    }
                }
            }
            .navigationTitle("同步历史")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if !syncManager.syncHistory.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("清空") {
                            syncManager.clearHistory()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

// MARK: - Sync History Row

private struct SyncHistoryRow: View {
    let entry: SyncHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Circle()
                .fill(entry.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.details)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label {
                        Text(entry.startTime, style: .time)
                    } icon: {
                        Image(systemName: "clock")
                    }
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let duration = entry.durationDisplay as String? {
                        Label(duration, systemImage: "timer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Label("\(entry.itemsSynced) 项", systemImage: "doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 状态标签
            Text(entry.status.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(entry.status.color.opacity(0.15))
                .foregroundStyle(entry.status.color)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        iCloudSyncSettingsView()
    }
    .preferredColorScheme(.dark)
}
#endif

// MARK: - Sync Stats Overview

private struct SyncStatsOverview: View {
    let stats: SyncStatistics

    var body: some View {
        VStack(spacing: 12) {
            // 概要指标
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                StatsMetric(title: "总同步", value: "\(stats.totalSyncs)")
                StatsMetric(title: "成功率", value: String(format: "%.0f%%", stats.successRate))
                StatsMetric(title: "平均耗时", value: stats.formattedAverageDuration)
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
        }
        .padding(.vertical, 4)
    }
}

private struct StatsMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.bold())
                .foregroundStyle(.blue)
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
