#if os(iOS)
import SwiftUI
import OKRAlignmentShared

// MARK: - iOSTreeView

/// iOS主树视图
/// ==========
/// OKR Alignment iOS端的核心视图，展示OKR树状结构。
///
/// # 视图结构
/// 采用`NavigationStack`作为容器，包含：
/// - **顶部工具栏**: 周期选择器（Menu/Picker形式）
/// - **主内容区**: `TreeView`共享组件渲染完整的OKR树
/// - **底部工具栏**: 新建节点、刷新按钮
///
/// # 交互设计
/// - 点击节点卡片 → 导航到`iOSNodeDetailView`详情页
/// - 下拉手势 → 触发`refreshable`重新加载树数据
/// - 底部工具栏 → 快速创建新节点或刷新数据
///
/// # 状态管理
/// 根据`TreeViewModel`的状态自动切换：
/// - `isLoading` → 展示`LoadingView`
/// - `errorMessage != nil` → 展示`ErrorView`
/// - `rootNode == nil` → 展示`EmptyStateView`
/// - `rootNode != nil` → 展示`TreeView`
///
/// ## 使用示例
/// ```swift
/// iOSTreeView()
///     .environment(treeViewModel)
///     .environment(cycleListViewModel)
/// ```
struct iOSTreeView: View {

    // MARK: - 环境

    /// 树视图模型 - 管理OKR树数据
    /// 从环境获取，通过App根视图注入
    @Environment(TreeViewModel.self) private var treeViewModel

    /// 周期列表视图模型 - 管理周期选择
    /// 从环境获取，用于顶部周期选择器的数据源
    @Environment(CycleListViewModel.self) private var cycleViewModel

    // MARK: - 导航状态

    /// 当前导航路径
    /// 用于管理NavigationStack的导航栈
    @State private var navigationPath = NavigationPath()

    /// 当前选中的节点（用于导航到详情页）
    /// 当用户点击树中的节点时设置此值
    @State private var selectedNode: OKRNode? = nil

    // MARK: - 编辑状态

    /// 是否展示编辑/创建Sheet
    /// 当用户点击新建或编辑按钮时设为true
    @State private var isEditSheetPresented: Bool = false

    /// 正在编辑的节点
    /// nil表示创建模式，非nil表示编辑模式
    @State private var editingNode: OKRNode? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // 深色背景铺满整个视图
                Color.appBackground
                    .ignoresSafeArea()

                // 主内容区域 - 根据状态展示不同视图
                mainContent
            }
            // 导航栏标题
            .navigationTitle("OKR Alignment")
            .navigationBarTitleDisplayMode(.large)
            // 顶部工具栏 - 周期选择器
            .toolbar {
                ToolbarItem(placement: .principal) {
                    cyclePicker
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            // 底部工具栏
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    newNodeButton
                    Spacer()
                    statusIndicator
                }
            }
            // 下拉刷新
            .refreshable {
                await refreshTree()
            }
            // 编辑Sheet
            .sheet(isPresented: $isEditSheetPresented) {
                iOSNodeEditSheet(
                    node: editingNode,
                    onSave: { savedNode in
                        // 保存后刷新树数据
                        Task {
                            await refreshTree()
                        }
                        isEditSheetPresented = false
                        editingNode = nil
                    },
                    onCancel: {
                        isEditSheetPresented = false
                        editingNode = nil
                    }
                )
            }
            // 导航目标配置
            .navigationDestination(for: OKRNode.self) { node in
                iOSNodeDetailView(node: node)
                    .environment(treeViewModel)
                    .environment(cycleViewModel)
            }
            // 视图首次出现时加载数据
            .task {
                await loadInitialTree()
            }
        }
    }

    // MARK: - 主内容

    /// 根据视图模型的当前状态展示对应内容
    /// 这是视图状态机的核心逻辑
    @ViewBuilder
    private var mainContent: some View {
        if treeViewModel.isLoading {
            // ===== 加载状态 =====
            // 展示居中加载指示器
            LoadingView(message: "加载OKR树...")
        } else if let errorMessage = treeViewModel.errorMessage {
            // ===== 错误状态 =====
            // 展示错误信息和重试按钮
            ErrorView(message: errorMessage) {
                Task {
                    await refreshTree()
                }
            }
        } else if treeViewModel.rootNode == nil {
            // ===== 空状态 =====
            // 展示空状态提示和创建按钮
            EmptyStateView(
                title: "暂无OKR数据",
                subtitle: "当前周期没有OKR数据，点击下方按钮创建第一个目标",
                iconName: "tree",
                actionTitle: "创建OKR"
            ) {
                // 打开创建Sheet
                editingNode = nil
                isEditSheetPresented = true
            }
        } else {
            // ===== 正常状态: 展示OKR树 =====
            // 使用共享的TreeView组件渲染树状结构
            if let rootNode = treeViewModel.rootNode {
                TreeView(
                    rootNode: rootNode,
                    onNodeTap: { node in
                        // 点击节点 → 导航到详情页
                        handleNodeTap(node)
                    },
                    onUpdateProgress: { nodeId, delta in
                        // 叶子KR进度更新
                        Task {
                            await treeViewModel.updateLeafProgress(
                                nodeId: nodeId,
                                delta: delta
                            )
                        }
                    }
                )
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 周期选择器

    /// 顶部周期选择器
    /// 使用Menu组件展示可用周期列表，支持快速切换
    private var cyclePicker: some View {
        Menu {
            // 周期列表
            if cycleViewModel.hasCycles {
                ForEach(cycleViewModel.cycles) { cycle in
                    Button {
                        // 选择周期并加载对应OKR树
                        Task {
                            cycleViewModel.selectCycle(cycle)
                            await treeViewModel.loadTree(cycleId: cycle.id)
                        }
                    } label: {
                        HStack {
                            Text(cycle.name)
                            if cycleViewModel.selectedCycle?.id == cycle.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } else {
                // 无周期时展示提示
                Text("暂无可用周期")
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 刷新周期列表选项
            Button {
                Task {
                    await cycleViewModel.loadCycles()
                }
            } label: {
                Label("刷新周期列表", systemImage: "arrow.clockwise")
            }
        } label: {
            // 选择器按钮外观
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))

                Text(cycleViewModel.selectedCycleName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primaryText)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.appBackgroundSecondary)
            )
            .overlay(
                Capsule()
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - 工具栏按钮

    /// 刷新按钮
    /// 位于导航栏右侧，用于手动刷新OKR树数据
    private var refreshButton: some View {
        Button {
            Task {
                await refreshTree()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.body)
                .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
        }
        .disabled(treeViewModel.isLoading)
        .opacity(treeViewModel.isLoading ? 0.5 : 1.0)
    }

    /// 新建节点按钮
    /// 位于底部工具栏左侧，点击打开创建Sheet
    private var newNodeButton: some View {
        Button {
            editingNode = nil
            isEditSheetPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("新建")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
        }
    }

    /// 状态指示器
    /// 位于底部工具栏右侧，展示当前加载状态
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            if treeViewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondaryText)
                Text("加载中...")
                    .font(.caption)
                    .foregroundStyle(.secondaryText)
            } else if let rootNode = treeViewModel.rootNode {
                // 显示树的总体进度
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiaryText)
                    Text("总进度: \(rootNode.progressPercentage)")
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                }
            }
        }
    }

    // MARK: - 事件处理

    /// 处理节点点击事件
    /// 将点击的节点推入导航栈，触发导航到详情页
    /// - Parameter node: 被点击的OKR节点
    private func handleNodeTap(_ node: OKRNode) {
        // 将节点推入导航路径
        // NavigationStack会自动导航到对应的navigationDestination
        navigationPath.append(node)
    }

    // MARK: - 数据操作

    /// 刷新OKR树数据
    /// 使用当前选中的周期ID重新加载树数据
    private func refreshTree() async {
        let cycleId = cycleViewModel.selectedCycle?.id
        await treeViewModel.loadTree(cycleId: cycleId)
    }

    /// 加载初始树数据
    /// 在视图首次出现时调用
    private func loadInitialTree() async {
        // 仅在尚未加载数据时执行
        // 避免在已有数据时重复加载
        if treeViewModel.rootNode == nil && !treeViewModel.isLoading {
            let cycleId = cycleViewModel.selectedCycle?.id
            await treeViewModel.loadTree(cycleId: cycleId)
        }
    }
}

// MARK: - Previews

#Preview("iOSTreeView - Loading") {
    let previewRepo = CoreDataOKRRepository(
        container: PersistenceController.preview.container
    )

    iOSTreeView()
        .environment(TreeViewModel(repository: previewRepo))
        .environment(CycleListViewModel(repository: previewRepo))
        .preferredColorScheme(.dark)
}

#Preview("iOSTreeView - Empty") {
    let previewRepo = CoreDataOKRRepository(
        container: PersistenceController.preview.container
    )

    iOSTreeView()
        .environment(TreeViewModel(repository: previewRepo))
        .environment(CycleListViewModel(repository: previewRepo))
        .preferredColorScheme(.dark)
}

#Preview("iOSTreeView - With Data") {
    let previewRepo = CoreDataOKRRepository(
        container: PersistenceController.preview.container
    )

    iOSTreeView()
        .environment(TreeViewModel(repository: previewRepo))
        .environment(CycleListViewModel(repository: previewRepo))
        .preferredColorScheme(.dark)
}

#endif
