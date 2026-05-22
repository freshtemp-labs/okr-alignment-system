// OKRAlignmentShared/Services/DataMigrationService.swift

import Foundation
import CoreData
import os

/// 数据迁移服务
/// ==============
/// 提供从旧版本数据格式迁移到新版本的功能。
/// 支持版本检测、自动迁移、进度报告和回滚。
///
/// # 迁移策略
/// - 版本号存储在 UserDefaults 中
/// - 每个版本的迁移逻辑注册在 migrationSteps 数组中
/// - 迁移过程支持进度回调和取消
/// - 迁移前自动创建备份，支持回滚
///
/// # 使用示例
/// ```swift
/// let service = DataMigrationService(persistenceController: .shared)
/// if service.needsMigration {
///     let result = await service.performMigration()
///     print(result.message)
/// }
/// ```
@MainActor
public final class DataMigrationService: ObservableObject {

    // MARK: - Types

    /// 迁移状态
    public enum MigrationState: Equatable {
        case idle
        case checking
        case migrating(step: Int, totalSteps: Int, description: String)
        case completed(MigrationResult)
        case failed(MigrationResult)
        case rolledBack

        public static func == (lhs: MigrationState, rhs: MigrationState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.checking, .checking): return true
            case (.migrating(let s1, let t1, _), .migrating(let s2, let t2, _)):
                return s1 == s2 && t1 == t2
            case (.completed, .completed): return true
            case (.failed, .failed): return true
            case (.rolledBack, .rolledBack): return true
            default: return false
            }
        }
    }

    /// 迁移结果
    public struct MigrationResult {
        public let success: Bool
        public let message: String
        public let migratedNodeCount: Int
        public let migratedCycleCount: Int
        public let backupPath: String?
        public let duration: TimeInterval

        public var summary: String {
            if success {
                return "迁移成功：处理了 \(migratedCycleCount) 个周期和 \(migratedNodeCount) 个节点，耗时 \(String(format: "%.1f", duration)) 秒"
            } else {
                return "迁移失败：\(message)"
            }
        }
    }

    /// 迁移步骤定义
    private struct MigrationStep {
        let fromVersion: Int
        let toVersion: Int
        let description: String
        let execute: (NSManagedObjectContext) throws -> Void
    }

    // MARK: - Properties

    /// 当前迁移状态
    @Published public private(set) var state: MigrationState = .idle

    /// 迁移进度 (0.0 - 1.0)
    @Published public private(set) var progress: Double = 0.0

    /// 迁移日志
    @Published public private(set) var migrationLog: [String] = []

    /// 持久化控制器
    private let persistenceController: PersistenceController

    /// 当前数据版本
    private let currentDataVersion = 3

    /// UserDefaults 中版本号的 key
    private let versionKey = "okr_data_schema_version"

    /// 备份文件路径
    private var backupPath: String?

    // MARK: - Computed Properties

    /// 当前存储的数据版本
    public var storedDataVersion: Int {
        UserDefaults.standard.integer(forKey: versionKey)
    }

    /// 是否需要迁移
    public var needsMigration: Bool {
        storedDataVersion < currentDataVersion
    }

    /// 已注册的迁移步骤
    private var migrationSteps: [MigrationStep] {
        [
            MigrationStep(
                fromVersion: 1,
                toVersion: 2,
                description: "添加权重(weight)和版本号(version)字段"
            ) { context in
                try DataMigrationService.migrateV1toV2(context: context)
            },
            MigrationStep(
                fromVersion: 2,
                toVersion: 3,
                description: "添加归档(isArchived)字段到周期"
            ) { context in
                try DataMigrationService.migrateV2toV3(context: context)
            }
        ]
    }

    // MARK: - Initialization

    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController

        // 首次安装时设置为最新版本
        if storedDataVersion == 0 {
            UserDefaults.standard.set(currentDataVersion, forKey: versionKey)
        }
    }

    // MARK: - Public API

    /// 执行数据迁移
    /// - Returns: 迁移结果
    public func performMigration() async -> MigrationResult {
        guard needsMigration else {
            let result = MigrationResult(
                success: true,
                message: "数据已是最新版本，无需迁移",
                migratedNodeCount: 0,
                migratedCycleCount: 0,
                backupPath: nil,
                duration: 0
            )
            state = .completed(result)
            return result
        }

        state = .checking
        migrationLog.append("开始检查数据版本...")
        migrationLog.append("当前存储版本: \(storedDataVersion), 目标版本: \(currentDataVersion)")

        let startTime = Date()

        // 创建备份
        do {
            backupPath = try createBackup()
            migrationLog.append("已创建数据备份: \(backupPath ?? "unknown")")
        } catch {
            migrationLog.append("警告：备份创建失败 - \(error.localizedDescription)")
        }

        // 筛选需要执行的迁移步骤
        let stepsToExecute = migrationSteps.filter { $0.fromVersion >= storedDataVersion }
        let totalSteps = stepsToExecute.count

        guard !stepsToExecute.isEmpty else {
            let result = MigrationResult(
                success: true,
                message: "没有需要执行的迁移步骤",
                migratedNodeCount: 0,
                migratedCycleCount: 0,
                backupPath: backupPath,
                duration: 0
            )
            state = .completed(result)
            return result
        }

        var migratedNodes = 0
        var migratedCycles = 0

        for (index, step) in stepsToExecute.enumerated() {
            let stepNum = index + 1
            state = .migrating(
                step: stepNum,
                totalSteps: totalSteps,
                description: step.description
            )
            progress = Double(stepNum - 1) / Double(totalSteps)
            migrationLog.append("[步骤 \(stepNum)/\(totalSteps)] \(step.description)")

            do {
                let context = persistenceController.newBackgroundContext()
                try await context.perform {
                    try step.execute(context)
                    try context.save()
                }

                // 更新版本号
                UserDefaults.standard.set(step.toVersion, forKey: versionKey)
                migrationLog.append("  ✓ 版本 \(step.fromVersion) → \(step.toVersion) 迁移完成")

                // 统计迁移的数据量
                let counts = try await countMigratedData(context: context)
                migratedNodes += counts.nodes
                migratedCycles += counts.cycles

            } catch {
                migrationLog.append("  ✗ 迁移失败: \(error.localizedDescription)")
                let duration = Date().timeIntervalSince(startTime)
                let result = MigrationResult(
                    success: false,
                    message: "步骤 \(stepNum) 失败: \(error.localizedDescription)",
                    migratedNodeCount: migratedNodes,
                    migratedCycleCount: migratedCycles,
                    backupPath: backupPath,
                    duration: duration
                )
                state = .failed(result)
                return result
            }
        }

        progress = 1.0
        let duration = Date().timeIntervalSince(startTime)
        migrationLog.append("迁移完成，耗时 \(String(format: "%.1f", duration)) 秒")

        let result = MigrationResult(
            success: true,
            message: "数据迁移成功完成",
            migratedNodeCount: migratedNodes,
            migratedCycleCount: migratedCycles,
            backupPath: backupPath,
            duration: duration
        )
        state = .completed(result)
        return result
    }

    /// 回滚到迁移前的备份状态
    /// - Returns: 是否回滚成功
    public func rollback() -> Bool {
        guard let backupPath = backupPath else {
            migrationLog.append("回滚失败：没有可用的备份文件")
            state = .rolledBack
            return false
        }

        let backupURL = URL(fileURLWithPath: backupPath)
        let storeURL = persistenceController.container
            .persistentStoreCoordinator
            .persistentStores.first?.url

        guard let storeURL = storeURL else {
            migrationLog.append("回滚失败：无法获取当前存储路径")
            state = .rolledBack
            return false
        }

        do {
            // 关闭当前存储
            for store in persistenceController.container.persistentStoreCoordinator.persistentStores {
                try persistenceController.container.persistentStoreCoordinator.remove(store)
            }

            // 用备份覆盖当前数据
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
            }
            try fileManager.copyItem(at: backupURL, to: storeURL)

            // 重新加载存储
            try persistenceController.container.persistentStoreCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: nil
            )

            // 恢复版本号
            UserDefaults.standard.set(storedDataVersion - 1, forKey: versionKey)

            migrationLog.append("回滚成功：已恢复到迁移前的状态")
            state = .rolledBack
            return true
        } catch {
            migrationLog.append("回滚失败: \(error.localizedDescription)")
            state = .rolledBack
            return false
        }
    }

    /// 重置迁移状态
    public func resetState() {
        state = .idle
        progress = 0.0
        migrationLog = []
    }

    /// 强制设置数据版本（用于测试或手动修复）
    /// - Parameter version: 要设置的版本号
    public func setDatabaseVersion(_ version: Int) {
        UserDefaults.standard.set(version, forKey: versionKey)
    }

    // MARK: - Migration Steps

    /// V1 → V2: 添加 weight 和 version 字段
    private static func migrateV1toV2(context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "OKRNodeEntity")
        let nodes = try context.fetch(request)

        for node in nodes {
            // 设置默认权重
            if node.value(forKey: "weight") == nil {
                node.setValue(1.0, forKey: "weight")
            }
            // 设置默认版本号
            if node.value(forKey: "version") == nil {
                node.setValue(Int64(0), forKey: "version")
            }
        }
    }

    /// V2 → V3: 添加 isArchived 字段到周期
    private static func migrateV2toV3(context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "OKRCycleEntity")
        let cycles = try context.fetch(request)

        for cycle in cycles {
            if cycle.value(forKey: "isArchived") == nil {
                cycle.setValue(false, forKey: "isArchived")
            }
        }
    }

    // MARK: - Helpers

    /// 创建数据备份
    private func createBackup() throws -> String {
        let storeURL = persistenceController.container
            .persistentStoreCoordinator
            .persistentStores.first?.url

        guard let storeURL = storeURL else {
            throw MigrationError.backupFailed("无法获取存储路径")
        }

        let backupDir = storeURL.deletingLastPathComponent()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupURL = backupDir.appendingPathComponent("OKRAlignment_backup_\(timestamp).sqlite")

        try FileManager.default.copyItem(at: storeURL, to: backupURL)
        return backupURL.path
    }

    /// 统计迁移后的数据量
    private func countMigratedData(context: NSManagedObjectContext) throws -> (nodes: Int, cycles: Int) {
        let nodeRequest = NSFetchRequest<NSManagedObject>(entityName: "OKRNodeEntity")
        let nodeCount = try context.count(for: nodeRequest)

        let cycleRequest = NSFetchRequest<NSManagedObject>(entityName: "OKRCycleEntity")
        let cycleCount = try context.count(for: cycleRequest)

        return (nodeCount, cycleCount)
    }
}

// MARK: - Errors

public enum MigrationError: LocalizedError {
    case backupFailed(String)
    case migrationStepFailed(Int, String)
    case rollbackFailed(String)

    public var errorDescription: String? {
        switch self {
        case .backupFailed(let reason):
            return "备份失败: \(reason)"
        case .migrationStepFailed(let step, let reason):
            return "迁移步骤 \(step) 失败: \(reason)"
        case .rollbackFailed(let reason):
            return "回滚失败: \(reason)"
        }
    }
}
