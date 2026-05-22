import SwiftUI

// MARK: - DeleteConfirmView

/// A confirmation dialog for deleting OKR nodes with cascade delete option.
///
/// `DeleteConfirmView` presents a modal that warns users about the implications
/// of deleting a node and provides an optional cascade delete toggle. When cascade
/// delete is enabled, all child nodes will be removed along with the selected node.
///
/// The view includes:
/// - A warning icon and title
/// - Descriptive message about deletion impact
/// - Cascade delete toggle switch
/// - Cancel and Delete action buttons
///
/// ## Example
/// ```swift
/// DeleteConfirmView(
///     nodeTitle: "Q4 Revenue Objective",
///     hasChildren: true,
///     onCancel: { dismiss() },
///     onConfirm: { cascade in
///         await viewModel.deleteNode(id: nodeId, cascade: cascade)
///     }
/// )
/// ```
public struct DeleteConfirmView: View {
    // MARK: - Properties
    
    /// The title of the node being deleted (displayed for context).
    let nodeTitle: String
    
    /// Whether the node has child nodes (controls cascade delete visibility).
    let hasChildren: Bool
    
    /// Callback when the user cancels the deletion.
    let onCancel: () -> Void
    
    /// Callback when the user confirms deletion. Parameter indicates cascade mode.
    let onConfirm: (Bool) -> Void
    
    /// Whether cascade delete is enabled.
    @State private var cascadeDelete: Bool = false
    
    /// Whether a deletion operation is in progress.
    @State private var isDeleting: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a new delete confirmation view.
    /// - Parameters:
    ///   - nodeTitle: The title of the node being deleted.
    ///   - hasChildren: Whether the node has children (shows cascade option).
    ///   - onCancel: Closure called when cancelled.
    ///   - onConfirm: Closure called with cascade flag when confirmed.
    public init(
        nodeTitle: String,
        hasChildren: Bool,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (Bool) -> Void
    ) {
        self.nodeTitle = nodeTitle
        self.hasChildren = hasChildren
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 20) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(red: 234/255, green: 179/255, blue: 8/255))
                .accessibilityHidden(true)
            
            // Title
            Text("Confirm Deletion")
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundStyle(.white)
            
            // Description
            VStack(spacing: 8) {
                Text("Are you sure you want to delete \"\(nodeTitle)\"?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 203/255, green: 213/255, blue: 225/255))
                    .multilineTextAlignment(.center)
                
                if hasChildren {
                    Text("This node has \(cascadeDelete ? "children that will also be" : "child nodes that will remain in the tree") deleted.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 360)
            
            // Cascade delete toggle (only for nodes with children)
            if hasChildren {
                Toggle(isOn: $cascadeDelete) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete all children")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        Text("Remove this node and all its descendants")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 239/255, green: 68/255, blue: 68/255)))
                .frame(maxWidth: 360)
                .accessibilityLabel("Cascade delete toggle")
                .accessibilityValue(cascadeDelete ? "Enabled" : "Disabled")
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 100, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel deletion")
                
                Button {
                    isDeleting = true
                    onConfirm(cascadeDelete)
                } label: {
                    HStack(spacing: 6) {
                        if isDeleting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text("Delete")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(minWidth: 100, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 239/255, green: 68/255, blue: 68/255))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
                .accessibilityLabel("Confirm deletion")
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(minWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 30/255, green: 41/255, blue: 59/255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Previews

#Preview("With Children - Cascade Option") {
    DeleteConfirmView(
        nodeTitle: "Q4 Company Objective",
        hasChildren: true,
        onCancel: {},
        onConfirm: { _ in }
    )
    .padding()
    .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}

#Preview("Leaf Node - No Children") {
    DeleteConfirmView(
        nodeTitle: "Reduce churn to 5%",
        hasChildren: false,
        onCancel: {},
        onConfirm: { _ in }
    )
    .padding()
    .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}

#Preview("Long Title") {
    DeleteConfirmView(
        nodeTitle: "Increase quarterly revenue by 50% through new market expansion in Southeast Asia",
        hasChildren: true,
        onCancel: {},
        onConfirm: { _ in }
    )
    .padding()
    .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}
