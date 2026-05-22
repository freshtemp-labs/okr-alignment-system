// OKRAlignmentShared/Services/UndoRedoManager.swift

import Foundation
import SwiftUI

/// 撤销/重做管理器
///
/// 提供操作历史管理功能，支持撤销和重做操作：
/// - 记录操作历史栈
/// - 支持撤销/重做
/// - 可配置最大历史记录数
/// - 提供操作描述供UI展示
///
/// ## 使用示例
/// ```swift
/// let manager = UndoRedoManager.shared
/// manager.registerAction(UndoRedoAction(
///     name: "修改标题",
///     undo: { /* undo logic */ },
///     redo: { /* redo logic */ }
/// ))
/// manager.undo()
/// manager.redo()
/// ```
@MainActor
public final class UndoRedoManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = UndoRedoManager()

    // MARK: - Published Properties

    /// 操作历史栈（用于撤销）
    @Published public private(set) var undoStack: [UndoRedoAction] = []

    /// 重做栈
    @Published public private(set) var redoStack: [UndoRedoAction] = []

    /// 是否可以撤销
    public var canUndo: Bool { !undoStack.isEmpty }

    /// 是否可以重做
    public var canRedo: Bool { !redoStack.isEmpty }

    /// 下一个可撤销的操作名称
    public var nextUndoActionName: String? { undoStack.last?.name }

    /// 下一个可重做的操作名称
    public var nextRedoActionName: String? { redoStack.last?.name }

    // MARK: - Configuration

    /// 最大历史记录数
    public let maxHistoryCount: Int

    // MARK: - Initialization

    public init(maxHistoryCount: Int = 50) {
        self.maxHistoryCount = maxHistoryCount
    }

    // MARK: - Public Methods

    /// 注册新操作
    /// - Parameter action: 要注册的操作
    public func registerAction(_ action: UndoRedoAction) {
        undoStack.append(action)

        // 超出最大数量时移除最早的
        if undoStack.count > maxHistoryCount {
            undoStack.removeFirst(undoStack.count - maxHistoryCount)
        }

        // 新操作会清空重做栈
        redoStack.removeAll()
    }

    /// 执行撤销
    public func undo() {
        guard let action = undoStack.popLast() else { return }
        action.undo()
        redoStack.append(action)
    }

    /// 执行重做
    public func redo() {
        guard let action = redoStack.popLast() else { return }
        action.redo()
        undoStack.append(action)
    }

    /// 清空所有历史
    public func clearAll() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// 批量撤销（撤销最近N个操作）
    public func undoLast(_ count: Int) {
        for _ in 0..<count {
            undo()
        }
    }
}

// MARK: - Undo/Redo Action

/// 撤销/重做操作
public struct UndoRedoAction: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let timestamp: Date

    // 使用 nonisolated 存储闭包，执行时由管理器在 MainActor 上调用
    private let _undo: @Sendable () -> Void
    private let _redo: @Sendable () -> Void

    public init(
        id: UUID = UUID(),
        name: String,
        timestamp: Date = Date(),
        undo: @escaping @Sendable () -> Void,
        redo: @escaping @Sendable () -> Void
    ) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self._undo = undo
        self._redo = redo
    }

    public func undo() { _undo() }
    public func redo() { _redo() }

    /// 格式化的时间戳
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Keyboard Shortcut Support

extension UndoRedoManager {

    /// 处理键盘快捷键
    /// - Parameter key: 按键事件
    /// - Returns: 是否已处理
    @discardableResult
    public func handleKeyPress(key: KeyboardShortcutKey) -> Bool {
        switch key {
        case .undo:
            if canUndo {
                undo()
                return true
            }
        case .redo:
            if canRedo {
                redo()
                return true
            }
        }
        return false
    }
}

/// 键盘快捷键标识
public enum KeyboardShortcutKey: Sendable {
    case undo
    case redo
}
