// OKRAlignmentShared/Views/Settings/AppearanceSettingsView.swift

import SwiftUI

/// 外观设置视图
/// 支持跟随系统 / 始终浅色 / 始终深色 三种模式切换
/// 使用 @AppStorage 通过 ThemeManager 持久化用户偏好
public struct AppearanceSettingsView: View {

    // MARK: - Properties

    @State private var themeManager = ThemeManager.shared

    // MARK: - Body

    public init() {}

    public var body: some View {
        Form {
            Section {
                ForEach(ThemeManager.AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.appearanceMode = mode
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.iconName)
                                .font(.title3)
                                .foregroundStyle(Color(red: 139/255, green: 92/255, blue: 246/255))
                                .frame(width: 28)

                            Text(mode.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if themeManager.appearanceMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("外观模式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("跟随系统将根据 iOS/macOS 系统设置自动切换浅色和深色模式。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("外观")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
    .preferredColorScheme(.dark)
}
#endif
