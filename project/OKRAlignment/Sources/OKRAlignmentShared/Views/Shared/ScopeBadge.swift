import SwiftUI

// MARK: - ScopeBadge

/// A pill-shaped badge that displays the owner name with a scope-indicating color.
///
/// `ScopeBadge` appears in the top-right corner of OKR node cards. It shows
/// the owner's name with a border color that indicates the node's scope:
/// - Gold border for enterprise-level nodes
/// - Blue border for personal nodes
///
/// The badge has a dark background with subtle transparency, making it
/// visually distinct without overwhelming the card content.
///
/// ## Example
/// ```swift
/// ScopeBadge(ownerName: "Alice Chen", scope: .enterprise)
/// ```
public struct ScopeBadge: View {
    // MARK: - Properties
    
    /// The name of the node owner to display.
    let ownerName: String
    
    /// The scope that determines the badge's border color.
    let scope: Scope
    
    // MARK: - Initialization
    
    /// Creates a new scope badge.
    /// - Parameters:
    ///   - ownerName: The display name of the node owner.
    ///   - scope: The scope (enterprise or personal).
    public init(ownerName: String, scope: Scope) {
        self.ownerName = ownerName
        self.scope = scope
    }
    
    // MARK: - Computed Properties
    
    /// The border color based on scope.
    private var borderColor: Color {
        switch scope {
        case .enterprise:
            return Color(red: 234/255, green: 179/255, blue: 8/255)
        case .personal:
            return Color(red: 59/255, green: 130/255, blue: 246/255)
        }
    }
    
    /// The text color based on scope.
    private var textColor: Color {
        switch scope {
        case .enterprise:
            return Color(red: 250/255, green: 204/255, blue: 21/255)
        case .personal:
            return Color(red: 147/255, green: 197/255, blue: 253/255)
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        Text(ownerName)
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(red: 30/255, green: 41/255, blue: 59/255))
            )
            .overlay(
                Capsule()
                    .strokeBorder(borderColor.opacity(0.5), lineWidth: 1)
            )
            .accessibilityLabel("Owner: \(ownerName), \(scope == .enterprise ? "Enterprise" : "Personal") scope")
    }
}

// MARK: - Previews

// --- Preview block commented out for SPM build ---
// #Preview("Enterprise Scope Badge") {
//     ScopeBadge(ownerName: "Alice Chen", scope: .enterprise)
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Personal Scope Badge") {
//     ScopeBadge(ownerName: "Bob Smith", scope: .personal)
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Long Name Badge") {
//     ScopeBadge(ownerName: "Christopher Alexander", scope: .enterprise)
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }
