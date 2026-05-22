// OKRAlignmentShared/Services/ShortcutsService.swift

import Foundation
#if canImport(AppIntents)
import AppIntents
#endif

/// OKR 快捷指令服务
///
/// 提供与 Siri 快捷指令和 Shortcuts App 的集成，支持：
/// - "查看我的 OKR 进度" - 查询并播报当前活跃周期的整体进度
/// - "更新 KR 进度" - 通过语音或快捷指令更新指定 KR 的当前值
///
/// ## 使用前提
/// - 需要 iOS 16+ / macOS 13+ 才能使用 AppIntents 框架
/// - 需要在 App 启动时注册 Intent
///
/// ## 使用示例
/// ```swift
/// // App 启动时注册
/// ShortcutsService.setupShortcuts()
/// ```
public final class ShortcutsService: Sendable {

    public init() {}

    /// 注册快捷指令并在 Shortcuts App 中展示
    ///
    /// 在 App 启动时调用，向系统注册所有可用的快捷指令。
    public static func setupShortcuts() {
        #if canImport(AppIntents)
        if #available(iOS 16.0, macOS 13.0, *) {
            // AppShortcuts 在 AppIntent 的 shortcuts 属性中定义
            // 此方法可用于额外的配置
        }
        #endif
    }
}

// MARK: - AppIntents

#if canImport(AppIntents)

/// 查看 OKR 进度的快捷指令
///
/// 用户可以通过 Siri 说 "查看我的 OKR 进度" 或在 Shortcuts App 中使用此指令。
/// 返回当前活跃周期的进度摘要。
@available(iOS 16.0, macOS 13.0, *)
public struct ViewOKRProgressIntent: AppIntent {

    public static let title: LocalizedStringResource = "查看 OKR 进度"
    public static let description = IntentDescription("查看当前活跃 OKR 周期的整体进度")

    /// 在 Shortcuts App 和 Siri 建议中展示
    public static var parameterSummary: some ParameterSummary {
        Summary("查看当前 OKR 进度")
    }

    /// 触发短语
    public static let openAppWhenRun: Bool = false

    /// 依赖的仓库（通过依赖注入设置）
    @Dependency
    var repository: any OKRRepositoryProtocol

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let cycles = try await repository.fetchCycles()

        // 查找活跃周期
        guard let activeCycle = cycles.first(where: { $0.isActive && !$0.isArchived }) else {
            return .result(dialog: "当前没有活跃的 OKR 周期。")
        }

        // 获取该周期的所有根节点
        let rootNodes = try await repository.fetchRootNodes(cycleId: activeCycle.id)

        guard !rootNodes.isEmpty else {
            return .result(dialog: "当前周期「\(activeCycle.name)」暂无 OKR 节点。")
        }

        // 计算整体进度
        let totalProgress = rootNodes.map(\.progress).reduce(0, +) / Double(rootNodes.count)
        let completedCount = rootNodes.filter { $0.status == .completed }.count

        let summary = """
        当前周期：\(activeCycle.name)
        时间进度：\(String(format: "%.0f%%", activeCycle.timeProgressPercentage))
        OKR 数量：\(rootNodes.count) 个
        已完成：\(completedCount) 个
        平均进度：\(String(format: "%.1f%%", totalProgress))
        """

        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

/// 更新 KR 进度的快捷指令
///
/// 用户可以通过 Siri 说 "更新 KR 进度" 或在 Shortcuts App 中使用此指令。
/// 接收 KR 标题和新值作为参数。
@available(iOS 16.0, macOS 13.0, *)
public struct UpdateKRProgressIntent: AppIntent {

    public static let title: LocalizedStringResource = "更新 KR 进度"
    public static let description = IntentDescription("更新指定关键结果的当前进度值")

    public static var parameterSummary: some ParameterSummary {
        Summary("将 \(\.$krTitle) 的进度更新为 \(\.$newValue)")
    }

    /// KR 标题（用于匹配节点）
    @Parameter(title: "KR 标题", description: "要更新的关键结果标题")
    var krTitle: String

    /// 新的进度值
    @Parameter(title: "新进度值", description: "关键结果的新当前值")
    var newValue: Double

    @Dependency
    var repository: any OKRRepositoryProtocol

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // 获取所有活跃周期
        let cycles = try await repository.fetchCycles()
        let activeCycles = cycles.filter { $0.isActive && !$0.isArchived }

        guard !activeCycles.isEmpty else {
            return .result(dialog: "当前没有活跃的 OKR 周期。")
        }

        // 在所有活跃周期中搜索匹配的 KR
        for cycle in activeCycles {
            let rootNodes = try await repository.fetchRootNodes(cycleId: cycle.id)
            if let node = findLeafKR(titled: krTitle, in: rootNodes) {
                let updatedNode = try await repository.updateLeafValue(
                    nodeId: node.id,
                    newValue: newValue
                )

                return .result(
                    dialog: "已将「\(updatedNode.title)」更新为 \(Int(newValue))，当前进度 \(updatedNode.progressPercentage)。"
                )
            }
        }

        return .result(dialog: "未找到标题包含「\(krTitle)」的关键结果。")
    }

    /// 递归查找标题匹配的叶子 KR 节点
    private func findLeafKR(titled title: String, in nodes: [OKRNode]) -> OKRNode? {
        for node in nodes {
            // 精确匹配或包含匹配
            if node.isLeaf && (node.title == title || node.title.contains(title)) {
                return node
            }
            if let found = findLeafKR(titled: title, in: node.children) {
                return found
            }
        }
        return nil
    }
}

/// OKR 快捷指令集合
///
/// 定义所有可用的 App Shortcuts，在 Shortcuts App 和 Siri 建议中展示。
@available(iOS 16.0, macOS 13.0, *)
public struct OKRShortcutsProvider: AppShortcutsProvider {

    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ViewOKRProgressIntent(),
            phrases: [
                "查看我的 \(.applicationName) 进度",
                "查看 \(.applicationName) OKR 进度",
                "我的 OKR 进度如何"
            ],
            shortTitle: "查看 OKR 进度",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: UpdateKRProgressIntent(),
            phrases: [
                "更新 \(.applicationName) KR 进度",
                "更新 \(.applicationName) 关键结果"
            ],
            shortTitle: "更新 KR 进度",
            systemImageName: "arrow.up.circle.fill"
        )
    }
}

// MARK: - Dependency Injection for AppIntents

/// AppIntents 依赖注入容器
///
/// 为 AppIntents 提供仓库实例的访问。
/// 需要在 App 启动时通过 `configure` 注入实际的仓库实例。
@available(iOS 16.0, macOS 13.0, *)
public final class IntentDependencyContainer: @unchecked Sendable {

    /// 共享实例
    public static let shared = IntentDependencyContainer()

    /// 注入的仓库实例
    private var _repository: (any OKRRepositoryProtocol)?

    private init() {}

    /// 配置依赖注入容器
    ///
    /// 在 App 启动时调用，注入实际的仓库实例。
    ///
    /// - Parameter repository: OKR 数据仓库
    public func configure(repository: any OKRRepositoryProtocol) {
        self._repository = repository
    }

    /// 获取仓库实例
    ///
    /// - Returns: 注入的仓库实例
    /// - Throws: 若未配置则抛出错误
    public func repository() throws -> any OKRRepositoryProtocol {
        guard let repo = _repository else {
            fatalError("IntentDependencyContainer 未配置。请在 App 启动时调用 configure(repository:)。")
        }
        return repo
    }
}

#endif // canImport(AppIntents)
