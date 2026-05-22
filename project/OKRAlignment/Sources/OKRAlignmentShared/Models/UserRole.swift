import Foundation
import SwiftUI

/// 用户角色枚举
/// 定义OKR系统中的三种角色级别，每种角色有不同的权限
/// 管理员 > 经理 > 成员
public enum UserRole: String, CaseIterable, Codable, Sendable {
    /// 管理员 - 拥有所有权限
    case admin = "admin"

    /// 经理 - 可以创建和编辑，但不能删除系统级数据
    case manager = "manager"

    /// 成员 - 只能查看和编辑自己的节点
    case member = "member"
}

// MARK: - Display Helpers

extension UserRole {
    /// 角色的中文显示名称
    public var displayName: String {
        switch self {
        case .admin:
            return "管理员"
        case .manager:
            return "经理"
        case .member:
            return "成员"
        }
    }

    /// 角色的图标名称（SF Symbols）
    public var iconName: String {
        switch self {
        case .admin:
            return "crown.fill"
        case .manager:
            return "person.badge.shield.checkmark"
        case .member:
            return "person.fill"
        }
    }

    /// 角色对应的颜色
    public var color: Color {
        switch self {
        case .admin:
            return Color(red: 0.918, green: 0.702, blue: 0.031)  // 金色
        case .manager:
            return Color(red: 0.231, green: 0.510, blue: 0.965)  // 蓝色
        case .member:
            return Color(red: 0.556, green: 0.604, blue: 0.671)  // 灰色
        }
    }

    /// 角色的简短描述
    public var description: String {
        switch self {
        case .admin:
            return "拥有所有权限，可以管理用户角色、创建/编辑/删除任何OKR节点和周期"
        case .manager:
            return "可以创建和编辑OKR节点和周期，查看所有数据，但不能管理系统设置"
        case .member:
            return "可以查看所有OKR数据，编辑自己负责的节点，但不能创建/删除周期"
        }
    }
}

// MARK: - Permission Checks

extension UserRole {
    /// 是否可以创建节点
    public var canCreateNode: Bool {
        self == .admin || self == .manager
    }

    /// 是否可以编辑任意节点
    public var canEditAnyNode: Bool {
        self == .admin || self == .manager
    }

    /// 是否可以删除节点
    public var canDeleteNode: Bool {
        self == .admin || self == .manager
    }

    /// 是否可以创建/编辑/删除周期
    public var canManageCycles: Bool {
        self == .admin || self == .manager
    }

    /// 是否可以管理用户角色
    public var canManageRoles: Bool {
        self == .admin
    }

    /// 是否可以查看分析数据
    public var canViewAnalytics: Bool {
        true  // 所有角色都可以查看分析
    }

    /// 是否可以导出数据
    public var canExportData: Bool {
        self == .admin || self == .manager
    }

    /// 是否可以管理备份
    public var canManageBackup: Bool {
        self == .admin
    }

    /// 是否可以管理系统设置
    public var canManageSettings: Bool {
        self == .admin
    }
}
