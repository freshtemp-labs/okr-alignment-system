import SwiftUI

// MARK: - TreeView

/// The core tree visualization component that renders the entire OKR hierarchy.
///
/// `TreeView` displays the OKR tree structure with:
/// - A vertically scrollable container for the entire tree
/// - Root node centered at the top
/// - Recursive rendering of child node rows
/// - Visual connector lines between parent and child levels
/// - Smooth expand/collapse animations
///
/// The tree uses a recursive layout approach where each level of nodes is
/// rendered as a horizontal row, with connector lines drawn between levels.
///
/// ## Example
/// ```swift
/// TreeView(
///     rootNode: viewModel.rootNode,
///     onNodeTap: { node in /* handle selection */ },
///     onUpdateProgress: { id, delta in /* handle progress */ }
/// )
/// ```
public struct TreeView: View {
    // MARK: - Properties
    
    /// The root node of the OKR tree.
    let rootNode: OKRNode?
    
    /// Callback when a node is tapped.
    let onNodeTap: (OKRNode) -> Void
    
    /// Callback for leaf KR progress updates.
    let onUpdateProgress: ((UUID, Double) -> Void)?
    
    /// The set of currently expanded node IDs.
    @State private var expandedNodeIds: Set<UUID> = []
    
    /// Vertical spacing between tree levels.
    private let levelSpacing: CGFloat = 48
    
    /// Horizontal spacing between sibling nodes.
    private let nodeSpacing: CGFloat = 40
    
    // MARK: - Initialization
    
    /// Creates a new tree view.
    /// - Parameters:
    ///   - rootNode: The root node of the OKR tree (nil if no data).
    ///   - onNodeTap: Closure called when a node is tapped.
    ///   - onUpdateProgress: Optional closure for leaf KR progress updates.
    public init(
        rootNode: OKRNode?,
        onNodeTap: @escaping (OKRNode) -> Void,
        onUpdateProgress: ((UUID, Double) -> Void)? = nil
    ) {
        self.rootNode = rootNode
        self.onNodeTap = onNodeTap
        self.onUpdateProgress = onUpdateProgress
    }
    
    // MARK: - Body
    
    public var body: some View {
        ScrollView([.vertical, .horizontal]) {
            if let rootNode = rootNode {
                VStack(spacing: 0) {
                    // Root node card
                    OKRNodeCard(
                        node: rootNode,
                        isExpanded: Binding(
                            get: { expandedNodeIds.contains(rootNode.id) },
                            set: { isExpanded in
                                toggleNode(rootNode.id, isExpanded: isExpanded)
                            }
                        ),
                        onTap: { onNodeTap(rootNode) },
                        onUpdateProgress: onUpdateProgress
                    )
                    .padding(.bottom, levelSpacing)
                    
                    // Recursively render children
                    if expandedNodeIds.contains(rootNode.id) {
                        childTreeView(for: rootNode.children)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 600)
                .padding(40)
            } else {
                // Empty state handled by parent
                Color.clear
                    .frame(minWidth: 400, minHeight: 400)
            }
        }
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        .onAppear {
            // Auto-expand root node on first appearance
            if let rootNode = rootNode, expandedNodeIds.isEmpty {
                expandedNodeIds.insert(rootNode.id)
            }
        }
    }
    
    // MARK: - Child Tree Rendering
    
    /// Recursively renders a subtree starting from an array of sibling nodes.
    /// - Parameter nodes: The sibling nodes at this level.
    /// - Returns: A view containing the rendered subtree.
    private func childTreeView(for nodes: [OKRNode]) -> AnyView {
        if nodes.isEmpty {
            return AnyView(EmptyView())
        } else {
            return AnyView(VStack(spacing: 0) {
                // Connector lines from parent to this row
                TreeConnector(
                    childCount: nodes.count,
                    nodeSpacing: 280 + nodeSpacing, // card width + spacing
                    verticalGap: levelSpacing,
                    isExpanded: true
                )
                .frame(width: calculateRowWidth(for: nodes.count))
                
                // Node row
                TreeNodeRow(
                    nodes: nodes,
                    expandedNodeIds: $expandedNodeIds,
                    onNodeTap: onNodeTap,
                    onUpdateProgress: onUpdateProgress
                )
                .padding(.top, levelSpacing)
                
                // Recursively render grandchildren for each expanded node
                ForEach(nodes) { node in
                    if expandedNodeIds.contains(node.id) && !node.children.isEmpty {
                        childTreeView(for: node.children)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .padding(.top, levelSpacing)
                    }
                }
            })
        }
    }
    
    // MARK: - Helpers
    
    /// Toggles a node's expansion state.
    /// - Parameters:
    ///   - nodeId: The ID of the node to toggle.
    ///   - isExpanded: The desired expansion state.
    private func toggleNode(_ nodeId: UUID, isExpanded: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if isExpanded {
                expandedNodeIds.insert(nodeId)
            } else {
                expandedNodeIds.remove(nodeId)
            }
        }
    }
    
    /// Calculates the total width needed for a row with the given number of nodes.
    /// - Parameter count: The number of nodes in the row.
    /// - Returns: The calculated width.
    private func calculateRowWidth(for count: Int) -> CGFloat {
        let cardWidth: CGFloat = 280
        return CGFloat(count) * cardWidth + CGFloat(count - 1) * nodeSpacing + 80 // padding
    }
}

// MARK: - Preview Helpers

private func makeTreeNode(
    title: String,
    nodeType: NodeType,
    scope: Scope,
    progress: Double,
    ownerName: String,
    children: [OKRNode] = []
) -> OKRNode {
    OKRNode(
        id: UUID(),
        title: title,
        nodeDescription: nil,
        nodeType: nodeType,
        scope: scope,
        currentValue: nodeType == .keyResult ? progress : 0,
        targetValue: nodeType == .keyResult ? 100 : 0,
        unit: nodeType == .keyResult ? "%" : nil,
        progress: progress,
        status: .inProgress,
        ownerName: ownerName,
        sortOrder: 0,
        parentId: nil,
        children: children,
        cycleId: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
}

// MARK: - Previews

// --- Preview block commented out for SPM build ---
// #Preview("Simple Tree - 2 Levels") {
//     let root = makeTreeNode(
//         title: "Q4 Company Objective",
//         nodeType: .objective,
//         scope: .enterprise,
//         progress: 65.0,
//         ownerName: "CEO",
//         children: [
//             makeTreeNode(title: "Increase revenue by 30%", nodeType: .keyResult, scope: .personal, progress: 80.0, ownerName: "Sales Lead"),
//             makeTreeNode(title: "Launch 3 new features", nodeType: .keyResult, scope: .personal, progress: 50.0, ownerName: "Product Mgr"),
//             makeTreeNode(title: "Reduce churn to 5%", nodeType: .keyResult, scope: .personal, progress: 65.0, ownerName: "CS Lead")
//         ]
//     )
//     
//     TreeView(
//         rootNode: root,
//         onNodeTap: { _ in },
//         onUpdateProgress: { _, _ in }
//     )
// }

// --- Preview block commented out for SPM build ---
// #Preview("Deep Tree - 3 Levels") {
//     let level3 = [
//         makeTreeNode(title: "Sub-KR A1", nodeType: .keyResult, scope: .personal, progress: 75, ownerName: "Engineer 1"),
//         makeTreeNode(title: "Sub-KR A2", nodeType: .keyResult, scope: .personal, progress: 60, ownerName: "Engineer 2")
//     ]
//     
//     let level2 = [
//         makeTreeNode(title: "Launch Feature X", nodeType: .objective, scope: .personal, progress: 70, ownerName: "Team A", children: level3),
//         makeTreeNode(title: "Launch Feature Y", nodeType: .keyResult, scope: .personal, progress: 45, ownerName: "Team B"),
//         makeTreeNode(title: "Launch Feature Z", nodeType: .keyResult, scope: .personal, progress: 90, ownerName: "Team C")
//     ]
//     
//     let root = makeTreeNode(
//         title: "Annual Product Goal",
//         nodeType: .objective,
//         scope: .enterprise,
//         progress: 68.0,
//         ownerName: "CTO",
//         children: level2
//     )
//     
//     TreeView(
//         rootNode: root,
//         onNodeTap: { _ in },
//         onUpdateProgress: { _, _ in }
//     )
// }

// --- Preview block commented out for SPM build ---
// #Preview("No Root Node") {
//     TreeView(
//         rootNode: nil,
//         onNodeTap: { _ in },
//         onUpdateProgress: nil
//     )
// }

// --- Preview block commented out for SPM build ---
// #Preview("Single Root Only") {
//     let root = makeTreeNode(
//         title: "Standalone Objective",
//         nodeType: .objective,
//         scope: .enterprise,
//         progress: 50.0,
//         ownerName: "Director"
//     )
//     
//     TreeView(
//         rootNode: root,
//         onNodeTap: { _ in },
//         onUpdateProgress: nil
//     )
// }
