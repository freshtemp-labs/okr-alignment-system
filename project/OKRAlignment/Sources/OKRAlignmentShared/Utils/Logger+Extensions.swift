// OKRAlignmentShared/Utils/Logger+Extensions.swift

import Foundation
import os

/// 统一日志扩展
///
/// 为整个应用提供统一的 `os.Logger` 实例，替代 `print()` 和 `debugPrint()`。
/// 使用 `os.Logger` 的好处：
/// - 在 Release 构建中自动抑制 Debug 级别日志
/// - 与 Console.app 和 `log` 命令行工具集成
/// - 支持隐私标记（公开/私有）
/// - 线程安全
///
/// ## 使用方式
/// ```swift
/// Logger.app.info("用户登录成功")
/// Logger.app.error("数据库操作失败: \(error.localizedDescription)")
/// Logger.app.debug("调试信息: \(someValue, privacy: .public)")
/// ```
extension Logger {
    /// 应用统一日志实例
    /// - subsystem: 使用应用的 bundle identifier，便于在 Console.app 中过滤
    /// - category: "app" 作为默认分类
    static let app = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.okr.alignment",
        category: "app"
    )

    /// 数据层日志实例
    /// 用于 CoreData 操作、Repository 和 Mapper 层的日志输出
    static let data = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.okr.alignment",
        category: "data"
    )

    /// 业务逻辑层日志实例
    /// 用于级联计算引擎、验证器等业务逻辑的日志输出
    static let domain = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.okr.alignment",
        category: "domain"
    )
}
