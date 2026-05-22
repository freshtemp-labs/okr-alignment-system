import SwiftUI
import Charts

// MARK: - GanttChartView

/// 甘特图视图
/// 展示OKR节点的时间线，包括开始/结束日期和进度
/// 使用SwiftUI Charts框架实现水平条形图模拟甘特图效果
public struct GanttChartView: View {

    // MARK: - Properties

    /// 甘特图数据项
    let items: [GanttItem]

    /// 周期开始日期
    let cycleStartDate: Date

    /// 周期结束日期
    let cycleEndDate: Date

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(.blue)
                Text("OKR 时间线（甘特图）")
                    .font(.headline)
            }

            if items.isEmpty {
                Text("暂无数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // 时间轴标题
                    HStack {
                        Text("")
                            .frame(width: 120, alignment: .leading)
                        Spacer()
                        dateAxisLabels
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    // 甘特条
                    ForEach(items) { item in
                        ganttRow(item)
                    }

                    // 图例
                    HStack(spacing: 16) {
                        legendItem(color: .blue, label: "计划时间")
                        legendItem(color: .green, label: "已完成")
                        legendItem(color: .orange, label: "进行中")
                        legendItem(color: .red, label: "有风险")
                    }
                    .font(.caption2)
                    .padding(.top, 8)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var dateAxisLabels: some View {
        let totalDays = max(Calendar.current.dateComponents([.day], from: cycleStartDate, to: cycleEndDate).day ?? 1, 1)
        HStack {
            ForEach(0..<min(5, totalDays), id: \.self) { i in
                let fraction = Double(i) / Double(max(4, totalDays - 1))
                let date = Calendar.current.date(byAdding: .day, value: Int(fraction * Double(totalDays)), to: cycleStartDate) ?? cycleStartDate
                Text(shortDate(date))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func ganttRow(_ item: GanttItem) -> some View {
        let totalDays = max(Calendar.current.dateComponents([.day], from: cycleStartDate, to: cycleEndDate).day ?? 1, 1)

        HStack(spacing: 8) {
            // 节点名称（截断）
            Text(String(item.title.prefix(12)))
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            // 甘特条区域
            GeometryReader { geo in
                let barStart = max(0, Double(Calendar.current.dateComponents([.day], from: cycleStartDate, to: item.actualStartDate).day ?? 0) / Double(totalDays))
                let barEnd = min(1, Double(Calendar.current.dateComponents([.day], from: cycleStartDate, to: item.actualEndDate).day ?? 0) / Double(totalDays))
                let barWidth = max(barEnd - barStart, 0.02)

                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 20)

                    // 计划时间条（浅色）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.statusColor.opacity(0.3))
                        .frame(width: geo.size.width * barWidth, height: 20)
                        .offset(x: geo.size.width * barStart)

                    // 进度填充（深色）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.statusColor)
                        .frame(width: geo.size.width * barWidth * (item.progress / 100), height: 20)
                        .offset(x: geo.size.width * barStart)

                    // 进度百分比
                    Text(String(format: "%.0f%%", item.progress))
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                        .offset(x: geo.size.width * barStart + 4)
                }
            }
            .frame(height: 20)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - GanttItem Model

/// 甘特图数据项
public struct GanttItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let actualStartDate: Date
    public let actualEndDate: Date
    public let progress: Double
    public let status: NodeStatus

    public var statusColor: Color {
        switch status {
        case .completed: return .green
        case .inProgress: return .blue
        case .atRisk: return .orange
        case .notStarted: return .gray
        case .cancelled: return .red.opacity(0.6)
        }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        actualStartDate: Date,
        actualEndDate: Date,
        progress: Double,
        status: NodeStatus
    ) {
        self.id = id
        self.title = title
        self.actualStartDate = actualStartDate
        self.actualEndDate = actualEndDate
        self.progress = progress
        self.status = status
    }
}
