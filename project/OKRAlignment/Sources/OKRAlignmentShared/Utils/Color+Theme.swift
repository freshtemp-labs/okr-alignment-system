import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - OKR Alignment System Color Theme
/// 应用颜色主题扩展
/// 定义了OKR对齐管理系统的完整色彩体系
/// 支持浅色/深色模式自动适配
///
/// 色彩体系：
/// - 企业级：金色系（#EAB308 / #CA8A04），象征战略与权威
/// - 个人级：蓝色系（#3B82F6），象征执行与活力
/// - 关键结果：绿色系（#059669），象征可衡量的成果
/// - 背景：深色（#0F172A）/ 浅色（#F8FAFC），降低视觉疲劳
/// - 卡片：半透明叠加，营造层级感
extension Color {

    // MARK: - Adaptive Color Helper

    /// Creates a color that adapts between light and dark appearances.
    /// - Parameters:
    ///   - lightRed: Red component for light mode (0.0 - 1.0)
    ///   - lightGreen: Green component for light mode
    ///   - lightBlue: Blue component for light mode
    ///   - lightOpacity: Opacity for light mode
    ///   - darkRed: Red component for dark mode
    ///   - darkGreen: Green component for dark mode
    ///   - darkBlue: Blue component for dark mode
    ///   - darkOpacity: Opacity for dark mode
    /// - Returns: An adaptive Color
    private static func adaptive(
        lightRed: Double, lightGreen: Double, lightBlue: Double, lightOpacity: Double = 1.0,
        darkRed: Double, darkGreen: Double, darkBlue: Double, darkOpacity: Double = 1.0
    ) -> Color {
        #if os(macOS)
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(red: CGFloat(darkRed), green: CGFloat(darkGreen),
                               blue: CGFloat(darkBlue), alpha: CGFloat(darkOpacity))
            } else {
                return NSColor(red: CGFloat(lightRed), green: CGFloat(lightGreen),
                               blue: CGFloat(lightBlue), alpha: CGFloat(lightOpacity))
            }
        }))
        #else
        return Color(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            if isDark {
                return UIColor(red: CGFloat(darkRed), green: CGFloat(darkGreen),
                               blue: CGFloat(darkBlue), alpha: CGFloat(darkOpacity))
            } else {
                return UIColor(red: CGFloat(lightRed), green: CGFloat(lightGreen),
                               blue: CGFloat(lightBlue), alpha: CGFloat(lightOpacity))
            }
        })
        #endif
    }

    /// Creates an adaptive white-based color with different opacities for light/dark.
    private static func adaptiveWhite(
        lightWhite: Double, lightOpacity: Double = 1.0,
        darkWhite: Double, darkOpacity: Double = 1.0
    ) -> Color {
        #if os(macOS)
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(white: CGFloat(darkWhite), alpha: CGFloat(darkOpacity))
            } else {
                return NSColor(white: CGFloat(lightWhite), alpha: CGFloat(lightOpacity))
            }
        }))
        #else
        return Color(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            if isDark {
                return UIColor(white: CGFloat(darkWhite), alpha: CGFloat(darkOpacity))
            } else {
                return UIColor(white: CGFloat(lightWhite), alpha: CGFloat(lightOpacity))
            }
        })
        #endif
    }

    // MARK: - Scope Colors

    /// 企业级范围标识颜色 - 金色
    /// 用于企业级Objective和KR的视觉标识
    public static let enterpriseScope = adaptive(
        lightRed: 0.831, lightGreen: 0.608, lightBlue: 0.000,
        darkRed: 0.918, darkGreen: 0.702, darkBlue: 0.031
    )

    /// 个人级范围标识颜色 - 蓝色
    /// 用于个人级Objective和KR的视觉标识
    public static let personalScope = adaptive(
        lightRed: 0.188, lightGreen: 0.412, lightBlue: 0.812,
        darkRed: 0.231, darkGreen: 0.510, darkBlue: 0.965
    )

    // MARK: - Progress Colors

    /// 企业级进度条颜色 - 深金色
    /// 用于企业级节点的进度指示
    public static let enterpriseProgress = adaptive(
        lightRed: 0.725, lightGreen: 0.471, lightBlue: 0.000,
        darkRed: 0.792, darkGreen: 0.541, darkBlue: 0.016
    )

    /// 个人级进度条颜色 - 蓝色
    /// 用于个人级节点的进度指示
    public static let personalProgress = adaptive(
        lightRed: 0.188, lightGreen: 0.412, lightBlue: 0.812,
        darkRed: 0.231, darkGreen: 0.510, darkBlue: 0.965
    )

    /// 关键结果进度条颜色 - 绿色
    /// 用于叶子KR节点的进度指示
    public static let krProgress = adaptive(
        lightRed: 0.000, lightGreen: 0.502, lightBlue: 0.353,
        darkRed: 0.020, darkGreen: 0.588, darkBlue: 0.412
    )

    // MARK: - Background Colors

    /// 应用主背景色
    /// 深色模式: 深蓝灰色 (#0F172A)
    /// 浅色模式: 浅蓝灰色 (#F1F5F9)
    public static let appBackground = adaptive(
        lightRed: 0.945, lightGreen: 0.961, lightBlue: 0.976,
        darkRed: 0.059, darkGreen: 0.090, darkBlue: 0.165
    )

    /// 应用二级背景色
    /// 深色模式: 稍浅的蓝灰色 (#162033)
    /// 浅色模式: 白色 (#FFFFFF)
    public static let appBackgroundSecondary = adaptive(
        lightRed: 1.0, lightGreen: 1.0, lightBlue: 1.0,
        darkRed: 0.086, darkGreen: 0.125, darkBlue: 0.212
    )

    /// 卡片背景色
    /// 深色模式: 白色5%透明度
    /// 浅色模式: 白色100%
    public static let cardBackground = adaptiveWhite(
        lightWhite: 1.0, lightOpacity: 1.0,
        darkWhite: 1.0, darkOpacity: 0.05
    )

    /// 卡片悬浮背景色
    /// 深色模式: 白色8%透明度
    /// 浅色模式: 浅灰色
    public static let cardBackgroundHover = adaptive(
        lightRed: 0.925, lightGreen: 0.941, lightBlue: 0.961,
        darkRed: 1.0, darkGreen: 1.0, darkBlue: 1.0, darkOpacity: 0.08
    )

    // MARK: - Border Colors

    /// 卡片边框色
    /// 深色模式: 白色10%透明度
    /// 浅色模式: 浅灰色边框
    public static let cardBorder = adaptive(
        lightRed: 0.820, lightGreen: 0.843, lightBlue: 0.863,
        lightOpacity: 1.0,
        darkRed: 1.0, darkGreen: 1.0, darkBlue: 1.0, darkOpacity: 0.10
    )

    /// 卡片悬浮边框色
    /// 深色模式: 白色20%透明度
    /// 浅色模式: 中灰色边框
    public static let cardBorderHover = adaptive(
        lightRed: 0.710, lightGreen: 0.741, lightBlue: 0.773,
        lightOpacity: 1.0,
        darkRed: 1.0, darkGreen: 1.0, darkBlue: 1.0, darkOpacity: 0.20
    )

    /// 分隔线颜色
    /// 深色模式: 白色5%透明度
    /// 浅色模式: 浅灰色
    public static let divider = adaptive(
        lightRed: 0.871, lightGreen: 0.890, lightBlue: 0.910,
        lightOpacity: 1.0,
        darkRed: 1.0, darkGreen: 1.0, darkBlue: 1.0, darkOpacity: 0.05
    )

    // MARK: - Text Colors

    /// 主文本色 - 用于标题和重要文本
    /// 深色模式: 高对比度白色
    /// 浅色模式: 深灰色（确保 WCAG AA 对比度）
    public static let primaryText = adaptive(
        lightRed: 0.114, lightGreen: 0.161, lightBlue: 0.227,
        darkRed: 0.95, darkGreen: 0.95, darkBlue: 0.95
    )

    /// 次级文本色 - 用于描述、标签等次要信息
    /// 深色模式: 中灰色
    /// 浅色模式: 中深灰色（确保可读性）
    public static let secondaryText = adaptive(
        lightRed: 0.420, lightGreen: 0.471, lightBlue: 0.533,
        darkRed: 0.6, darkGreen: 0.6, darkBlue: 0.6
    )

    /// 三级文本色 - 用于占位符和禁用状态的文本
    /// 深色模式: 深灰色
    /// 浅色模式: 浅灰色
    public static let tertiaryText = adaptive(
        lightRed: 0.620, lightGreen: 0.663, lightBlue: 0.710,
        darkRed: 0.4, darkGreen: 0.4, darkBlue: 0.4
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
