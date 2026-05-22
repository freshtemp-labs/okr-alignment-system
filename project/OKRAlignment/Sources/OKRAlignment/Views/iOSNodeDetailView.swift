import SwiftUI
import OKRAlignmentShared

// MARK: - iOSNodeDetailView

/// iOS节点详情视图
/// ==============
/// 展示单个OKR节点的完整信息，支持进度调整、编辑和删除操作。
///
/// # 信息展示
/// - 节点标题（导航栏标题）
/// - 节点类型标签（Objective / Key Result）
/// - 范围标识（企业级金色 / 个人级蓝色）
/// - 负责人姓名
/// - 详细描述（如有）
/// - 彩色进度条（根据scope显示金色/蓝色/绿色）
/// - 当前进度百分比
/// - 状态标签
/// - 创建/更新时间
///
/// # 交互功能
/// - **叶子KR节点**: 显示当前值/目标值，提供±10%快捷调整按钮
/// - **编辑按钮**: 弹出编辑Sheet修改节点属性
/// - **删除按钮**: 带确认弹窗的删除操作
///
/// # 导航
/// - 导航栏标题为节点标题
/// - 自动包含返回按钮
///
/// ## 使用示例
/// ```swift
/// NavigationStack {
///     iOSNodeDetailView(node: selectedNode)
///         .environment(treeViewModel)
/// }
/// ```
struct iOSNodeDetailView: View {

    // MARK: - 环境

    /// 树视图模型 - 用于进度更新和删除操作
    /// 从环境获取，与iOSTreeView共享同一个实例
    @Environment(TreeViewModel.self) private var treeViewModel

    /// 周期列表视图模型 - 用于周期信息展示
    @Environment(CycleListViewModel.self) private var cycleViewModel

    // MARK: - 属性

    /// 当前展示的OKR节点
    /// 通过初始化参数传入，是此视图的展示目标
    let node: OKRNode

    // MARK: - 状态

    /// 是否展示编辑Sheet
    /// 点击编辑按钮时设为true
    @State private var isEditSheetPresented: Bool = false

    /// 是否展示删除确认弹窗
    /// 点击删除按钮时设为true
    @State private var showDeleteConfirmation: Bool = false

    /// 是否展示操作菜单（更多选项）
    /// 点击更多按钮时设为true
    @State private var showActionMenu: Bool = false

    /// 是否正在执行删除操作
    /// 用于展示删除过程中的加载状态
    @State private var isDeleting: Bool = false

    /// 编辑后的节点副本
    /// 用于在编辑Sheet中绑定修改
    @State private var editingNodeCopy: OKRNode? = nil

    // MARK: - 初始化

    /// 创建节点详情视图
    /// - Parameter node: 要展示详情的OKR节点
    init(node: OKRNode) {
        self.node = node
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 深色背景铺满整个视图
            Color.appBackground
                .ignoresSafeArea()

            // 主内容 - 可滚动
            ScrollView {
                VStack(spacing: 0) {
                    // 头部信息卡片
                    headerCard
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // 进度区域
                    progressSection
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 数值详情区域（仅叶子KR）
                    if node.isLeaf {
                        valueSection
                            .padding(.horizontal)
                            .padding(.top, 16)
                    }

                    // 详细信息网格
                    detailsGrid
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 子节点列表（如有）
                    if !node.children.isEmpty {
                        childrenSection
                            .padding(.horizontal)
                            .padding(.top, 16)
                    }

                    // 时间戳信息
                    timestampSection
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                }
            }
        }
        // 导航栏标题使用节点标题
        .navigationTitle(node.title)
        .navigationBarTitleDisplayMode(.inline)
        // 工具栏
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 更多操作菜单
                Menu {
                    // 编辑选项
                    Button {
                        editingNodeCopy = node
                        isEditSheetPresented = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }

                    Divider()

                    // 删除选项（红色警告样式）
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                }
            }
        }
        // 编辑Sheet
        .sheet(isPresented: $isEditSheetPresented) {
            if let editingNode = editingNodeCopy {
                iOSNodeEditSheet(
                    node: editingNode,
                    onSave: { _ in
                        Task {
                            await refreshTree()
                        }
                        isEditSheetPresented = false
                        editingNodeCopy = nil
                    },
                    onCancel: {
                        isEditSheetPresented = false
                        editingNodeCopy = nil
                    }
                )
            }
        }
        // 删除确认弹窗
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                // 取消删除，不做任何操作
            }
            Button("删除", role: .destructive) {
                Task {
                    await performDelete()
                }
            }
        } message: {
            Text("确定要删除\"\(node.title)\"吗？此操作不可撤销，将同时删除该节点下的所有子节点。")
        }
        // 加载完成后准备编辑副本
        .onAppear {
            editingNodeCopy = node
        }
    }

    // MARK: - 头部卡片

    /// 头部信息卡片
    /// 展示节点标题、类型标签、范围标识和负责人
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 类型和范围标签行
            HStack(spacing: 8) {
                NodeTypeLabel(nodeType: node.nodeType)

                Spacer()

                ScopeBadge(ownerName: node.ownerName, scope: node.scope)
            }

            // 标题
            Text(node.title)
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundStyle(.primaryText)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            // 描述（如有）
            if let description = node.nodeDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .cardBackground()
    }

    // MARK: - 进度区域

    /// 进度展示区域
    /// 包含彩色进度条和百分比显示
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 区域标题
            HStack {
                Text("完成进度")
                    .font(.headline)
                    .foregroundStyle(.primaryText)

                Spacer()

                // 状态标签
                HStack(spacing: 6) {
                    Image(systemName: node.status.iconName)
                        .font(.caption2)
                    Text(node.status.displayName)
                        .font(.caption)
                }
                .foregroundStyle(node.status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(node.status.color.opacity(0.15))
                .clipShape(Capsule())
            }

            // 进度条
            ProgressBar(
                progress: node.progress,
                scope: node.scope,
                nodeType: node.nodeType
            )
            .frame(height: 8)

            // 进度百分比和值显示
            HStack {
                Text(node.valueDisplayString)
                    .font(.caption)
                    .foregroundStyle(.secondaryText)

                Spacer()

                Text(node.progressPercentage)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(progressColor)
            }
        }
        .padding(16)
        .cardBackground()
    }

    // MARK: - 数值区域（仅叶子KR）

    /// 叶子KR数值展示和调整区域
    /// 仅对叶子Key Result节点显示，提供±10%快捷调整按钮
    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 区域标题
            HStack {
                Text("数值调整")
                    .font(.headline)
                    .foregroundStyle(.primaryText)

                Spacer()

                // 范围图标
                Image(systemName: node.scope.iconName)
                    .font(.caption)
                    .foregroundStyle(node.scope.color)
            }

            // 当前值 / 目标值大字体展示
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(formattedCurrentValue)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primaryText)

                Text("/ \(formattedTargetValue) \(node.unit ?? "")")
                    .font(.title3)
                    .foregroundStyle(.secondaryText)

                Spacer()
            }
            .padding(.vertical, 8)

            Divider()
                .background(Color.divider)

            // ±10%快捷调整按钮
            HStack(spacing: 16) {
                // -10% 按钮
                Button {
                    Task {
                        // 计算减量（不低于0）
                        let delta = calculateDelta(percentage: -10)
                        await treeViewModel.updateLeafProgress(
                            nodeId: node.id,
                            delta: delta
                        )
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle.fill")
                        Text("10%")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(canDecrement ? .white : .gray)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(canDecrement ? Color.red.opacity(0.2) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(canDecrement ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canDecrement)

                // +10% 按钮
                Button {
                    Task {
                        // 计算增量（不超过目标值）
                        let delta = calculateDelta(percentage: 10)
                        await treeViewModel.updateLeafProgress(
                            nodeId: node.id,
                            delta: delta
                        )
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("10%")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(canIncrement ? .white : .gray)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(canIncrement ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(canIncrement ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canIncrement)
            }
        }
        .padding(16)
        .cardBackground()
        .overlay(
            // 左侧范围指示条
            RoundedRectangle(cornerRadius: 12)
                .fill(scopeColor)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2)),
            alignment: .leading
        )
    }

    // MARK: - 详情网格

    /// 详细信息网格
    /// 以两列网格形式展示节点的各类元信息
    private var detailsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {
            DetailInfoItem(
                title: "节点类型",
                value: node.nodeType.displayName,
                iconName: node.nodeType.iconName,
                iconColor: node.nodeType.color
            )

            DetailInfoItem(
                title: "范围",
                value: node.scope.displayName,
                iconName: node.scope.iconName,
                iconColor: node.scope.color
            )

            DetailInfoItem(
                title: "状态",
                value: node.status.displayName,
                iconName: node.status.iconName,
                iconColor: node.status.color
            )

            DetailInfoItem(
                title: "子节点数",
                value: "\(node.children.count)",
                iconName: "folder.fill",
                iconColor: .secondaryText
            )
        }
    }

    // MARK: - 子节点区域

    /// 子节点列表区域
    /// 展示当前节点的所有直接子节点
    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("子节点 (\(node.children.count))")
                    .font(.headline)
                    .foregroundStyle(.primaryText)

                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(node.children) { child in
                    childRow(for: child)
                }
            }
        }
        .padding(16)
        .cardBackground()
    }

    // MARK: - 时间戳区域

    /// 时间戳信息区域
    /// 展示节点的创建时间和最后更新时间
    private var timestampSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("时间信息")
                    .font(.headline)
                    .foregroundStyle(.primaryText)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                timestampRow(
                    label: "创建时间",
                    date: node.createdAt,
                    iconName: "calendar.badge.plus"
                )

                timestampRow(
                    label: "更新时间",
                    date: node.updatedAt,
                    iconName: "calendar.badge.clock"
                )
            }
        }
        .padding(16)
        .cardBackground()
    }

    // MARK: - 辅助视图

    /// 子节点行视图
    /// - Parameter child: 子节点数据
    /// - Returns: 子节点行视图
    private func childRow(for child: OKRNode) -> some View {
        HStack(spacing: 12) {
            // 范围指示色块
            Circle()
                .fill(child.scope == .enterprise ? Color.enterpriseScope : Color.personalScope)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(child.title)
                    .font(.subheadline)
                    .foregroundStyle(.primaryText)
                    .lineLimit(1)

                Text(child.ownerName)
                    .font(.caption2)
                    .foregroundStyle(.secondaryText)
            }

            Spacer()

            // 进度百分比
            Text(child.progressPercentage)
                .font(.caption.bold())
                .foregroundStyle(child.scope == .enterprise ? Color.enterpriseScope : Color.personalScope)
        }
        .padding(.vertical, 6)
    }

    /// 时间戳行视图
    /// - Parameters:
    ///   - label: 标签文字
    ///   - date: 日期
    ///   - iconName: SF Symbols图标名
    /// - Returns: 时间戳行视图
    private func timestampRow(label: String, date: Date, iconName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(.tertiaryText)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondaryText)

            Spacer()

            Text(formattedDate(date))
                .font(.caption)
                .foregroundStyle(.secondaryText)
        }
    }

    // MARK: - 计算属性

    /// 进度条颜色
    /// 根据节点范围和类型返回对应的进度颜色
    private var progressColor: Color {
        if node.nodeType == .keyResult {
            return .krProgress
        }
        return node.scope == .enterprise ? .enterpriseProgress : .personalProgress
    }

    /// 范围颜色
    /// 根据节点范围返回标识颜色
    private var scopeColor: Color {
        node.scope == .enterprise ? .enterpriseScope : .personalScope
    }

    /// 格式化后的当前值
    private var formattedCurrentValue: String {
        if node.currentValue == floor(node.currentValue) {
            return String(format: "%.0f", node.currentValue)
        }
        return String(format: "%.1f", node.currentValue)
    }

    /// 格式化后的目标值
    private var formattedTargetValue: String {
        if node.targetValue == floor(node.targetValue) {
            return String(format: "%.0f", node.targetValue)
        }
        return String(format: "%.1f", node.targetValue)
    }

    /// 是否可以减少进度
    /// 当前值大于0时允许减少
    private var canDecrement: Bool {
        node.currentValue > 0
    }

    /// 是否可以增加进度
    /// 当前值小于目标值时允许增加
    private var canIncrement: Bool {
        node.currentValue < node.targetValue
    }

    // MARK: - 辅助方法

    /// 计算增量/减量值
    /// 将百分比转换为实际的数值变化量，并进行边界保护
    /// - Parameter percentage: 百分比变化量（如10表示+10%，-10表示-10%）
    /// - Returns: 实际的数值变化量
    private func calculateDelta(percentage: Double) -> Double {
        let rawDelta = node.targetValue * (percentage / 100.0)
        let newValue = node.currentValue + rawDelta

        // 边界保护: 确保新值在[0, targetValue]范围内
        if newValue < 0 {
            return -node.currentValue
        } else if newValue > node.targetValue {
            return node.targetValue - node.currentValue
        }
        return rawDelta
    }

    /// 格式化日期
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的日期字符串
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    /// 刷新OKR树数据
    /// 在编辑或删除操作后调用，确保数据一致性
    private func refreshTree() async {
        let cycleId = cycleViewModel.selectedCycle?.id
        await treeViewModel.loadTree(cycleId: cycleId)
    }

    /// 执行删除操作
    /// 删除当前节点及其子树，然后返回上一级视图
    private func performDelete() async {
        isDeleting = true
        await treeViewModel.deleteNode(id: node.id)
        isDeleting = false
        // 删除后视图会自动从导航栈中弹出
        // 因为父视图会检测到rootNode变化并刷新
    }
}

// MARK: - DetailInfoItem

/// 详情信息项视图
/// ============
/// 用于在详情网格中展示单个信息项，
/// 包含图标、标签和值。
struct DetailInfoItem: View {

    /// 信息项标题
    let title: String

    /// 信息项值
    let value: String

    /// SF Symbols图标名称
    let iconName: String

    /// 图标颜色
    let iconColor: Color

    var body: some View {
        VStack(spacing: 8) {
            // 图标
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)

            // 标题
            Text(title)
                .font(.caption)
                .foregroundStyle(.tertiaryText)

            // 值
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.appBackgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("iOSNodeDetailView - Enterprise Objective") {
    NavigationStack {
        iOSNodeDetailView(node: OKRNode.sampleEnterpriseObjective())
            .environment(TreeViewModel(
                repository: CoreDataOKRRepository(
                    container: PersistenceController.preview.container
                )
            ))
            .environment(CycleListViewModel(
                repository: CoreDataOKRRepository(
                    container: PersistenceController.preview.container
                )
            ))
    }
    .preferredColorScheme(.dark)
}

#Preview("iOSNodeDetailView - Personal Key Result") {
    NavigationStack {
        iOSNodeDetailView(node: OKRNode.samplePersonalKeyResult())
            .environment(TreeViewModel(
                repository: CoreDataOKRRepository(
                    container: PersistenceController.preview.container
                )
            ))
            .environment(CycleListViewModel(
                repository: CoreDataOKRRepository(
                    container: PersistenceController.preview.container
                )
            ))
    }
    .preferredColorScheme(.dark)
}

#Preview("iOSNodeDetailView - Leaf KR with Values") {
    let leafNode = OKRNode(
        id: UUID(),
        title: "新用户7日留存率提升至40%",
        nodeDescription: "通过优化引导流程和增加激励措施提升留存率",
        nodeType: .keyResult,
        scope: .personal,
        currentValue: 32,
        targetValue: 40,
        unit: "%",
        progress: 80.0,
        status: .inProgress,
        ownerName: "王五（产品经理）",
        createdAt: Date(),
        updatedAt: Date(),
        sortOrder: 0,
        parentId: UUID(),
        children: [],
        cycleId: UUID()
    )

    NavigationStack {
        iOSNodeDetailView(node: leafNode)
            .environment(TreeViewModel(
                repository: CoreDataOKRRepository(
                    container: PersistenceController.preview.container
                )
            ))
            .environment(CycleListViewModel(
                repository: CoreDataOKRRepository(
                    container: PersistenceController.preview.container
                )
            ))
    }
    .preferredColorScheme(.dark)
}
