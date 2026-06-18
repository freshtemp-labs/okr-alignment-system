import SwiftUI

// MARK: - NodeDetailView

/// A dedicated detail panel for displaying comprehensive OKR node information.
///
/// `NodeDetailView` presents all metadata for a selected node:
/// - Type badge and scope badge
/// - Title and description
/// - Owner information
/// - Animated color-coded progress bar
/// - Child nodes list with individual progress bars
/// - Creation and update timestamps
/// - Edit button to jump to edit form
///
/// ## Example
/// ```swift
/// NodeDetailView(
///     node: selectedNode,
///     onEdit: { node in /* open edit form */ },
///     onDismiss: { /* close panel */ }
/// )
/// ```
public struct NodeDetailView: View {
    // MARK: - Properties

    /// The OKR node to display details for.
    let node: OKRNode

    /// Callback to open the edit form for this node.
    let onEdit: (OKRNode) -> Void

    /// Callback to dismiss/close the detail panel.
    let onDismiss: () -> Void

    // MARK: - Constants

    private let sectionLabelColor = Color.secondaryText
    private let textColor = Color.primaryText

    // MARK: - Initialization

    public init(
        node: OKRNode,
        onEdit: @escaping (OKRNode) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.node = node
        self.onEdit = onEdit
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Close button header
            HStack {
                Text("Details")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(sectionLabelColor)
                    .tracking(0.5)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(sectionLabelColor)
                }
                .buttonStyle(.plain)
                .help("Close detail panel")
                .accessibilityLabel("Close detail panel")
                .accessibilityHint("Closes the node detail view")
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(Color.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Type and scope badges
                    HStack {
                        NodeTypeLabel(nodeType: node.nodeType)
                        Spacer()
                        ScopeBadge(ownerName: node.ownerName, scope: node.scope)
                    }

                    // Title
                    Text(node.title)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()
                        .background(Color.divider)

                    // Description
                    if let desc = node.nodeDescription, !desc.isEmpty {
                        sectionHeader("Description")
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundStyle(textColor)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()
                            .background(Color.divider)
                    }

                    // Owner
                    sectionHeader("Owner")
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                            .accessibilityHidden(true)
                        Text(node.ownerName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                    }

                    Divider()
                        .background(Color.divider)

                    // Progress section with color indicator
                    sectionHeader("Progress")

                    AnimatedProgressIndicator(
                        progress: node.progress,
                        scope: node.scope,
                        nodeType: node.nodeType
                    )

                    HStack {
                        Text(node.valueDisplayString)
                            .font(.system(size: 12))
                            .foregroundStyle(sectionLabelColor)
                        Spacer()
                        Text(node.progressPercentage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                    }

                    // Children progress list
                    if !node.children.isEmpty {
                        Divider()
                            .background(Color.divider)

                        sectionHeader("Children (\(node.children.count))")

                        VStack(spacing: 8) {
                            ForEach(node.children) { child in
                                childProgressRow(child)
                            }
                        }
                    }

                    // Details grid
                    Divider()
                        .background(Color.divider)

                    sectionHeader("Details")

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        DetailItem(title: "Status", value: statusDisplayName(node.status))
                        DetailItem(title: "Scope", value: node.scope == .enterprise ? "Enterprise" : "Personal")
                        DetailItem(title: "Type", value: node.nodeType == .objective ? "Objective" : "Key Result")
                        DetailItem(title: "Children", value: "\(node.children.count)")
                    }

                    // Timestamps
                    Divider()
                        .background(Color.divider)

                    sectionHeader("Timestamps")

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(sectionLabelColor)
                                .frame(width: 16)
                                .accessibilityHidden(true)
                            Text("Created: \(formattedDate(node.createdAt))")
                                .font(.system(size: 11))
                                .foregroundStyle(sectionLabelColor)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                                .foregroundStyle(sectionLabelColor)
                                .frame(width: 16)
                                .accessibilityHidden(true)
                            Text("Updated: \(formattedDate(node.updatedAt))")
                                .font(.system(size: 11))
                                .foregroundStyle(sectionLabelColor)
                        }
                    }

                    Spacer(minLength: 20)

                    // 评论区域
                    Divider()
                        .background(Color.divider)

                    CommentListView(
                        nodeId: node.id,
                        currentUserName: RoleManager.shared.currentUserName,
                        availableUsers: extractAllOwners(from: node)
                    )
                    .onAppear {
                        // Comments will load on appear
                    }

                    Spacer(minLength: 20)
                }
                .padding(20)
            }

            Divider()
                .background(Color.divider)

            // Edit button
            Button {
                onEdit(node)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                    Text("Edit Node")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(red: 147/255, green: 197/255, blue: 253/255))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .accessibilityLabel("Edit \(node.title)")
            .accessibilityHint("Opens the edit form for this node")
            .keyboardShortcut("e", modifiers: .command)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Detail panel for \(node.title)")
    }

    // MARK: - Subviews

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(sectionLabelColor)
            .tracking(0.5)
    }

    /// A row showing a child node's name and progress bar.
    @ViewBuilder
    private func childProgressRow(_ child: OKRNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(child.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                Spacer()
                Text(child.progressPercentage)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primaryText)
            }

            AnimatedProgressIndicator(
                progress: child.progress,
                scope: child.scope,
                nodeType: child.nodeType
            )
        }
        .padding(10)
        .background(Color.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(child.title), \(child.progressPercentage) complete")
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func statusDisplayName(_ status: NodeStatus) -> String {
        switch status {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .atRisk: return "At Risk"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    /// 从节点树中提取所有Owner名称
    private func extractAllOwners(from node: OKRNode) -> [String] {
        var owners = Set<String>()
        func walk(_ n: OKRNode) {
            owners.insert(n.ownerName)
            for child in n.children {
                walk(child)
            }
        }
        walk(node)
        return Array(owners).sorted()
    }
}

// MARK: - DetailItem (Shared)

/// A small key-value display component for the detail panel.
struct DetailItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.secondaryText)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
