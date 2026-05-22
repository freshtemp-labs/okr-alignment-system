// OKRAlignmentShared/Utils/AppErrorHandler.swift

import Foundation
import os

/// 统一错误处理框架
///
/// 提供：
/// - 统一的错误类型定义
/// - 用户友好的错误消息
/// - 错误日志记录与持久化
/// - 网络错误重试机制
///
/// ## 使用方式
/// ```swift
/// do {
///     try someOperation()
/// } catch {
///     AppErrorHandler.shared.handle(error, context: "保存节点")
/// }
/// ```
public final class AppErrorHandler: @unchecked Sendable {

    // MARK: - Shared Instance

    public static let shared = AppErrorHandler()

    // MARK: - Properties

    /// 错误日志存储路径
    private let logFileURL: URL

    /// 最大日志条数
    private let maxLogEntries = 500

    /// 内存中的错误日志缓存
    private var logCache: [ErrorLogEntry] = []

    /// 线程安全锁
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDir = documentsDir.appendingPathComponent("ErrorLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.logFileURL = logsDir.appendingPathComponent("error_log.json")

        // 加载已有日志
        loadLogs()
    }

    // MARK: - Error Types

    /// 应用级统一错误类型
    public enum AppError: Error, Sendable, Identifiable {
        case dataStore(DataStoreError)
        case network(NetworkError)
        case validation(String)
        case backup(BackupError)
        case encryption(EncryptionError)
        case biometric(BiometricError)
        case unknown(String)

        public var id: String { localizedDescription }

        /// 用户友好的错误消息
        public var userMessage: String {
            switch self {
            case .dataStore(let err): return err.userMessage
            case .network(let err): return err.userMessage
            case .validation(let msg): return msg
            case .backup(let err): return err.userMessage
            case .encryption(let err): return err.userMessage
            case .biometric(let err): return err.userMessage
            case .unknown(let msg): return "未知错误：\(msg)"
            }
        }

        /// 错误标题
        public var title: String {
            switch self {
            case .dataStore: return "数据存储错误"
            case .network: return "网络错误"
            case .validation: return "数据验证错误"
            case .backup: return "备份错误"
            case .encryption: return "加密错误"
            case .biometric: return "身份验证错误"
            case .unknown: return "未知错误"
            }
        }

        /// 错误严重程度
        public var severity: ErrorSeverity {
            switch self {
            case .dataStore: return .critical
            case .network: return .warning
            case .validation: return .info
            case .backup: return .warning
            case .encryption: return .critical
            case .biometric: return .warning
            case .unknown: return .error
            }
        }
    }

    /// 错误严重程度
    public enum ErrorSeverity: String, Sendable, Codable {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"

        public var iconName: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .critical: return "xmark.octagon"
            }
        }
    }

    /// 数据存储错误
    public enum DataStoreError: Error, Sendable {
        case loadFailed(String)
        case saveFailed(String)
        case migrationFailed(String)
        case corruptedData
        case entityNotFound

        public var userMessage: String {
            switch self {
            case .loadFailed: return "数据加载失败，请重试"
            case .saveFailed: return "数据保存失败，请检查存储空间"
            case .migrationFailed: return "数据迁移失败，请联系技术支持"
            case .corruptedData: return "数据损坏，建议从备份恢复"
            case .entityNotFound: return "未找到请求的数据"
            }
        }
    }

    /// 网络错误
    public enum NetworkError: Error, Sendable {
        case noConnection
        case timeout
        case serverError(Int)
        case rateLimited

        public var userMessage: String {
            switch self {
            case .noConnection: return "网络连接不可用，请检查网络设置"
            case .timeout: return "请求超时，请稍后重试"
            case .serverError(let code): return "服务器错误（\(code)），请稍后重试"
            case .rateLimited: return "请求过于频繁，请稍后重试"
            }
        }

        /// 是否可重试
        public var isRetryable: Bool {
            switch self {
            case .noConnection, .timeout, .serverError, .rateLimited:
                return true
            }
        }
    }

    /// 备份错误
    public enum BackupError: Error, Sendable {
        case creationFailed(String)
        case restoreFailed(String)
        case fileNotFound
        case diskSpaceInsufficient

        public var userMessage: String {
            switch self {
            case .creationFailed: return "备份创建失败"
            case .restoreFailed: return "备份恢复失败"
            case .fileNotFound: return "备份文件不存在"
            case .diskSpaceInsufficient: return "磁盘空间不足，无法创建备份"
            }
        }
    }

    /// 加密错误
    public enum EncryptionError: Error, Sendable {
        case keyGenerationFailed
        case encryptionFailed
        case decryptionFailed
        case protectionLevelNotSupported

        public var userMessage: String {
            switch self {
            case .keyGenerationFailed: return "加密密钥生成失败"
            case .encryptionFailed: return "数据加密失败"
            case .decryptionFailed: return "数据解密失败"
            case .protectionLevelNotSupported: return "当前设备不支持此加密级别"
            }
        }
    }

    /// 生物识别错误
    public enum BiometricError: Error, Sendable {
        case notAvailable
        case notEnrolled
        case authenticationFailed
        case userCancelled
        case passcodeNotSet

        public var userMessage: String {
            switch self {
            case .notAvailable: return "当前设备不支持生物识别"
            case .notEnrolled: return "请先在系统设置中录入生物识别信息"
            case .authenticationFailed: return "身份验证失败，请重试"
            case .userCancelled: return "身份验证已取消"
            case .passcodeNotSet: return "请先在系统设置中设置密码"
            }
        }
    }

    // MARK: - Error Log Entry

    /// 错误日志条目
    public struct ErrorLogEntry: Codable, Identifiable, Sendable {
        public let id: UUID
        public let timestamp: Date
        public let severity: String
        public let title: String
        public let message: String
        public let context: String?
        public let file: String
        public let line: Int

        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            severity: ErrorSeverity,
            title: String,
            message: String,
            context: String? = nil,
            file: String = #file,
            line: Int = #line
        ) {
            self.id = id
            self.timestamp = timestamp
            self.severity = severity.rawValue
            self.title = title
            self.message = message
            self.context = context
            self.file = URL(fileURLWithPath: file).lastPathComponent
            self.line = line
        }
    }

    // MARK: - Public Methods

    /// 处理错误并记录日志
    /// - Parameters:
    ///   - error: 捕获的错误
    ///   - context: 错误发生的上下文描述
    ///   - file: 源文件（自动捕获）
    ///   - line: 行号（自动捕获）
    public func handle(
        _ error: Error,
        context: String? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        let appError: AppError
        if let existing = error as? AppError {
            appError = existing
        } else {
            appError = .unknown(error.localizedDescription)
        }

        Logger.app.error("[\(appError.severity.rawValue)] \(appError.title): \(appError.userMessage) | Context: \(context ?? "N/A")")

        let entry = ErrorLogEntry(
            severity: appError.severity,
            title: appError.title,
            message: appError.userMessage,
            context: context,
            file: file,
            line: line
        )

        appendLog(entry)
    }

    /// 记录自定义错误日志
    public func log(
        severity: ErrorSeverity,
        title: String,
        message: String,
        context: String? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        let entry = ErrorLogEntry(
            severity: severity,
            title: title,
            message: message,
            context: context,
            file: file,
            line: line
        )
        appendLog(entry)
    }

    /// 获取所有错误日志
    public func allLogs() -> [ErrorLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return logCache.sorted { $0.timestamp > $1.timestamp }
    }

    /// 清除所有错误日志
    public func clearLogs() {
        lock.lock()
        logCache.removeAll()
        lock.unlock()
        saveLogs()
    }

    // MARK: - Retry Mechanism

    /// 带重试机制的异步操作执行
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（默认3）
    ///   - delay: 重试间隔（秒，默认1.0，指数退避）
    ///   - context: 操作上下文描述
    ///   - operation: 要执行的异步操作
    /// - Returns: 操作结果
    public func withRetry<T: Sendable>(
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0,
        context: String = "",
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // 检查是否为可重试错误
                if let appError = error as? AppError,
                   case .network(let netErr) = appError,
                   !netErr.isRetryable {
                    throw error
                }

                if attempt < maxRetries {
                    let retryDelay = delay * pow(2.0, Double(attempt))
                    Logger.app.warning("操作失败（第\(attempt + 1)次重试，\(retryDelay)秒后）: \(error.localizedDescription) | \(context)")
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }

        let finalError = lastError ?? AppError.unknown("重试耗尽")
        handle(finalError, context: "重试失败: \(context)")
        throw finalError
    }

    // MARK: - Private Methods

    private func appendLog(_ entry: ErrorLogEntry) {
        lock.lock()
        logCache.append(entry)
        // 超过上限时移除最旧的日志
        if logCache.count > maxLogEntries {
            logCache.removeFirst(logCache.count - maxLogEntries)
        }
        lock.unlock()
        saveLogs()
    }

    private func loadLogs() {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: logFileURL)
            let entries = try JSONDecoder().decode([ErrorLogEntry].self, from: data)
            lock.lock()
            logCache = entries
            lock.unlock()
        } catch {
            Logger.app.warning("加载错误日志失败: \(error.localizedDescription)")
        }
    }

    private func saveLogs() {
        lock.lock()
        let entries = logCache
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: logFileURL, options: .atomic)
        } catch {
            Logger.app.warning("保存错误日志失败: \(error.localizedDescription)")
        }
    }
}
