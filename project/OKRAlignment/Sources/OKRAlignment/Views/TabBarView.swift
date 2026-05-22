#if os(iOS)
import SwiftUI
import OKRAlignmentShared

// MARK: - TabBarView

/// iOS底部Tab导航视图
/// =================
/// 提供应用的主导航结构，包含2-3个Tab项：
/// - **OKR树**: 主功能Tab，展示和交互OKR树
/// - **周期**: 周期列表和管理
/// - **设置**: 应用设置（可选）
///
/// 使用SwiftUI的`TabView`实现底部导航栏，
/// 每个Tab包含独立的导航栈和状态管理。
///
/// ## 设计说明
/// - 深色背景适配，使用.appBackground
/// - SF Symbols图标系统
/// - 选中状态使用蓝色强调色
/// - 未选中状态使用灰色
///
/// ## 使用示例
/// ```swift
/// TabBarView()
///     .environment(treeViewModel)
///     .environment(cycleListViewModel)
/// ```
struct TabBarView: View {

    // MARK: - 状态

    /// 当前选中的Tab索引
    /// 用于控制TabView的当前页面
    @State private var selectedTab: Tab = .tree

    // MARK: - Tab枚举

    /// 定义所有可用的Tab项
    /// 每个case对应一个独立的视图和功能模块
    enum Tab: String, CaseIterable {
        /// OKR树Tab - 主功能
        case tree
        /// 周期Tab - 周期管理
        case cycles
        /// 设置Tab - 应用设置
        case settings

        /// Tab的标签文本
        var label: String {
            switch self {
            case .tree: return "OKR树"
            case .cycles: return "周期"
            case .settings: return "设置"
            }
        }

        /// Tab的SF Symbols图标名称
        var iconName: String {
            switch self {
            case .tree: return "tree"
            case .cycles: return "calendar"
            case .settings: return "gearshape.fill"
            }
        }

        /// Tab的选中状态图标名称
        var selectedIconName: String {
            switch self {
            case .tree: return "tree.fill"
            case .cycles: return "calendar.circle.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // ===== Tab 1: OKR树（主功能）=====
            iOSTreeView()
                .tabItem {
                    Image(
                        systemName: selectedTab == .tree
                            ? Tab.tree.selectedIconName
                            : Tab.tree.iconName
                    )
                    Text(Tab.tree.label)
                }
                .tag(Tab.tree)
                .environment(\.tabBarVisibility, .visible)

            // ===== Tab 2: 周期管理 =====
            iOSCycleListView()
                .tabItem {
                    Image(
                        systemName: selectedTab == .cycles
                            ? Tab.cycles.selectedIconName
                            : Tab.cycles.iconName
                    )
                    Text(Tab.cycles.label)
                }
                .tag(Tab.cycles)

            // ===== Tab 3: 设置 =====
            iOSSettingsView()
                .tabItem {
                    Image(systemName: Tab.settings.iconName)
                    Text(Tab.settings.label)
                }
                .tag(Tab.settings)
        }
        // 使用不透明的TabBar背景
        .toolbarBackground(.appBackground, for: .tabBar)
        // 确保TabBar始终可见
        .toolbarBackground(.visible, for: .tabBar)
        // 设置强调色为蓝色
        .accentColor(Color(red: 59/255, green: 130/255, blue: 246/255))
        // 设置整体背景色
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - iOSCycleListView

/// iOS周期列表视图
/// ==============
/// 展示所有OKR周期的列表，支持选择和创建新周期。
///
/// 作为TabBarView的第二个Tab内容，提供周期管理功能。
struct iOSCycleListView: View {

    // MARK: - 环境

    /// 周期列表视图模型
    /// 从环境获取，管理周期数据和选择状态
    @Environment(CycleListViewModel.self) private var viewModel

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 深色背景
                Color.appBackground
                    .ignoresSafeArea()

                // 主内容区域
                content
            }
            .navigationTitle("周期管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // 新建周期按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // 触发新建周期操作
                        // 实际实现中应展示新建周期的Sheet
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                    }
                }
            }
        }
    }

    // MARK: - 内容视图

    /// 根据视图模型状态展示不同内容
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            // 加载状态
            LoadingView(message: "加载周期列表...")
        } else if let errorMessage = viewModel.errorMessage {
            // 错误状态
            ErrorView(message: errorMessage) {
                Task {
                    await viewModel.loadCycles()
                }
            }
        } else if !viewModel.hasCycles {
            // 空状态
            EmptyStateView(
                title: "暂无周期",
                subtitle: "创建第一个OKR周期来开始管理目标",
                iconName: "calendar.badge.plus",
                actionTitle: "创建周期"
            ) {
                // 展示创建周期的Sheet
            }
        } else {
            // 周期列表
            cycleList
        }
    }

    // MARK: - 周期列表

    /// 周期列表视图
    /// 展示所有周期的卡片列表
    private var cycleList: some View {
        List {
            // 活跃周期Section
            if !viewModel.activeCycles.isEmpty {
                Section {
                    ForEach(viewModel.activeCycles) { cycle in
                        cycleRow(for: cycle)
                    }
                } header: {
                    Text("活跃周期")
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                }
            }

            // 已归档周期Section
            if !viewModel.archivedCycles.isEmpty {
                Section {
                    ForEach(viewModel.archivedCycles) { cycle in
                        cycleRow(for: cycle)
                            .opacity(0.6)
                    }
                } header: {
                    Text("已归档")
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    // MARK: - 周期行

    /// 单个周期的列表行视图
    /// - Parameter cycle: 要展示的周期
    /// - Returns: 周期行视图
    private func cycleRow(for cycle: OKRCycle) -> some View {
        Button {
            // 选择该周期
            viewModel.selectCycle(cycle)
            // 切换到OKR树Tab查看该周期的数据
            // 实际可通过NotificationCenter或共享状态实现
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // 周期名称和状态标签
                HStack {
                    Text(cycle.name)
                        .font(.headline)
                        .foregroundStyle(.primaryText)

                    Spacer()

                    // 状态标签
                    if cycle.isActive {
                        statusBadge(text: "进行中", color: .green)
                    } else if cycle.isArchived {
                        statusBadge(text: "已归档", color: .gray)
                    } else if cycle.isExpired {
                        statusBadge(text: "已过期", color: .orange)
                    }
                }

                // 日期范围
                Text(cycle.dateRangeString)
                    .font(.caption)
                    .foregroundStyle(.secondaryText)

                // 时间进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景轨道
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 4)

                        // 进度填充
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 37/255, green: 99/255, blue: 235/255),
                                        Color(red: 139/255, green: 92/255, blue: 246/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(0, min(
                                    CGFloat(cycle.timeProgressPercentage / 100.0) * geometry.size.width,
                                    geometry.size.width
                                )),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)

                // 进度百分比
                Text("时间进度: \(String(format: "%.1f%%", cycle.timeProgressPercentage))")
                    .font(.caption2)
                    .foregroundStyle(.tertiaryText)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.appBackgroundSecondary)
    }

    // MARK: - 辅助视图

    /// 状态标签视图
    /// - Parameters:
    ///   - text: 标签文字
    ///   - color: 标签颜色
    /// - Returns: 胶囊形状的状态标签
    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - iOSSettingsView

/// iOS设置视图
/// ==========
/// 提供应用的设置选项和关于信息。
///
/// 作为TabBarView的第三个Tab内容，提供以下功能：
/// - 应用信息展示
/// - 数据管理选项
/// - 主题设置（预留）
struct iOSSettingsView: View {

    // MARK: - 主题管理

    @Environment(ThemeManager.self) private var themeManager

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 深色背景
                Color.appBackground
                    .ignoresSafeArea()

                // 设置列表
                List {
                    // 应用信息Section
                    Section {
                        appInfoRow
                    } header: {
                        Text("关于")
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    }

                    // 数据管理Section
                    Section {
                        dataManagementRows
                    } header: {
                        Text("数据管理")
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    } footer: {
                        Text("导出功能将在未来版本中提供。")
                            .font(.caption2)
                            .foregroundStyle(.tertiaryText)
                    }

                    // iCloud 同步 Section
                    Section {
                        NavigationLink {
                            iCloudSyncSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "icloud.fill")
                                    .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                                Text("iCloud 同步")
                                    .foregroundStyle(.primaryText)
                            }
                        }
                    } header: {
                        Text("数据同步")
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    } footer: {
                        Text("启用 iCloud 同步后，您的 OKR 数据将在所有 Apple 设备间保持一致。")
                            .font(.caption2)
                            .foregroundStyle(.tertiaryText)
                    }

                    // 通知 Section
                    Section {
                        NavigationLink {
                            NotificationSettingsView(notificationService: NotificationService())
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                                Text("通知设置")
                                    .foregroundStyle(.primaryText)
                            }
                        }

                        NavigationLink {
                            NotificationDashboardView(notificationService: NotificationService())
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge.circle.fill")
                                    .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                                Text("通知仪表盘")
                                    .foregroundStyle(.primaryText)
                            }
                        }

                        NavigationLink {
                            SyncDashboardView()
                        } label: {
                            HStack {
                                Image(systemName: "gauge.with.dots.needle.bottom.fill")
                                    .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                                Text("同步仪表盘")
                                    .foregroundStyle(.primaryText)
                            }
                        }
                    } header: {
                        Text("通知与同步")
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    } footer: {
                        Text("通知仪表盘查看通知统计和历史，同步仪表盘查看同步健康度和趋势。")
                            .font(.caption2)
                            .foregroundStyle(.tertiaryText)
                    }

                    // 安全与加密 Section
                    Section {
                        NavigationLink {
                            SecuritySettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                                Text("安全与加密")
                                    .foregroundStyle(.primaryText)
                            }
                        }

                        NavigationLink {
                            BackupSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                                Text("数据备份")
                                    .foregroundStyle(.primaryText)
                            }
                        }

                        NavigationLink {
                            ErrorLogView()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                                Text("错误日志")
                                    .foregroundStyle(.primaryText)
                            }
                        }
                    } header: {
                        Text("安全与备份")
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    } footer: {
                        Text("数据加密使用 NSFileProtectionComplete 保护级别。自动备份每天执行一次，保留最近 7 天。")
                            .font(.caption2)
                            .foregroundStyle(.tertiaryText)
                    }

                    // 外观Section
                    Section {
                        // 外观模式选择
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundStyle(Color(red: 139/255, green: 92/255, blue: 246/255))
                                Text("外观模式")
                                    .foregroundStyle(.primaryText)
                                Spacer()
                                Text(themeManager.appearanceMode.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondaryText)
                            }
                        }
                    } header: {
                        Text("外观")
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 应用信息行

    /// 应用信息展示行
    /// 包含应用名称、版本号和图标
    private var appInfoRow: some View {
        HStack(spacing: 16) {
            // 应用图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 37/255, green: 99/255, blue: 235/255),
                                Color(red: 139/255, green: 92/255, blue: 246/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: "tree.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("OKR Alignment")
                    .font(.headline)
                    .foregroundStyle(.primaryText)

                Text("版本 \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondaryText)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - 数据管理行

    /// 数据管理选项行
    /// 包含导出数据、清除缓存等选项
    private var dataManagementRows: some View {
        Group {
            Button {
                // 导出数据操作（预留）
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                    Text("导出数据")
                        .foregroundStyle(.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiaryText)
                }
            }

            Button {
                // 刷新所有数据操作
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                    Text("刷新数据")
                        .foregroundStyle(.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiaryText)
                }
            }
        }
    }

    // MARK: - 外观设置行

    /// 外观设置选项行
    private var appearanceRow: some View {
        HStack {
            Image(systemName: "moon.fill")
                .foregroundStyle(Color(red: 139/255, green: 92/255, blue: 246/255))
            Text("深色模式")
                .foregroundStyle(.primaryText)
            Spacer()
            Text("始终开启")
                .font(.caption)
                .foregroundStyle(.secondaryText)
        }
    }

    // MARK: - 辅助属性

    /// 应用版本号
    /// 从Bundle的infoDictionary中读取
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - TabBarVisibility Environment Key

/// TabBar可见性环境键
/// 用于在子视图中控制TabBar的显示/隐藏
private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: Visibility = .visible
}

extension EnvironmentValues {
    /// TabBar可见性
    /// 在需要全屏展示内容（如树视图）时设置为.hidden
    var tabBarVisibility: Visibility {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

// MARK: - Previews

#Preview("TabBarView") {
    let previewRepo = CoreDataOKRRepository(
        container: PersistenceController.preview.container
    )

    TabBarView()
        .environment(TreeViewModel(repository: previewRepo))
        .environment(CycleListViewModel(repository: previewRepo))
        .preferredColorScheme(.dark)
}

#Preview("iOSCycleListView") {
    let previewRepo = CoreDataOKRRepository(
        container: PersistenceController.preview.container
    )

    iOSCycleListView()
        .environment(CycleListViewModel(repository: previewRepo))
        .preferredColorScheme(.dark)
}

#Preview("iOSSettingsView") {
    iOSSettingsView()
        .preferredColorScheme(.dark)
}

#endif
