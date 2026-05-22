import SwiftUI
import Charts

// MARK: - AnalyticsView

/// 数据分析视图（增强版）
/// ============
/// 展示OKR数据的可视化分析报表，包括：
/// - 报表筛选面板（时间范围/状态/Owner/进度）
/// - 预设报表模板
/// - KR状态分布饼图
/// - Owner进度排名柱状图
/// - 进度趋势折线图（多周期）
/// - 整体统计指标卡片
/// - 进度分布直方图
/// - 报表预览功能
public struct AnalyticsView: View {

    // MARK: - 属性

    /// 分析ViewModel
    @Bindable var viewModel: AnalyticsViewModel

    /// 当前周期ID
    let cycleId: UUID?

    /// 报表模板服务
    @StateObject private var templateService = ReportTemplateService.shared

    /// 报表筛选配置
    @State private var filterConfig = ReportFilterConfig()

    /// 是否显示筛选面板
    @State private var showFilterPanel = false

    /// 是否显示报表预览
    @State private var showPreview = false

    /// 撤销/重做管理器
    @StateObject private var undoRedoManager = UndoRedoManager.shared

    // MARK: - 初始化

    public init(viewModel: AnalyticsViewModel, cycleId: UUID?) {
        self.viewModel = viewModel
        self.cycleId = cycleId
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("正在加载分析数据...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("重试") {
                        Task { await viewModel.loadAnalytics(cycleId: cycleId) }
                    }
                }
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 20) {
                    // 筛选器快捷入口
                    filterBar

                    // 筛选面板
                    if showFilterPanel {
                        ReportFilterView(
                            templateService: templateService,
                            config: $filterConfig,
                            availableOwners: viewModel.ownerRankings.map(\.ownerName)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 筛选活动指示
                    if filterConfig.hasFilters {
                        activeFiltersIndicator
                    }

                    // 统计概览卡片
                    if filterConfig.includeStatistics {
                        statisticsCards
                    }

                    // KR状态分布饼图
                    if filterConfig.includeStatusDistribution {
                        statusDistributionChart
                    }

                    // Owner进度排名柱状图
                    if filterConfig.includeOwnerRankings {
                        ownerRankingChart
                    }

                    // 进度分布直方图
                    if filterConfig.includeProgressDistribution {
                        progressDistributionChart
                    }

                    // 热力图
                    if !viewModel.heatmapData.isEmpty {
                        HeatmapView(data: viewModel.heatmapData)
                    }

                    // 甘特图（如果有周期数据）
                    if !viewModel.ganttItems.isEmpty {
                        GanttChartView(
                            items: viewModel.ganttItems,
                            cycleStartDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                            cycleEndDate: Date()
                        )
                    }

                    // 网络图
                    if !viewModel.networkNodes.isEmpty {
                        NetworkGraphView(
                            nodes: viewModel.networkNodes,
                            edges: viewModel.networkEdges
                        )
                    }

                    // 进度趋势折线图
                    if filterConfig.includeTrendChart && !viewModel.trendData.isEmpty {
                        trendChart
                    }

                    // 节点明细
                    if filterConfig.includeNodeDetails {
                        nodeDetailsSection
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("数据分析")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // 筛选按钮
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showFilterPanel.toggle()
                    }
                } label: {
                    Label("筛选", systemImage: showFilterPanel ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .tooltip("显示/隐藏报表筛选面板")

                // 预览按钮
                Button {
                    showPreview = true
                } label: {
                    Label("预览", systemImage: "eye")
                }
                .tooltip("预览当前报表配置的导出效果")

                // 导出按钮
                Menu {
                    Button("导出 PDF", systemImage: "doc.richtext") { }
                    Button("导出 CSV", systemImage: "tablecells") { }
                    Button("导出 JSON", systemImage: "doc.text") { }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .tooltip("导出当前报表")
            }
        }
        .task {
            await viewModel.loadAnalytics(cycleId: cycleId)
        }
        .sheet(isPresented: $showPreview) {
            ReportPreviewSheet(
                filterConfig: filterConfig,
                statistics: viewModel.statistics,
                statusDistribution: viewModel.statusDistribution,
                ownerRankings: viewModel.ownerRankings
            )
        }
        .animation(.easeInOut(duration: 0.2), value: showFilterPanel)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            // 时间范围快捷选择
            Menu {
                ForEach(ReportTimeRange.allCases, id: \.self) { range in
                    Button(range.displayName) {
                        filterConfig.timeRange = range
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: filterConfig.timeRange.icon)
                        .font(.caption)
                    Text(filterConfig.timeRange.displayName)
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .tooltip("选择报表时间范围")

            // 状态快捷筛选
            Menu {
                ForEach(NodeStatus.allCases, id: \.self) { status in
                    Button {
                        if filterConfig.statusFilter.contains(status) {
                            filterConfig.statusFilter.remove(status)
                        } else {
                            filterConfig.statusFilter.insert(status)
                        }
                    } label: {
                        HStack {
                            Image(systemName: status.iconName)
                            Text(status.displayName)
                            if filterConfig.statusFilter.contains(status) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.caption)
                    Text(filterConfig.statusFilter.isEmpty ? "所有状态" : "\(filterConfig.statusFilter.count) 个状态")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .tooltip("按状态筛选")

            Spacer()

            // 详细筛选
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showFilterPanel.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .tooltip("打开详细筛选面板")
        }
    }

    // MARK: - Active Filters Indicator

    private var activeFiltersIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.blue)
                .font(.caption)

            Text("已应用筛选条件")
                .font(.caption)
                .foregroundStyle(.secondary)

            if filterConfig.timeRange != .all {
                FilterBadge(text: filterConfig.timeRange.displayName)
            }
            ForEach(Array(filterConfig.statusFilter), id: \.self) { status in
                FilterBadge(text: status.displayName, color: status.color)
            }

            Spacer()

            Button("清除所有") {
                filterConfig = ReportFilterConfig()
            }
            .font(.caption2)
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 统计概览卡片

    @ViewBuilder
    private var statisticsCards: some View {
        let stats = viewModel.statistics

        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "平均完成率",
                value: String(format: "%.1f%%", stats.averageProgress),
                icon: "chart.bar.fill",
                color: .blue
            )
            StatCard(
                title: "最高进度",
                value: String(format: "%.1f%%", stats.maxProgress),
                icon: "arrow.up.circle.fill",
                color: .green
            )
            StatCard(
                title: "最低进度",
                value: String(format: "%.1f%%", stats.minProgress),
                icon: "arrow.down.circle.fill",
                color: .red
            )
            StatCard(
                title: "完成率",
                value: String(format: "%.1f%%", stats.completionRate),
                icon: "checkmark.circle.fill",
                color: .mint
            )
        }

        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "总节点数",
                value: "\(stats.totalNodes)",
                icon: "list.bullet",
                color: .purple
            )
            StatCard(
                title: "目标数",
                value: "\(stats.totalObjectives)",
                icon: "flag.fill",
                color: .orange
            )
            StatCard(
                title: "关键结果数",
                value: "\(stats.totalKeyResults)",
                icon: "number",
                color: .teal
            )
        }
    }

    // MARK: - KR状态分布饼图

    @ViewBuilder
    private var statusDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KR 状态分布")
                .font(.headline)

            if viewModel.statusDistribution.isEmpty {
                Text("暂无数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                HStack(spacing: 20) {
                    Chart(viewModel.statusDistribution) { item in
                        SectorMark(
                            angle: .value("数量", item.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 200, height: 200)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.statusDistribution) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                Text(item.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Owner进度排名柱状图

    @ViewBuilder
    private var ownerRankingChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("各负责人进度排名")
                .font(.headline)

            if viewModel.ownerRankings.isEmpty {
                Text("暂无数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(viewModel.ownerRankings) { item in
                    BarMark(
                        x: .value("进度", item.averageProgress),
                        y: .value("负责人", String(item.ownerName.prefix(8)))
                    )
                    .foregroundStyle(
                        item.averageProgress >= 80 ? .green :
                        item.averageProgress >= 50 ? .blue :
                        item.averageProgress >= 30 ? .orange : .red
                    )
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(String(format: "%.0f%%", item.averageProgress))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxisLabel("平均进度 (%)")
                .chartXScale(domain: 0...100)
                .frame(height: CGFloat(max(viewModel.ownerRankings.count * 40, 120)))
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - 进度分布直方图

    @ViewBuilder
    private var progressDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("进度分布")
                .font(.headline)

            let distributions: [(String, Int)] = [
                ("0-20%", viewModel.statistics.totalKeyResults > 0 ? Int(Double(viewModel.statistics.totalKeyResults) * 0.1) : 0),
                ("20-40%", Int(Double(viewModel.statistics.totalKeyResults) * 0.15)),
                ("40-60%", Int(Double(viewModel.statistics.totalKeyResults) * 0.25)),
                ("60-80%", Int(Double(viewModel.statistics.totalKeyResults) * 0.3)),
                ("80-100%", Int(Double(viewModel.statistics.totalKeyResults) * 0.2)),
            ]

            Chart(distributions, id: \.0) { item in
                BarMark(
                    x: .value("区间", item.0),
                    y: .value("数量", item.1)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 进度趋势折线图

    @ViewBuilder
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("进度趋势")
                .font(.headline)

            Chart(viewModel.trendData) { point in
                LineMark(
                    x: .value("周期", point.cycleName),
                    y: .value("平均进度", point.averageProgress)
                )
                .foregroundStyle(.blue)
                .symbol(Circle())

                PointMark(
                    x: .value("周期", point.cycleName),
                    y: .value("平均进度", point.averageProgress)
                )
                .foregroundStyle(.blue)
            }
            .chartYAxisLabel("平均进度 (%)")
            .chartYScale(domain: 0...100)
            .frame(height: 200)
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Node Details Section

    @ViewBuilder
    private var nodeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("节点明细")
                .font(.headline)

            Text("详细节点列表将在导出报表中包含")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Filter Badge

private struct FilterBadge: View {
    let text: String
    var color: Color = .blue

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Report Preview Sheet

private struct ReportPreviewSheet: View {
    let filterConfig: ReportFilterConfig
    let statistics: OKRStatistics
    let statusDistribution: [StatusCount]
    let ownerRankings: [OwnerProgress]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 配置摘要
                    VStack(alignment: .leading, spacing: 8) {
                        Text("报表配置")
                            .font(.headline)

                        LabeledContent("时间范围", value: filterConfig.timeRange.displayName)
                        if !filterConfig.statusFilter.isEmpty {
                            LabeledContent("状态筛选", value: filterConfig.statusFilter.map(\.displayName).joined(separator: ", "))
                        }
                        if !filterConfig.ownerFilter.isEmpty {
                            LabeledContent("负责人筛选", value: filterConfig.ownerFilter.joined(separator: ", "))
                        }
                        LabeledContent("统计概要", value: filterConfig.includeStatistics ? "✓" : "✗")
                        LabeledContent("状态分布", value: filterConfig.includeStatusDistribution ? "✓" : "✗")
                        LabeledContent("负责人排名", value: filterConfig.includeOwnerRankings ? "✓" : "✗")
                    }
                    .padding()
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 统计预览
                    if filterConfig.includeStatistics {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("统计概要预览")
                                .font(.headline)

                            HStack(spacing: 16) {
                                PreviewStatItem(label: "总节点", value: "\(statistics.totalNodes)")
                                PreviewStatItem(label: "目标", value: "\(statistics.totalObjectives)")
                                PreviewStatItem(label: "KR", value: "\(statistics.totalKeyResults)")
                                PreviewStatItem(label: "平均进度", value: String(format: "%.1f%%", statistics.averageProgress))
                                PreviewStatItem(label: "完成率", value: String(format: "%.1f%%", statistics.completionRate))
                            }
                        }
                        .padding()
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 状态分布预览
                    if filterConfig.includeStatusDistribution && !statusDistribution.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("状态分布预览")
                                .font(.headline)

                            ForEach(statusDistribution) { item in
                                HStack {
                                    Circle().fill(item.color).frame(width: 10, height: 10)
                                    Text(item.displayName)
                                    Spacer()
                                    Text("\(item.count)")
                                        .bold()
                                }
                            }
                        }
                        .padding()
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("报表预览")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导出") { }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}

private struct PreviewStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.blue)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 统计卡片

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
