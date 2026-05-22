import SwiftUI

// MARK: - AnimatedProgressIndicator

/// A progress bar with color-coded indicator based on progress value.
///
/// Color scheme:
/// - Red: < 30%
/// - Yellow/Orange: 30% - 70%
/// - Green: > 70%
///
/// Features smooth animated transitions when progress changes.
public struct AnimatedProgressIndicator: View {
    // MARK: - Properties

    /// The current progress value (0.0 - 100.0).
    let progress: Double

    /// The node's scope (affects bar style).
    let scope: Scope

    /// The node type.
    let nodeType: NodeType

    // MARK: - Initialization

    public init(progress: Double, scope: Scope, nodeType: NodeType) {
        self.progress = progress
        self.scope = scope
        self.nodeType = nodeType
    }

    // MARK: - Computed Properties

    /// Color indicator based on progress thresholds.
    /// - Red: < 30%
    /// - Yellow/Orange: 30% - 70%
    /// - Green: > 70%
    private var progressColor: Color {
        if progress < 30 {
            return Color(red: 239/255, green: 68/255, blue: 68/255) // red
        } else if progress < 70 {
            return Color(red: 245/255, green: 158/255, blue: 11/255) // amber
        } else {
            return Color(red: 16/255, green: 185/255, blue: 129/255) // green
        }
    }

    /// The gradient fill based on progress color.
    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [
                progressColor,
                progressColor.opacity(0.7)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track (background)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))

                // Fill (progress indicator)
                RoundedRectangle(cornerRadius: 3)
                    .fill(fillGradient)
                    .frame(width: max(0, min(CGFloat(progress / 100.0) * geometry.size.width, geometry.size.width)))
            }
        }
        .frame(height: 6)
        .overlay(
            // Color dot indicator at the end
            HStack {
                Spacer()
                Circle()
                    .fill(progressColor)
                    .frame(width: 8, height: 8)
                    .opacity(progress > 0 ? 1 : 0)
                    .padding(.trailing, max(0, CGFloat(1.0 - progress / 100.0) * 260))
            }
        )
        .animation(.easeInOut(duration: 0.5), value: progress)
        .animation(.easeInOut(duration: 0.3), value: progressColor)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress)) percent")
    }
}
