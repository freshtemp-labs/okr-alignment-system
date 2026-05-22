// OKRAlignmentShared/Views/Settings/SecuritySettingsView.swift

import SwiftUI

/// 安全与加密设置视图
///
/// 提供：
/// - 数据加密开关
/// - 生物识别解锁开关
/// - 加密状态信息展示
public struct SecuritySettingsView: View {

    // MARK: - Properties

    @State private var encryptionManager = DataEncryptionManager.shared
    @State private var isEncryptionEnabled: Bool
    @State private var isBiometricEnabled: Bool
    @State private var isAuthenticating = false
    @State private var showAuthAlert = false

    // MARK: - Initialization

    public init() {
        let mgr = DataEncryptionManager.shared
        _isEncryptionEnabled = State(initialValue: mgr.isEncryptionEnabled)
        _isBiometricEnabled = State(initialValue: mgr.isBiometricEnabled)
    }

    // MARK: - Body

    public var body: some View {
        Form {
            // 数据加密区域
            Section {
                Toggle(isOn: $isEncryptionEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("数据加密")
                            Text("使用 NSFileProtectionComplete 保护数据")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                    }
                }
                .onChange(of: isEncryptionEnabled) { _, newValue in
                    encryptionManager.isEncryptionEnabled = newValue
                }

                // 加密状态
                HStack {
                    Text("保护级别")
                    Spacer()
                    Text(encryptionManager.protectionLevel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("加密状态")
                    Spacer()
                    if isEncryptionEnabled {
                        Label("已启用", systemImage: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("未启用", systemImage: "shield.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("数据加密")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("启用后，数据将使用 NSFileProtectionComplete 级别保护，设备锁定时数据不可访问。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 生物识别区域
            Section {
                Toggle(isOn: $isBiometricEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("生物识别解锁")
                            Text("使用 \(encryptionManager.biometricTypeName) 保护应用")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: biometricIcon)
                            .foregroundStyle(Color(red: 139/255, green: 92/255, blue: 246/255))
                    }
                }
                .disabled(!encryptionManager.isBiometricAvailable)
                .onChange(of: isBiometricEnabled) { _, newValue in
                    if newValue {
                        // 启用时先验证一次生物识别
                        isAuthenticating = true
                        Task {
                            let success = await encryptionManager.authenticateWithBiometrics(
                                reason: "验证 \(encryptionManager.biometricTypeName) 以启用生物识别解锁"
                            )
                            isAuthenticating = false
                            if !success {
                                isBiometricEnabled = false
                                showAuthAlert = true
                            } else {
                                encryptionManager.isBiometricEnabled = true
                            }
                        }
                    } else {
                        encryptionManager.isBiometricEnabled = false
                    }
                }

                HStack {
                    Text("生物识别类型")
                    Spacer()
                    Text(encryptionManager.biometricTypeName)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("设备支持")
                    Spacer()
                    if encryptionManager.isBiometricAvailable {
                        Label("支持", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("不支持", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("身份验证")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                if encryptionManager.isBiometricAvailable {
                    Text("启用后，每次打开应用时需要通过 \(encryptionManager.biometricTypeName) 验证。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("当前设备不支持生物识别。请在系统设置中录入指纹或面容。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("安全设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("身份验证失败", isPresented: $showAuthAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("生物识别验证失败，无法启用解锁功能。请确保已录入生物识别信息。")
        }
        .overlay {
            if isAuthenticating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("正在验证...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private var biometricIcon: String {
        switch encryptionManager.biometricTypeName {
        case "Face ID": return "faceid"
        case "Touch ID": return "touchid"
        case "Optic ID": return "opticid"
        default: return "person.badge.shield.checkmark"
        }
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
    .preferredColorScheme(.dark)
}
#endif
