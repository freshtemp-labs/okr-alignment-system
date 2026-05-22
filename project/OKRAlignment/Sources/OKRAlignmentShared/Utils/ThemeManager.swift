// OKRAlignmentShared/Utils/ThemeManager.swift

import SwiftUI
import os

/// 应用主题管理器
/// 支持三种外观模式：跟随系统 / 始终浅色 / 始终深色
/// 使用 @AppStorage 持久化用户偏好
@Observable
public final class ThemeManager: @unchecked Sendable {

    // MARK: - Appearance Mode

    /// 外观模式枚举
    public enum AppearanceMode: String, CaseIterable, Sendable {
        /// 跟随系统设置
        case system = "system"
        /// 始终浅色模式
        case light = "light"
        /// 始终深色模式
        case dark = "dark"

        /// 显示名称
        public var displayName: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "始终浅色"
            case .dark: return "始终深色"
            }
        }

        /// SF Symbol 图标名称
        public var iconName: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }

        /// 对应的 SwiftUI ColorScheme（system 模式返回 nil）
        public var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    // MARK: - Properties

    nonisolated(unsafe) public static var shared = ThemeManager()

    /// 当前外观模式
    public var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Self.storageKey)
            Logger.app.info("外观模式切换为: \(self.appearanceMode.displayName)")
        }
    }

    // MARK: - Private

    private static let storageKey = "okr_appearance_mode"

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.appearanceMode = AppearanceMode(rawValue: stored) ?? .dark
    }

    // MARK: - Computed

    /// 当前的 preferredColorScheme 值
    public var preferredColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }
}
