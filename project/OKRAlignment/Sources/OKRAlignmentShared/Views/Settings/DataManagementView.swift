// OKRAlignmentShared/Views/Settings/DataManagementView.swift

import SwiftUI

/// 数据管理视图
/// =============
/// 整合数据备份、迁移、完整性检查和存储统计的统一入口。
/// 在 Settings 中作为"数据管理"的主入口页面。
///
/// 功能包括：
/// - 存储统计概览
/// - 数据迁移
/// - 数据备份与恢复
/// - 数据完整性检查
/// - 数据清理
public struct DataManagementView: View {

    // MARK: - Properties

    @StateObject private var migrationService = DataMigrationService()

    /// 存储统计
    @State private var storageStats: DataMigrationService.StorageStatistics?
    /// 完整性检查结果
    @State private var integrityResult: DataMigrationService.IntegrityCheckResult?
    /// 是否正在检查
    @State private var isCheckingIntegrity = false
    /// 是否正在计算存储
    @State private var isCalculatingStorage = false
    /// 是否显示迁移视图
    @State private var showMigration = false
    /// 是否显示备份视图
    @State private var showBackup = false

    // MARK: - Body

    public init() {}

    public var body: some View {
        Form {
            // 存储统计概览
            storageOverviewSection

            // 数据完整性
            integritySection

            // 数据迁移
            migrationSection

            // 数据备份
            backupSection

            // 数据清理
            cleanupSection
        }
        .formStyle(.grouped)
        .navigationTitle("数据管理")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadStorageStats()
        }
    }

    // MARK: - Storage Overview

    private var storageOverviewSection: some View {
        Section {
            if isCalculatingStorage {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在计算存储空间...")
                        .foregroundStyle(.secondary)
                }
            } else if let stats = storageStats {
                HStack {
                    Label("数据库大小", systemImage: "internaldrive")
                    Spacer()
                    Text(stats.formattedDatabaseSize)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("备份大小", systemImage: "archivebox")
                    Spacer()
                    Text(stats.formattedBackupSize)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("总占用空间", systemImage: "internaldrive.fill")
                    Spacer()
                    Text(stats.formattedTotalSize)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                }

                Divider()

                HStack {
                    Text("节点")
                    Spacer()
                    Text("\(stats.nodeCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("周期")
                    Spacer()
                    Text("\(stats.cycleCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("评论")
                    Spacer()
                    Text("\(stats.commentCount)")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("暂无统计数据")
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await loadStorageStats() }
            } label: {
                Label("刷新统计", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("存储概览")
        }
    }

    // MARK: - Integrity Section

    private var integritySection: some View {
        Section {
            if isCheckingIntegrity {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在检查数据完整性...")
                        .foregroundStyle(.secondary)
                }
            } else if let result = integrityResult {
                HStack {
                    Image(systemName: result.isHealthy ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(result.isHealthy ? .green : .orange)
                    Text(result.summary)
                        .font(.callout)
                }

                if !result.isHealthy {
                    ForEach(result.issues.prefix(5)) { issue in
                        HStack(spacing: 8) {
                            Image(systemName: issue.severity.iconName)
                                .foregroundStyle(colorForSeverity(issue.severity))
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.description)
                                    .font(.caption)
                                Text("\(issue.entityType)\(issue.entityId.map { " · \($0.prefix(8))..." } ?? "")")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if result.issues.count > 5 {
                        Text("还有 \(result.issues.count - 5) 个问题...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("检查了 \(result.totalEntitiesChecked) 条记录，耗时 \(String(format: "%.2f", result.duration)) 秒")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button {
                Task { await runIntegrityCheck() }
            } label: {
                Label("检查数据完整性", systemImage: "shield.checkered")
            }
            .disabled(isCheckingIntegrity)
        } header: {
            Text("数据完整性")
        }
    }

    // MARK: - Migration Section

    private var migrationSection: some View {
        Section {
            HStack {
                Text("数据版本")
                Spacer()
                Text("v\(migrationService.storedDataVersion)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("迁移状态")
                Spacer()
                if migrationService.needsMigration {
                    Label("需要迁移", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Label("已是最新", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            NavigationLink {
                DataMigrationView()
            } label: {
                Label("打开数据迁移", systemImage: "arrow.triangle.2.circlepath")
            }
        } header: {
            Text("数据迁移")
        } footer: {
            Text("迁移前会自动创建备份，支持回滚到迁移前的状态。")
                .font(.caption2)
        }
    }

    // MARK: - Backup Section

    private var backupSection: some View {
        Section {
            NavigationLink {
                BackupSettingsView()
            } label: {
                Label("打开数据备份", systemImage: "archivebox")
            }
        } header: {
            Text("数据备份")
        } footer: {
            Text("支持手动备份和自动备份，可从备份恢复数据。")
                .font(.caption2)
        }
    }

    // MARK: - Cleanup Section

    private var cleanupSection: some View {
        Section {
            Button(role: .destructive) {
                // 清理临时文件
            } label: {
                Label("清理临时文件", systemImage: "trash")
            }
        } header: {
            Text("数据清理")
        } footer: {
            Text("清理导出缓存、临时文件等，不影响核心数据。")
                .font(.caption2)
        }
    }

    // MARK: - Helpers

    private func loadStorageStats() async {
        isCalculatingStorage = true
        storageStats = migrationService.getStorageStatistics()
        isCalculatingStorage = false
    }

    private func runIntegrityCheck() async {
        isCheckingIntegrity = true
        integrityResult = await migrationService.checkDataIntegrity()
        isCheckingIntegrity = false
    }

    private func colorForSeverity(_ severity: DataMigrationService.IntegrityIssue.Severity) -> Color {
        switch severity {
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        DataManagementView()
    }
    .preferredColorScheme(.dark)
}
#endif
