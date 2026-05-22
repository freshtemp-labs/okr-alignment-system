// OKRAlignmentShared/Views/Settings/SyncDashboardView.swift

import SwiftUI

/// 同步仪表盘视图
///
/// 提供一站式的同步监控体验，包括：
/// - 实时同步状态指示器（带动画）
/// - 同步健康评分
/// - 最近同步活动时间线
/// - 快速冲突解决入口
/// - 同步性能指标（平均耗时、成功率）
/// - 7天同步趋势图
///
/// ## 使用示例
/// ```swift
/// SyncDashboardView()
/// ```
public struct SyncDashboardView: View {

    // MARK: - Properties

    @ObservedObject private var syncManager: DataSyncManager
    @Environment(\.dismiss) private var dismiss

    /// 是否显示冲突解决面板
    @State private var showConflictResolver = false

    /// 是否显示同步历史
    @State private var showSyncHistory = false

    // MARK: - Initialization

    public init(syncManager: DataSyncManager = .shared) {
        self._syncManager = ObservedObject(wrappedValue: syncManager)
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 实时状态卡片
                    syncStatusCard

                    // 健康评分
                    healthScoreSection

                    // 快速操作
                    quickActionsSection

                    // 性能指标
                    performanceMetricsSection

                    // 最近活动时间线
                    recentActivitySection

                    // 错误历史
                    if !syncManager.errorHistory.isEmpty {
                        SyncErrorHistorySection(syncManager: syncManager)
                    }

                    // 7天趋势
                    if !syncManager.statistics.last7Days.isEmpty {
                        weeklyTrendSection
                    }
                }
                .padding()
            }
            .navigationTitle("同步仪表盘")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSyncHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showConflictResolver) {
                ConflictResolverView(syncManager: syncManager)
            }
            .sheet(isPresented: $showSyncHistory) {
                SyncHistoryListView(syncManager: syncManager)
            }
        }
        .frame(minWidth: 480, minHeight: 600)
    }

    // MARK: - Sync Status Card

    private var syncStatusCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // 状态指示器
                ZStack {
                    Circle()
                        .fill(syncManager.syncState.color.opacity(0.15))
                        .frame(width: 64, height: 64)

                    if syncManager.syncState == .syncing {
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(syncManager.syncState.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(syncRotateAngle))
                            .onAppear {
                                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                    syncRotateAngle = 360
                                }
                            }
                    } else {
                        Image(systemName: syncManager.syncState.icon)
                            .font(.title2)
                            .foregroundStyle(syncManager.syncState.color)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(syncManager.syncState.displayName)
                        .font(.title3.bold())

                    if let lastDate = syncManager.lastSyncDate {
                        Text("上次同步: \(lastDate, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("从未同步")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // 设备信息
                    HStack(spacing: 4) {
                        Image(systemName: "desktopcomputer")
                            .font(.caption2)
                        Text(syncManager.deviceName)
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                // 同步按钮
                if syncManager.syncState == .idle || syncManager.syncState == .completed {
                    Button {
                        Task { await syncManager.startSync() }
                    } label: {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                            .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }

            // 进度条
            if syncManager.syncState == .syncing {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: syncManager.syncProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                    Text("正在同步... \(Int(syncManager.syncProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @State private var syncRotateAngle: Double = 0

    // MARK: - Health Score Section

    private var healthScoreSection: some View {
        let stats = syncManager.statistics
        let score = calculateHealthScore(stats: stats)

        return VStack(spacing: 12) {
            HStack {
                Text("同步健康度")
                    .font(.headline)
                Spacer()
                healthScoreBadge(score: score)
            }

            // 进度环
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: score / 100)
                        .stroke(healthScoreColor(score: score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(score))")
                        .font(.title2.bold())
                        .foregroundStyle(healthScoreColor(score: score))
                }

                VStack(alignment: .leading, spacing: 8) {
                    healthIndicator(
                        label: "成功率",
                        value: String(format: "%.0f%%", stats.successRate),
                        isGood: stats.successRate >= 90
                    )
                    healthIndicator(
                        label: "平均耗时",
                        value: stats.formattedAverageDuration,
                        isGood: stats.averageDuration < 5
                    )
                    healthIndicator(
                        label: "冲突率",
                        value: stats.totalSyncs > 0
                            ? String(format: "%.1f%%", Double(stats.totalConflictsFound) / Double(max(stats.totalSyncs, 1)) * 100)
                            : "0%",
                        isGood: stats.totalConflictsFound == 0
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func healthScoreBadge(score: Double) -> some View {
        let text: String
        let color: Color
        if score >= 90 {
            text = "优秀"
            color = .green
        } else if score >= 70 {
            text = "良好"
            color = .blue
        } else if score >= 50 {
            text = "一般"
            color = .orange
        } else {
            text = "需关注"
            color = .red
        }

        return Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func healthScoreColor(score: Double) -> Color {
        if score >= 90 { return .green }
        if score >= 70 { return .blue }
        if score >= 50 { return .orange }
        return .red
    }

    private func calculateHealthScore(stats: SyncStatistics) -> Double {
        guard stats.totalSyncs > 0 else { return 50 }

        let successWeight = 0.5
        let speedWeight = 0.3
        let conflictWeight = 0.2

        let successScore = stats.successRate
        let speedScore = max(0, 100 - stats.averageDuration * 10) // 10s = 0
        let conflictScore = max(0, 100 - Double(stats.totalConflictsFound) / Double(max(stats.totalSyncs, 1)) * 100)

        return successScore * successWeight + speedScore * speedWeight + conflictScore * conflictWeight
    }

    private func healthIndicator(label: String, value: String, isGood: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(isGood ? .green : .orange)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速操作")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    title: "立即同步",
                    color: .blue
                ) {
                    Task { await syncManager.startSync() }
                }

                QuickActionButton(
                    icon: "exclamationmark.triangle",
                    title: "解决冲突",
                    badge: syncManager.pendingConflicts.isEmpty ? nil : "\(syncManager.pendingConflicts.count)",
                    color: .orange
                ) {
                    showConflictResolver = true
                }

                QuickActionButton(
                    icon: "clock.arrow.circlepath",
                    title: "同步历史",
                    color: .purple
                ) {
                    showSyncHistory = true
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Performance Metrics Section

    private var performanceMetricsSection: some View {
        let stats = syncManager.statistics

        return VStack(alignment: .leading, spacing: 12) {
            Text("性能指标")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "总同步次数",
                    value: "\(stats.totalSyncs)",
                    icon: "number",
                    color: .blue
                )
                MetricCard(
                    title: "成功率",
                    value: String(format: "%.0f%%", stats.successRate),
                    icon: "checkmark.circle",
                    color: stats.successRate >= 90 ? .green : .orange
                )
                MetricCard(
                    title: "平均耗时",
                    value: stats.formattedAverageDuration,
                    icon: "timer",
                    color: .purple
                )
                MetricCard(
                    title: "同步项目数",
                    value: "\(stats.totalItemsSynced)",
                    icon: "doc.on.doc",
                    color: .teal
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近活动")
                    .font(.headline)
                Spacer()
                if syncManager.syncHistory.count > 3 {
                    Button("查看全部") {
                        showSyncHistory = true
                    }
                    .font(.caption)
                }
            }

            if syncManager.syncHistory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("暂无同步记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(syncManager.syncHistory.prefix(5)) { entry in
                        SyncActivityRow(entry: entry)
                        if entry.id != syncManager.syncHistory.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 30)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Weekly Trend Section

    private var weeklyTrendSection: some View {
        let last7Days = syncManager.statistics.last7Days.sorted(by: { $0.key < $1.key })
        let maxCount = last7Days.map(\.value).max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("最近 7 天同步趋势")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(last7Days, id: \.key) { day, count in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.gradient)
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
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let icon: String
    let title: String
    var badge: String? = nil
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .bold))
                            .padding(3)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                            .offset(x: 6, y: -4)
                    }
                }
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error History Section

private struct SyncErrorHistorySection: View {
    @ObservedObject var syncManager: DataSyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("错误记录")
                    .font(.headline)
                Spacer()
                Button("清除") {
                    syncManager.clearErrorHistory()
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

            ForEach(syncManager.errorHistory.prefix(5)) { error in
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(error.message)
                            .font(.caption)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(error.errorCode)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(error.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Sync Activity Row

private struct SyncActivityRow: View {
    let entry: SyncHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // 状态指示点
            Circle()
                .fill(entry.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.details)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(entry.startTime, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(entry.durationDisplay)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text("\(entry.itemsSynced) 项")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(entry.status.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(entry.status.color.opacity(0.12))
                .foregroundStyle(entry.status.color)
                .clipShape(Capsule())
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Conflict Resolver View

private struct ConflictResolverView: View {
    @ObservedObject var syncManager: DataSyncManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if syncManager.pendingConflicts.isEmpty {
                    ContentUnavailableView(
                        "暂无冲突",
                        systemImage: "checkmark.circle",
                        description: Text("所有数据已同步，没有需要解决的冲突")
                    )
                } else {
                    List {
                        ForEach(syncManager.pendingConflicts) { conflict in
                            ConflictCard(conflict: conflict) { resolution in
                                syncManager.resolveConflict(conflict, resolution: resolution)
                            }
                        }
                    }
                }
            }
            .navigationTitle("冲突解决")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if !syncManager.pendingConflicts.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("全部使用本地版本") {
                            for conflict in syncManager.pendingConflicts {
                                syncManager.resolveConflict(conflict, resolution: .keepLocal)
                            }
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

// MARK: - Conflict Card

private struct ConflictCard: View {
    let conflict: SyncConflict
    let onResolve: (ConflictResolution) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(conflict.entityName)
                    .font(.headline)
                Spacer()
                Text(conflict.entityType)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(conflict.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            // 对比信息
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本地版本")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.blue)
                    Text("v\(conflict.localVersion)")
                        .font(.caption)
                    Text(conflict.localModifiedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("远程版本")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                    Text("v\(conflict.remoteVersion)")
                        .font(.caption)
                    Text(conflict.remoteModifiedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // 解决按钮
            HStack(spacing: 8) {
                Button {
                    onResolve(.keepLocal)
                } label: {
                    Label("使用本地", systemImage: "laptopcomputer")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button {
                    onResolve(.keepRemote)
                } label: {
                    Label("使用远程", systemImage: "icloud")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button {
                    onResolve(.merge)
                } label: {
                    Label("合并", systemImage: "arrow.triangle.merge")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - SyncHistoryListView (reuse from iCloudSyncSettingsView)

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
                        Section {
                            let stats = syncManager.statistics
                            if stats.totalSyncs > 0 {
                                SyncDashboardStatsOverview(stats: stats)
                            }
                        }

                        Section("同步记录") {
                            ForEach(syncManager.syncHistory) { entry in
                                SyncDashboardHistoryRow(entry: entry)
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

private struct SyncDashboardStatsOverview: View {
    let stats: SyncStatistics

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                VStack(spacing: 2) {
                    Text("\(stats.totalSyncs)")
                        .font(.callout.bold())
                        .foregroundStyle(.blue)
                    Text("总同步")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", stats.successRate))
                        .font(.callout.bold())
                        .foregroundStyle(.blue)
                    Text("成功率")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text(stats.formattedAverageDuration)
                        .font(.callout.bold())
                        .foregroundStyle(.blue)
                    Text("平均耗时")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SyncDashboardHistoryRow: View {
    let entry: SyncHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.details)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                        Text(entry.startTime, style: .time)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                        Text(entry.durationDisplay)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "doc")
                        Text("\(entry.itemsSynced) 项")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

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
