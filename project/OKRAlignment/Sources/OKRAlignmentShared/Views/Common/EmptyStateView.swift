import SwiftUI

// MARK: - EmptyStateView

/// A view displayed when no OKR data is available, prompting the user to create their first OKR.
///
/// `EmptyStateView` presents a friendly, visually appealing empty state with:
/// - A centered icon representing goal setting
/// - A descriptive headline and subtitle
/// - A prominent call-to-action button to create the first OKR
///
/// This view is shown when the tree has no root node or when a cycle has no OKRs.
///
/// ## Example
/// ```swift
/// EmptyStateView(
///     title: "No OKRs Yet",
///     subtitle: "Create your first objective to get started",
///     iconName: "target",
///     actionTitle: "Create OKR",
///     onAction: { showCreateForm = true }
/// )
/// ```
public struct EmptyStateView: View {
    // MARK: - Properties
    
    /// The main headline text.
    let title: String
    
    /// The descriptive subtitle text.
    let subtitle: String
    
    /// The SF Symbol name for the icon.
    let iconName: String
    
    /// The title for the action button.
    let actionTitle: String
    
    /// Callback when the action button is tapped.
    let onAction: () -> Void
    
    /// Whether an action is currently in progress.
    let isLoading: Bool
    
    // MARK: - Initialization
    
    /// Creates a new empty state view.
    /// - Parameters:
    ///   - title: The headline text (default: "No OKRs Yet").
    ///   - subtitle: The descriptive text (default: "Create your first objective to start tracking goals").
    ///   - iconName: SF Symbol name (default: "flag.fill").
    ///   - actionTitle: Button label (default: "Create First OKR").
    ///   - isLoading: Whether the action is loading (default: false).
    ///   - onAction: Closure called when the action button is tapped.
    public init(
        title: String = "No OKRs Yet",
        subtitle: String = "Create your first objective to start tracking goals",
        iconName: String = "flag.fill",
        actionTitle: String = "Create First OKR",
        isLoading: Bool = false,
        onAction: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.actionTitle = actionTitle
        self.isLoading = isLoading
        self.onAction = onAction
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 100, height: 100)
                
                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 59/255, green: 130/255, blue: 246/255),
                                Color(red: 139/255, green: 92/255, blue: 246/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .accessibilityHidden(true)
            
            // Title
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(.white)
            
            // Subtitle
            Text(subtitle)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            // Action button
            Button {
                onAction()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 37/255, green: 99/255, blue: 235/255),
                                    Color(red: 59/255, green: 130/255, blue: 246/255)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .padding(.top, 8)
            .accessibilityLabel("\(actionTitle) button")
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Previews

#Preview("Default Empty State") {
    EmptyStateView {
        print("Create tapped")
    }
}

#Preview("Custom Empty State") {
    EmptyStateView(
        title: "No Cycle Selected",
        subtitle: "Select a cycle from the sidebar or create a new one to view OKRs",
        iconName: "calendar.badge.clock",
        actionTitle: "Create New Cycle",
        onAction: {}
    )
}

#Preview("Loading State") {
    EmptyStateView(
        title: "Loading...",
        subtitle: "Preparing your workspace",
        iconName: "arrow.clockwise.circle.fill",
        actionTitle: "Please Wait",
        isLoading: true,
        onAction: {}
    )
}

#Preview("After Deletion") {
    EmptyStateView(
        title: "All OKRs Deleted",
        subtitle: "Your cycle is now empty. Create a new OKR to start fresh.",
        iconName: "trash.slash.fill",
        actionTitle: "Create OKR",
        onAction: {}
    )
}
