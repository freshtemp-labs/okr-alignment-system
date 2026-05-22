import SwiftUI

// MARK: - HeatmapView

/// 热力图视图
/// 展示各Owner的进度分布，颜色深浅表示进度高低
/// 行表示Owner，列表示状态维度
public struct HeatmapView: View {

    // MARK: - Properties

    /// 热力图数据
    let data: [HeatmapRow]

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(.purple)
                Text("负责人进度分布（热力图）")
                    .font(.headline)
            }

            if data.isEmpty {
                Text("暂无数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(spacing: 0) {
                    // 表头
                    HStack(spacing: 2) {
                        Text("负责人")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)
                        ForEach(HeatmapColumn.allCases, id: \.self) { column in
                            Text(column.shortName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 6)

                    // 数据行
                    ForEach(data) { row in
                        heatmapRow(row)
                    }

                    // 颜色图例
                    HStack(spacing: 8) {
                        Text("低")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .green, .green.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 100, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("高")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
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
    private func heatmapRow(_ row: HeatmapRow) -> some View {
        HStack(spacing: 2) {
            Text(String(row.ownerName.prefix(10)))
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            ForEach(HeatmapColumn.allCases, id: \.self) { column in
                let value = row.value(for: column)
                heatmapCell(value: value, column: column)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func heatmapCell(value: Double, column: HeatmapColumn) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(cellColor(value: value, column: column))
            .frame(height: 32)
            .overlay {
                Text(cellText(value: value, column: column))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(value > 50 ? .white : .primary)
            }
    }

    private func cellColor(value: Double, column: HeatmapColumn) -> Color {
        switch column {
        case .progress:
            if value >= 80 { return .green.opacity(0.8) }
            if value >= 50 { return .blue.opacity(0.6) }
            if value >= 30 { return .orange.opacity(0.5) }
            return .red.opacity(0.4)
        case .completedRate:
            return .green.opacity(min(0.9, max(0.1, value / 100)))
        case .atRiskRate:
            if value > 50 { return .red.opacity(0.7) }
            if value > 25 { return .orange.opacity(0.6) }
            return .gray.opacity(0.3)
        case .krCount:
            let normalized = min(1.0, value / 10)
            return .purple.opacity(max(0.15, normalized * 0.8))
        }
    }

    private func cellText(value: Double, column: HeatmapColumn) -> String {
        switch column {
        case .progress:
            return String(format: "%.0f%%", value)
        case .completedRate:
            return String(format: "%.0f%%", value)
        case .atRiskRate:
            return String(format: "%.0f%%", value)
        case .krCount:
            return "\(Int(value))"
        }
    }
}

// MARK: - HeatmapColumn

/// 热力图列维度
public enum HeatmapColumn: String, CaseIterable, Sendable {
    case progress = "progress"
    case completedRate = "completed"
    case atRiskRate = "at_risk"
    case krCount = "kr_count"

    public var shortName: String {
        switch self {
        case .progress: return "平均进度"
        case .completedRate: return "完成率"
        case .atRiskRate: return "风险率"
        case .krCount: return "KR数"
        }
    }
}

// MARK: - HeatmapRow Model

/// 热力图行数据
public struct HeatmapRow: Identifiable, Sendable {
    public let id: UUID
    public let ownerName: String
    public let averageProgress: Double
    public let completedRate: Double
    public let atRiskRate: Double
    public let krCount: Int

    public init(
        id: UUID = UUID(),
        ownerName: String,
        averageProgress: Double,
        completedRate: Double,
        atRiskRate: Double,
        krCount: Int
    ) {
        self.id = id
        self.ownerName = ownerName
        self.averageProgress = averageProgress
        self.completedRate = completedRate
        self.atRiskRate = atRiskRate
        self.krCount = krCount
    }

    public func value(for column: HeatmapColumn) -> Double {
        switch column {
        case .progress: return averageProgress
        case .completedRate: return completedRate
        case .atRiskRate: return atRiskRate
        case .krCount: return Double(krCount)
        }
    }
}
