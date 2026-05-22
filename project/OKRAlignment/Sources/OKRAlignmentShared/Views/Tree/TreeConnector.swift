import SwiftUI

// MARK: - TreeConnectorShape

/// A custom Shape that draws the connecting lines between parent and child nodes in the tree.
///
/// `TreeConnectorShape` draws:
/// - A vertical line from the parent node down to the child row level
/// - Horizontal lines connecting sibling nodes at the same level
/// - T-junction connections where the vertical line splits to each child
///
/// The shape adapts its geometry based on the number of children and available width.
struct TreeConnectorShape: Shape {
    /// The number of child nodes that need to be connected.
    let childCount: Int
    
    /// The spacing between each child node center.
    let nodeSpacing: CGFloat
    
    /// The vertical distance from parent bottom to child row top.
    let verticalGap: CGFloat
    
    /// Creates a tree connector shape.
    /// - Parameters:
    ///   - childCount: Number of children to connect.
    ///   - nodeSpacing: Horizontal spacing between node centers.
    ///   - verticalGap: Vertical distance from parent to children.
    init(childCount: Int, nodeSpacing: CGFloat = 320, verticalGap: CGFloat = 48) {
        self.childCount = childCount
        self.nodeSpacing = nodeSpacing
        self.verticalGap = verticalGap
    }
    
    func path(in rect: CGRect) -> Path {
        guard childCount > 0 else { return Path() }
        
        var path = Path()
        
        let startX = rect.midX
        let startY = CGFloat(0)
        let midY = verticalGap / 2
        let endY = verticalGap
        
        // Single child: simple vertical line
        if childCount == 1 {
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: startX, y: endY))
            return path
        }
        
        // Multiple children: T-shaped connector
        // Calculate horizontal span
        let totalWidth = CGFloat(childCount - 1) * nodeSpacing
        let leftX = startX - totalWidth / 2
        let rightX = startX + totalWidth / 2
        
        // Vertical line from parent down to midpoint
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: startX, y: midY))
        
        // Horizontal line spanning all children
        path.addLine(to: CGPoint(x: leftX, y: midY))
        path.move(to: CGPoint(x: startX, y: midY))
        path.addLine(to: CGPoint(x: rightX, y: midY))
        
        // Vertical drops from horizontal line to each child
        for i in 0..<childCount {
            let childX = leftX + CGFloat(i) * nodeSpacing
            path.move(to: CGPoint(x: childX, y: midY))
            path.addLine(to: CGPoint(x: childX, y: endY))
        }
        
        return path
    }
}

// MARK: - TreeConnector

/// A view that renders the connecting lines between a parent node and its children.
///
/// `TreeConnector` uses the custom `TreeConnectorShape` to draw elegant 2px lines
/// that visually link parent and child nodes in the tree hierarchy. The lines are
/// semi-transparent white, creating a subtle but clear visual connection.
///
/// The connector only appears when there is at least one child node.
///
/// ## Example
/// ```swift
/// TreeConnector(childCount: 3, nodeSpacing: 320)
/// ```
public struct TreeConnector: View {
    // MARK: - Properties
    
    /// The number of child nodes to connect.
    let childCount: Int
    
    /// Horizontal spacing between node centers.
    let nodeSpacing: CGFloat
    
    /// Vertical distance from parent bottom to child row top.
    let verticalGap: CGFloat
    
    /// Whether the parent node is expanded (controls visibility).
    let isExpanded: Bool
    
    // MARK: - Initialization
    
    /// Creates a new tree connector.
    /// - Parameters:
    ///   - childCount: Number of children to connect.
    ///   - nodeSpacing: Horizontal spacing between node centers (default: 320).
    ///   - verticalGap: Vertical distance from parent to children (default: 48).
    ///   - isExpanded: Whether the parent is expanded and children are visible.
    public init(
        childCount: Int,
        nodeSpacing: CGFloat = 320,
        verticalGap: CGFloat = 48,
        isExpanded: Bool = true
    ) {
        self.childCount = childCount
        self.nodeSpacing = nodeSpacing
        self.verticalGap = verticalGap
        self.isExpanded = isExpanded
    }
    
    // MARK: - Body
    
    public var body: some View {
        if childCount > 0 && isExpanded {
            TreeConnectorShape(
                childCount: childCount,
                nodeSpacing: nodeSpacing,
                verticalGap: verticalGap
            )
            .stroke(Color.white.opacity(0.25), lineWidth: 2)
            .frame(height: verticalGap)
            .animation(.easeInOut(duration: 0.3), value: isExpanded)
            .animation(.easeInOut(duration: 0.3), value: childCount)
        }
    }
}

// MARK: - Previews

#Preview("Single Child Connector") {
    TreeConnector(childCount: 1, isExpanded: true)
        .frame(width: 280)
        .padding()
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}

#Preview("Three Children Connector") {
    TreeConnector(childCount: 3, nodeSpacing: 320, isExpanded: true)
        .frame(width: 960)
        .padding()
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}

#Preview("Five Children Connector") {
    TreeConnector(childCount: 5, nodeSpacing: 300, isExpanded: true)
        .frame(width: 1500)
        .padding()
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}

#Preview("Collapsed (Hidden)") {
    TreeConnector(childCount: 3, isExpanded: false)
        .frame(width: 280)
        .padding()
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}
