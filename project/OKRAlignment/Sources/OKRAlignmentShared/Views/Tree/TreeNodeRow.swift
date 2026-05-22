import SwiftUI

// MARK: - TreeNodeRow

/// A horizontal row of OKR nodes representing siblings at the same tree level.
///
/// `TreeNodeRow` arranges a group of sibling nodes horizontally with consistent
/// spacing between each node. Each node in the row is rendered as an `OKRNodeCard`
/// with its own expansion state and interaction handlers.
///
/// The row maintains a fixed spacing of 40px between node cards and centers
/// the group within the available horizontal space.
///
/// ## Example
/// ```swift
/// TreeNodeRow(
///     nodes: siblingNodes,
///     expandedNodeIds: $expandedIds,
///     onNodeTap: { node in /* handle tap */ },
///     onUpdateProgress: { id, delta in /* handle update */ }
/// )
/// ```
public struct TreeNodeRow: View {
    // MARK: - Properties
    
    /// The array of sibling nodes to display in this row.
    let nodes: [OKRNode]
    
    /// Binding to the set of currently expanded node IDs.
    @Binding var expandedNodeIds: Set<UUID>
    
    /// Callback when a node card is tapped.
    let onNodeTap: (OKRNode) -> Void
    
    /// Callback for leaf KR progress updates.
    let onUpdateProgress: ((UUID, Double) -> Void)?
    
    /// Horizontal spacing between node cards.
    private let nodeSpacing: CGFloat = 40
    
    // MARK: - Initialization
    
    /// Creates a new tree node row.
    /// - Parameters:
    ///   - nodes: The sibling nodes to display.
    ///   - expandedNodeIds: Binding to the set of expanded node IDs.
    ///   - onNodeTap: Closure called when a node is tapped.
    ///   - onUpdateProgress: Optional closure for leaf KR progress updates.
    public init(
        nodes: [OKRNode],
        expandedNodeIds: Binding<Set<UUID>>,
        onNodeTap: @escaping (OKRNode) -> Void,
        onUpdateProgress: ((UUID, Double) -> Void)? = nil
    ) {
        self.nodes = nodes
        self._expandedNodeIds = expandedNodeIds
        self.onNodeTap = onNodeTap
        self.onUpdateProgress = onUpdateProgress
    }
    
    // MARK: - Computed Properties
    
    /// Summary description for accessibility.
    private var nodeSummary: String {
        let types = nodes.map { $0.nodeType == .objective ? "Objective" : "Key Result" }
        let titles = nodes.map { $0.title }
        return "Tree level with \(nodes.count) \(nodes.count == 1 ? "node" : "nodes"): \(titles.joined(separator: ", "))"
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: nodeSpacing) {
            ForEach(nodes) { node in
                OKRNodeCard(
                    node: node,
                    isExpanded: Binding(
                        get: { expandedNodeIds.contains(node.id) },
                        set: { isExpanded in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isExpanded {
                                    expandedNodeIds.insert(node.id)
                                } else {
                                    expandedNodeIds.remove(node.id)
                                }
                            }
                        }
                    ),
                    onTap: { onNodeTap(node) },
                    onUpdateProgress: onUpdateProgress
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.8))
                ))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, nodeSpacing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(nodeSummary)
        .accessibilityHint("Contains \(nodes.count) sibling nodes at the same level")
    }
}

// MARK: - Preview Helpers

private func makeSampleNode(
    id: UUID,
    title: String,
    nodeType: NodeType,
    scope: Scope,
    progress: Double,
    ownerName: String,
    children: [OKRNode] = []
) -> OKRNode {
    OKRNode(
        id: id,
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
// #Preview("Single Node Row") {
//     @Previewable @State var expanded: Set<UUID> = []
//     
//     let nodes = [
//         makeSampleNode(
//             id: UUID(),
//             title: "Increase Revenue",
//             nodeType: .objective,
//             scope: .enterprise,
//             progress: 75.0,
//             ownerName: "Alice"
//         )
//     ]
//     
//     TreeNodeRow(
//         nodes: nodes,
//         expandedNodeIds: $expanded,
//         onNodeTap: { _ in },
//         onUpdateProgress: nil
//     )
//     .padding()
//     .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Three Nodes Row") {
//     @Previewable @State var expanded: Set<UUID> = []
//     
//     let nodes = [
//         makeSampleNode(
//             id: UUID(),
//             title: "Increase Revenue",
//             nodeType: .objective,
//             scope: .enterprise,
//             progress: 75.0,
//             ownerName: "Alice"
//         ),
//         makeSampleNode(
//             id: UUID(),
//             title: "Improve Retention",
//             nodeType: .keyResult,
//             scope: .personal,
//             progress: 45.0,
//             ownerName: "Bob"
//         ),
//         makeSampleNode(
//             id: UUID(),
//             title: "Launch Product",
//             nodeType: .keyResult,
//             scope: .enterprise,
//             progress: 90.0,
//             ownerName: "Carol"
//         )
//     ]
//     
//     TreeNodeRow(
//         nodes: nodes,
//         expandedNodeIds: $expanded,
//         onNodeTap: { _ in },
//         onUpdateProgress: nil
//     )
//     .padding()
//     .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Mixed Types Row with Expansion") {
//     @Previewable @State var expanded: Set<UUID> = [UUID()]
//     
//     let parentId = expanded.first!
//     let nodes = [
//         makeSampleNode(
//             id: parentId,
//             title: "Q4 Growth Objective",
//             nodeType: .objective,
//             scope: .enterprise,
//             progress: 60.0,
//             ownerName: "Alice",
//             children: [
//                 makeSampleNode(id: UUID(), title: "KR1", nodeType: .keyResult, scope: .personal, progress: 50, ownerName: "Team A"),
//                 makeSampleNode(id: UUID(), title: "KR2", nodeType: .keyResult, scope: .personal, progress: 70, ownerName: "Team B")
//             ]
//         ),
//         makeSampleNode(
//             id: UUID(),
//             title: "Standalone KR",
//             nodeType: .keyResult,
//             scope: .personal,
//             progress: 80.0,
//             ownerName: "Bob"
//         )
//     ]
//     
//     TreeNodeRow(
//         nodes: nodes,
//         expandedNodeIds: $expanded,
//         onNodeTap: { _ in },
//         onUpdateProgress: { _, _ in }
//     )
//     .padding()
//     .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }
