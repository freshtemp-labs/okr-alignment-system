// OKRAlignmentShared/Views/Settings/LanguageSettingsView.swift

import SwiftUI

/// 语言设置视图
/// =============
/// 提供语言切换界面，支持简体中文和英文。
/// 切换后立即生效，所有 UI 文本更新为目标语言。
public struct LanguageSettingsView: View {

    // MARK: - Properties

    @State private var localizationManager = LocalizationManager.shared

    // MARK: - Body

    public init() {}

    public var body: some View {
        Form {
            Section {
                ForEach(LocalizationManager.Language.allCases, id: \.self) { language in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            localizationManager.currentLanguage = language
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(languageFlag(language))
                                .font(.title2)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.displayName)
                                    .foregroundStyle(.primary)
                                Text(languageCode(language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if localizationManager.currentLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("settings.language".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("切换语言后，所有界面文本将立即更新为目标语言。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("settings.language".localized)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Helpers

    private func languageFlag(_ language: LocalizationManager.Language) -> String {
        switch language {
        case .zhHans: return "🇨🇳"
        case .en: return "🇺🇸"
        }
    }

    private func languageCode(_ language: LocalizationManager.Language) -> String {
        switch language {
        case .zhHans: return "zh-Hans"
        case .en: return "en"
        }
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
#endif
