// This file provides a minimal entry point for the OKRAlignment (iOS) target
// when building on non-iOS platforms (e.g., macOS via `swift build`).
// On iOS, all source files in this target are wrapped in #if os(iOS),
// so this stub is only compiled on other platforms.

#if !os(iOS)
import Foundation

// Provide a minimal @main entry point so the iOS target compiles on macOS.
// This executable does nothing — the real iOS app entry point is in
// OKRAlignmentApp.swift which is guarded by #if os(iOS).
@main
struct OKRAlignmentStub {
    static func main() {
        // No-op: this target is only meaningful on iOS.
        // On macOS, build OKRAlignmentMac instead.
    }
}
#endif
