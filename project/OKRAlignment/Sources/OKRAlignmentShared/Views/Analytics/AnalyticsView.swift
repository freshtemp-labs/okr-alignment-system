import SwiftUI
import Charts

// MARK: - AnalyticsView

/// 数据分析视图
/// ============
/// 展示OKR数据的可视化分析报表，包括：
/// - KR状态分布饼图
/// - Owner进度排名柱状图
/// - 进度趋势折线图（多周期）
/// - 整体统计指标卡片
///
public struct AnalyticsView: View {

    // MARK: - 属性

    /// 分析ViewModel
    @Bindable var viewModel: AnalyticsViewModel

    /// 当前周期ID
    let cycleId: UUID?

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
                    // 统计概览卡片
                    statisticsCards

                    // KR状态分布饼图
                    statusDistributionChart

                    // Owner进度排名柱状图
                    ownerRankingChart

                    // 进度趋势折线图
                    if !viewModel.trendData.isEmpty {
                        trendChart
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("数据分析")
        .task {
            await viewModel.loadAnalytics(cycleId: cycleId)
        }
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
