#if os(iOS)
import SwiftUI
import OKRAlignmentShared
import CoreData

// MARK: - OKRAlignmentApp

/// iOS应用主入口点
/// ===============
/// OKR Alignment管理系统的iOS应用入口，使用App协议定义应用生命周期。
///
/// # 应用配置
/// - 应用名称: "OKR Alignment"
/// - 主视图: `TabBarView`（底部Tab导航）
/// - 强调色: 蓝色 (#3B82F6)
/// - 默认外观: 深色模式
///
/// # 依赖注入
/// 应用在启动时创建以下共享实例并通过environment注入视图层级：
/// - `CoreDataOKRRepository`: Core Data数据仓库
/// - `TreeViewModel`: OKR树视图模型
/// - `CycleListViewModel`: 周期列表视图模型
///
/// # 架构说明
/// 采用MVVM+Clean Architecture，通过共享模块`OKRAlignmentShared`获取
/// 所有业务逻辑和可复用视图组件，本模块仅包含iOS平台特定的入口代码。
///
/// ## 使用示例
/// ```swift
/// @main
/// struct OKRAlignmentApp: App {
///     let repository = CoreDataOKRRepository(...)
///
///     var body: some Scene {
///         WindowGroup {
///             TabBarView()
///                 .environment(treeViewModel)
///         }
///     }
/// }
/// ```
@main
struct OKRAlignmentApp: App {

    // MARK: - 共享依赖

    /// Core Data持久化控制器单例
    /// 管理整个应用的Core Data栈和持久化存储
    private let persistenceController = PersistenceController.shared

    /// OKR数据仓库
    /// 基于Core Data实现，封装所有持久化操作
    /// 作为ViewModel的依赖注入到整个视图层级
    private let repository: CoreDataOKRRepository

    // MARK: - 视图模型

    /// 树视图模型 - 管理OKR树的展示和交互
    /// @Observable类型，自动驱动依赖它的视图刷新
    @State private var treeViewModel: TreeViewModel

    /// 周期列表视图模型 - 管理OKR周期的选择和管理
    /// @Observable类型，自动驱动依赖它的视图刷新
    @State private var cycleListViewModel: CycleListViewModel

    // MARK: - 初始化

    /// 应用初始化
    /// 创建所有必要的依赖和视图模型实例
    init() {
        // ===== 步骤1: 创建数据仓库 =====
        // 使用PersistenceController的持久化容器初始化仓库
        let repo = CoreDataOKRRepository(container: persistenceController.container)
        self.repository = repo

        // ===== 步骤2: 创建视图模型 =====
        // 将仓库注入到各个ViewModel中
        // 使用_赋值因为@State属性包装器需要特殊初始化
        _treeViewModel = State(initialValue: TreeViewModel(repository: repo))
        _cycleListViewModel = State(initialValue: CycleListViewModel(repository: repo))

        // ===== 步骤3: 配置全局UI外观 =====
        configureAppearance()
    }

    // MARK: - App Body

    /// 定义应用的场景结构
    var body: some Scene {
        WindowGroup("OKR Alignment") {
            TabBarView()
                // 注入共享的视图模型到环境
                .environment(treeViewModel)
                .environment(cycleListViewModel)
                .environment(\.managedObjectContext, persistenceController.viewContext)
                // 强制使用深色模式
                .preferredColorScheme(.dark)
                // 设置强调色（交互式元素的高亮色）
                .tint(Color(red: 59/255, green: 130/255, blue: 246/255))
                // 应用启动时加载初始数据
                .task {
                    await loadInitialData()
                }
        }
    }

    // MARK: - 数据加载

    /// 加载应用的初始数据
    /// 在应用启动时异步执行，加载周期列表和默认周期的OKR树
    private func loadInitialData() async {
        // ===== 步骤1: 加载周期列表 =====
        // 从Repository获取所有可用周期
        await cycleListViewModel.loadCycles()

        // ===== 步骤2: 加载默认周期的OKR树 =====
        // 使用当前选中的周期ID加载对应的OKR树
        // 如果用户未选择周期，loadTree会处理nil情况
        let selectedCycleId = cycleListViewModel.selectedCycle?.id
        await treeViewModel.loadTree(cycleId: selectedCycleId)
    }

    // MARK: - UI外观配置

    /// 配置全局UI外观
    /// 设置TabBar、NavigationBar等系统组件的外观样式
    private func configureAppearance() {
        // 配置TabBar外观 - 深色背景
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(
            red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0
        )

        // 未选中状态的图标和文字颜色
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(
            red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0
        )
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
        ]

        // 选中状态的图标和文字颜色（蓝色强调色）
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(
            red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0
        )
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0)
        ]

        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // 配置NavigationBar外观 - 深色背景
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(
            red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0
        )
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
}

// MARK: - Previews

#Preview("iOS App") {
    // 预览使用预览专用数据
    let previewRepo = CoreDataOKRRepository(
        container: PersistenceController.preview.container
    )

    TabBarView()
        .environment(TreeViewModel(repository: previewRepo))
        .environment(CycleListViewModel(repository: previewRepo))
        .preferredColorScheme(.dark)
}

#endif
