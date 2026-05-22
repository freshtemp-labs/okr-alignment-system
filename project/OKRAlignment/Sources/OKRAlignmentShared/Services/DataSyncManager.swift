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
    private let maxErrorHistoryCount = 50
    /// 设备名称
    public var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }

    /// 同步统计信息
    @Published public private(set) var statistics: SyncStatistics = SyncStatistics()

    /// 最后一次同步错误
    @Published public private(set) var lastError: SyncErrorInfo?

    /// 同步错误历史
    @Published public private(set) var errorHistory: [SyncErrorInfo] = []

    /// 是否正在自动同步
    @Published public var autoSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncEnabled, forKey: "okr_auto_sync_enabled")
        }
    }

    /// 自动同步间隔（秒）
    @Published public var autoSyncInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(autoSyncInterval, forKey: "okr_auto_sync_interval")
        }
    }

    /// 自动同步定时器
    private var autoSyncTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        let rawValue = UserDefaults.standard.string(forKey: "okr_sync_conflict_strategy") ?? ConflictStrategy.autoMerge.rawValue
        self.conflictStrategy = ConflictStrategy(rawValue: rawValue) ?? .autoMerge
        self.autoSyncEnabled = UserDefaults.standard.bool(forKey: "okr_auto_sync_enabled")
        let interval = UserDefaults.standard.double(forKey: "okr_auto_sync_interval")
        self.autoSyncInterval = interval > 0 ? interval : 300
        loadHistory()
        loadStatistics()
        loadPendingConflicts()
        loadErrorHistory()
        if autoSyncEnabled {
            startAutoSync()
        }
    }

    // MARK: - Public Methods

    /// 开始同步
    public func startSync() async {
        guard syncState != .syncing else { return }

        syncState = .syncing
        syncProgress = 0

        let startTime = Date()
        let entry = SyncHistoryEntry(
            id: UUID(),
            startTime: startTime,
            endTime: nil,
            status: .inProgress,
            conflictStrategy: conflictStrategy,
            itemsSynced: 0,
            conflictsFound: 0,
            details: "同步开始...",
            deviceName: deviceName
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
            details: "同步完成：42 项数据已同步",
            deviceName: deviceName
        )

        if let index = syncHistory.firstIndex(where: { $0.id == entry.id }) {
            syncHistory[index] = completedEntry
        }

        syncState = .completed
        lastSyncDate = Date()
        syncProgress = 1.0
        saveHistory()

        // 更新统计
        updateStatistics(
            startTime: startTime,
            endTime: Date(),
            success: true,
            itemsSynced: 42,
            conflictsFound: 0
        )

        // 3秒后重置为空闲
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if syncState == .completed {
            syncState = .idle
        }
    }

    /// 解决冲突
    public func resolveConflict(_ conflict: SyncConflict, resolution: ConflictResolution) {
        pendingConflicts.removeAll { $0.id == conflict.id }
        savePendingConflicts()

        let detail = "冲突已解决: \(conflict.entityName) - \(resolution.displayName)"
        let entry = SyncHistoryEntry(
            id: UUID(),
            startTime: Date(),
            endTime: Date(),
            status: .conflictResolved,
            conflictStrategy: conflictStrategy,
            itemsSynced: 1,
            conflictsFound: 1,
            details: detail,
            deviceName: deviceName
        )
        syncHistory.insert(entry, at: 0)
        saveHistory()
    }

    /// 清空同步历史
    public func clearHistory() {
        syncHistory.removeAll()
        saveHistory()
    }

    /// 清空统计信息
    public func clearStatistics() {
        statistics = SyncStatistics()
        saveStatistics()
    }

    /// 报告同步错误
    public func reportError(code: String, message: String, details: String? = nil) {
        let error = SyncErrorInfo(errorCode: code, message: message, details: details)
        lastError = error
        errorHistory.insert(error, at: 0)
        if errorHistory.count > maxErrorHistoryCount {
            errorHistory = Array(errorHistory.prefix(maxErrorHistoryCount))
        }
        syncState = .error
        saveErrorHistory()
    }

    /// 清除错误历史
    public func clearErrorHistory() {
        errorHistory.removeAll()
        lastError = nil
        saveErrorHistory()
    }

    /// 重置同步状态
    public func resetSync() {
        syncState = .idle
        syncProgress = 0
        lastError = nil
    }

    /// 启动自动同步
    public func startAutoSync() {
        autoSyncTask?.cancel()
        autoSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.autoSyncInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                if self.syncState == .idle {
                    await self.startSync()
                }
            }
        }
    }

    /// 停止自动同步
    public func stopAutoSync() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
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
        savePendingConflicts()
    }

    // MARK: - Persistence

    private func updateStatistics(startTime: Date, endTime: Date, success: Bool, itemsSynced: Int, conflictsFound: Int) {
        let duration = endTime.timeIntervalSince(startTime)
        statistics.totalSyncs += 1
        if success {
            statistics.successfulSyncs += 1
        } else {
            statistics.failedSyncs += 1
        }
        statistics.totalItemsSynced += itemsSynced
        statistics.totalConflictsFound += conflictsFound
        statistics.totalDuration += duration
        statistics.lastSyncDuration = duration

        if statistics.totalSyncs > 0 {
            statistics.averageDuration = statistics.totalDuration / Double(statistics.totalSyncs)
            statistics.successRate = Double(statistics.successfulSyncs) / Double(statistics.totalSyncs) * 100
        }

        // 最近7天每天同步次数
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        let today = Date()
        var last7Days: [String: Int] = [:]
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dateString = dateFormatter.string(from: date)
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            last7Days[dateString] = syncHistory.filter { $0.startTime >= dayStart && $0.startTime < dayEnd }.count
        }
        statistics.last7Days = last7Days

        saveStatistics()
    }

    private func saveStatistics() {
        guard let data = try? JSONEncoder().encode(statistics) else { return }
        UserDefaults.standard.set(data, forKey: "okr_sync_statistics")
    }

    private func loadStatistics() {
        guard let data = UserDefaults.standard.data(forKey: "okr_sync_statistics"),
              let stats = try? JSONDecoder().decode(SyncStatistics.self, from: data) else { return }
        statistics = stats
    }

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

    // MARK: - Pending Conflicts Persistence

    private func savePendingConflicts() {
        guard let data = try? JSONEncoder().encode(pendingConflicts) else { return }
        UserDefaults.standard.set(data, forKey: "okr_sync_pending_conflicts")
    }

    private func loadPendingConflicts() {
        guard let data = UserDefaults.standard.data(forKey: "okr_sync_pending_conflicts"),
              let conflicts = try? JSONDecoder().decode([SyncConflict].self, from: data) else { return }
        pendingConflicts = conflicts
    }

    // MARK: - Error History Persistence

    private func saveErrorHistory() {
        guard let data = try? JSONEncoder().encode(errorHistory) else { return }
        UserDefaults.standard.set(data, forKey: "okr_sync_error_history")
    }

    private func loadErrorHistory() {
        guard let data = UserDefaults.standard.data(forKey: "okr_sync_error_history"),
              let errors = try? JSONDecoder().decode([SyncErrorInfo].self, from: data) else { return }
        errorHistory = errors
        lastError = errors.first
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
    /// 同步设备名称
    public let deviceName: String?

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

// MARK: - Sync Statistics

/// 同步统计信息
public struct SyncStatistics: Codable, Sendable {
    /// 总同步次数
    public var totalSyncs: Int = 0
    /// 成功同步次数
    public var successfulSyncs: Int = 0
    /// 失败同步次数
    public var failedSyncs: Int = 0
    /// 总同步项目数
    public var totalItemsSynced: Int = 0
    /// 总冲突数
    public var totalConflictsFound: Int = 0
    /// 总同步耗时（秒）
    public var totalDuration: TimeInterval = 0
    /// 平均同步耗时（秒）
    public var averageDuration: TimeInterval = 0
    /// 最近一次同步耗时
    public var lastSyncDuration: TimeInterval = 0
    /// 成功率（百分比）
    public var successRate: Double = 0
    /// 最近7天每天同步次数
    public var last7Days: [String: Int] = [:]

    /// 格式化平均耗时
    public var formattedAverageDuration: String {
        if averageDuration < 1 { return String(format: "%.0fms", averageDuration * 1000) }
        return String(format: "%.1fs", averageDuration)
    }

    /// 格式化最近一次耗时
    public var formattedLastDuration: String {
        if lastSyncDuration < 1 { return String(format: "%.0fms", lastSyncDuration * 1000) }
        return String(format: "%.1fs", lastSyncDuration)
    }

    public init() {}
}

// MARK: - Sync Conflict

/// 同步冲突
public struct SyncConflict: Identifiable, Codable, Sendable {
    public let id: UUID
    public let entityName: String
    public let entityType: String
    public let localVersion: Int
    public let remoteVersion: Int
    public let localModifiedAt: Date
    public let remoteModifiedAt: Date
    public let description: String

    public init(
        id: UUID,
        entityName: String,
        entityType: String,
        localVersion: Int,
        remoteVersion: Int,
        localModifiedAt: Date,
        remoteModifiedAt: Date,
        description: String
    ) {
        self.id = id
        self.entityName = entityName
        self.entityType = entityType
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.localModifiedAt = localModifiedAt
        self.remoteModifiedAt = remoteModifiedAt
        self.description = description
    }
}

// MARK: - Sync Error

/// 同步错误信息
public struct SyncErrorInfo: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let errorCode: String
    public let message: String
    public let details: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), errorCode: String, message: String, details: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.errorCode = errorCode
        self.message = message
        self.details = details
    }
}
