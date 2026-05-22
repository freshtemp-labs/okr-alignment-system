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
/// # 快捷键
/// - Cmd+N: 新建 Objective
/// - Cmd+F: 搜索
/// - Delete: 删除选中节点
/// - Escape: 关闭弹窗
/// - Cmd+R: 刷新
/// - Cmd+E: 编辑
///
@main
struct OKRAlignmentMacApp: App {

    // MARK: - 主题管理

    /// 主题管理器
    @State private var themeManager = ThemeManager.shared

    // MARK: - 初始化

    /// 应用初始化
    /// 在应用启动时执行一次性的设置操作
    init() {
        // 注册默认用户偏好设置
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
                // 使用用户选择的外观模式
                .preferredColorScheme(themeManager.preferredColorScheme)
                .environment(themeManager)
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
            NavigationStack {
                List {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("外观", systemImage: "paintbrush")
                    }

                    NavigationLink {
                        iCloudSyncSettingsView()
                    } label: {
                        Label("iCloud 同步", systemImage: "icloud")
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 200)
            }
            .frame(width: 500, height: 350)
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
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "CreateNewNode"),
                    object: nil
                )
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // 添加编辑菜单
        CommandMenu("Edit") {
            Button("Search OKRs") {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "FocusSearch"),
                    object: nil
                )
            }
            .keyboardShortcut("f", modifiers: .command)
            
            Divider()
            
            Button("Delete Selected") {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "DeleteSelectedNode"),
                    object: nil
                )
            }
            .keyboardShortcut(.delete, modifiers: [])
        }

        // 添加视图菜单
        CommandMenu("View") {
            Button("Refresh Tree") {
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
        
        // 数据菜单
        CommandMenu("Data") {
            Button("Export as CSV...") {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "ExportCSV"),
                    object: nil
                )
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            
            Button("Export as JSON...") {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "ExportJSON"),
                    object: nil
                )
            }
            .keyboardShortcut("j", modifiers: [.command, .shift])
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
    static let minWindowWidth: CGFloat = 900

    /// 应用窗口的最小高度（像素）
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
