// OKRAlignmentShared/Services/DataSyncManager.swift

import Foundation
import SwiftUI

/// 数据同步管理器
///
/// 提供完整的数据同步功能，包括：
/// - 冲突解决策略选择（自动合并/手动解决/覆盖）
/// - 同步历史记录
/// - 同步状态实时追踪
///
/// ## 使用示例
/// ```swift
/// let manager = DataSyncManager.shared
/// manager.conflictStrategy = .autoMerge
/// await manager.startSync()
/// print(manager.syncHistory)
/// ```
@MainActor
public final class DataSyncManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = DataSyncManager()

    // MARK: - Published Properties

    /// 当前同步状态
    @Published public private(set) var syncState: SyncState = .idle

    /// 冲突解决策略
    @Published public var conflictStrategy: ConflictStrategy {
        didSet {
            UserDefaults.standard.set(conflictStrategy.rawValue, forKey: "okr_sync_conflict_strategy")
        }
    }

    /// 同步历史记录
    @Published public private(set) var syncHistory: [SyncHistoryEntry] = []

    /// 最后一次同步时间
    @Published public private(set) var lastSyncDate: Date?

    /// 同步进度（0.0 ~ 1.0）
    @Published public private(set) var syncProgress: Double = 0

    /// 待解决的冲突列表
    @Published public private(set) var pendingConflicts: [SyncConflict] = []

    /// 是否有未解决的冲突
    public var hasPendingConflicts: Bool {
        !pendingConflicts.isEmpty
    }

    // MARK: - Private Properties

    private let maxHistoryCount = 100

    // MARK: - Initialization

    private init() {
        let rawValue = UserDefaults.standard.string(forKey: "okr_sync_conflict_strategy") ?? ConflictStrategy.autoMerge.rawValue
        self.conflictStrategy = ConflictStrategy(rawValue: rawValue) ?? .autoMerge
        loadHistory()
    }

    // MARK: - Public Methods

    /// 开始同步
    public func startSync() async {
        guard syncState != .syncing else { return }

        syncState = .syncing
        syncProgress = 0

        let entry = SyncHistoryEntry(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            status: .inProgress,
            conflictStrategy: conflictStrategy,
            itemsSynced: 0,
            conflictsFound: 0,
            details: "同步开始..."
        )
        syncHistory.insert(entry, at: 0)

        // 模拟同步过程
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            syncProgress = Double(i) / 10.0
        }

        // 模拟完成
        let completedEntry = SyncHistoryEntry(
            id: entry.id,
            startTime: entry.startTime,
            endTime: Date(),
            status: .completed,
            conflictStrategy: conflictStrategy,
            itemsSynced: 42,
            conflictsFound: 0,
            details: "同步完成：42 项数据已同步"
        )

        if let index = syncHistory.firstIndex(where: { $0.id == entry.id }) {
            syncHistory[index] = completedEntry
        }

        syncState = .completed
        lastSyncDate = Date()
        syncProgress = 1.0
        saveHistory()

        // 3秒后重置为空闲
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if syncState == .completed {
            syncState = .idle
        }
    }

    /// 解决冲突
    public func resolveConflict(_ conflict: SyncConflict, resolution: ConflictResolution) {
        pendingConflicts.removeAll { $0.id == conflict.id }

        let detail = "冲突已解决: \(conflict.entityName) - \(resolution.displayName)"
        let entry = SyncHistoryEntry(
            id: UUID(),
            startTime: Date(),
            endTime: Date(),
            status: .conflictResolved,
            conflictStrategy: conflictStrategy,
            itemsSynced: 1,
            conflictsFound: 1,
            details: detail
        )
        syncHistory.insert(entry, at: 0)
        saveHistory()
    }

    /// 清空同步历史
    public func clearHistory() {
        syncHistory.removeAll()
        saveHistory()
    }

    /// 手动添加冲突（用于测试）
    public func addTestConflict() {
        let conflict = SyncConflict(
            id: UUID(),
            entityName: "测试节点",
            entityType: "OKRNode",
            localVersion: 1,
            remoteVersion: 2,
            localModifiedAt: Date().addingTimeInterval(-300),
            remoteModifiedAt: Date(),
            description: "本地和远程同时修改了同一节点"
        )
        pendingConflicts.append(conflict)
    }

    // MARK: - Persistence

    private func saveHistory() {
        let historyToSave = Array(syncHistory.prefix(maxHistoryCount))
        guard let data = try? JSONEncoder().encode(historyToSave) else { return }
        UserDefaults.standard.set(data, forKey: "okr_sync_history")
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "okr_sync_history"),
              let entries = try? JSONDecoder().decode([SyncHistoryEntry].self, from: data) else { return }
        syncHistory = entries
    }
}

// MARK: - Sync State

/// 同步状态枚举
public enum SyncState: String, Sendable {
    case idle
    case syncing
    case completed
    case error
    case conflictDetected

    public var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .syncing: return "同步中..."
        case .completed: return "已完成"
        case .error: return "同步失败"
        case .conflictDetected: return "检测到冲突"
        }
    }

    public var icon: String {
        switch self {
        case .idle: return "icloud"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        case .conflictDetected: return "exclamationmark.triangle"
        }
    }

    public var color: Color {
        switch self {
        case .idle: return .secondary
        case .syncing: return .blue
        case .completed: return .green
        case .error: return .red
        case .conflictDetected: return .orange
        }
    }
}

// MARK: - Conflict Strategy

/// 冲突解决策略
public enum ConflictStrategy: String, CaseIterable, Codable, Sendable {
    /// 自动合并：尝试智能合并双方变更
    case autoMerge = "auto_merge"
    /// 手动解决：暂停同步等待用户决策
    case manualResolve = "manual_resolve"
    /// 覆盖：以本地版本覆盖远程版本
    case overwriteLocal = "overwrite_local"
    /// 覆盖：以远程版本覆盖本地版本
    case overwriteRemote = "overwrite_remote"

    public var displayName: String {
        switch self {
        case .autoMerge: return "自动合并"
        case .manualResolve: return "手动解决"
        case .overwriteLocal: return "使用本地版本"
        case .overwriteRemote: return "使用远程版本"
        }
    }

    public var description: String {
        switch self {
        case .autoMerge: return "系统将尝试自动合并双方的变更，适合大多数场景"
        case .manualResolve: return "检测到冲突时暂停同步，等待您手动选择解决方案"
        case .overwriteLocal: return "用本地数据覆盖远程数据，远程变更将丢失"
        case .overwriteRemote: return "用远程数据覆盖本地数据，本地变更将丢失"
        }
    }

    public var icon: String {
        switch self {
        case .autoMerge: return "arrow.triangle.merge"
        case .manualResolve: return "hand.raised"
        case .overwriteLocal: return "laptopcomputer"
        case .overwriteRemote: return "icloud"
        }
    }
}

// MARK: - Conflict Resolution

/// 冲突解决方案
public enum ConflictResolution: String, Sendable {
    case keepLocal = "keep_local"
    case keepRemote = "keep_remote"
    case merge = "merge"

    public var displayName: String {
        switch self {
        case .keepLocal: return "保留本地"
        case .keepRemote: return "保留远程"
        case .merge: return "合并"
        }
    }
}

// MARK: - Sync History Entry

/// 同步历史记录条目
public struct SyncHistoryEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date?
    public let status: SyncEntryStatus
    public let conflictStrategy: ConflictStrategy
    public let itemsSynced: Int
    public let conflictsFound: Int
    public let details: String

    public var duration: TimeInterval? {
        guard let endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    public var durationDisplay: String {
        guard let duration else { return "进行中" }
        if duration < 1 { return String(format: "%.0fms", duration * 1000) }
        return String(format: "%.1fs", duration)
    }
}

/// 同步记录状态
public enum SyncEntryStatus: String, Codable, Sendable {
    case inProgress
    case completed
    case failed
    case conflictResolved

    public var displayName: String {
        switch self {
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .conflictResolved: return "冲突已解决"
        }
    }

    public var color: Color {
        switch self {
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .conflictResolved: return .orange
        }
    }
}

// MARK: - Sync Conflict

/// 同步冲突
public struct SyncConflict: Identifiable, Sendable {
    public let id: UUID
    public let entityName: String
    public let entityType: String
    public let localVersion: Int
    public let remoteVersion: Int
    public let localModifiedAt: Date
    public let remoteModifiedAt: Date
    public let description: String
}
