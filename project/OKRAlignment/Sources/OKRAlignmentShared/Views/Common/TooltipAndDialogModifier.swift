// OKRAlignmentShared/Views/Common/TooltipModifier.swift

import SwiftUI

/// 工具提示修饰符
///
/// 为视图添加鼠标悬停/长按提示信息
///
/// ## 使用示例
/// ```swift
/// Text("Hello")
///     .tooltip("这是一个问候")
///
/// Button("删除") { }
///     .tooltip("删除此节点及其所有子节点", position: .top)
/// ```
extension View {

    /// 添加工具提示
    /// - Parameters:
    ///   - text: 提示文本
    ///   - position: 提示位置（默认上方）
    public func tooltip(_ text: String, position: TooltipPosition = .top) -> some View {
        self.modifier(TooltipModifier(text: text, position: position))
    }
}

/// 提示位置
public enum TooltipPosition {
    case top
    case bottom
    case leading
    case trailing
}

/// 工具提示修饰符
private struct TooltipModifier: ViewModifier {
    let text: String
    let position: TooltipPosition

    @State private var isHovered = false
    @State private var tooltipSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .overlay(alignment: alignment) {
                if isHovered {
                    TooltipView(text: text)
                        .offset(x: offsetX, y: offsetY)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(1000)
                }
            }
    }

    private var alignment: Alignment {
        switch position {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    private var offsetX: CGFloat {
        switch position {
        case .leading: return -8
        case .trailing: return 8
        default: return 0
        }
    }

    private var offsetY: CGFloat {
        switch position {
        case .top: return -8
        case .bottom: return 8
        default: return 0
        }
    }
}

/// 提示视图
private struct TooltipView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 30/255, green: 41/255, blue: 59/255))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .fixedSize()
    }
}

// MARK: - Confirmation Dialog Modifier

/// 操作确认对话框
///
/// 为危险操作提供二次确认的模态对话框
///
/// ## 使用示例
/// ```swift
/// .confirmationDialog(
///     isPresented: $showConfirm,
///     title: "删除确认",
///     message: "确定要删除此节点吗？",
///     confirmTitle: "删除",
///     isDestructive: true,
///     onConfirm: { deleteNode() }
/// )
/// ```
public struct ActionConfirmDialog: ViewModifier {

    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void

    public func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button("取消", role: .cancel) {}
                Button(confirmTitle, role: isDestructive ? .destructive : .cancel) {
                    onConfirm()
                }
            } message: {
                Text(message)
            }
    }
}

extension View {

    /// 添加操作确认对话框
    public func actionConfirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "确认",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        self.modifier(ActionConfirmDialog(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            isDestructive: isDestructive,
            onConfirm: onConfirm
        ))
    }
}

// MARK: - Drag & Drop Sortable List

/// 可拖拽排序的列表视图
///
/// ## 使用示例
/// ```swift
/// DragDropSortableView(
///     items: $nodes,
///     id: \.id,
///     content: { node in
///         Text(node.title)
///     },
///     onReorder: { reordered in
///         // handle reorder
///     }
/// )
/// ```
public struct DragDropSortableView<Item: Identifiable, Content: View>: View {

    @Binding var items: [Item]
    let content: (Item) -> Content
    let onReorder: (([Item]) -> Void)?

    @State private var draggedItem: Item?
    @State private var dragOffset: CGSize = .zero
    @State private var targetIndex: Int?

    public init(
        items: Binding<[Item]>,
        @ViewBuilder content: @escaping (Item) -> Content,
        onReorder: (([Item]) -> Void)? = nil
    ) {
        self._items = items
        self.content = content
        self.onReorder = onReorder
    }

    public var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .cursor(.openHand)

                    content(item)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(targetIndex == index ? Color.blue.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(targetIndex == index ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .onDrag {
                    draggedItem = item
                    return NSItemProvider(object: "\(index)" as NSString)
                }
                .onDrop(of: [.text], delegate: SortDropDelegate(
                    item: item,
                    items: $items,
                    draggedItem: $draggedItem,
                    targetIndex: $targetIndex,
                    onReorder: onReorder
                ))
            }
        }
    }
}

/// 排序拖放代理
private struct SortDropDelegate<Item: Identifiable>: DropDelegate {
    let item: Item
    @Binding var items: [Item]
    @Binding var draggedItem: Item?
    @Binding var targetIndex: Int?
    let onReorder: (([Item]) -> Void)?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        targetIndex = nil
        onReorder?(items)
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem else { return }
        guard dragged.id != item.id else { return }

        guard let from = items.firstIndex(where: { $0.id == dragged.id }),
              let to = items.firstIndex(where: { $0.id == item.id }),
              from != to else { return }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Cursor Extension

#if os(macOS)
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
#else
extension View {
    func cursor(_ cursor: Any) -> some View {
        self
    }
}
#endif
