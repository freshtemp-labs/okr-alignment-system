// OKRAlignmentShared/Views/Tree/VirtualizedTreeView.swift

import SwiftUI

/// 虚拟化树视图
/// =============
/// 针对大型 OKR 树（100+ 节点）优化的树视图组件。
///
/// # 优化策略
/// - 使用 LazyVStack 替代 VStack，只渲染可见节点
/// - 实现节点虚拟化（只渲染可见区域的节点）
/// - 平铺化树结构，减少递归深度
/// - 使用 id 稳定的 ForEach 避免不必要的重绘
///
/// # 使用场景
/// 当 OKR 树节点数超过阈值（默认 100）时自动启用。
/// 对于小型树，仍使用原始 TreeView 获得更好的动画效果。
public struct VirtualizedTreeView: View {

    // MARK: - Properties

    /// 根节点
    let rootNode: OKRNode?

    /// 节点点击回调
    let onNodeTap: (OKRNode) -> Void

    /// 进度更新回调
    let onUpdateProgress: ((UUID, Double) -> Void)?

    /// 展开的节点 ID 集合
    @State private var expandedNodeIds: Set<UUID> = []

    /// 平铺后的可见节点列表
    @State private var flattenedNodes: [FlattenedNode] = []

    /// 是否正在重建节点列表
    @State private var isRebuilding = false

    // MARK: - Types

    /// 平铺后的节点表示
    struct FlattenedNode: Identifiable {
        let id: UUID
        let node: OKRNode
        let depth: Int
        let isLastChild: Bool
        let hasChildren: Bool
    }

    // MARK: - Constants

    private let nodeSpacing: CGFloat = 12
    private let indentWidth: CGFloat = 24
    private let rebuildThreshold = 100

    // MARK: - Body

    public init(
        rootNode: OKRNode?,
        onNodeTap: @escaping (OKRNode) -> Void,
        onUpdateProgress: ((UUID, Double) -> Void)? = nil
    ) {
        self.rootNode = rootNode
        self.onNodeTap = onNodeTap
        self.onUpdateProgress = onUpdateProgress
    }

    public var body: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(spacing: nodeSpacing) {
                ForEach(flattenedNodes) { flatNode in
                    virtualizedNodeRow(flatNode)
                        .transition(.opacity)
                }
            }
            .padding(24)
            .frame(minWidth: 600, minHeight: 400)
        }
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        .onAppear {
            rebuildFlattenedNodes()
        }
        .onChange(of: expandedNodeIds) { _, _ in
            rebuildFlattenedNodes()
        }
        .onChange(of: rootNode?.id) { _, _ in
            rebuildFlattenedNodes()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Virtualized OKR tree with \(flattenedNodes.count) visible nodes")
    }

    // MARK: - Node Row Builder

    @ViewBuilder
    private func virtualizedNodeRow(_ flatNode: FlattenedNode) -> some View {
        HStack(spacing: 0) {
            // Indentation
            if flatNode.depth > 0 {
                HStack(spacing: 0) {
                    ForEach(0..<flatNode.depth, id: \.self) { level in
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 1)
                            .padding(.leading, indentWidth / 2)
                    }
                }
                .frame(width: CGFloat(flatNode.depth) * indentWidth)
            }

            // Node card (simplified for performance)
            LightweightNodeCard(
                node: flatNode.node,
                isExpanded: Binding(
                    get: { expandedNodeIds.contains(flatNode.id) },
                    set: { isExpanded in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedNodeIds.insert(flatNode.id)
                            } else {
                                expandedNodeIds.remove(flatNode.id)
                            }
                        }
                    }
                ),
                onTap: { onNodeTap(flatNode.node) },
                onUpdateProgress: onUpdateProgress
            )
        }
    }

    // MARK: - Flatten Tree

    /// 将树结构平铺为线性列表（只包含可见节点）
    private func rebuildFlattenedNodes() {
        guard let root = rootNode else {
            flattenedNodes = []
            return
        }

        isRebuilding = true
        var result: [FlattenedNode] = []

        flattenNode(root, depth: 0, isLast: true, into: &result)
        flattenedNodes = result
        isRebuilding = false
    }

    private func flattenNode(
        _ node: OKRNode,
        depth: Int,
        isLast: Bool,
        into result: inout [FlattenedNode]
    ) {
        let flatNode = FlattenedNode(
            id: node.id,
            node: node,
            depth: depth,
            isLastChild: isLast,
            hasChildren: !node.children.isEmpty
        )
        result.append(flatNode)

        // 只有展开的节点才渲染子节点
        if expandedNodeIds.contains(node.id) {
            for (index, child) in node.children.enumerated() {
                flattenNode(
                    child,
                    depth: depth + 1,
                    isLast: index == node.children.count - 1,
                    into: &result
                )
            }
        }
    }
}

// MARK: - Lightweight Node Card

/// 轻量级节点卡片（用于虚拟化树视图）
/// 相比 OKRNodeCard，减少了动画和装饰效果以提升性能
public struct LightweightNodeCard: View {

    let node: OKRNode
    @Binding var isExpanded: Bool
    let onTap: () -> Void
    let onUpdateProgress: ((UUID, Double) -> Void)?

    private let cardWidth: CGFloat = 260

    private var scopeBorderColor: Color {
        node.scope == .enterprise
            ? Color(red: 234/255, green: 179/255, blue: 8/255)
            : Color(red: 59/255, green: 130/255, blue: 246/255)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top border
            scopeBorderColor
                .frame(height: 3)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Type + Owner
                HStack {
                    Text(node.nodeType == .objective ? "OBJ" : "KR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(scopeBorderColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(scopeBorderColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer()

                    Text(node.ownerName)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                        .lineLimit(1)
                }

                // Title
                Text(node.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                // Progress
                HStack(spacing: 6) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                            Capsule()
                                .fill(scopeBorderColor)
                                .frame(width: geo.size.width * (node.progress / 100))
                        }
                    }
                    .frame(height: 4)

                    Text(node.progressPercentage)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, alignment: .trailing)
                }

                // Value display
                Text(node.valueDisplayString)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))

                // Leaf controls
                if node.isLeaf, let onUpdate = onUpdateProgress {
                    HStack {
                        Spacer()
                        Button {
                            onUpdate(node.id, -10)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onUpdate(node.id, 10)
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }

                // Expand indicator
                if !node.children.isEmpty {
                    HStack {
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                        Spacer()
                    }
                }
            }
            .padding(10)
        }
        .frame(width: cardWidth)
        .background(Color(red: 30/255, green: 41/255, blue: 59/255))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onTapGesture {
            if !node.children.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(node.nodeType == .objective ? "Objective" : "Key Result"): \(node.title)")
        .accessibilityValue("\(node.progressPercentage) progress")
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview("Virtualized Tree") {
    let root = OKRNode(
        title: "Company Objective",
        nodeType: .objective,
        scope: .enterprise,
        targetValue: 100,
        status: .inProgress,
        ownerName: "CEO",
        children: (0..<5).map { i in
            OKRNode(
                title: "Key Result \(i + 1)",
                nodeType: .keyResult,
                scope: .enterprise,
                currentValue: Double(i * 20),
                targetValue: 100,
                unit: "%",
                status: .inProgress,
                ownerName: "Team \(i + 1)"
            )
        }
    )

    VirtualizedTreeView(
        rootNode: root,
        onNodeTap: { _ in },
        onUpdateProgress: nil
    )
}
#endif
