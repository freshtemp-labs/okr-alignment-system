import Foundation
import SwiftUI

/// ====================================================================
/// MARK: - BatchOperationViewModel
/// ====================================================================

/// 批量操作ViewModel
/// ================
/// 支持对多个OKR节点执行批量操作。
///
/// # 支持的操作
/// - 多选节点（Cmd+Click 切换选中状态）
/// - 批量删除选中节点
/// - 批量更新Owner
/// - 批量导出选中节点
///
@MainActor
@Observable
public final class BatchOperationViewModel {

    // MARK: - 发布状态属性

    /// 当前选中的节点ID集合
    public var selectedNodeIds: Set<UUID> = []

    /// 是否处于多选模式
    public var isMultiSelectMode: Bool = false

    /// 操作状态消息
    public var operationMessage: String?

    /// 是否正在执行操作
    public var isOperating: Bool = false

    /// 批量删除确认对话框状态
    public var showDeleteConfirmation: Bool = false

    /// 批量更新Owner对话框状态
    public var showOwnerUpdateSheet: Bool = false

    /// 新的Owner名称（用于批量更新）
    public var newOwnerName: String = ""

    /// 待删除节点的子节点警告信息
    public var deleteWarningMessage: String?

    // MARK: - 依赖

    private let repository: OKRRepositoryProtocol

    // MARK: - 初始化

    public init(repository: OKRRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - 计算属性

    /// 选中的节点数量
    public var selectedCount: Int {
        selectedNodeIds.count
    }

    /// 是否有选中节点
    public var hasSelection: Bool {
        !selectedNodeIds.isEmpty
    }

    // MARK: - 公开接口: 选择管理

    /// 切换节点的选中状态
    /// - Parameter nodeId: 要切换的节点ID
    public func toggleSelection(_ nodeId: UUID) {
        if selectedNodeIds.contains(nodeId) {
            selectedNodeIds.remove(nodeId)
        } else {
            selectedNodeIds.insert(nodeId)
        }
    }

    /// 选中节点
    /// - Parameter nodeId: 要选中的节点ID
    public func select(_ nodeId: UUID) {
        selectedNodeIds.insert(nodeId)
    }

    /// 取消选中节点
    /// - Parameter nodeId: 要取消选中的节点ID
    public func deselect(_ nodeId: UUID) {
        selectedNodeIds.remove(nodeId)
    }

    /// 全选
    /// - Parameter nodeIds: 所有可选节点ID
    public func selectAll(_ nodeIds: [UUID]) {
        selectedNodeIds = Set(nodeIds)
    }

    /// 取消全部选择
    public func deselectAll() {
        selectedNodeIds.removeAll()
    }

    /// 进入/退出多选模式
    public func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            selectedNodeIds.removeAll()
        }
    }

    // MARK: - 公开接口: 批量删除

    /// 计算待删除节点的子节点警告信息
    /// - Parameters:
    ///   - selectedIds: 选中的节点ID集合
    ///   - root: 树的根节点
    /// - Returns: 警告信息（包含将被级联删除的子节点数量）
    public func calculateDeleteWarning(selectedIds: Set<UUID>, in root: OKRNode) -> String {
        var totalChildCount = 0
        for id in selectedIds {
            if let node = findNode(in: root, id: id) {
                totalChildCount += countDescendants(node)
            }
        }

        if totalChildCount > 0 {
            return "将同时删除 \(totalChildCount) 个子节点"
        }
        return ""
    }

    /// 批量删除选中节点
    /// - Parameters:
    ///   - selectedIds: 选中的节点ID集合
    ///   - root: 树的根节点（用于刷新）
    /// - Returns: 删除后需要刷新
    public func batchDelete(selectedIds: Set<UUID>, in root: OKRNode) async -> Bool {
        isOperating = true
        operationMessage = nil

        do {
            for id in selectedIds {
                try await repository.deleteNode(id: id, cascade: true)
            }
            try await repository.save()
            operationMessage = "已删除 \(selectedIds.count) 个节点"
            selectedNodeIds.removeAll()
            isOperating = false
            return true
        } catch {
            operationMessage = "批量删除失败: \(error.localizedDescription)"
            isOperating = false
            return false
        }
    }

    // MARK: - 公开接口: 批量更新Owner

    /// 批量更新选中节点的Owner
    /// - Parameters:
    ///   - newOwner: 新的Owner名称
    ///   - selectedIds: 选中的节点ID集合
    ///   - root: 树的根节点
    /// - Returns: 更新后的根节点
    public func batchUpdateOwner(
        newOwner: String,
        selectedIds: Set<UUID>,
        in root: OKRNode
    ) async -> OKRNode? {
        guard !newOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            operationMessage = "负责人名称不能为空"
            return nil
        }

        isOperating = true
        operationMessage = nil

        do {
            var updatedCount = 0
            for id in selectedIds {
                if let node = findNode(in: root, id: id) {
                    var updatedNode = node
                    updatedNode.ownerName = newOwner.trimmingCharacters(in: .whitespacesAndNewlines)
                    updatedNode.updatedAt = Date()
                    _ = try await repository.updateNode(updatedNode)
                    updatedCount += 1
                }
            }
            try await repository.save()
            operationMessage = "已更新 \(updatedCount) 个节点的负责人为 \(newOwner)"
            selectedNodeIds.removeAll()
            isOperating = false

            // 返回更新后的树（通过重新查找实现简单级联更新）
            return updateOwnerInTree(root: root, selectedIds: selectedIds, newOwner: newOwner)

        } catch {
            operationMessage = "批量更新失败: \(error.localizedDescription)"
            isOperating = false
            return nil
        }
    }

    // MARK: - 公开接口: 批量导出

    /// 导出选中节点为CSV
    /// - Parameters:
    ///   - selectedIds: 选中的节点ID集合
    ///   - root: 树的根节点
    /// - Returns: CSV格式字符串
    public func batchExportCSV(selectedIds: Set<UUID>, in root: OKRNode) -> String {
        var rows: [String] = []
        rows.append("id,title,owner,progress,status,nodeType,scope")

        for id in selectedIds {
            if let node = findNode(in: root, id: id) {
                let escapedTitle = escapeCSV(node.title)
                let escapedOwner = escapeCSV(node.ownerName)
                let progressStr = String(format: "%.1f", node.progress)
                let nodeTypeStr = node.nodeType == .objective ? "objective" : "key_result"
                let scopeStr = node.scope == .enterprise ? "enterprise" : "personal"
                rows.append("\(node.id.uuidString),\(escapedTitle),\(escapedOwner),\(progressStr),\(node.status.rawValue),\(nodeTypeStr),\(scopeStr)")
            }
        }

        return rows.joined(separator: "\n")
    }

    /// 导出选中节点为JSON
    /// - Parameters:
    ///   - selectedIds: 选中的节点ID集合
    ///   - root: 树的根节点
    /// - Returns: JSON格式Data
    public func batchExportJSON(selectedIds: Set<UUID>, in root: OKRNode) -> Data? {
        var exportNodes: [OKRExportService.ExportNode] = []

        for id in selectedIds {
            if let node = findNode(in: root, id: id) {
                exportNodes.append(OKRExportService.ExportNode(from: node))
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(exportNodes)
    }

    // MARK: - 私有辅助方法

    /// 在树中查找指定ID的节点
    private func findNode(in root: OKRNode, id: UUID) -> OKRNode? {
        if root.id == id { return root }
        for child in root.children {
            if let found = findNode(in: child, id: id) {
                return found
            }
        }
        return nil
    }

    /// 统计节点的后代节点数量
    private func countDescendants(_ node: OKRNode) -> Int {
        var count = node.children.count
        for child in node.children {
            count += countDescendants(child)
        }
        return count
    }

    /// 在树中更新选中节点的Owner（本地版本，用于UI刷新）
    private func updateOwnerInTree(root: OKRNode, selectedIds: Set<UUID>, newOwner: String) -> OKRNode {
        var updated = root
        if selectedIds.contains(root.id) {
            updated.ownerName = newOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        updated.children = root.children.map { child in
            updateOwnerInTree(root: child, selectedIds: selectedIds, newOwner: newOwner)
        }
        return updated
    }

    /// CSV字段转义
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
