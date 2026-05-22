// OKRAlignmentShared/Views/Settings/DataMigrationView.swift

import SwiftUI

/// 数据迁移视图
/// =============
/// 提供数据迁移的用户界面，包括：
/// - 版本信息展示
/// - 迁移进度和日志
/// - 迁移操作按钮
/// - 回滚功能
public struct DataMigrationView: View {

    // MARK: - Properties

    @StateObject private var migrationService = DataMigrationService()

    @State private var showRollbackConfirmation = false
    @State private var showResetConfirmation = false

    // MARK: - Body

    public init() {}

    public var body: some View {
        Form {
            // 版本信息
            versionInfoSection

            // 迁移状态
            migrationStatusSection

            // 迁移日志
            if !migrationService.migrationLog.isEmpty {
                migrationLogSection
            }

            // 操作按钮
            actionSection
        }
        .formStyle(.grouped)
        .navigationTitle("数据迁移")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Version Info

    private var versionInfoSection: some View {
        Section {
            HStack {
                Text("当前数据版本")
                Spacer()
                Text("v\(migrationService.storedDataVersion)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("最新数据版本")
                Spacer()
                Text("v4")
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
        } header: {
            Text("版本信息")
        }
    }

    // MARK: - Migration Status

    private var migrationStatusSection: some View {
        Section {
            switch migrationService.state {
            case .idle:
                Text("就绪")
                    .foregroundStyle(.secondary)
            case .checking:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在检查数据...")
                }
            case .migrating(let step, let total, let description):
                VStack(alignment: .leading, spacing: 8) {
                    Text("步骤 \(step)/\(total): \(description)")
                        .font(.callout)
                    ProgressView(value: migrationService.progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(migrationService.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .completed(let result):
                VStack(alignment: .leading, spacing: 4) {
                    Label("迁移完成", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                    Text(result.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .failed(let result):
                VStack(alignment: .leading, spacing: 4) {
                    Label("迁移失败", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.headline)
                    Text(result.message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            case .rolledBack:
                Label("已回滚", systemImage: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("迁移状态")
        }
    }

    // MARK: - Migration Log

    private var migrationLogSection: some View {
        Section {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(migrationService.migrationLog.enumerated()), id: \.offset) { _, log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        } header: {
            Text("迁移日志")
        }
    }

    // MARK: - Actions

    private var actionSection: some View {
        Section {
            // 开始迁移按钮
            Button {
                Task {
                    _ = await migrationService.performMigration()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("开始迁移")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!migrationService.needsMigration ||
                      migrationService.state == .migrating(step: 0, totalSteps: 0, description: ""))

            // 回滚按钮
            Button {
                showRollbackConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.uturn.backward")
                    Text("回滚到迁移前")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled({
                if case .completed = migrationService.state { return false }
                return true
            }())

            // 重置状态按钮
            Button {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清除日志")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(migrationService.migrationLog.isEmpty)
        } footer: {
            Text("迁移前会自动创建数据备份。如果迁移过程中出现问题，可以回滚到备份状态。")
                .font(.caption2)
        }
        .confirmationDialog(
            "确认回滚",
            isPresented: $showRollbackConfirmation,
            titleVisibility: .visible
        ) {
            Button("回滚", role: .destructive) {
                _ = migrationService.rollback()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("回滚将恢复到迁移前的数据状态，迁移过程中新增的数据将丢失。确定要继续吗？")
        }
        .confirmationDialog(
            "清除日志",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除", role: .destructive) {
                migrationService.resetState()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清除迁移日志和状态信息。")
        }
    }
}

// MARK: - Migration Result Equatable Conformance

extension DataMigrationService.MigrationResult: Equatable {
    public static func == (lhs: DataMigrationService.MigrationResult,
                          rhs: DataMigrationService.MigrationResult) -> Bool {
        lhs.success == rhs.success && lhs.message == rhs.message
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        DataMigrationView()
    }
}
#endif
