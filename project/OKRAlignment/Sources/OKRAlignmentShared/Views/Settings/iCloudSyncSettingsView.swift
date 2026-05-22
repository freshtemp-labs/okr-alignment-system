// OKRAlignmentShared/Views/Settings/iCloudSyncSettingsView.swift

import SwiftUI
#if canImport(CloudKit)
import CloudKit
#endif

/// iCloud 同步设置视图
/// 提供 iCloud 同步的开关和状态展示
///
/// 功能说明：
/// - 开关控制是否启用 iCloud/CloudKit 数据同步
/// - 展示当前同步状态（已启用/未启用/不可用）
/// - 切换后需要重启应用生效
public struct iCloudSyncSettingsView: View {

    // MARK: - Properties

    /// iCloud 同步开关状态
    @State private var syncEnabled: Bool

    /// 同步状态描述
    @State private var syncStatus: SyncStatus = .unknown

    /// 是否显示重启提示
    @State private var showRestartAlert = false

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

            // 同步状态
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
                    value: "Last-Write-Wins",
                    color: .secondary
                )
            } header: {
                Text("同步信息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Last-Write-Wins 策略：当多设备同时修改同一数据时，最后写入的变更将被保留。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
        .alert("需要重启", isPresented: $showRestartAlert) {
            Button("确定") {}
        } message: {
            Text("iCloud 同步设置已更改，请重启应用以使更改生效。")
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

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        iCloudSyncSettingsView()
    }
    .preferredColorScheme(.dark)
}
#endif
