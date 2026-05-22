import SwiftUI

// MARK: - NetworkGraphView

/// 网络图视图
/// 展示OKR节点之间的对齐关系（父→子、对齐链接）
/// 使用Canvas绘制节点和连线
public struct NetworkGraphView: View {

    // MARK: - Properties

    /// 网络图节点
    let nodes: [NetworkNode]

    /// 网络图边（连线）
    let edges: [NetworkEdge]

    /// 当前选中的节点
    @State private var selectedNodeId: UUID?

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(.teal)
                Text("对齐关系网络图")
                    .font(.headline)
            }

            if nodes.isEmpty {
                Text("暂无数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                ZStack {
                    // 背景
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))

                    Canvas { context, size in
                        drawGraph(context: context, size: size)
                    }
                    .frame(height: 350)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let location = value.location
                                selectedNodeId = findNode(at: location, in: nodes, size: CGSize(width: 350, height: 350))
                            }
                    )

                    // 选中节点的提示
                    if let selectedId = selectedNodeId,
                       let node = nodes.first(where: { $0.id == selectedId }) {
                        VStack {
                            Spacer()
                            nodeInfoCard(node)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .frame(height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Drawing

    private func drawGraph(context: GraphicsContext, size: CGSize) {
        let padding: CGFloat = 30
        let drawableSize = CGSize(
            width: size.width - padding * 2,
            height: size.height - padding * 2
        )

        // Draw edges first (behind nodes)
        for edge in edges {
            guard let fromNode = nodes.first(where: { $0.id == edge.fromId }),
                  let toNode = nodes.first(where: { $0.id == edge.toId }) else { continue }

            let fromPoint = CGPoint(
                x: padding + fromNode.normalizedX * drawableSize.width,
                y: padding + fromNode.normalizedY * drawableSize.height
            )
            let toPoint = CGPoint(
                x: padding + toNode.normalizedX * drawableSize.width,
                y: padding + toNode.normalizedY * drawableSize.height
            )

            var path = Path()
            path.move(to: fromPoint)
            // Use a curved line for parent-child relationships
            let midY = (fromPoint.y + toPoint.y) / 2
            path.addCurve(
                to: toPoint,
                control1: CGPoint(x: fromPoint.x, y: midY),
                control2: CGPoint(x: toPoint.x, y: midY)
            )

            context.stroke(path, with: .color(edge.color.opacity(0.6)), lineWidth: 1.5)

            // Draw arrow head at target
            let arrowSize: CGFloat = 6
            let angle = atan2(toPoint.y - midY, toPoint.x - toPoint.x == 0 ? 0.001 : (toPoint.x - toPoint.x))
            var arrowPath = Path()
            arrowPath.move(to: toPoint)
            arrowPath.addLine(to: CGPoint(
                x: toPoint.x - arrowSize * cos(angle - .pi / 6),
                y: toPoint.y - arrowSize * sin(angle - .pi / 6)
            ))
            arrowPath.move(to: toPoint)
            arrowPath.addLine(to: CGPoint(
                x: toPoint.x - arrowSize * cos(angle + .pi / 6),
                y: toPoint.y - arrowSize * sin(angle + .pi / 6)
            ))
            context.stroke(arrowPath, with: .color(edge.color.opacity(0.8)), lineWidth: 1.5)
        }

        // Draw nodes
        for node in nodes {
            let center = CGPoint(
                x: padding + node.normalizedX * drawableSize.width,
                y: padding + node.normalizedY * drawableSize.height
            )
            let nodeSize = node.nodeType == .objective
                ? CGSize(width: 60, height: 30)
                : CGSize(width: 54, height: 24)
            let isSelected = selectedNodeId == node.id

            let rect = CGRect(
                x: center.x - nodeSize.width / 2,
                y: center.y - nodeSize.height / 2,
                width: nodeSize.width,
                height: nodeSize.height
            )

            // Node background
            let roundedRect = Path(roundedRect: rect, cornerRadius: 8)
            context.fill(roundedRect, with: .color(node.color.opacity(isSelected ? 0.9 : 0.6)))

            // Node border
            if isSelected {
                context.stroke(roundedRect, with: .color(.white), lineWidth: 2)
            } else {
                context.stroke(roundedRect, with: .color(node.color.opacity(0.8)), lineWidth: 1)
            }

            // Progress indicator
            let progressWidth = rect.width * (node.progress / 100)
            let progressRect = CGRect(
                x: rect.minX,
                y: rect.maxY - 3,
                width: progressWidth,
                height: 3
            )
            context.fill(Path(roundedRect: progressRect, cornerRadius: 1), with: .color(.white.opacity(0.7)))

            // Node label
            let label = String(node.title.prefix(6))
            let text = Text(label).font(.caption2).foregroundColor(.white)
            context.draw(
                text,
                at: CGPoint(x: center.x, y: center.y),
                anchor: .center
            )
        }
    }

    // MARK: - Helpers

    private func findNode(at point: CGPoint, in nodes: [NetworkNode], size: CGSize) -> UUID? {
        let padding: CGFloat = 30
        let drawableSize = CGSize(
            width: size.width - padding * 2,
            height: size.height - padding * 2
        )

        for node in nodes {
            let center = CGPoint(
                x: padding + node.normalizedX * drawableSize.width,
                y: padding + node.normalizedY * drawableSize.height
            )
            let hitRadius: CGFloat = 25
            let dx = point.x - center.x
            let dy = point.y - center.y
            if sqrt(dx * dx + dy * dy) < hitRadius {
                return node.id
            }
        }
        return nil
    }

    @ViewBuilder
    private func nodeInfoCard(_ node: NetworkNode) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(node.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(node.nodeType.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(node.ownerName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", node.progress))
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
                }
            }

            Spacer()

            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .onTapGesture { selectedNodeId = nil }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - NetworkNode Model

/// 网络图节点
public struct NetworkNode: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let nodeType: NodeType
    public let ownerName: String
    public let progress: Double
    public let normalizedX: CGFloat  // 0.0 - 1.0
    public let normalizedY: CGFloat  // 0.0 - 1.0

    public var color: Color {
        switch nodeType {
        case .objective:
            return .orange
        case .keyResult:
            return .blue
        }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        nodeType: NodeType,
        ownerName: String,
        progress: Double,
        normalizedX: CGFloat,
        normalizedY: CGFloat
    ) {
        self.id = id
        self.title = title
        self.nodeType = nodeType
        self.ownerName = ownerName
        self.progress = progress
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
    }
}

// MARK: - NetworkEdge Model

/// 网络图边
public struct NetworkEdge: Identifiable, Sendable {
    public let id: UUID
    public let fromId: UUID
    public let toId: UUID
    public let color: Color

    public init(id: UUID = UUID(), fromId: UUID, toId: UUID, color: Color = .gray) {
        self.id = id
        self.fromId = fromId
        self.toId = toId
        self.color = color
    }
}
