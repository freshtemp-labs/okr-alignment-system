import Foundation
import SwiftUI

// MARK: - OKR Alignment System Color Theme
/// 应用颜色主题扩展
/// 定义了OKR对齐管理系统的完整色彩体系
/// 采用深色背景搭配高对比度强调色的设计方案
///
/// 色彩体系：
/// - 企业级：金色系（#EAB308 / #CA8A04），象征战略与权威
/// - 个人级：蓝色系（#3B82F6），象征执行与活力
/// - 关键结果：绿色系（#059669），象征可衡量的成果
/// - 背景：深色（#0F172A），降低视觉疲劳
/// - 卡片：半透明白色叠加，营造层级感
extension Color {

    // MARK: - Scope Colors

    /// 企业级范围标识颜色 - 金色
    /// 用于企业级Objective和KR的视觉标识
    public static let enterpriseScope = Color(
        red: 0.918, green: 0.702, blue: 0.031,
        opacity: 1.0
    )  // #EAB308

    /// 个人级范围标识颜色 - 蓝色
    /// 用于个人级Objective和KR的视觉标识
    public static let personalScope = Color(
        red: 0.231, green: 0.510, blue: 0.965,
        opacity: 1.0
    )  // #3B82F6

    // MARK: - Progress Colors

    /// 企业级进度条颜色 - 深金色
    /// 用于企业级节点的进度指示
    public static let enterpriseProgress = Color(
        red: 0.792, green: 0.541, blue: 0.016,
        opacity: 1.0
    )  // #CA8A04

    /// 个人级进度条颜色 - 蓝色
    /// 用于个人级节点的进度指示
    public static let personalProgress = Color(
        red: 0.231, green: 0.510, blue: 0.965,
        opacity: 1.0
    )  // #3B82F6

    /// 关键结果进度条颜色 - 绿色
    /// 用于叶子KR节点的进度指示
    public static let krProgress = Color(
        red: 0.020, green: 0.588, blue: 0.412,
        opacity: 1.0
    )  // #059669

    // MARK: - Background Colors

    /// 应用主背景色 - 深蓝灰色
    /// 作为整个应用的底色，降低视觉疲劳
    public static let appBackground = Color(
        red: 0.059, green: 0.090, blue: 0.165,
        opacity: 1.0
    )  // #0F172A

    /// 应用二级背景色 - 稍浅的蓝灰色
    /// 用于次级面板和分隔区域
    public static let appBackgroundSecondary = Color(
        red: 0.086, green: 0.125, blue: 0.212,
        opacity: 1.0
    )  // #162033

    /// 卡片背景色 - 白色5%透明度
    /// 在深色背景上营造微妙的层级感
    public static let cardBackground = Color(
        white: 1.0,
        opacity: 0.05
    )

    /// 卡片悬浮背景色 - 白色8%透明度
    /// 鼠标/手指悬停时的卡片高亮效果
    public static let cardBackgroundHover = Color(
        white: 1.0,
        opacity: 0.08
    )

    // MARK: - Border Colors

    /// 卡片边框色 - 白色10%透明度
    /// 为卡片提供微妙的边界定义
    public static let cardBorder = Color(
        white: 1.0,
        opacity: 0.10
    )

    /// 卡片悬浮边框色 - 白色20%透明度
    /// 悬停时增强边框可见度
    public static let cardBorderHover = Color(
        white: 1.0,
        opacity: 0.20
    )

    /// 分隔线颜色 - 白色5%透明度
    /// 用于列表项和区域之间的分隔
    public static let divider = Color(
        white: 1.0,
        opacity: 0.05
    )

    // MARK: - Text Colors

    /// 主文本色 - 高对比度白色
    /// 用于标题和重要文本
    public static let primaryText = Color(
        white: 0.95,
        opacity: 1.0
    )

    /// 次级文本色 - 中灰色
    /// 用于描述、标签等次要信息
    public static let secondaryText = Color(
        white: 0.6,
        opacity: 1.0
    )

    /// 三级文本色 - 深灰色
    /// 用于占位符和禁用状态的文本
    public static let tertiaryText = Color(
        white: 0.4,
        opacity: 1.0
    )
}

// MARK: - Scope-based Color Resolution

extension Color {
    /// 根据范围返回对应的标识颜色
    /// - Parameter scope: 节点范围（企业级或个人级）
    /// - Returns: 对应的颜色
    public static func scopeColor(for scope: Scope) -> Color {
        switch scope {
        case .enterprise:
            return .enterpriseScope
        case .personal:
            return .personalScope
        }
    }

    /// 根据范围返回对应的进度颜色
    /// - Parameter scope: 节点范围（企业级或个人级）
    /// - Returns: 对应的进度条颜色
    public static func progressColor(for scope: Scope) -> Color {
        switch scope {
        case .enterprise:
            return .enterpriseProgress
        case .personal:
            return .personalProgress
        }
    }
}
