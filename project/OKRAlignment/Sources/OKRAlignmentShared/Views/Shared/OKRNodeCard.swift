import SwiftUI

// MARK: - OKRNodeCard

/// The primary card component for displaying an OKR node in the tree visualization.
///
/// `OKRNodeCard` presents a comprehensive view of an OKR node including:
/// - A colored top border indicating scope (gold=enterprise, blue=personal)
/// - Owner badge in the top-right corner
/// - Node type label (OBJECTIVE / KEY RESULT)
/// - Node title
/// - Animated progress bar with scope-appropriate coloring
/// - Value statistics at the bottom
/// - Leaf KR adjustment controls (visible on hover for leaf nodes)
///
/// The card features hover effects (subtle lift and shadow enhancement) and
/// supports tap-to-toggle expansion for parent nodes.
///
/// ## Example
/// ```swift
/// OKRNodeCard(
///     node: myNode,
///     isExpanded: $isExpanded,
///     onTap: { /* handle tap */ },
///     onUpdateProgress: { id, delta in /* handle progress update */ }
/// )
/// ```
public struct OKRNodeCard: View {
    // MARK: - Properties
    
    /// The OKR node to display.
    let node: OKRNode
    
    /// Whether the node's children are currently expanded.
    @Binding var isExpanded: Bool
    
    /// Callback when the card is tapped.
    let onTap: () -> Void
    
    /// Callback for progress updates on leaf KR nodes.
    let onUpdateProgress: ((UUID, Double) -> Void)?
    
    /// Whether the user is currently hovering over this card.
    @State private var isHovered: Bool = false
    
    // MARK: - Constants
    
    private let cardWidth: CGFloat = 280
    private let topBorderHeight: CGFloat = 4
    
    // MARK: - Initialization
    
    /// Creates a new OKR node card.
    /// - Parameters:
    ///   - node: The OKR node to display.
    ///   - isExpanded: Binding controlling expansion state.
    ///   - onTap: Closure called when the card is tapped.
    ///   - onUpdateProgress: Optional closure for leaf KR progress updates.
    public init(
        node: OKRNode,
        isExpanded: Binding<Bool>,
        onTap: @escaping () -> Void,
        onUpdateProgress: ((UUID, Double) -> Void)? = nil
    ) {
        self.node = node
        self._isExpanded = isExpanded
        self.onTap = onTap
        self.onUpdateProgress = onUpdateProgress
    }
    
    // MARK: - Computed Properties
    
    /// The top border color based on node scope.
    private var scopeBorderColor: Color {
        switch node.scope {
        case .enterprise:
            return Color(red: 234/255, green: 179/255, blue: 8/255)
        case .personal:
            return Color(red: 59/255, green: 130/255, blue: 246/255)
        }
    }
    
    /// The card's background color.
    private var cardBackground: Color {
        Color(red: 30/255, green: 41/255, blue: 59/255)
    }
    
    /// The shadow color for hover state.
    private var hoverShadow: Color {
        scopeBorderColor.opacity(0.3)
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top colored border
            scopeBorderColor
                .frame(height: topBorderHeight)
            
            // Card content
            VStack(alignment: .leading, spacing: 10) {
                // Header row: type label + scope badge
                HStack {
                    NodeTypeLabel(nodeType: node.nodeType)
                    Spacer()
                    ScopeBadge(ownerName: node.ownerName, scope: node.scope)
                }
                
                // Title
                Text(node.title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress bar
                ProgressBar(
                    progress: node.progress,
                    scope: node.scope,
                    nodeType: node.nodeType
                )
                
                // Bottom stats row
                HStack {
                    Text(node.valueDisplayString)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                    
                    Spacer()
                    
                    Text(node.progressPercentage)
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                }
                
                // Leaf controls (only for leaf KR nodes, visible on hover)
                if node.isLeaf, onUpdateProgress != nil {
                    HStack {
                        Spacer()
                        LeafControls(
                            node: node,
                            isVisible: isHovered,
                            onUpdate: onUpdateProgress!
                        )
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                
                // Expand/collapse indicator for nodes with children
                if !node.children.isEmpty {
                    HStack {
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
        }
        .frame(width: cardWidth)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        // Hover effects
        .shadow(
            color: isHovered ? hoverShadow : .clear,
            radius: isHovered ? 12 : 0,
            x: 0,
            y: isHovered ? 4 : 0
        )
        .offset(y: isHovered ? -2 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        // Interactions
        .onTapGesture {
            if !node.children.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
            onTap()
        }
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(node.nodeType == .objective ? "Objective" : "Key Result"): \(node.title), progress \(node.progressPercentage)")
        .accessibilityHint(node.children.isEmpty ? "" : "Double tap to \(isExpanded ? "collapse" : "expand") children")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview Helpers

private func makeSampleNode(
    title: String,
    nodeType: NodeType,
    scope: Scope,
    currentValue: Double,
    targetValue: Double,
    unit: String?,
    progress: Double,
    status: NodeStatus,
    ownerName: String,
    children: [OKRNode] = []
) -> OKRNode {
    OKRNode(
        id: UUID(),
        title: title,
        nodeDescription: nil,
        nodeType: nodeType,
        scope: scope,
        currentValue: currentValue,
        targetValue: targetValue,
        unit: unit,
        progress: progress,
        status: status,
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
// #Preview("Enterprise Objective") {
//     @Previewable @State var expanded = true
//     
//     let node = makeSampleNode(
//         title: "Increase Q4 Revenue by 25%",
//         nodeType: .objective,
//         scope: .enterprise,
//         currentValue: 0,
//         targetValue: 0,
//         unit: nil,
//         progress: 68.5,
//         status: .inProgress,
//         ownerName: "Alice Chen",
//         children: [makeSampleNode(title: "Child", nodeType: .keyResult, scope: .enterprise, currentValue: 50, targetValue: 100, unit: "%", progress: 50, status: .inProgress, ownerName: "Bob")]
//     )
//     
//     OKRNodeCard(
//         node: node,
//         isExpanded: $expanded,
//         onTap: {},
//         onUpdateProgress: nil
//     )
//     .padding()
//     .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Personal Key Result") {
//     @Previewable @State var expanded = false
//     
//     let node = makeSampleNode(
//         title: "Launch new onboarding flow",
//         nodeType: .keyResult,
//         scope: .personal,
//         currentValue: 3,
//         targetValue: 5,
//         unit: "features",
//         progress: 60.0,
//         status: .inProgress,
//         ownerName: "Bob Smith"
//     )
//     
//     OKRNodeCard(
//         node: node,
//         isExpanded: $expanded,
//         onTap: {},
//         onUpdateProgress: { _, _ in }
//     )
//     .padding()
//     .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Completed Leaf KR") {
//     @Previewable @State var expanded = false
//     
//     let node = makeSampleNode(
//         title: "Reduce customer churn to 5%",
//         nodeType: .keyResult,
//         scope: .enterprise,
//         currentValue: 100,
//         targetValue: 100,
//         unit: "%",
//         progress: 100.0,
//         status: .completed,
//         ownerName: "Carol Lee"
//     )
//     
//     OKRNodeCard(
//         node: node,
//         isExpanded: $expanded,
//         onTap: {},
//         onUpdateProgress: { _, _ in }
//     )
//     .padding()
//     .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("At Risk Objective") {
//     @Previewable @State var expanded = true
//     
//     let node = makeSampleNode(
//         title: "Expand to European markets",
//         nodeType: .objective,
//         scope: .enterprise,
//         currentValue: 0,
//         targetValue: 0,
//         unit: nil,
//         progress: 23.0,
//         status: .atRisk,
//         ownerName: "David Park",
//         children: [
//             makeSampleNode(title: "KR1", nodeType: .keyResult, scope: .enterprise, currentValue: 10, targetValue: 100, unit: "%", progress: 10, status: .atRisk, ownerName: "Team A"),
//             makeSampleNode(title: "KR2", nodeType: .keyResult, scope: .personal, currentValue: 35, targetValue: 100, unit: "%", progress: 35, status: .inProgress, ownerName: "Team B")
//         ]
//     )
//     
//     OKRNodeCard(
//         node: node,
//         isExpanded: $expanded,
//         onTap: {},
//         onUpdateProgress: nil
//     )
//     .padding()
//     .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }
