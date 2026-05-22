import SwiftUI

// MARK: - ErrorView

/// A view that displays an error state with an icon, message, and retry option.
///
/// `ErrorView` presents a user-friendly error display with:
/// - An error icon in a warning-colored circle
/// - The error message prominently displayed
/// - A retry button to attempt the failed operation again
/// - Optional secondary action for additional recovery options
///
/// Use this view when data loading fails or an unrecoverable error occurs.
///
/// ## Example
/// ```swift
/// ErrorView(
///     message: "Failed to load OKR tree. Please check your connection.",
///     onRetry: { await viewModel.refresh() }
/// )
/// ```
public struct ErrorView: View {
    // MARK: - Properties
    
    /// The error message to display.
    let message: String
    
    /// Callback when the retry button is tapped.
    let onRetry: () -> Void
    
    /// Optional title override (default shows "Something Went Wrong").
    let title: String
    
    /// Whether a retry operation is currently in progress.
    let isRetrying: Bool
    
    /// The icon SF Symbol name.
    let iconName: String
    
    // MARK: - Initialization
    
    /// Creates a new error view.
    /// - Parameters:
    ///   - message: The error message to display.
    ///   - title: Optional title text (default: "Something Went Wrong").
    ///   - iconName: SF Symbol for the icon (default: "exclamationmark.triangle.fill").
    ///   - isRetrying: Whether retry is in progress (default: false).
    ///   - onRetry: Closure called when retry is tapped.
    public init(
        message: String,
        title: String = "Something Went Wrong",
        iconName: String = "exclamationmark.triangle.fill",
        isRetrying: Bool = false,
        onRetry: @escaping () -> Void
    ) {
        self.message = message
        self.title = title
        self.iconName = iconName
        self.isRetrying = isRetrying
        self.onRetry = onRetry
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Error icon
            ZStack {
                Circle()
                    .fill(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.1))
                    .frame(width: 88, height: 88)
                
                Circle()
                    .stroke(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.2), lineWidth: 1)
                    .frame(width: 88, height: 88)
                
                Image(systemName: iconName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color(red: 239/255, green: 68/255, blue: 68/255))
            }
            .accessibilityHidden(true)
            
            // Title
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundStyle(.white)
            
            // Error message
            Text(message)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(Color(red: 203/255, green: 213/255, blue: 225/255))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .lineSpacing(4)
            
            // Retry button
            Button {
                onRetry()
            } label: {
                HStack(spacing: 8) {
                    if isRetrying {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text(isRetrying ? "Retrying..." : "Try Again")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRetrying ? Color.white.opacity(0.1) : Color.white.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isRetrying)
            .padding(.top, 8)
            .accessibilityLabel("Retry")
            .accessibilityHint("Attempts to reload the data")
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Previews

// --- Preview block commented out for SPM build ---
// #Preview("Default Error") {
//     ErrorView(
//         message: "Failed to load OKR tree. Please check your network connection and try again.",
//         onRetry: {}
//     )
// }

// --- Preview block commented out for SPM build ---
// #Preview("Retrying State") {
//     ErrorView(
//         message: "Failed to load OKR tree. Please check your network connection and try again.",
//         isRetrying: true,
//         onRetry: {}
//     )
// }

// --- Preview block commented out for SPM build ---
// #Preview("Custom Error") {
//     ErrorView(
//         message: "The selected cycle does not exist or has been deleted.",
//         title: "Cycle Not Found",
//         iconName: "magnifyingglass.circle.fill",
//         onRetry: {}
//     )
// }

// --- Preview block commented out for SPM build ---
// #Preview("Server Error") {
//     ErrorView(
//         message: "Internal server error (500). Our team has been notified. Please try again later.",
//         title: "Server Error",
//         iconName: "server.rack",
//         onRetry: {}
//     )
// }
