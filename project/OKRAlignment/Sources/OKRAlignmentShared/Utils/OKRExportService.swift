import Foundation

/// OKR数据导出/导入服务
/// ====================
/// 提供将OKR数据导出为CSV和JSON格式的功能，以及从JSON文件恢复数据。
///
/// # 支持格式
/// - CSV: 遍历所有节点，输出 id/title/owner/progress/status/parentId
/// - JSON: 完整的结构化数据导出（包含所有周期和节点树）
///
/// # 使用方式
/// ```swift
/// let csvString = OKRExportService.exportToCSV(rootNode: root)
/// let jsonData = OKRExportService.exportFullData(cycles: cycles, trees: trees)
/// let imported = try OKRExportService.importFromJSON(data: fileData)
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

    // MARK: - JSON 单树导出（向后兼容）

    /// 将OKR树导出为JSON格式Data（单棵树）
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
    private struct ExportWrapper: Codable {
        let root: ExportNode
        let exportDate: Date
    }

    // MARK: - 全量数据导出

    /// 导出全部数据（所有周期及对应的节点树）
    /// - Parameters:
    ///   - cycles: 所有周期数组
    ///   - trees: 每个周期对应的根节点字典 [cycleId: rootNode?]
    /// - Returns: JSON格式的Data
    public static func exportFullData(cycles: [OKRCycle], trees: [UUID: OKRNode?]) -> Data? {
        let exportCycles = cycles.map { ExportCycle(from: $0, trees: trees) }
        let fullExport = FullExport(
            version: "1.0",
            exportDate: Date(),
            cycles: exportCycles
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(fullExport)
    }

    // MARK: - JSON 导入

    /// 从JSON数据导入全量数据
    /// - Parameter data: JSON格式的Data
    /// - Returns: 导入结果，包含周期列表和每个周期的根节点
    /// - Throws: 解码错误
    public static func importFromJSON(data: Data) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 尝试作为全量导出格式解析
        if let fullExport = try? decoder.decode(FullExport.self, from: data) {
            return try parseFullExport(fullExport)
        }

        // 尝试作为单树导出格式解析（向后兼容）
        if let singleExport = try? decoder.decode(ExportWrapper.self, from: data) {
            let node = try parseExportNode(singleExport.root)
            return ImportResult(cycles: [], nodesByCycle: [:], standaloneNodes: [node])
        }

        throw ImportError.invalidFormat
    }

    /// 解析全量导出数据
    private static func parseFullExport(_ export: FullExport) throws -> ImportResult {
        var cycles: [OKRCycle] = []
        var nodesByCycle: [UUID: OKRNode] = [:]

        for exportCycle in export.cycles {
            let cycle = OKRCycle(
                id: UUID(uuidString: exportCycle.id) ?? UUID(),
                name: exportCycle.name,
                startDate: exportCycle.startDate,
                endDate: exportCycle.endDate,
                isActive: exportCycle.isActive,
                isArchived: exportCycle.isArchived
            )
            cycles.append(cycle)

            if let rootNodeData = exportCycle.rootNode {
                let rootNode = try parseExportNode(rootNodeData)
                nodesByCycle[cycle.id] = rootNode
            }
        }

        return ImportResult(cycles: cycles, nodesByCycle: nodesByCycle, standaloneNodes: [])
    }

    /// 递归解析导出节点为领域模型
    private static func parseExportNode(_ export: ExportNode) throws -> OKRNode {
        let nodeType: NodeType = export.nodeType == "objective" ? .objective : .keyResult
        let scope: Scope = export.scope == "enterprise" ? .enterprise : .personal
        let status = NodeStatus(rawValue: export.status) ?? .notStarted
        let children = try export.children.map { try parseExportNode($0) }

        return OKRNode(
            id: UUID(uuidString: export.id) ?? UUID(),
            title: export.title,
            nodeDescription: export.description,
            nodeType: nodeType,
            scope: scope,
            currentValue: export.currentValue,
            targetValue: export.targetValue,
            unit: export.unit,
            progress: export.progress,
            status: status,
            ownerName: export.ownerName,
            sortOrder: 0,
            parentId: export.parentId.flatMap { UUID(uuidString: $0) },
            children: children,
            cycleId: nil,
            createdAt: export.createdAt ?? Date(),
            updatedAt: export.updatedAt ?? Date()
        )
    }

    // MARK: - JSON导出用结构

    /// JSON导出用的节点结构（Codable）
    public struct ExportNode: Codable {
        public let id: String
        public let title: String
        public let description: String?
        public let nodeType: String
        public let scope: String
        public let ownerName: String
        public let progress: Double
        public let status: String
        public let parentId: String?
        public let currentValue: Double
        public let targetValue: Double
        public let unit: String?
        public let children: [ExportNode]
        public let createdAt: Date?
        public let updatedAt: Date?

        public init(from node: OKRNode) {
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
            self.createdAt = node.createdAt
            self.updatedAt = node.updatedAt
        }
    }

    /// JSON导出用的周期结构
    public struct ExportCycle: Codable {
        public let id: String
        public let name: String
        public let startDate: Date
        public let endDate: Date
        public let isActive: Bool
        public let isArchived: Bool
        public let rootNode: ExportNode?

        public init(from cycle: OKRCycle, trees: [UUID: OKRNode?]) {
            self.id = cycle.id.uuidString
            self.name = cycle.name
            self.startDate = cycle.startDate
            self.endDate = cycle.endDate
            self.isActive = cycle.isActive
            self.isArchived = cycle.isArchived
            if let tree = trees[cycle.id], let root = tree {
                self.rootNode = ExportNode(from: root)
            } else {
                self.rootNode = nil
            }
        }
    }

    /// 全量导出顶层结构
    public struct FullExport: Codable {
        public let version: String
        public let exportDate: Date
        public let cycles: [ExportCycle]
    }

    // MARK: - 导入结果

    /// 导入操作的结果
    public struct ImportResult {
        /// 导入的周期列表
        public let cycles: [OKRCycle]
        /// 每个周期对应的根节点
        public let nodesByCycle: [UUID: OKRNode]
        /// 独立节点（不关联周期的节点，来自单树导出格式）
        public let standaloneNodes: [OKRNode]
    }

    // MARK: - 错误类型

    /// 导入错误
    public enum ImportError: Error, LocalizedError {
        case invalidFormat
        case missingData

        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid JSON format. Expected OKR export data."
            case .missingData:
                return "The imported file contains no valid data."
            }
        }
    }
}
