import SwiftUI
import OKRAlignmentShared

// MARK: - OKRAlignmentMacApp

/// macOS应用主入口点
/// ================
/// OKR Alignment管理系统的macOS应用入口，使用App协议定义应用生命周期和窗口配置。
///
/// # 应用配置
/// - 应用名称: "OKR Alignment"
/// - 主视图: `MacTreeView`（三栏NavigationSplitView布局）
/// - 默认窗口大小: 1200x800
/// - 最小窗口尺寸: 900x600
/// - 默认外观: 深色模式
///
/// # 架构说明
/// 应用通过共享模块`OKRAlignmentShared`获取所有业务逻辑和视图组件，
/// 本模块仅包含macOS平台特定的入口代码和窗口配置。
///
/// ## 使用示例
/// ```swift
/// @main
/// struct OKRAlignmentMacApp: App {
///     var body: some Scene {
///         WindowGroup {
///             MacTreeView()
///         }
///     }
/// }
/// ```
@main
struct OKRAlignmentMacApp: App {

    // MARK: - 初始化

    /// 应用初始化
    /// 在应用启动时执行一次性的设置操作
    init() {
        // 设置深色模式为默认外观
        // 通过NSApp的appearance代理强制使用深色外观
        if let window = NSApplication.shared.mainWindow {
            window.appearance = NSAppearance(named: .darkAqua)
        }

        // 注册默认用户偏好设置
        // 确保首次启动时应用使用深色主题
        UserDefaults.standard.register(defaults: [
            "AppleInterfaceStyle": "Dark"
        ])
    }

    // MARK: - App Body

    /// 定义应用的场景结构
    /// 包含主窗口组和可选的设置窗口
    var body: some Scene {
        // MARK: 主窗口
        WindowGroup("OKR Alignment") {
            MacTreeView()
                // 强制深色模式外观
                .preferredColorScheme(.dark)
        }
        // 配置默认窗口尺寸
        .defaultSize(width: 1200, height: 800)
        // 配置窗口尺寸限制
        .windowResizability(.contentSize)
        .commands {
            // 自定义菜单命令
            OKRMenuCommands()
        }

        // MARK: 设置窗口（可选）
        #if os(macOS)
        Settings {
            // 应用设置面板
            // 可扩展为包含主题选择、数据同步配置等
            Text("Settings")
                .frame(width: 400, height: 300)
        }
        #endif
    }
}

// MARK: - Menu Commands

/// 自定义菜单命令扩展
/// 为macOS菜单栏添加OKR相关的快捷操作
struct OKRMenuCommands: Commands {

    /// 菜单命令内容
    var body: some Commands {
        // 替换标准新建文件菜单
        CommandGroup(replacing: .newItem) {
            Button("New OKR Node") {
                // 发送新建节点通知
                // 由MacTreeView监听并响应
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "CreateNewNode"),
                    object: nil
                )
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // 添加刷新命令到视图菜单
        CommandMenu("View") {
            Button("Refresh Tree") {
                // 发送刷新树通知
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "RefreshTree"),
                    object: nil
                )
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Expand All") {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "ExpandAllNodes"),
                    object: nil
                )
            }
            .keyboardShortcut("e", modifiers: [.command, .option])

            Button("Collapse All") {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "CollapseAllNodes"),
                    object: nil
                )
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
        }
    }
}

// MARK: - Window Size Constraints Extension

#if os(macOS)
import AppKit

/// 窗口尺寸约束辅助扩展
/// 用于限制用户调整窗口时的最小尺寸，确保UI元素不被过度压缩
extension OKRAlignmentMacApp {
    /// 应用窗口的最小宽度（像素）
    /// 低于此宽度时树状视图将无法正常显示
    static let minWindowWidth: CGFloat = 900

    /// 应用窗口的最小高度（像素）
    /// 低于此高度时详情面板将无法正常显示
    static let minWindowHeight: CGFloat = 600
}
#endif

#if !SWIFT_PACKAGE
// MARK: - Previews

#Preview("Mac App Window") {
    MacTreeView()
        .preferredColorScheme(.dark)
        .frame(width: 1200, height: 800)
}
#endif
