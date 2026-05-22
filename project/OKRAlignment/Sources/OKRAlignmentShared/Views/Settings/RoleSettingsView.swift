import SwiftUI

// MARK: - RoleSettingsView

/// 角色设置视图
/// 显示当前用户角色，允许管理员切换角色
/// 展示各角色的权限说明
public struct RoleSettingsView: View {

    // MARK: - Properties

    @State private var roleManager = RoleManager.shared
    @State private var selectedRole: UserRole
    @State private var editingName: String
    @State private var showRoleChangeAlert = false
    @State private var pendingRole: UserRole?

    // MARK: - Initialization

    public init() {
        let mgr = RoleManager.shared
        _selectedRole = State(initialValue: mgr.currentRole)
        _editingName = State(initialValue: mgr.currentUserName)
    }

    // MARK: - Body

    public var body: some View {
        Form {
            // 当前角色区域
            Section {
                HStack(spacing: 12) {
                    Image(systemName: roleManager.currentRole.iconName)
                        .font(.title2)
                        .foregroundStyle(roleManager.currentRole.color)
                        .frame(width: 44, height: 44)
                        .background(roleManager.currentRole.color.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(roleManager.currentUserName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text(roleManager.currentRole.displayName)
                                .font(.caption.bold())
                                .foregroundStyle(roleManager.currentRole.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(roleManager.currentRole.color.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("当前用户")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 用户名编辑
            Section {
                HStack {
                    Text("显示名称")
                    TextField("输入名称", text: $editingName)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .onSubmit {
                            roleManager.setUserName(editingName)
                        }
                }
            } header: {
                Text("用户信息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("输入您的显示名称，将用于评论和操作记录中标识身份。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 角色切换
            Section {
                ForEach(UserRole.allCases, id: \.self) { role in
                    RoleOptionRow(
                        role: role,
                        isSelected: selectedRole == role,
                        isCurrentRole: roleManager.currentRole == role
                    ) {
                        if role != roleManager.currentRole {
                            pendingRole = role
                            showRoleChangeAlert = true
                        }
                    }
                }
            } header: {
                Text("切换角色")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("切换角色后，权限将立即生效。角色设置保存在本地设备。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 当前权限一览
            Section {
                PermissionRow(title: "创建节点", allowed: roleManager.currentRole.canCreateNode)
                PermissionRow(title: "编辑任意节点", allowed: roleManager.currentRole.canEditAnyNode)
                PermissionRow(title: "删除节点", allowed: roleManager.currentRole.canDeleteNode)
                PermissionRow(title: "管理周期", allowed: roleManager.currentRole.canManageCycles)
                PermissionRow(title: "管理用户角色", allowed: roleManager.currentRole.canManageRoles)
                PermissionRow(title: "查看分析数据", allowed: roleManager.currentRole.canViewAnalytics)
                PermissionRow(title: "导出数据", allowed: roleManager.currentRole.canExportData)
                PermissionRow(title: "管理备份", allowed: roleManager.currentRole.canManageBackup)
                PermissionRow(title: "系统设置", allowed: roleManager.currentRole.canManageSettings)
            } header: {
                Text("当前权限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("角色管理")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("确认切换角色", isPresented: $showRoleChangeAlert) {
            Button("取消", role: .cancel) {
                pendingRole = nil
            }
            Button("确认切换") {
                if let newRole = pendingRole {
                    roleManager.setRole(newRole)
                    selectedRole = newRole
                }
                pendingRole = nil
            }
        } message: {
            if let pendingRole {
                Text("将角色切换为「\(pendingRole.displayName)」？\n\n\(pendingRole.description)")
            }
        }
    }
}

// MARK: - RoleOptionRow

/// 角色选项行
private struct RoleOptionRow: View {
    let role: UserRole
    let isSelected: Bool
    let isCurrentRole: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: role.iconName)
                    .font(.title3)
                    .foregroundStyle(role.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(role.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        if isCurrentRole {
                            Text("当前")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(role.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PermissionRow

/// 权限显示行
private struct PermissionRow: View {
    let title: String
    let allowed: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            if allowed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.body)
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red.opacity(0.6))
                    .font(.body)
            }
        }
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        RoleSettingsView()
    }
    .preferredColorScheme(.dark)
}
#endif
