import SwiftUI

// MARK: - LoadingView

/// A centered loading indicator with optional descriptive text.
///
/// `LoadingView` displays a progress spinner with customizable text, used during
/// async operations like data fetching or tree loading. The view centers its
/// content and provides a subtle pulsing animation for visual feedback.
///
/// ## Example
/// ```swift
/// LoadingView(message: "Loading OKR tree...")
/// ```
public struct LoadingView: View {
    // MARK: - Properties
    
    /// The loading message displayed below the spinner.
    let message: String
    
    /// The size of the progress indicator.
    let controlSize: ControlSize
    
    /// Whether to show the pulsing animation effect.
    let animated: Bool
    
    // MARK: - State
    
    @State private var pulseOpacity: Double = 0.6
    
    // MARK: - Initialization
    
    /// Creates a new loading view.
    /// - Parameters:
    ///   - message: The text to display below the spinner (default: "Loading...").
    ///   - controlSize: The size of the progress indicator (default: .regular).
    ///   - animated: Whether to animate the pulsing effect (default: true).
    public init(
        message: String = "Loading...",
        controlSize: ControlSize = .regular,
        animated: Bool = true
    ) {
        self.message = message
        self.controlSize = controlSize
        self.animated = animated
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Progress indicator
            ProgressView()
                .controlSize(controlSize)
                .tint(
                    LinearGradient(
                        colors: [
                            Color(red: 59/255, green: 130/255, blue: 246/255),
                            Color(red: 139/255, green: 92/255, blue: 246/255)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(controlSize == .large ? 1.3 : (controlSize == .small ? 0.8 : 1.0))
            
            // Loading message
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                .opacity(animated ? pulseOpacity : 1.0)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 1.0
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityHint("Please wait while content loads")
    }
}

// MARK: - Loading Overlay

/// An overlay loading view that can be placed on top of existing content.
///
/// Use this variant when you want to show a loading state over partially loaded content.
public struct LoadingOverlay: View {
    // MARK: - Properties
    
    /// The loading message.
    let message: String
    
    /// Whether the overlay is visible.
    let isVisible: Bool
    
    // MARK: - Initialization
    
    /// Creates a loading overlay.
    /// - Parameters:
    ///   - isVisible: Whether to show the overlay.
    ///   - message: The loading text (default: "Loading...").
    public init(isVisible: Bool, message: String = "Loading...") {
        self.isVisible = isVisible
        self.message = message
    }
    
    // MARK: - Body
    
    public var body: some View {
        if isVisible {
            ZStack {
                Color(red: 15/255, green: 23/255, blue: 42/255)
                    .opacity(0.85)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(Color(red: 59/255, green: 130/255, blue: 246/255))
                    
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                }
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            .accessibilityLabel(message)
        }
    }
}

// MARK: - Previews

#Preview("Default Loading") {
    LoadingView()
}

#Preview("Custom Message") {
    LoadingView(message: "Loading OKR tree...")
}

#Preview("Small - Loading Data") {
    LoadingView(message: "Fetching cycles", controlSize: .small)
}

#Preview("Large - Initializing") {
    LoadingView(message: "Preparing your workspace", controlSize: .large)
}

#Preview("Loading Overlay") {
    ZStack {
        Color(red: 15/255, green: 23/255, blue: 42/255)
        
        Text("Background Content")
            .foregroundStyle(.white)
        
        LoadingOverlay(isVisible: true, message: "Refreshing data...")
    }
}
