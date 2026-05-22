// OKRAlignmentShared/Services/AutoBackupManager.swift

import Foundation
import os
import CoreData

/// 自动备份管理器
///
/// 功能：
/// - 每天自动备份 CoreData 数据库到 Documents/Backups
/// - 保留最近 7 天的备份
/// - 支持从备份恢复
/// - 备份文件使用时间戳命名
///
/// ## 备份策略
/// - 备份存储在 Documents/Backups/ 目录
/// - 文件名格式: okr_backup_yyyy-MM-dd_HH-mm-ss.sqlite
/// - 保留最近 7 天的备份，自动清理旧备份
/// - 每次应用启动时检查是否需要备份
public final class AutoBackupManager: @unchecked Sendable {

    // MARK: - Shared Instance

    public static let shared = AutoBackupManager()

    // MARK: - Constants

    private static let lastBackupDateKey = "okr_last_backup_date"
    private static let maxBackupDays = 7
    private static let backupDirectoryName = "Backups"

    // MARK: - Properties

    /// 备份目录 URL
    public let backupDirectory: URL

    /// 上次备份时间
    public var lastBackupDate: Date? {
        get {
            UserDefaults.standard.object(forKey: Self.lastBackupDateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.lastBackupDateKey)
        }
    }

    // MARK: - Initialization

    private init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.backupDirectory = documentsDir.appendingPathComponent(Self.backupDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Backup Info

    /// 备份文件信息
    public struct BackupInfo: Identifiable, Sendable {
        public let id: String
        public let fileName: String
        public let date: Date
        public let fileSize: Int64

        public var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: fileSize)
        }

        public var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        }
    }

    // MARK: - Public Methods

    /// 检查是否需要执行每日备份
    /// 应在应用启动时调用
    public func checkAndAutoBackupIfNeeded() {
        guard let lastBackup = lastBackupDate else {
            // 从未备份过，立即执行
            Task { await performBackup() }
            return
        }

        let calendar = Calendar.current
        if !calendar.isDateInToday(lastBackup) {
            // 今天还没有备份
            Task { await performBackup() }
        }
    }

    /// 执行备份操作
    /// - Parameter context: 可选的 CoreData 上下文（默认使用 PersistenceController 的上下文）
    /// - Returns: 备份是否成功
    @discardableResult
    public func performBackup(context: NSManagedObjectContext? = nil) async -> Bool {
        Logger.app.info("开始执行自动备份...")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let backupFileName = "okr_backup_\(timestamp).sqlite"
        let backupURL = backupDirectory.appendingPathComponent(backupFileName)

        // 获取 CoreData 存储文件路径
        let storeURL = CoreDataStoreURL
        guard let storeURL = storeURL else {
            AppErrorHandler.shared.handle(
                AppErrorHandler.AppError.backup(.creationFailed("无法获取数据存储路径")),
                context: "自动备份"
            )
            return false
        }

        // 检查源文件是否存在
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            AppErrorHandler.shared.handle(
                AppErrorHandler.AppError.backup(.creationFailed("数据存储文件不存在")),
                context: "自动备份"
            )
            return false
        }

        // 执行备份（复制 SQLite 及相关文件）
        do {
            let fileManager = FileManager.default
            // 复制主 .sqlite 文件
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: storeURL, to: backupURL)

            // 复制 WAL 和 SHM 文件（如果存在）
            let walSource = storeURL.appendingPathExtension("wal")
            let shmSource = storeURL.appendingPathExtension("shm")
            let walDest = backupURL.appendingPathExtension("wal")
            let shmDest = backupURL.appendingPathExtension("shm")

            if fileManager.fileExists(atPath: walSource.path) {
                try? fileManager.copyItem(at: walSource, to: walDest)
            }
            if fileManager.fileExists(atPath: shmSource.path) {
                try? fileManager.copyItem(at: shmSource, to: shmDest)
            }

            // 更新最后备份时间
            lastBackupDate = Date()

            // 清理旧备份
            cleanOldBackups()

            Logger.app.info("自动备份完成: \(backupFileName)")
            return true
        } catch {
            AppErrorHandler.shared.handle(
                AppErrorHandler.AppError.backup(.creationFailed(error.localizedDescription)),
                context: "自动备份"
            )
            return false
        }
    }

    /// 获取所有备份列表
    /// - Returns: 按时间倒序排列的备份信息数组
    public func listBackups() -> [BackupInfo] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        var backups: [BackupInfo] = []

        for file in files where file.pathExtension == "sqlite" {
            let fileName = file.lastPathComponent
            guard fileName.hasPrefix("okr_backup_") else { continue }

            let resources = try? file.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let date = resources?.creationDate ?? Date()
            let size = Int64(resources?.fileSize ?? 0)

            backups.append(BackupInfo(
                id: fileName,
                fileName: fileName,
                date: date,
                fileSize: size
            ))
        }

        return backups.sorted { $0.date > $1.date }
    }

    /// 从备份恢复数据
    /// - Parameter backupInfo: 要恢复的备份信息
    /// - Returns: 恢复是否成功
    public func restoreFromBackup(_ backupInfo: BackupInfo) async -> Bool {
        let backupURL = backupDirectory.appendingPathComponent(backupInfo.fileName)

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            AppErrorHandler.shared.handle(
                AppErrorHandler.AppError.backup(.fileNotFound),
                context: "备份恢复"
            )
            return false
        }

        guard let storeURL = CoreDataStoreURL else {
            AppErrorHandler.shared.handle(
                AppErrorHandler.AppError.backup(.restoreFailed("无法获取数据存储路径")),
                context: "备份恢复"
            )
            return false
        }

        do {
            let fileManager = FileManager.default

            // 先创建当前数据的临时备份
            let tempBackup = backupDirectory.appendingPathComponent("pre_restore_temp.sqlite")
            if fileManager.fileExists(atPath: tempBackup.path) {
                try fileManager.removeItem(at: tempBackup)
            }
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.copyItem(at: storeURL, to: tempBackup)
            }

            // 替换当前存储文件
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
            }
            try fileManager.copyItem(at: backupURL, to: storeURL)

            Logger.app.info("备份恢复成功: \(backupInfo.fileName)")
            return true
        } catch {
            AppErrorHandler.shared.handle(
                AppErrorHandler.AppError.backup(.restoreFailed(error.localizedDescription)),
                context: "备份恢复"
            )
            return false
        }
    }

    /// 删除指定备份
    /// - Parameter backupInfo: 要删除的备份信息
    public func deleteBackup(_ backupInfo: BackupInfo) {
        let backupURL = backupDirectory.appendingPathComponent(backupInfo.fileName)
        try? FileManager.default.removeItem(at: backupURL)
        Logger.app.info("已删除备份: \(backupInfo.fileName)")
    }

    /// 删除所有备份
    public func deleteAllBackups() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            try? fileManager.removeItem(at: file)
        }
        Logger.app.info("已删除所有备份")
    }

    // MARK: - Private Methods

    /// CoreData 存储文件的 URL
    private var CoreDataStoreURL: URL? {
        let storeURL = PersistenceController.shared.container.persistentStoreDescriptions.first?.url
        return storeURL
    }

    /// 清理超过保留天数的旧备份
    private func cleanOldBackups() {
        let backups = listBackups()
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -Self.maxBackupDays, to: Date()) ?? Date()

        for backup in backups where backup.date < cutoffDate {
            deleteBackup(backup)
            Logger.app.info("已清理过期备份: \(backup.fileName)")
        }
    }
}
