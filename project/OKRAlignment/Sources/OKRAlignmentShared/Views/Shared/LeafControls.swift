import SwiftUI

// MARK: - LeafControls

/// Control buttons for adjusting leaf key result progress values.
///
/// `LeafControls` provides "-10%" and "+10%" buttons that appear when hovering
/// over a leaf KR node card. The buttons allow quick progress adjustments with
/// built-in boundary protection (values cannot go below 0 or exceed target).
///
/// The controls fade in on hover with a smooth opacity animation.
///
/// ## Example
/// ```swift
/// LeafControls(
///     node: leafNode,
///     onUpdate: { id, delta in await viewModel.updateLeafProgress(nodeId: id, delta: delta) }
/// )
/// ```
public struct LeafControls: View {
    // MARK: - Properties
    
    /// The leaf KR node being controlled.
    let node: OKRNode
    
    /// Callback invoked when the user taps a control button.
    /// Parameters: node ID and delta value to apply.
    let onUpdate: (UUID, Double) -> Void
    
    /// Whether the controls are visible (controlled by parent hover state).
    var isVisible: Bool = true
    
    // MARK: - Initialization
    
    /// Creates new leaf controls.
    /// - Parameters:
    ///   - node: The leaf key result node.
    ///   - isVisible: Whether controls should be visible.
    ///   - onUpdate: Callback for progress updates.
    public init(
        node: OKRNode,
        isVisible: Bool = true,
        onUpdate: @escaping (UUID, Double) -> Void
    ) {
        self.node = node
        self.isVisible = isVisible
        self.onUpdate = onUpdate
    }
    
    // MARK: - Computed Properties
    
    /// Whether the decrement button should be disabled.
    private var canDecrement: Bool {
        node.currentValue > 0
    }
    
    /// Whether the increment button should be disabled.
    private var canIncrement: Bool {
        node.currentValue < node.targetValue
    }
    
    /// The decrement delta, clamped to not go below 0.
    private var decrementDelta: Double {
        let rawDelta = -node.targetValue * 0.1
        let newValue = node.currentValue + rawDelta
        if newValue < 0 {
            return -node.currentValue
        }
        return rawDelta
    }
    
    /// The increment delta, clamped to not exceed target.
    private var incrementDelta: Double {
        let rawDelta = node.targetValue * 0.1
        let newValue = node.currentValue + rawDelta
        if newValue > node.targetValue {
            return node.targetValue - node.currentValue
        }
        return rawDelta
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 8) {
            Button {
                guard canDecrement else { return }
                onUpdate(node.id, decrementDelta)
            } label: {
                Text("-10%")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(canDecrement ? .white : .gray)
                    .frame(width: 48, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(canDecrement ? 0.12 : 0.04))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)
            .help("Decrease progress by 10%")
            .accessibilityLabel("Decrease progress by 10 percent")
            .accessibilityHint(canDecrement ? "Current value: \(Int(node.currentValue)). Tap to decrease." : "Already at minimum value")
            .accessibilityAction(named: "Decrease Progress") {
                if canDecrement {
                    onUpdate(node.id, decrementDelta)
                }
            }
            
            Button {
                guard canIncrement else { return }
                onUpdate(node.id, incrementDelta)
            } label: {
                Text("+10%")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(canIncrement ? .white : .gray)
                    .frame(width: 48, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(canIncrement ? 0.12 : 0.04))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canIncrement)
            .help("Increase progress by 10%")
            .accessibilityLabel("Increase progress by 10 percent")
            .accessibilityHint(canIncrement ? "Current value: \(Int(node.currentValue)). Tap to increase." : "Already at target value")
            .accessibilityAction(named: "Increase Progress") {
                if canIncrement {
                    onUpdate(node.id, incrementDelta)
                }
            }
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Progress adjustment controls for \(node.title)")
        .accessibilityValue("Current: \(Int(node.currentValue)) of \(Int(node.targetValue)) \(node.unit ?? "")")
    }
}

// MARK: - Previews

// --- Preview block commented out for SPM build ---
// #Preview("Visible Controls") {
//     let sampleNode = OKRNode(
//         id: UUID(),
//         title: "Sample KR",
//         nodeDescription: nil,
//         nodeType: .keyResult,
//         scope: .personal,
//         currentValue: 50,
//         targetValue: 100,
//         unit: "%",
//         progress: 50.0,
//         status: .inProgress,
//         ownerName: "Alice",
//         createdAt: Date(),
//         updatedAt: Date(),
//         sortOrder: 0,
//         parentId: nil,
//         children: [],
//         cycleId: nil
//     )
//     
//     LeafControls(node: sampleNode, isVisible: true) { _, _ in }
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Hidden Controls") {
//     let sampleNode = OKRNode(
//         id: UUID(),
//         title: "Sample KR",
//         nodeDescription: nil,
//         nodeType: .keyResult,
//         scope: .personal,
//         currentValue: 50,
//         targetValue: 100,
//         unit: "%",
//         progress: 50.0,
//         status: .inProgress,
//         ownerName: "Alice",
//         createdAt: Date(),
//         updatedAt: Date(),
//         sortOrder: 0,
//         parentId: nil,
//         children: [],
//         cycleId: nil
//     )
//     LeafControls(node: sampleNode, isVisible: false) { _, _ in }
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("At Zero - Decrement Disabled") {
//     let zeroNode = OKRNode(
//         id: UUID(),
//         title: "Zero Progress KR",
//         nodeDescription: nil,
//         nodeType: .keyResult,
//         scope: .enterprise,
//         currentValue: 0,
//         targetValue: 100,
//         unit: nil,
//         progress: 0.0,
//         status: .notStarted,
//         ownerName: "Bob",
//         createdAt: Date(),
//         updatedAt: Date(),
//         sortOrder: 0,
//         parentId: nil,
//         children: [],
//         cycleId: nil
//     )
//     
//     LeafControls(node: zeroNode, isVisible: true) { _, _ in }
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }
