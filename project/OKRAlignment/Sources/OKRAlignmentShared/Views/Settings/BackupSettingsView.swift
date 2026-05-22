// OKRAlignmentShared/Views/Settings/BackupSettingsView.swift

import SwiftUI

/// 备份管理设置视图
///
/// 提供：
/// - 显示上次备份时间
/// - 手动触发备份
/// - 备份列表展示
/// - 从备份恢复
/// - 删除备份
public struct BackupSettingsView: View {

    // MARK: - Properties

    @State private var backupManager = AutoBackupManager.shared
    @State private var backups: [AutoBackupManager.BackupInfo] = []
    @State private var isBackingUp = false
    @State private var showRestoreAlert = false
    @State private var showDeleteAlert = false
    @State private var selectedBackup: AutoBackupManager.BackupInfo?
    @State private var showRestoreSuccess = false
    @State private var showDeleteAllAlert = false

    // MARK: - Body

    public init() {}

    public var body: some View {
        Form {
            // 备份状态区域
            Section {
                HStack {
                    Text("上次备份")
                    Spacer()
                    if let lastDate = backupManager.lastBackupDate {
                        Text(lastDate, style: .relative)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("从未备份")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("备份数量")
                    Spacer()
                    Text("\(backups.count) 个备份")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("保留策略")
                    Spacer()
                    Text("最近 7 天")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        isBackingUp = true
                        await backupManager.performBackup()
                        refreshBackups()
                        isBackingUp = false
                    }
                } label: {
                    HStack {
                        if isBackingUp {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isBackingUp ? "正在备份..." : "立即备份")
                    }
                }
                .disabled(isBackingUp)
            } header: {
                Text("自动备份")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("系统每天自动备份一次数据。备份文件存储在本地 Documents 目录中。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 备份列表
            if !backups.isEmpty {
                Section {
                    ForEach(backups) { backup in
                        Button {
                            selectedBackup = backup
                            showRestoreAlert = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(backup.formattedDate)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(backup.formattedSize)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            backupManager.deleteBackup(backups[index])
                        }
                        refreshBackups()
                    }

                    // 删除所有备份
                    Button(role: .destructive) {
                        showDeleteAllAlert = true
                    } label: {
                        Label("删除所有备份", systemImage: "trash")
                    }
                } header: {
                    Text("备份列表")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("点击备份可恢复数据。左滑可删除单个备份。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("数据备份")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            refreshBackups()
        }
        .alert("恢复备份", isPresented: $showRestoreAlert) {
            Button("取消", role: .cancel) { selectedBackup = nil }
            Button("恢复", role: .destructive) {
                guard let backup = selectedBackup else { return }
                Task {
                    let success = await backupManager.restoreFromBackup(backup)
                    if success {
                        showRestoreSuccess = true
                    }
                    selectedBackup = nil
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("确定要恢复到 \(backup.formattedDate) 的备份吗？当前数据将被替换。建议先创建一个新备份。")
            }
        }
        .alert("恢复成功", isPresented: $showRestoreSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("备份已恢复。请重新启动应用以加载恢复的数据。")
        }
        .alert("删除所有备份", isPresented: $showDeleteAllAlert) {
            Button("取消", role: .cancel) {}
            Button("全部删除", role: .destructive) {
                backupManager.deleteAllBackups()
                refreshBackups()
            }
        } message: {
            Text("确定要删除所有备份文件吗？此操作不可撤销。")
        }
    }

    // MARK: - Private Methods

    private func refreshBackups() {
        backups = backupManager.listBackups()
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        BackupSettingsView()
    }
    .preferredColorScheme(.dark)
}
#endif
