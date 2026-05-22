import SwiftUI

// MARK: - ProgressBar

/// A reusable progress bar component that visualizes OKR completion percentage.
///
/// `ProgressBar` displays a horizontal bar with a fill amount proportional to
/// the progress value. The bar's color adapts based on the node's scope and type:
/// - Enterprise nodes use a gold/yellow gradient
/// - Personal objectives use a blue-purple gradient
/// - Leaf key results use an emerald green gradient
///
/// The fill width animates smoothly when the progress value changes.
///
/// ## Example
/// ```swift
/// ProgressBar(progress: 65.0, scope: .enterprise, nodeType: .objective)
/// ```
public struct ProgressBar: View {
    // MARK: - Properties
    
    /// The current progress value, ranging from 0.0 to 100.0.
    let progress: Double
    
    /// The scope of the node, determining the bar's color scheme.
    let scope: Scope
    
    /// The type of the node (objective or key result), affecting color selection.
    let nodeType: NodeType
    
    // MARK: - Initialization
    
    /// Creates a new progress bar.
    /// - Parameters:
    ///   - progress: The progress percentage (0.0 - 100.0).
    ///   - scope: The node's scope (enterprise or personal).
    ///   - nodeType: The node's type (objective or key result).
    public init(progress: Double, scope: Scope, nodeType: NodeType) {
        self.progress = progress
        self.scope = scope
        self.nodeType = nodeType
    }
    
    // MARK: - Computed Properties
    
    /// The gradient used to fill the progress bar based on scope and type.
    private var progressGradient: LinearGradient {
        if nodeType == .keyResult {
            return LinearGradient(
                colors: [
                    Color(red: 5/255, green: 150/255, blue: 105/255),
                    Color(red: 16/255, green: 185/255, blue: 129/255)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        
        switch scope {
        case .enterprise:
            return LinearGradient(
                colors: [
                    Color(red: 202/255, green: 138/255, blue: 4/255),
                    Color(red: 234/255, green: 179/255, blue: 8/255)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .personal:
            return LinearGradient(
                colors: [
                    Color(red: 37/255, green: 99/255, blue: 235/255),
                    Color(red: 139/255, green: 92/255, blue: 246/255)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    /// The background color of the unfilled portion.
    private var trackColor: Color {
        Color.white.opacity(0.08)
    }
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track (unfilled background)
                RoundedRectangle(cornerRadius: 3)
                    .fill(trackColor)
                
                // Fill (progress indicator)
                RoundedRectangle(cornerRadius: 3)
                    .fill(progressGradient)
                    .frame(width: max(0, min(CGFloat(progress / 100.0) * geometry.size.width, geometry.size.width)))
            }
            .overlay(alignment: .leading) {
                // Color status dot at progress end
                if progress > 2 {
                    Circle()
                        .fill(progressStatusColor)
                        .frame(width: 6, height: 6)
                        .offset(x: max(0, min(CGFloat(progress / 100.0) * geometry.size.width, geometry.size.width)) - 3)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.5), value: progress)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress)) percent")
    }

    /// Color status based on progress thresholds:
    /// - Red: < 30%
    /// - Yellow/Orange: 30% - 70%
    /// - Green: > 70%
    private var progressStatusColor: Color {
        if progress < 30 {
            return Color(red: 239/255, green: 68/255, blue: 68/255) // red
        } else if progress < 70 {
            return Color(red: 245/255, green: 158/255, blue: 11/255) // amber
        } else {
            return Color(red: 16/255, green: 185/255, blue: 129/255) // green
        }
    }
}

// MARK: - Previews

// --- Preview block commented out for SPM build ---
// #Preview("Enterprise Objective - 45%") {
//     ProgressBar(progress: 45.0, scope: .enterprise, nodeType: .objective)
//         .frame(width: 260)
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Personal Objective - 72%") {
//     ProgressBar(progress: 72.0, scope: .personal, nodeType: .objective)
//         .frame(width: 260)
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Key Result - 100%") {
//     ProgressBar(progress: 100.0, scope: .enterprise, nodeType: .keyResult)
//         .frame(width: 260)
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }

// --- Preview block commented out for SPM build ---
// #Preview("Zero Progress") {
//     ProgressBar(progress: 0.0, scope: .personal, nodeType: .keyResult)
//         .frame(width: 260)
//         .padding()
//         .background(Color(red: 15/255, green: 23/255, blue: 42/255))
// }
