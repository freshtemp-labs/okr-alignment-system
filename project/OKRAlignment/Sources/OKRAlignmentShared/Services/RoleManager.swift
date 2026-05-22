import Foundation
import SwiftUI

/// 角色管理器
/// 管理当前用户的角色设置，使用UserDefaults持久化
/// 提供权限检查方法，用于控制UI元素的可见性和可操作性
@Observable
@MainActor
public final class RoleManager {

    // MARK: - Shared Instance

    public static let shared = RoleManager()

    // MARK: - Published Properties

    /// 当前用户角色
    public private(set) var currentRole: UserRole

    /// 当前用户显示名称
    public private(set) var currentUserName: String

    /// 角色变更事件（用于日志记录）
    public private(set) var lastRoleChangeDate: Date?

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let currentRole = "okr_user_role"
        static let currentUserName = "okr_user_name"
        static let lastRoleChangeDate = "okr_role_last_change"
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        // 加载角色（默认为管理员，首次安装时的设置）
        if let roleString = defaults.string(forKey: Keys.currentRole),
           let role = UserRole(rawValue: roleString) {
            self.currentRole = role
        } else {
            self.currentRole = .admin  // 默认管理员
        }

        // 加载用户名
        self.currentUserName = defaults.string(forKey: Keys.currentUserName) ?? "当前用户"

        // 加载最后角色变更时间
        if let timestamp = defaults.object(forKey: Keys.lastRoleChangeDate) as? Date {
            self.lastRoleChangeDate = timestamp
        }
    }

    // MARK: - Public Methods

    /// 更新用户角色
    /// - Parameter newRole: 新的角色
    public func setRole(_ newRole: UserRole) {
        guard newRole != currentRole else { return }
        currentRole = newRole
        lastRoleChangeDate = Date()
        persistRole()
    }

    /// 更新当前用户显示名称
    /// - Parameter name: 新的用户名称
    public func setUserName(_ name: String) {
        currentUserName = name
        UserDefaults.standard.set(name, forKey: Keys.currentUserName)
    }

    /// 检查是否可以执行指定操作
    /// - Parameter permission: 权限类型
    /// - Returns: 是否有权限
    public func hasPermission(_ permission: Permission) -> Bool {
        switch permission {
        case .createNode:
            return currentRole.canCreateNode
        case .editAnyNode:
            return currentRole.canEditAnyNode
        case .deleteNode:
            return currentRole.canDeleteNode
        case .manageCycles:
            return currentRole.canManageCycles
        case .manageRoles:
            return currentRole.canManageRoles
        case .viewAnalytics:
            return currentRole.canViewAnalytics
        case .exportData:
            return currentRole.canExportData
        case .manageBackup:
            return currentRole.canManageBackup
        case .manageSettings:
            return currentRole.canManageSettings
        }
    }

    // MARK: - Private Methods

    private func persistRole() {
        let defaults = UserDefaults.standard
        defaults.set(currentRole.rawValue, forKey: Keys.currentRole)
        defaults.set(lastRoleChangeDate, forKey: Keys.lastRoleChangeDate)
    }
}

// MARK: - Permission Enum

/// 系统权限枚举
/// 用于RoleManager的权限检查
public enum Permission: String, Sendable {
    /// 创建节点
    case createNode
    /// 编辑任意节点
    case editAnyNode
    /// 删除节点
    case deleteNode
    /// 管理周期
    case manageCycles
    /// 管理角色
    case manageRoles
    /// 查看分析
    case viewAnalytics
    /// 导出数据
    case exportData
    /// 管理备份
    case manageBackup
    /// 管理设置
    case manageSettings
}
