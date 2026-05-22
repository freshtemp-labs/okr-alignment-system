// OKRAlignmentShared/Views/Common/KeyboardShortcutsHelpView.swift

import SwiftUI

/// 键盘快捷键帮助对话框
///
/// 展示所有可用的键盘快捷键，可通过 Cmd+? 触发
///
/// ## 使用示例
/// ```swift
/// .sheet(isPresented: $showShortcuts) {
///     KeyboardShortcutsHelpView()
/// }
/// ```
public struct KeyboardShortcutsHelpView: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: - Shortcut Data

    private let shortcutGroups: [ShortcutGroup] = [
        ShortcutGroup(
            title: "通用",
            icon: "command",
            shortcuts: [
                KeyboardShortcutItem(key: "Z", modifiers: "⌘", name: "撤销", description: "撤销上一步操作"),
                KeyboardShortcutItem(key: "Z", modifiers: "⇧⌘", name: "重做", description: "重做上一步撤销"),
                KeyboardShortcutItem(key: "S", modifiers: "⌘", name: "保存", description: "保存当前更改"),
                KeyboardShortcutItem(key: "N", modifiers: "⌘", name: "新建", description: "创建新节点"),
                KeyboardShortcutItem(key: "F", modifiers: "⌘", name: "搜索", description: "全局搜索"),
                KeyboardShortcutItem(key: ",", modifiers: "⌘", name: "设置", description: "打开设置"),
                KeyboardShortcutItem(key: "?", modifiers: "⌘", name: "快捷键帮助", description: "显示此帮助"),
            ]
        ),
        ShortcutGroup(
            title: "树视图",
            icon: "list.bullet.indent",
            shortcuts: [
                KeyboardShortcutItem(key: "E", modifiers: "⌘", name: "展开全部", description: "展开所有节点"),
                KeyboardShortcutItem(key: "C", modifiers: "⌘", name: "折叠全部", description: "折叠所有节点"),
                KeyboardShortcutItem(key: "↑", modifiers: "", name: "上一个", description: "选择上一个节点"),
                KeyboardShortcutItem(key: "↓", modifiers: "", name: "下一个", description: "选择下一个节点"),
                KeyboardShortcutItem(key: "←", modifiers: "", name: "折叠", description: "折叠当前节点"),
                KeyboardShortcutItem(key: "→", modifiers: "", name: "展开", description: "展开当前节点"),
                KeyboardShortcutItem(key: "⌫", modifiers: "", name: "删除", description: "删除选中节点"),
                KeyboardShortcutItem(key: "⏎", modifiers: "", name: "编辑", description: "编辑选中节点"),
            ]
        ),
        ShortcutGroup(
            title: "数据",
            icon: "arrow.triangle.2.circlepath",
            shortcuts: [
                KeyboardShortcutItem(key: "R", modifiers: "⌘", name: "刷新", description: "刷新数据"),
                KeyboardShortcutItem(key: "E", modifiers: "⇧⌘", name: "导出", description: "导出报表"),
                KeyboardShortcutItem(key: "I", modifiers: "⌘", name: "导入", description: "导入数据"),
            ]
        ),
        ShortcutGroup(
            title: "视图切换",
            icon: "rectangle.split.3x1",
            shortcuts: [
                KeyboardShortcutItem(key: "1", modifiers: "⌘", name: "树视图", description: "切换到树视图"),
                KeyboardShortcutItem(key: "2", modifiers: "⌘", name: "分析", description: "切换到分析视图"),
                KeyboardShortcutItem(key: "3", modifiers: "⌘", name: "设置", description: "切换到设置"),
            ]
        )
    ]

    // MARK: - Body

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("键盘快捷键")
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(shortcutGroups) { group in
                        ShortcutGroupView(group: group)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 520, minHeight: 500)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
    }
}

// MARK: - Shortcut Group View

private struct ShortcutGroupView: View {
    let group: ShortcutGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Group header
            HStack(spacing: 8) {
                Image(systemName: group.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                Text(group.title)
                    .font(.headline)
            }

            // Shortcut rows
            ForEach(group.shortcuts) { shortcut in
                HStack {
                    Text(shortcut.name)
                        .font(.body)
                        .frame(width: 120, alignment: .leading)

                    // Key badge
                    HStack(spacing: 2) {
                        if !shortcut.modifiers.isEmpty {
                            ForEach(Array(shortcut.modifiers), id: \.self) { char in
                                KeyBadge(label: String(char))
                            }
                        }
                        KeyBadge(label: shortcut.key)
                    }

                    Spacer()

                    Text(shortcut.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Key Badge

private struct KeyBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(minWidth: 24, minHeight: 24)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
    }
}

// MARK: - Data Models

private struct ShortcutGroup: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let shortcuts: [KeyboardShortcutItem]
}

private struct KeyboardShortcutItem: Identifiable {
    let id = UUID()
    let key: String
    let modifiers: String
    let name: String
    let description: String
}
