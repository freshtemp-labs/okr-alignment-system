import Foundation
import SwiftUI

/// OKR范围枚举，区分企业级与个人级
/// 企业级：公司或组织层面的OKR，由管理层设定
/// 个人级：个人或团队层面的OKR，由员工设定并与上级OKR对齐
/// 层级关系：企业Objective → 企业KR → 个人Objective → 个人KR
public enum Scope: String, CaseIterable, Codable, Sendable {
    /// 企业级范围 - 公司或组织层面的OKR
    /// 通常由高管团队设定，体现公司战略方向
    case enterprise = "enterprise"

    /// 个人级范围 - 个人或团队层面的OKR
    /// 由员工或团队主管设定，与企业级OKR对齐
    case personal = "personal"
}

// MARK: - Display Helpers

extension Scope {
    /// 返回范围的中文显示名称
    public var displayName: String {
        switch self {
        case .enterprise:
            return "企业级"
        case .personal:
            return "个人级"
        }
    }

    /// 返回范围对应的颜色标识
    /// - 企业级使用金色，象征权威与战略
    /// - 个人级使用蓝色，象征活力与执行
    public var color: Color {
        switch self {
        case .enterprise:
            return Color(red: 0.918, green: 0.702, blue: 0.031)  // #EAB308 金色
        case .personal:
            return Color(red: 0.231, green: 0.510, blue: 0.965)  // #3B82F6 蓝色
        }
    }

    /// 返回范围对应的进度条颜色
    public var progressColor: Color {
        switch self {
        case .enterprise:
            return Color(red: 0.792, green: 0.541, blue: 0.016)  // #CA8A04 深金色
        case .personal:
            return Color(red: 0.231, green: 0.510, blue: 0.965)  // #3B82F6 蓝色
        }
    }

    /// 返回范围的图标名称（SF Symbols）
    public var iconName: String {
        switch self {
        case .enterprise:
            return "building.2.fill"
        case .personal:
            return "person.fill"
        }
    }
}
