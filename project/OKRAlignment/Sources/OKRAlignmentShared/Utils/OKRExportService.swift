import Foundation

/// OKR数据导出服务
/// ================
/// 提供将OKR树数据导出为CSV和JSON格式的功能。
///
/// # 支持格式
/// - CSV: 遍历所有节点，输出 id/title/owner/progress/status/parentId
/// - JSON: 完整的结构化数据导出
///
/// # 使用方式
/// ```swift
/// let csvString = OKRExportService.exportToCSV(rootNode: root)
/// let jsonData = OKRExportService.exportToJSON(rootNode: root)
/// ```
public enum OKRExportService {

    // MARK: - CSV 导出

    /// 将OKR树导出为CSV格式字符串
    /// - Parameter rootNode: 树的根节点
    /// - Returns: CSV格式的字符串（含表头）
    public static func exportToCSV(rootNode: OKRNode) -> String {
        var rows: [String] = []
        // 表头
        rows.append("id,title,owner,progress,status,parentId,nodeType,scope")

        // 递归收集所有节点
        flattenAndAppend(rootNode, into: &rows)
        return rows.joined(separator: "\n")
    }

    /// 递归展开节点并追加CSV行
    private static func flattenAndAppend(_ node: OKRNode, into rows: inout [String]) {
        let escapedTitle = escapeCSV(node.title)
        let escapedOwner = escapeCSV(node.ownerName)
        let parentIdStr = node.parentId?.uuidString ?? ""
        let progressStr = String(format: "%.1f", node.progress)
        let nodeTypeStr = node.nodeType == .objective ? "objective" : "key_result"
        let scopeStr = node.scope == .enterprise ? "enterprise" : "personal"

        rows.append("\(node.id.uuidString),\(escapedTitle),\(escapedOwner),\(progressStr),\(node.status.rawValue),\(parentIdStr),\(nodeTypeStr),\(scopeStr)")

        for child in node.children {
            flattenAndAppend(child, into: &rows)
        }
    }

    /// CSV字段转义：如果字段包含逗号、引号或换行，用双引号包裹
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    // MARK: - JSON 导出

    /// 将OKR树导出为JSON格式Data
    /// - Parameter rootNode: 树的根节点
    /// - Returns: JSON格式的Data
    public static func exportToJSON(rootNode: OKRNode) -> Data? {
        let exportModel = ExportNode(from: rootNode)
        let wrapper = ExportWrapper(root: exportModel, exportDate: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(wrapper)
    }

    /// JSON导出顶层包装
    private struct ExportWrapper: Encodable {
        let root: ExportNode
        let exportDate: Date
    }

    /// JSON导出用的扁平节点结构
    private struct ExportNode: Encodable {
        let id: String
        let title: String
        let description: String?
        let nodeType: String
        let scope: String
        let ownerName: String
        let progress: Double
        let status: String
        let parentId: String?
        let currentValue: Double
        let targetValue: Double
        let unit: String?
        let children: [ExportNode]

        init(from node: OKRNode) {
            self.id = node.id.uuidString
            self.title = node.title
            self.description = node.nodeDescription
            self.nodeType = node.nodeType == .objective ? "objective" : "key_result"
            self.scope = node.scope == .enterprise ? "enterprise" : "personal"
            self.ownerName = node.ownerName
            self.progress = node.progress
            self.status = node.status.rawValue
            self.parentId = node.parentId?.uuidString
            self.currentValue = node.currentValue
            self.targetValue = node.targetValue
            self.unit = node.unit
            self.children = node.children.map { ExportNode(from: $0) }
        }
    }
}
