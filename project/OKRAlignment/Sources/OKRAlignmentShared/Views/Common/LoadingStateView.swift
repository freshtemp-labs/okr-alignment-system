// OKRAlignmentShared/Views/Common/LoadingStateView.swift

import SwiftUI

/// 通用加载状态视图
/// =================
/// 提供统一的加载状态展示，包括：
/// - 加载中（带进度条或旋转指示器）
/// - 加载完成
/// - 加载失败（带重试按钮）
/// - 空状态
///
/// # 使用示例
/// ```swift
/// LoadingStateView(state: viewModel.loadingState) {
///     // 主内容
///     TreeView(rootNode: viewModel.rootNode, ...)
/// } onRetry: {
///     await viewModel.refresh()
/// }
/// ```
public struct LoadingStateView<Content: View>: View {

    // MARK: - Types

    /// 加载状态
    public enum State: Equatable {
        case idle
        case loading(message: String?)
        case loaded
        case error(String)
        case empty(title: String, subtitle: String?)
    }

    // MARK: - Properties

    let state: State
    let content: () -> Content
    let onRetry: (() -> Void)?

    // MARK: - Body

    public init(
        state: State,
        @ViewBuilder content: @escaping () -> Content,
        onRetry: (() -> Void)? = nil
    ) {
        self.state = state
        self.content = content
        self.onRetry = onRetry
    }

    public var body: some View {
        ZStack {
            switch state {
            case .idle, .loaded:
                content()

            case .loading(let message):
                content()
                    .overlay {
                        loadingOverlay(message: message)
                    }

            case .error(let message):
                errorView(message: message)

            case .empty(let title, let subtitle):
                emptyView(title: title, subtitle: subtitle)
            }
        }
    }

    // MARK: - Loading Overlay

    @ViewBuilder
    private func loadingOverlay(message: String?) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)

                if let message = message {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 30/255, green: 41/255, blue: 59/255))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: state == .loading(message: message))
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(red: 239/255, green: 68/255, blue: 68/255))

            Text("加载失败")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let onRetry = onRetry {
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 59/255, green: 130/255, blue: 246/255))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
    }

    // MARK: - Empty View

    @ViewBuilder
    private func emptyView(title: String, subtitle: String?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
    }
}

// MARK: - Inline Loading Indicator

/// 内联加载指示器（不覆盖内容，用于轻量加载场景）
public struct InlineLoadingView: View {

    let message: String?
    let showProgress: Bool

    public init(message: String? = nil, showProgress: Bool = true) {
        self.message = message
        self.showProgress = showProgress
    }

    public var body: some View {
        HStack(spacing: 8) {
            if showProgress {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color(red: 59/255, green: 130/255, blue: 246/255))
                    .scaleEffect(0.8)
            }

            if let message = message {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(red: 30/255, green: 41/255, blue: 59/255))
        )
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview("Loading States") {
    VStack(spacing: 20) {
        LoadingStateView(
            state: .loading(message: "正在加载 OKR 树..."),
            content: { Color.clear }
        )
        .frame(height: 200)

        LoadingStateView(
            state: .error("网络连接失败"),
            content: { Color.clear },
            onRetry: {}
        )
        .frame(height: 200)

        LoadingStateView(
            state: .empty(title: "暂无数据", subtitle: "创建您的第一个目标"),
            content: { Color.clear }
        )
        .frame(height: 200)

        InlineLoadingView(message: "保存中...")
    }
    .padding()
    .preferredColorScheme(.dark)
}
#endif
