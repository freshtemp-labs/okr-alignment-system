import SwiftUI

// MARK: - NodeTypeLabel

/// A small uppercase label indicating whether a node is an Objective or Key Result.
///
/// `NodeTypeLabel` displays the node type in a compact format:
/// - "OBJECTIVE" in muted gray (#94A3B8)
/// - "KEY RESULT" in emerald green (#10B981)
///
/// The label uses small font size with letter spacing for a refined appearance.
///
/// ## Example
/// ```swift
/// NodeTypeLabel(nodeType: .objective)
/// ```
public struct NodeTypeLabel: View {
    // MARK: - Properties
    
    /// The type of the node to display.
    let nodeType: NodeType
    
    // MARK: - Initialization
    
    /// Creates a new node type label.
    /// - Parameter nodeType: The type (objective or key result).
    public init(nodeType: NodeType) {
        self.nodeType = nodeType
    }
    
    // MARK: - Computed Properties
    
    /// The display text for the node type.
    private var displayText: String {
        switch nodeType {
        case .objective:
            return "OBJECTIVE"
        case .keyResult:
            return "KEY RESULT"
        }
    }
    
    /// The color for the node type label.
    private var labelColor: Color {
        switch nodeType {
        case .objective:
            return Color(red: 148/255, green: 163/255, blue: 184/255)
        case .keyResult:
            return Color(red: 16/255, green: 185/255, blue: 129/255)
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        Text(displayText)
            .font(.system(size: 10, weight: .semibold, design: .default))
            .foregroundStyle(labelColor)
            .tracking(1)
            .accessibilityLabel(displayText)
    }
}

// MARK: - Previews

#Preview("Objective Label") {
    NodeTypeLabel(nodeType: .objective)
        .padding()
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}

#Preview("Key Result Label") {
    NodeTypeLabel(nodeType: .keyResult)
        .padding()
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}
