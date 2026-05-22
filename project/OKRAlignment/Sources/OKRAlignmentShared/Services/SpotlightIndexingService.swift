// OKRAlignmentShared/Services/SpotlightIndexingService.swift

import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Spotlight 搜索索引服务
///
/// 负责将 OKR 节点索引到系统 Spotlight 搜索，使用户可以通过
/// 系统搜索直接找到 OKR 节点并跳转到 App 中对应位置。
///
/// ## 功能特性
/// - App 启动时批量索引所有活跃 OKR 节点
/// - 增量更新：创建/修改/删除节点时同步更新索引
/// - 支持按标题、描述、负责人搜索
/// - 点击搜索结果可通过 `NSUserActivity` 定位到节点
///
/// ## 使用示例
/// ```swift
/// let indexingService = SpotlightIndexingService()
/// // 启动时索引所有节点
/// try await indexingService.indexNodes(nodes)
/// // 单个节点更新
/// try await indexingService.indexNode(node)
/// // 删除节点索引
/// try await indexingService.removeNodeIndex(nodeId: node.id)
/// ```
public final class SpotlightIndexingService: Sendable {

    // MARK: - Constants

    /// Spotlight 可搜索项的域名标识符
    public static let domainIdentifier = "com.okralignment.node"

    /// 用户信息中存储节点 ID 的键
    public static let nodeIdUserInfoKey = "okr_node_id"

    // MARK: - Initialization

    public init() {}

    // MARK: - Batch Indexing

    /// 批量索引所有 OKR 节点到 Spotlight
    ///
    /// 通常在 App 启动时调用，将所有活跃的 OKR 节点添加到系统搜索索引。
    /// 已存在的节点会被更新，不会产生重复索引。
    ///
    /// - Parameter nodes: 要索引的节点数组
    /// - Throws: 索引错误
    public func indexNodes(_ nodes: [OKRNode]) async throws {
        let searchableItems = nodes.map { createSearchableItem(from: $0) }

        // 分批索引，每批最多 100 个，避免内存压力
        let batchSize = 100
        for batchStart in stride(from: 0, to: searchableItems.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, searchableItems.count)
            let batch = Array(searchableItems[batchStart..<batchEnd])

            try await CSSearchableIndex.default().indexSearchableItems(batch)
        }
    }

    /// 索引单个 OKR 节点到 Spotlight
    ///
    /// 在创建或更新节点后调用，同步更新搜索索引。
    ///
    /// - Parameter node: 要索引的节点
    /// - Throws: 索引错误
    public func indexNode(_ node: OKRNode) async throws {
        let searchableItem = createSearchableItem(from: node)
        try await CSSearchableIndex.default().indexSearchableItems([searchableItem])
    }

    // MARK: - Remove Index

    /// 移除指定节点的 Spotlight 索引
    ///
    /// 在删除节点后调用，确保搜索结果中不再显示已删除的节点。
    ///
    /// - Parameter nodeId: 要移除索引的节点 ID
    /// - Throws: 移除错误
    public func removeNodeIndex(nodeId: UUID) async throws {
        let identifier = SpotlightIndexingService.identifier(for: nodeId)
        try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier])
    }

    /// 移除指定节点数组的 Spotlight 索引
    ///
    /// - Parameter nodeIds: 要移除索引的节点 ID 数组
    /// - Throws: 移除错误
    public func removeNodeIndexes(nodeIds: [UUID]) async throws {
        let identifiers = nodeIds.map { SpotlightIndexingService.identifier(for: $0) }
        try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
    }

    /// 清除所有 OKR 节点的 Spotlight 索引
    ///
    /// 用于数据重置或用户退出登录时清理索引。
    ///
    /// - Throws: 清除错误
    public func clearAllIndexes() async throws {
        try await CSSearchableIndex.default()
            .deleteSearchableItems(withDomainIdentifiers: [SpotlightIndexingService.domainIdentifier])
    }

    // MARK: - Spotlight Result Handling

    /// 从 Spotlight 搜索结果的 `NSUserActivity` 中提取节点 ID
    ///
    /// 当用户通过 Spotlight 点击搜索结果进入 App 时，调用此方法
    /// 从 `NSUserActivity` 中解析出对应的 OKR 节点 ID。
    ///
    /// - Parameter activity: 系统传入的 `NSUserActivity`
    /// - Returns: 对应的节点 ID，若无法解析则返回 `nil`
    public static func nodeIdFromActivity(_ activity: NSUserActivity) -> UUID? {
        guard activity.activityType == CSSearchableItemActionType,
              let userInfo = activity.userInfo,
              let identifier = userInfo[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }
        return UUID(uuidString: identifier)
    }

    // MARK: - Private Helpers

    /// 生成节点的 Spotlight 标识符
    static func identifier(for nodeId: UUID) -> String {
        "\(domainIdentifier).\(nodeId.uuidString)"
    }

    /// 从 OKR 领域模型创建 Spotlight 可搜索项
    private func createSearchableItem(from node: OKRNode) -> CSSearchableItem {
        let identifier = SpotlightIndexingService.identifier(for: node.id)
        let attributeSet = createAttributeSet(from: node)

        return CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: SpotlightIndexingService.domainIdentifier,
            attributeSet: attributeSet
        )
    }

    /// 创建可搜索项的属性集
    private func createAttributeSet(from node: OKRNode) -> CSSearchableItemAttributeSet {
        // 使用 kUTTypeItem 作为内容类型
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)

        // 标题：节点标题
        attributeSet.title = node.title

        // 描述：包含类型、范围、负责人、进度信息
        var descriptionParts: [String] = []
        if let desc = node.nodeDescription, !desc.isEmpty {
            descriptionParts.append(desc)
        }
        descriptionParts.append("类型: \(node.nodeType.displayName)")
        descriptionParts.append("范围: \(node.scope.displayName)")
        descriptionParts.append("负责人: \(node.ownerName)")
        descriptionParts.append("进度: \(node.progressPercentage)")
        descriptionParts.append("状态: \(node.status.displayName)")

        attributeSet.contentDescription = descriptionParts.joined(separator: " | ")

        // 关键词：用于搜索匹配
        var keywords: [String] = [
            node.title,
            node.nodeType.displayName,
            node.scope.displayName,
            node.ownerName,
            node.status.displayName,
            "OKR"
        ]
        if let unit = node.unit {
            keywords.append(unit)
        }
        attributeSet.keywords = keywords

        // 附加元数据
        attributeSet.creator = node.ownerName
        attributeSet.startDate = node.createdAt
        attributeSet.endDate = node.updatedAt

        // 主题：用于分类
        attributeSet.subject = "\(node.scope.displayName) \(node.nodeType.displayName)"

        return attributeSet
    }
}
