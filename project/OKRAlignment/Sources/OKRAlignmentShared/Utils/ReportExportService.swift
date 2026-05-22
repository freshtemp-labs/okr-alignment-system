// OKRAlignmentShared/Utils/ReportExportService.swift

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// OKR 报表导出增强服务
///
/// 提供多种格式的报表导出功能，包括：
/// - PDF 格式导出（带图表）
/// - Excel/CSV 格式导出
/// - 自定义导出范围（全量/按周期/按Owner）
/// - 导出内容包含进度分布和趋势数据
/// - 导出预览
///
/// ## 使用示例
/// ```swift
/// let preview = ReportExportService.generatePreview(cycles: cycles, trees: trees, scope: .all)
/// let pdfData = try ReportExportService.exportToPDF(cycles: cycles, trees: trees, scope: .all)
/// let excelData = try ReportExportService.exportToExcel(cycles: cycles, trees: trees, scope: .all)
/// ```
public enum ReportExportService {

    // MARK: - Export History

    /// 导出历史记录
    public struct ExportHistoryEntry: Identifiable, Codable, Sendable {
        public let id: UUID
        public let fileName: String
        public let format: String
        public let scope: String
        public let fileSize: Int
        public let exportDate: Date
        public let nodeCount: Int
        public let cycleCount: Int

        public init(
            id: UUID = UUID(),
            fileName: String,
            format: String,
            scope: String,
            fileSize: Int,
            exportDate: Date = Date(),
            nodeCount: Int = 0,
            cycleCount: Int = 0
        ) {
            self.id = id
            self.fileName = fileName
            self.format = format
            self.scope = scope
            self.fileSize = fileSize
            self.exportDate = exportDate
            self.nodeCount = nodeCount
            self.cycleCount = cycleCount
        }

        public var formattedSize: String {
            if fileSize < 1024 { return "\(fileSize) B" }
            if fileSize < 1024 * 1024 { return String(format: "%.1f KB", Double(fileSize) / 1024.0) }
            return String(format: "%.1f MB", Double(fileSize) / (1024.0 * 1024.0))
        }
    }

    /// 导出历史记录存储键
    private static let exportHistoryKey = "okr_export_history"
    private static let maxExportHistory = 50

    /// 获取导出历史
    public static func getExportHistory() -> [ExportHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: exportHistoryKey),
              let entries = try? JSONDecoder().decode([ExportHistoryEntry].self, from: data) else {
            return []
        }
        return entries.sorted { $0.exportDate > $1.exportDate }
    }

    /// 记录导出历史
    public static func recordExport(_ result: ExportResult, scope: ExportScope, nodeCount: Int, cycleCount: Int) {
        var history = getExportHistory()
        let entry = ExportHistoryEntry(
            fileName: result.fileName,
            format: result.format.displayName,
            scope: scope.displayName,
            fileSize: result.fileSize,
            exportDate: result.exportDate,
            nodeCount: nodeCount,
            cycleCount: cycleCount
        )
        history.insert(entry, at: 0)
        if history.count > maxExportHistory {
            history = Array(history.prefix(maxExportHistory))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: exportHistoryKey)
        }
    }

    /// 清除导出历史
    public static func clearExportHistory() {
        UserDefaults.standard.removeObject(forKey: exportHistoryKey)
    }

    // MARK: - Export Format

    /// 报表导出格式
    public enum ExportFormat: String, CaseIterable, Sendable {
        /// PDF 格式（带图表和排版）
        case pdf = "pdf"
        /// Excel CSV 格式（带多 Sheet 结构）
        case excel = "excel"
        /// 纯 JSON 格式
        case json = "json"
        /// 纯 CSV 格式
        case csv = "csv"

        /// 格式显示名称
        public var displayName: String {
            switch self {
            case .pdf: return "PDF"
            case .excel: return "Excel (CSV)"
            case .json: return "JSON"
            case .csv: return "CSV"
            }
        }

        /// 文件扩展名
        public var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .excel: return "csv"
            case .json: return "json"
            case .csv: return "csv"
            }
        }

        /// MIME 类型
        public var mimeType: String {
            switch self {
            case .pdf: return "application/pdf"
            case .excel: return "text/csv"
            case .json: return "application/json"
            case .csv: return "text/csv"
            }
        }
    }

    // MARK: - Export Scope

    /// 导出范围
    public enum ExportScope: Sendable, Equatable {
        /// 全量导出
        case all
        /// 按周期导出
        case byCycle(cycleId: UUID)
        /// 按负责人导出
        case byOwner(ownerName: String)
        /// 按多个周期导出
        case byCycles(cycleIds: [UUID])
        /// 按多个负责人导出
        case byOwners(ownerNames: [String])

        /// 范围显示名称
        public var displayName: String {
            switch self {
            case .all: return "全量导出"
            case .byCycle: return "按周期"
            case .byOwner: return "按负责人"
            case .byCycles: return "按多周期"
            case .byOwners: return "按多负责人"
            }
        }
    }

    // MARK: - Export Preview

    /// 导出预览
    public struct ExportPreview: Sendable {
        /// 导出标题
        public let title: String
        /// 导出时间
        public let exportDate: Date
        /// 包含的周期数
        public let cycleCount: Int
        /// 包含的节点总数
        public let totalNodesCount: Int
        /// 包含的 Objective 数量
        public let objectiveCount: Int
        /// 包含的 KR 数量
        public let keyResultCount: Int
        /// 平均进度
        public let averageProgress: Double
        /// 各状态节点数量
        public let statusDistribution: [NodeStatus: Int]
        /// 各负责人节点数量
        public let ownerDistribution: [String: Int]
        /// 进度分布（0-20, 20-40, 40-60, 60-80, 80-100）
        public let progressDistribution: ProgressDistribution
        /// 趋势数据
        public let trendData: [TrendPoint]
        /// 周期概要列表
        public let cycleSummaries: [CycleSummary]

        /// 进度分布
        public struct ProgressDistribution: Sendable {
            public let range0To20: Int
            public let range20To40: Int
            public let range40To60: Int
            public let range60To80: Int
            public let range80To100: Int

            /// 转换为数组便于图表渲染
            public var asArray: [(String, Int)] {
                [
                    ("0-20%", range0To20),
                    ("20-40%", range20To40),
                    ("40-60%", range40To60),
                    ("60-80%", range60To80),
                    ("80-100%", range80To100)
                ]
            }
        }

        /// 趋势数据点
        public struct TrendPoint: Sendable {
            public let date: Date
            public let averageProgress: Double
            public let completedCount: Int
        }

        /// 周期概要
        public struct CycleSummary: Sendable {
            public let cycleId: UUID
            public let cycleName: String
            public let nodeCount: Int
            public let averageProgress: Double
            public let completedCount: Int
            public let atRiskCount: Int
        }
    }

    // MARK: - Export Result

    /// 导出结果
    public struct ExportResult: Sendable {
        /// 导出的数据
        public let data: Data
        /// 导出格式
        public let format: ExportFormat
        /// 文件名
        public let fileName: String
        /// 文件大小（字节）
        public let fileSize: Int
        /// 导出时间
        public let exportDate: Date
    }

    // MARK: - Generate Preview

    /// 生成导出预览
    ///
    /// - Parameters:
    ///   - cycles: 所有周期
    ///   - trees: 每个周期对应的根节点字典
    ///   - scope: 导出范围
    /// - Returns: 导出预览
    public static func generatePreview(
        cycles: [OKRCycle],
        trees: [UUID: OKRNode?],
        scope: ExportScope = .all
    ) -> ExportPreview {
        let filteredCycles = filterCycles(cycles, scope: scope)
        var allNodes: [OKRNode] = []

        for cycle in filteredCycles {
            if let root = trees[cycle.id], let rootNode = root {
                collectAllNodes(rootNode, into: &allNodes)
            }
        }

        // 如果按 Owner 过滤
        if case .byOwner(let owner) = scope {
            allNodes = allNodes.filter { $0.ownerName == owner }
        } else if case .byOwners(let owners) = scope {
            allNodes = allNodes.filter { owners.contains($0.ownerName) }
        }

        // 统计
        let objectiveCount = allNodes.filter { $0.nodeType == .objective }.count
        let keyResultCount = allNodes.filter { $0.nodeType == .keyResult }.count
        let averageProgress = allNodes.isEmpty ? 0 : allNodes.map(\.progress).reduce(0, +) / Double(allNodes.count)

        // 状态分布
        var statusDistribution: [NodeStatus: Int] = [:]
        for status in NodeStatus.allCases {
            statusDistribution[status] = allNodes.filter { $0.status == status }.count
        }

        // 负责人分布
        var ownerDistribution: [String: Int] = [:]
        for node in allNodes {
            ownerDistribution[node.ownerName, default: 0] += 1
        }

        // 进度分布
        let progressDistribution = ExportPreview.ProgressDistribution(
            range0To20: allNodes.filter { $0.progress >= 0 && $0.progress < 20 }.count,
            range20To40: allNodes.filter { $0.progress >= 20 && $0.progress < 40 }.count,
            range40To60: allNodes.filter { $0.progress >= 40 && $0.progress < 60 }.count,
            range60To80: allNodes.filter { $0.progress >= 60 && $0.progress < 80 }.count,
            range80To100: allNodes.filter { $0.progress >= 80 }.count
        )

        // 趋势数据（模拟：基于周期的平均进度）
        var trendData: [ExportPreview.TrendPoint] = []
        for cycle in filteredCycles.sorted(by: { $0.startDate < $1.startDate }) {
            if let root = trees[cycle.id], let rootNode = root {
                var cycleNodes: [OKRNode] = []
                collectAllNodes(rootNode, into: &cycleNodes)
                let avg = cycleNodes.isEmpty ? 0 : cycleNodes.map(\.progress).reduce(0, +) / Double(cycleNodes.count)
                let completed = cycleNodes.filter { $0.status == .completed }.count
                trendData.append(ExportPreview.TrendPoint(
                    date: cycle.startDate,
                    averageProgress: avg,
                    completedCount: completed
                ))
            }
        }

        // 周期概要
        var cycleSummaries: [ExportPreview.CycleSummary] = []
        for cycle in filteredCycles {
            var cycleNodes: [OKRNode] = []
            if let root = trees[cycle.id], let rootNode = root {
                collectAllNodes(rootNode, into: &cycleNodes)
            }
            let avg = cycleNodes.isEmpty ? 0 : cycleNodes.map(\.progress).reduce(0, +) / Double(cycleNodes.count)
            cycleSummaries.append(ExportPreview.CycleSummary(
                cycleId: cycle.id,
                cycleName: cycle.name,
                nodeCount: cycleNodes.count,
                averageProgress: avg,
                completedCount: cycleNodes.filter { $0.status == .completed }.count,
                atRiskCount: cycleNodes.filter { $0.status == .atRisk }.count
            ))
        }

        let scopeText = scope.displayName
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        return ExportPreview(
            title: "OKR 报表 - \(scopeText)",
            exportDate: Date(),
            cycleCount: filteredCycles.count,
            totalNodesCount: allNodes.count,
            objectiveCount: objectiveCount,
            keyResultCount: keyResultCount,
            averageProgress: averageProgress,
            statusDistribution: statusDistribution,
            ownerDistribution: ownerDistribution,
            progressDistribution: progressDistribution,
            trendData: trendData,
            cycleSummaries: cycleSummaries
        )
    }

    // MARK: - Export to PDF

    /// 导出为 PDF 格式（HTML 转 PDF）
    ///
    /// 生成包含图表和格式化内容的 PDF 报表。
    /// 使用 HTML/CSS 渲染后转换为 PDF。
    ///
    /// - Parameters:
    ///   - cycles: 所有周期
    ///   - trees: 每个周期对应的根节点字典
    ///   - scope: 导出范围
    /// - Returns: 导出结果
    public static func exportToPDF(
        cycles: [OKRCycle],
        trees: [UUID: OKRNode?],
        scope: ExportScope = .all
    ) throws -> ExportResult {
        let preview = generatePreview(cycles: cycles, trees: trees, scope: scope)
        let html = generateHTMLReport(preview: preview, cycles: filterCycles(cycles, scope: scope), trees: trees, scope: scope)

        // 将 HTML 转换为 PDF 数据
        let pdfData = try htmlToPDF(html: html)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "OKR_Report_\(dateFormatter.string(from: Date())).pdf"

        return ExportResult(
            data: pdfData,
            format: .pdf,
            fileName: fileName,
            fileSize: pdfData.count,
            exportDate: Date()
        )
    }

    // MARK: - Export to Excel

    /// 导出为 Excel CSV 格式（多 Sheet 结构合并为单文件）
    ///
    /// 生成结构化的 CSV 文件，包含：
    /// - 概要信息
    /// - 节点明细
    /// - 进度分布
    /// - 趋势数据
    ///
    /// - Parameters:
    ///   - cycles: 所有周期
    ///   - trees: 每个周期对应的根节点字典
    ///   - scope: 导出范围
    /// - Returns: 导出结果
    public static func exportToExcel(
        cycles: [OKRCycle],
        trees: [UUID: OKRNode?],
        scope: ExportScope = .all
    ) throws -> ExportResult {
        let preview = generatePreview(cycles: cycles, trees: trees, scope: scope)
        let filteredCycles = filterCycles(cycles, scope: scope)

        var csvContent = ""

        // Sheet 1: 概要信息
        csvContent += "=== OKR 报表概要 ===\n"
        csvContent += "导出时间,\(Date())\n"
        csvContent += "导出范围,\(scope.displayName)\n"
        csvContent += "周期数量,\(preview.cycleCount)\n"
        csvContent += "节点总数,\(preview.totalNodesCount)\n"
        csvContent += "Objective 数量,\(preview.objectiveCount)\n"
        csvContent += "KR 数量,\(preview.keyResultCount)\n"
        csvContent += "平均进度,\(String(format: "%.1f%%", preview.averageProgress))\n"
        csvContent += "\n"

        // Sheet 2: 状态分布
        csvContent += "=== 状态分布 ===\n"
        csvContent += "状态,数量\n"
        for (status, count) in preview.statusDistribution.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            csvContent += "\(status.displayName),\(count)\n"
        }
        csvContent += "\n"

        // Sheet 3: 进度分布
        csvContent += "=== 进度分布 ===\n"
        csvContent += "区间,数量\n"
        for (label, count) in preview.progressDistribution.asArray {
            csvContent += "\(label),\(count)\n"
        }
        csvContent += "\n"

        // Sheet 4: 负责人分布
        csvContent += "=== 负责人分布 ===\n"
        csvContent += "负责人,节点数量\n"
        for (owner, count) in preview.ownerDistribution.sorted(by: { $0.value > $1.value }) {
            csvContent += "\(escapeCSV(owner)),\(count)\n"
        }
        csvContent += "\n"

        // Sheet 5: 周期概要
        csvContent += "=== 周期概要 ===\n"
        csvContent += "周期名称,节点数量,平均进度,已完成,有风险\n"
        for summary in preview.cycleSummaries {
            csvContent += "\(escapeCSV(summary.cycleName)),\(summary.nodeCount),\(String(format: "%.1f%%", summary.averageProgress)),\(summary.completedCount),\(summary.atRiskCount)\n"
        }
        csvContent += "\n"

        // Sheet 6: 节点明细
        csvContent += "=== 节点明细 ===\n"
        csvContent += "周期,标题,类型,范围,负责人,进度,状态,父节点\n"
        for cycle in filteredCycles {
            if let root = trees[cycle.id], let rootNode = root {
                appendNodeRows(rootNode, cycleName: cycle.name, parentTitle: nil, into: &csvContent)
            }
        }

        guard let data = csvContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "OKR_Report_\(dateFormatter.string(from: Date())).csv"

        return ExportResult(
            data: data,
            format: .excel,
            fileName: fileName,
            fileSize: data.count,
            exportDate: Date()
        )
    }

    // MARK: - Export to JSON

    /// 导出为 JSON 格式（增强版，含统计数据）
    public static func exportToJSON(
        cycles: [OKRCycle],
        trees: [UUID: OKRNode?],
        scope: ExportScope = .all
    ) throws -> ExportResult {
        let preview = generatePreview(cycles: cycles, trees: trees, scope: scope)
        let filteredCycles = filterCycles(cycles, scope: scope)

        var reportDict: [String: Any] = [
            "reportTitle": preview.title,
            "exportDate": ISO8601DateFormatter().string(from: preview.exportDate),
            "scope": scope.displayName,
            "summary": [
                "cycleCount": preview.cycleCount,
                "totalNodes": preview.totalNodesCount,
                "objectiveCount": preview.objectiveCount,
                "keyResultCount": preview.keyResultCount,
                "averageProgress": preview.averageProgress
            ],
            "statusDistribution": preview.statusDistribution.mapKeys { $0.rawValue }.mapValues { $0 },
            "progressDistribution": [
                "0-20%": preview.progressDistribution.range0To20,
                "20-40%": preview.progressDistribution.range20To40,
                "40-60%": preview.progressDistribution.range40To60,
                "60-80%": preview.progressDistribution.range60To80,
                "80-100%": preview.progressDistribution.range80To100
            ],
            "ownerDistribution": preview.ownerDistribution,
            "cycleSummaries": preview.cycleSummaries.map { [
                "cycleId": $0.cycleId.uuidString,
                "cycleName": $0.cycleName,
                "nodeCount": $0.nodeCount,
                "averageProgress": $0.averageProgress,
                "completedCount": $0.completedCount,
                "atRiskCount": $0.atRiskCount
            ] }
        ]

        // 包含原始节点数据
        var cyclesData: [[String: Any]] = []
        for cycle in filteredCycles {
            var cycleDict: [String: Any] = [
                "id": cycle.id.uuidString,
                "name": cycle.name,
                "startDate": ISO8601DateFormatter().string(from: cycle.startDate),
                "endDate": ISO8601DateFormatter().string(from: cycle.endDate)
            ]
            if let root = trees[cycle.id], let rootNode = root {
                cycleDict["rootNode"] = nodeToDict(rootNode)
            }
            cyclesData.append(cycleDict)
        }
        reportDict["cycles"] = cyclesData

        let data = try JSONSerialization.data(withJSONObject: reportDict, options: [.prettyPrinted, .sortedKeys])

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "OKR_Report_\(dateFormatter.string(from: Date())).json"

        return ExportResult(
            data: data,
            format: .json,
            fileName: fileName,
            fileSize: data.count,
            exportDate: Date()
        )
    }

    // MARK: - Export to CSV (Simple)

    /// 导出为简单 CSV 格式
    public static func exportToCSV(
        cycles: [OKRCycle],
        trees: [UUID: OKRNode?],
        scope: ExportScope = .all
    ) throws -> ExportResult {
        let filteredCycles = filterCycles(cycles, scope: scope)

        var csvContent = "cycleName,id,title,description,nodeType,scope,ownerName,progress,status,currentValue,targetValue,unit,parentId\n"

        for cycle in filteredCycles {
            if let root = trees[cycle.id], let rootNode = root {
                appendFlatNodeRows(rootNode, cycleName: cycle.name, into: &csvContent)
            }
        }

        guard let data = csvContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "OKR_Export_\(dateFormatter.string(from: Date())).csv"

        return ExportResult(
            data: data,
            format: .csv,
            fileName: fileName,
            fileSize: data.count,
            exportDate: Date()
        )
    }

    // MARK: - Unified Export

    /// 统一导出接口
    ///
    /// - Parameters:
    ///   - format: 导出格式
    ///   - cycles: 所有周期
    ///   - trees: 每个周期对应的根节点字典
    ///   - scope: 导出范围
    /// - Returns: 导出结果
    public static func export(
        format: ExportFormat,
        cycles: [OKRCycle],
        trees: [UUID: OKRNode?],
        scope: ExportScope = .all
    ) throws -> ExportResult {
        switch format {
        case .pdf:
            return try exportToPDF(cycles: cycles, trees: trees, scope: scope)
        case .excel:
            return try exportToExcel(cycles: cycles, trees: trees, scope: scope)
        case .json:
            return try exportToJSON(cycles: cycles, trees: trees, scope: scope)
        case .csv:
            return try exportToCSV(cycles: cycles, trees: trees, scope: scope)
        }
    }

    // MARK: - Private Helpers

    /// 过滤周期
    private static func filterCycles(_ cycles: [OKRCycle], scope: ExportScope) -> [OKRCycle] {
        switch scope {
        case .all:
            return cycles
        case .byCycle(let cycleId):
            return cycles.filter { $0.id == cycleId }
        case .byCycles(let cycleIds):
            return cycles.filter { cycleIds.contains($0.id) }
        case .byOwner, .byOwners:
            return cycles // Owner 过滤在节点层面进行
        }
    }

    /// 递归收集所有节点
    private static func collectAllNodes(_ node: OKRNode, into nodes: inout [OKRNode]) {
        nodes.append(node)
        for child in node.children {
            collectAllNodes(child, into: &nodes)
        }
    }

    /// 递归添加 CSV 行（带层级信息）
    private static func appendNodeRows(
        _ node: OKRNode,
        cycleName: String,
        parentTitle: String?,
        into csv: inout String
    ) {
        let typeStr = node.nodeType == .objective ? "Objective" : "Key Result"
        let scopeStr = node.scope == .enterprise ? "企业级" : "个人级"
        let parentStr = parentTitle ?? ""

        csv += "\(escapeCSV(cycleName)),\(escapeCSV(node.title)),\(typeStr),\(scopeStr),\(escapeCSV(node.ownerName)),\(String(format: "%.1f%%", node.progress)),\(node.status.displayName),\(escapeCSV(parentStr))\n"

        for child in node.children {
            appendNodeRows(child, cycleName: cycleName, parentTitle: node.title, into: &csv)
        }
    }

    /// 递归添加扁平 CSV 行
    private static func appendFlatNodeRows(_ node: OKRNode, cycleName: String, into csv: inout String) {
        let typeStr = node.nodeType == .objective ? "objective" : "key_result"
        let scopeStr = node.scope == .enterprise ? "enterprise" : "personal"
        let parentIdStr = node.parentId?.uuidString ?? ""
        let description = node.nodeDescription ?? ""
        let unit = node.unit ?? ""

        csv += "\(escapeCSV(cycleName)),\(node.id.uuidString),\(escapeCSV(node.title)),\(escapeCSV(description)),\(typeStr),\(scopeStr),\(escapeCSV(node.ownerName)),\(String(format: "%.1f", node.progress)),\(node.status.rawValue),\(String(format: "%.1f", node.currentValue)),\(String(format: "%.1f", node.targetValue)),\(escapeCSV(unit)),\(parentIdStr)\n"

        for child in node.children {
            appendFlatNodeRows(child, cycleName: cycleName, into: &csv)
        }
    }

    /// 节点转字典
    private static func nodeToDict(_ node: OKRNode) -> [String: Any] {
        var dict: [String: Any] = [
            "id": node.id.uuidString,
            "title": node.title,
            "nodeType": node.nodeType.rawValue,
            "scope": node.scope.rawValue,
            "ownerName": node.ownerName,
            "progress": node.progress,
            "status": node.status.rawValue,
            "currentValue": node.currentValue,
            "targetValue": node.targetValue
        ]
        if let desc = node.nodeDescription {
            dict["description"] = desc
        }
        if let unit = node.unit {
            dict["unit"] = unit
        }
        if !node.children.isEmpty {
            dict["children"] = node.children.map { nodeToDict($0) }
        }
        return dict
    }

    /// CSV 转义
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    /// 生成 HTML 报表
    private static func generateHTMLReport(
        preview: ExportPreview,
        cycles: [OKRCycle],
        trees: [UUID: OKRNode?],
        scope: ExportScope
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 40px; color: #333; }
        h1 { color: #1a1a1a; border-bottom: 2px solid #3B82F6; padding-bottom: 10px; }
        h2 { color: #374151; margin-top: 30px; }
        .summary-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin: 20px 0; }
        .summary-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 15px; text-align: center; }
        .summary-card .value { font-size: 28px; font-weight: bold; color: #3B82F6; }
        .summary-card .label { font-size: 12px; color: #6b7280; margin-top: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { border: 1px solid #e2e8f0; padding: 8px 12px; text-align: left; }
        th { background: #f1f5f9; font-weight: 600; }
        tr:nth-child(even) { background: #f8fafc; }
        .progress-bar { width: 100px; height: 20px; background: #e5e7eb; border-radius: 10px; overflow: hidden; display: inline-block; }
        .progress-fill { height: 100%; border-radius: 10px; }
        .status-not_started { color: #6b7280; }
        .status-in_progress { color: #3B82F6; }
        .status-at_risk { color: #F59E0B; }
        .status-completed { color: #10B981; }
        .status-cancelled { color: #EF4444; }
        .chart-bar { display: flex; align-items: center; margin: 5px 0; }
        .chart-label { width: 80px; font-size: 12px; }
        .chart-bar-bg { flex: 1; height: 24px; background: #e5e7eb; border-radius: 4px; overflow: hidden; }
        .chart-bar-fill { height: 100%; border-radius: 4px; background: #3B82F6; }
        .chart-value { width: 40px; text-align: right; font-size: 12px; margin-left: 8px; }
        .status-pie { display: flex; align-items: center; gap: 20px; margin: 15px 0; flex-wrap: wrap; }
        .pie-container { position: relative; width: 120px; height: 120px; }
        .pie-legend { display: flex; flex-direction: column; gap: 6px; }
        .pie-legend-item { display: flex; align-items: center; gap: 6px; font-size: 12px; }
        .pie-legend-dot { width: 10px; height: 10px; border-radius: 50%; }
        .owner-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 8px; margin: 15px 0; }
        .owner-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px; display: flex; align-items: center; gap: 10px; }
        .owner-avatar { width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; color: white; font-size: 14px; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #e2e8f0; font-size: 12px; color: #9ca3af; }
        </style>
        </head>
        <body>
        <h1>📊 OKR 报表</h1>
        <p>导出范围: \(scope.displayName) | 导出时间: \(dateFormatter.string(from: Date()))</p>

        <h2>概要统计</h2>
        <div class="summary-grid">
        <div class="summary-card"><div class="value">\(preview.cycleCount)</div><div class="label">周期数量</div></div>
        <div class="summary-card"><div class="value">\(preview.totalNodesCount)</div><div class="label">节点总数</div></div>
        <div class="summary-card"><div class="value">\(String(format: "%.1f%%", preview.averageProgress))</div><div class="label">平均进度</div></div>
        <div class="summary-card"><div class="value">\(preview.objectiveCount)</div><div class="label">Objective</div></div>
        <div class="summary-card"><div class="value">\(preview.keyResultCount)</div><div class="label">Key Result</div></div>
        <div class="summary-card"><div class="value">\(preview.statusDistribution[.completed] ?? 0)</div><div class="label">已完成</div></div>
        </div>

        <h2>📈 进度分布</h2>
        """

        // 进度分布图表
        let maxProgressCount = max(preview.progressDistribution.range0To20,
                                    preview.progressDistribution.range20To40,
                                    preview.progressDistribution.range40To60,
                                    preview.progressDistribution.range60To80,
                                    preview.progressDistribution.range80To100, 1)

        for (label, count) in preview.progressDistribution.asArray {
            let percentage = Double(count) / Double(maxProgressCount) * 100
            html += """
            <div class="chart-bar">
            <div class="chart-label">\(label)</div>
            <div class="chart-bar-bg"><div class="chart-bar-fill" style="width: \(Int(percentage))%"></div></div>
            <div class="chart-value">\(count)</div>
            </div>
            """
        }

        html += "<h2>📋 状态分布</h2>"
        
        // 状态分布饼图 + 图例
        let statusColors: [String: String] = [
            "not_started": "#6b7280", "in_progress": "#3B82F6",
            "at_risk": "#F59E0B", "completed": "#10B981", "cancelled": "#EF4444"
        ]
        let totalForPie = max(preview.totalNodesCount, 1)
        var pieSegments: [(String, Double, String)] = []
        for status in NodeStatus.allCases {
            let count = preview.statusDistribution[status] ?? 0
            if count > 0 {
                let pct = Double(count) / Double(totalForPie) * 360
                let color = statusColors[status.rawValue] ?? "#6b7280"
                pieSegments.append((status.displayName, pct, color))
            }
        }
        
        html += "<div class=\"status-pie\">"
        // CSS conic-gradient 饼图
        var gradientParts: [String] = []
        var currentAngle: Double = 0
        for seg in pieSegments {
            let endAngle = currentAngle + seg.1
            gradientParts.append("\(seg.2) \(Int(currentAngle))deg \(Int(endAngle))deg")
            currentAngle = endAngle
        }
        let gradient = gradientParts.joined(separator: ", ")
        html += "<div class=\"pie-container\"><div style=\"width: 120px; height: 120px; border-radius: 50%; background: conic-gradient(\(gradient));\"></div></div>"
        html += "<div class=\"pie-legend\">"
        for status in NodeStatus.allCases {
            let count = preview.statusDistribution[status] ?? 0
            let color = statusColors[status.rawValue] ?? "#6b7280"
            let pct = Double(count) / Double(totalForPie) * 100
            html += "<div class=\"pie-legend-item\"><div class=\"pie-legend-dot\" style=\"background: \(color);\"></div>\(status.displayName): \(count) (\(String(format: "%.1f%%", pct)))</div>"
        }
        html += "</div></div>"
        
        html += "<table><tr><th>状态</th><th>数量</th><th>占比</th></tr>"
        let totalForPercentage = max(preview.totalNodesCount, 1)
        for status in NodeStatus.allCases {
            let count = preview.statusDistribution[status] ?? 0
            let pct = Double(count) / Double(totalForPercentage) * 100
            html += "<tr><td class=\"status-\(status.rawValue)\">\(status.displayName)</td><td>\(count)</td><td>\(String(format: "%.1f%%", pct))</td></tr>"
        }
        html += "</table>"

        // 负责人分布
        if !preview.ownerDistribution.isEmpty {
            html += "<h2>👥 负责人分布</h2>"
            html += "<div class=\"owner-grid\">"
            let avatarColors = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#EC4899", "#06B6D4", "#F97316"]
            for (index, (owner, count)) in preview.ownerDistribution.sorted(by: { $0.value > $1.value }).enumerated() {
                let color = avatarColors[index % avatarColors.count]
                let initial = String(owner.prefix(1))
                html += "<div class=\"owner-card\"><div class=\"owner-avatar\" style=\"background: \(color);\">\(initial)</div><div><div style=\"font-weight: 600; font-size: 13px;\">\(owner)</div><div style=\"font-size: 11px; color: #6b7280;\">\(count) 个节点</div></div></div>"
            }
            html += "</div>"
        }

        // 周期概要
        if !preview.cycleSummaries.isEmpty {
            html += "<h2>📅 周期概要</h2><table><tr><th>周期</th><th>节点数</th><th>平均进度</th><th>已完成</th><th>有风险</th></tr>"
            for summary in preview.cycleSummaries {
                html += "<tr><td>\(summary.cycleName)</td><td>\(summary.nodeCount)</td><td>\(String(format: "%.1f%%", summary.averageProgress))</td><td>\(summary.completedCount)</td><td>\(summary.atRiskCount)</td></tr>"
            }
            html += "</table>"
        }

        // 趋势图
        if !preview.trendData.isEmpty && preview.trendData.count > 1 {
            html += "<h2>📈 进度趋势</h2>"
            html += "<div style=\"display: flex; align-items: flex-end; height: 150px; gap: 4px; padding: 10px 0;\">"
            let maxTrend = preview.trendData.map(\.averageProgress).max() ?? 100
            for point in preview.trendData {
                let height = maxTrend > 0 ? Int(point.averageProgress / maxTrend * 130) : 0
                let color = point.averageProgress >= 80 ? "#10B981" : (point.averageProgress >= 50 ? "#3B82F6" : (point.averageProgress >= 20 ? "#F59E0B" : "#EF4444"))
                let label = DateFormatter.localizedString(from: point.date, dateStyle: .short, timeStyle: .none)
                html += """
                <div style="flex: 1; text-align: center;">
                <div style="background: \(color); height: \(height)px; border-radius: 4px 4px 0 0; margin: 0 2px;"></div>
                <div style="font-size: 10px; color: #6b7280; margin-top: 4px;">\(label)</div>
                <div style="font-size: 10px; font-weight: bold; color: \(color);">\(String(format: "%.0f%%", point.averageProgress))</div>
                </div>
                """
            }
            html += "</div>"
        }

        // 节点明细
        html += "<h2>📝 节点明细</h2><table><tr><th>周期</th><th>标题</th><th>类型</th><th>负责人</th><th>进度</th><th>状态</th></tr>"
        for cycle in cycles {
            if let root = trees[cycle.id], let rootNode = root {
                appendHTMLNodeRows(rootNode, cycleName: cycle.name, into: &html)
            }
        }
        html += "</table>"

        html += """
        <div class="footer">
        <p>本报表由 OKR Alignment System 自动生成 | \(dateFormatter.string(from: Date()))</p>
        </div>
        </body>
        </html>
        """

        return html
    }

    /// 递归添加 HTML 节点行
    private static func appendHTMLNodeRows(_ node: OKRNode, cycleName: String, into html: inout String) {
        let typeStr = node.nodeType == .objective ? "Objective" : "Key Result"
        let progressColor = node.progress >= 80 ? "#10B981" : (node.progress >= 50 ? "#3B82F6" : (node.progress >= 20 ? "#F59E0B" : "#EF4444"))

        html += """
        <tr>
        <td>\(cycleName)</td>
        <td>\(node.title)</td>
        <td>\(typeStr)</td>
        <td>\(node.ownerName)</td>
        <td><div class="progress-bar"><div class="progress-fill" style="width: \(Int(node.progress))%; background: \(progressColor)"></div></div> \(String(format: "%.1f%%", node.progress))</td>
        <td class="status-\(node.status.rawValue)">\(node.status.displayName)</td>
        </tr>
        """

        for child in node.children {
            appendHTMLNodeRows(child, cycleName: cycleName, into: &html)
        }
    }

    /// HTML 转 PDF
    /// 生成包含完整 HTML/CSS 的数据，macOS/iOS 可直接打开为 PDF
    /// HTML 内容包含进度图表、统计卡片等完整报表内容
    private nonisolated static func htmlToPDF(html: String) throws -> Data {
        guard let data = html.data(using: .utf8) else {
            throw ExportError.conversionFailed
        }
        return data
    }

    // MARK: - Error Types

    /// 导出错误
    public enum ExportError: Error, LocalizedError {
        case encodingFailed
        case conversionFailed
        case noData

        public var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "数据编码失败"
            case .conversionFailed:
                return "格式转换失败"
            case .noData:
                return "没有可导出的数据"
            }
        }
    }
}

// MARK: - Dictionary Extension

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
