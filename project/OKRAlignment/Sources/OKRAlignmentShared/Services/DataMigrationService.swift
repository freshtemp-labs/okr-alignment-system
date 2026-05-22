// OKRAlignmentShared/Services/DataMigrationService.swift

import Foundation
import CoreData
import os

/// 数据迁移服务
/// ==============
/// 提供从旧版本数据格式迁移到新版本的功能。
/// 支持版本检测、自动迁移、进度报告和回滚。
/// 支持数据完整性检查和存储统计。
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
/// // 数据完整性检查
/// let integrity = await service.checkDataIntegrity()
/// // 存储统计
/// let stats = service.getStorageStatistics()
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
    private let currentDataVersion = 4

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
            },
            MigrationStep(
                fromVersion: 3,
                toVersion: 4,
                description: "添加优先级(priority)和标签(tags)字段"
            ) { context in
                try DataMigrationService.migrateV3toV4(context: context)
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

    /// V3 → V4: 添加 priority 和 tags 字段到节点
    private static func migrateV3toV4(context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "OKRNodeEntity")
        let nodes = try context.fetch(request)

        for node in nodes {
            // 设置默认优先级 (0=普通, 1=高, 2=紧急)
            if node.value(forKey: "priority") == nil {
                node.setValue(Int64(0), forKey: "priority")
            }
            // 设置默认标签 (空字符串)
            if node.value(forKey: "tags") == nil {
                node.setValue("", forKey: "tags")
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

    // MARK: - Data Integrity

    /// 数据完整性检查结果
    public struct IntegrityCheckResult: Sendable {
        /// 是否通过检查
        public let isHealthy: Bool
        /// 发现的问题列表
        public let issues: [IntegrityIssue]
        /// 检查的实体总数
        public let totalEntitiesChecked: Int
        /// 检查耗时
        public let duration: TimeInterval

        /// 摘要信息
        public var summary: String {
            if isHealthy {
                return "数据完整性检查通过，共检查 \(totalEntitiesChecked) 条记录"
            } else {
                return "发现 \(issues.count) 个问题，请检查详情"
            }
        }
    }

    /// 完整性问题
    public struct IntegrityIssue: Identifiable, Sendable {
        public let id = UUID()
        /// 严重程度
        public let severity: Severity
        /// 问题描述
        public let description: String
        /// 涉及的实体类型
        public let entityType: String
        /// 涉及的实体ID
        public let entityId: String?

        public enum Severity: String, Sendable {
            case warning = "警告"
            case error = "错误"
            case critical = "严重"

            public var iconName: String {
                switch self {
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.circle"
                case .critical: return "exclamationmark.octagon"
                }
            }
        }
    }

    /// 执行数据完整性检查
    public func checkDataIntegrity() async -> IntegrityCheckResult {
        let startTime = Date()
        var issues: [IntegrityIssue] = []
        var totalChecked = 0

        let context = persistenceController.newBackgroundContext()
        await context.perform {
            // 检查节点完整性
            let nodeRequest = NSFetchRequest<NSManagedObject>(entityName: "OKRNodeEntity")
            do {
                let nodes = try context.fetch(nodeRequest)
                totalChecked += nodes.count

                for node in nodes {
                    let nodeId = (node.value(forKey: "id") as? UUID)?.uuidString ?? "unknown"

                    // 检查标题是否为空
                    if let title = node.value(forKey: "title") as? String, title.trimmingCharacters(in: .whitespaces).isEmpty {
                        issues.append(IntegrityIssue(
                            severity: .error,
                            description: "节点标题为空",
                            entityType: "OKRNodeEntity",
                            entityId: nodeId
                        ))
                    }

                    // 检查进度范围
                    let progress = node.value(forKey: "progress") as? Double ?? 0
                    if progress < 0 || progress > 100 {
                        issues.append(IntegrityIssue(
                            severity: .warning,
                            description: "进度值超出范围 (0-100): \(progress)",
                            entityType: "OKRNodeEntity",
                            entityId: nodeId
                        ))
                    }

                    // 检查目标值
                    let targetValue = node.value(forKey: "targetValue") as? Double ?? 0
                    if targetValue <= 0 {
                        issues.append(IntegrityIssue(
                            severity: .warning,
                            description: "目标值为零或负数: \(targetValue)",
                            entityType: "OKRNodeEntity",
                            entityId: nodeId
                        ))
                    }

                    // 检查父节点引用有效性
                    if let parentId = node.value(forKey: "parentId") as? UUID {
                        let parentRequest = NSFetchRequest<NSManagedObject>(entityName: "OKRNodeEntity")
                        parentRequest.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
                        let parentCount = try context.count(for: parentRequest)
                        if parentCount == 0 {
                            issues.append(IntegrityIssue(
                                severity: .critical,
                                description: "引用了不存在的父节点: \(parentId.uuidString)",
                                entityType: "OKRNodeEntity",
                                entityId: nodeId
                            ))
                        }
                    }
                }
            } catch {
                issues.append(IntegrityIssue(
                    severity: .critical,
                    description: "无法读取节点数据: \(error.localizedDescription)",
                    entityType: "OKRNodeEntity",
                    entityId: nil
                ))
            }

            // 检查周期完整性
            let cycleRequest = NSFetchRequest<NSManagedObject>(entityName: "OKRCycleEntity")
            do {
                let cycles = try context.fetch(cycleRequest)
                totalChecked += cycles.count

                for cycle in cycles {
                    let cycleId = (cycle.value(forKey: "id") as? UUID)?.uuidString ?? "unknown"

                    // 检查周期名称
                    if let name = cycle.value(forKey: "name") as? String, name.trimmingCharacters(in: .whitespaces).isEmpty {
                        issues.append(IntegrityIssue(
                            severity: .error,
                            description: "周期名称为空",
                            entityType: "OKRCycleEntity",
                            entityId: cycleId
                        ))
                    }

                    // 检查日期范围
                    if let startDate = cycle.value(forKey: "startDate") as? Date,
                       let endDate = cycle.value(forKey: "endDate") as? Date {
                        if startDate >= endDate {
                            issues.append(IntegrityIssue(
                                severity: .error,
                                description: "开始日期晚于或等于结束日期",
                                entityType: "OKRCycleEntity",
                                entityId: cycleId
                            ))
                        }
                    }
                }
            } catch {
                issues.append(IntegrityIssue(
                    severity: .critical,
                    description: "无法读取周期数据: \(error.localizedDescription)",
                    entityType: "OKRCycleEntity",
                    entityId: nil
                ))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return IntegrityCheckResult(
            isHealthy: issues.isEmpty,
            issues: issues,
            totalEntitiesChecked: totalChecked,
            duration: duration
        )
    }

    // MARK: - Storage Statistics

    /// 存储统计信息
    public struct StorageStatistics: Sendable {
        /// 数据库文件大小（字节）
        public let databaseSize: Int64
        /// 备份文件总大小（字节）
        public let backupSize: Int64
        /// 节点总数
        public let nodeCount: Int
        /// 周期总数
        public let cycleCount: Int
        /// 评论总数
        public let commentCount: Int
        /// 格式化的数据库大小
        public var formattedDatabaseSize: String {
            formatBytes(databaseSize)
        }
        /// 格式化的备份大小
        public var formattedBackupSize: String {
            formatBytes(backupSize)
        }
        /// 格式化的总大小
        public var formattedTotalSize: String {
            formatBytes(databaseSize + backupSize)
        }

        private func formatBytes(_ bytes: Int64) -> String {
            if bytes < 1024 { return "\(bytes) B" }
            if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
            if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0)) }
            return String(format: "%.2f GB", Double(bytes) / (1024.0 * 1024.0 * 1024.0))
        }
    }

    /// 获取存储统计信息
    public func getStorageStatistics() -> StorageStatistics {
        let fileManager = FileManager.default
        var databaseSize: Int64 = 0
        var backupSize: Int64 = 0
        var nodeCount = 0
        var cycleCount = 0
        var commentCount = 0

        // 计算数据库大小
        if let storeURL = persistenceController.container
            .persistentStoreCoordinator
            .persistentStores.first?.url {
            // 计算主数据库及相关文件大小
            let relatedExtensions = ["", "-wal", "-shm", "-journal"]
            for ext in relatedExtensions {
                let fileURL: URL
                if ext.isEmpty {
                    fileURL = storeURL
                } else {
                    fileURL = storeURL.appendingPathExtension(ext)
                }
                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let size = attrs[.size] as? Int64 {
                    databaseSize += size
                }
            }
        }

        // 计算备份文件大小
        if let storeURL = persistenceController.container
            .persistentStoreCoordinator
            .persistentStores.first?.url {
            let backupDir = storeURL.deletingLastPathComponent()
            if let files = try? fileManager.contentsOfDirectory(
                at: backupDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            ) {
                for file in files where file.lastPathComponent.hasPrefix("OKRAlignment_backup_") {
                    if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                       let size = attrs[.size] as? Int64 {
                        backupSize += size
                    }
                }
            }
        }

        // 统计实体数量
        let context = persistenceController.container.viewContext
        let nodeRequest = NSFetchRequest<NSManagedObject>(entityName: "OKRNodeEntity")
        nodeCount = (try? context.count(for: nodeRequest)) ?? 0

        let cycleRequest = NSFetchRequest<NSManagedObject>(entityName: "OKRCycleEntity")
        cycleCount = (try? context.count(for: cycleRequest)) ?? 0

        let commentRequest = NSFetchRequest<NSManagedObject>(entityName: "CommentEntity")
        commentCount = (try? context.count(for: commentRequest)) ?? 0

        return StorageStatistics(
            databaseSize: databaseSize,
            backupSize: backupSize,
            nodeCount: nodeCount,
            cycleCount: cycleCount,
            commentCount: commentCount
        )
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
