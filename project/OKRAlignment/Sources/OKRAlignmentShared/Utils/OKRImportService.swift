// OKRAlignmentShared/Utils/OKRImportService.swift

import Foundation

/// OKR 数据导入增强服务
///
/// 提供多种格式的数据导入功能，包括：
/// - CSV 文件导入
/// - JSON 文件导入（复用 OKRExportService）
/// - 飞书 OKR / Lark 格式导入
/// - 导入前预览
/// - 自动创建缺失周期
/// - 冲突处理策略（跳过/覆盖/合并）
///
/// ## 使用示例
/// ```swift
/// let preview = try OKRImportService.previewImport(from: csvData, format: .csv)
/// let result = try OKRImportService.importData(from: csvData, format: .csv, conflictStrategy: .skip)
/// ```
public enum OKRImportService {

    // MARK: - Import Format

    /// 支持的导入格式
    public enum ImportFormat: String, CaseIterable, Sendable {
        /// CSV 格式
        case csv = "csv"
        /// JSON 格式（OKR Alignment System 原生格式）
        case json = "json"
        /// 飞书 OKR / Lark 格式
        case lark = "lark"

        /// 格式显示名称
        public var displayName: String {
            switch self {
            case .csv: return "CSV"
            case .json: return "JSON"
            case .lark: return "飞书 OKR / Lark"
            }
        }

        /// 支持的文件扩展名
        public var fileExtensions: [String] {
            switch self {
            case .csv: return ["csv"]
            case .json: return ["json"]
            case .lark: return ["json", "csv"]
            }
        }
    }

    // MARK: - Conflict Strategy

    /// 导入冲突处理策略
    public enum ConflictStrategy: String, CaseIterable, Sendable {
        /// 跳过已存在的节点
        case skip = "skip"
        /// 覆盖已存在的节点
        case overwrite = "overwrite"
        /// 合并（保留现有节点，仅更新变更的字段）
        case merge = "merge"

        /// 策略显示名称
        public var displayName: String {
            switch self {
            case .skip: return "跳过"
            case .overwrite: return "覆盖"
            case .merge: return "合并"
            }
        }

        /// 策略描述
        public var description: String {
            switch self {
            case .skip: return "已存在的节点将被跳过，不会修改现有数据"
            case .overwrite: return "已存在的节点将被导入数据完全覆盖"
            case .merge: return "已存在的节点将合并导入数据中的变更字段"
            }
        }
    }

    // MARK: - Import Preview

    /// 导入预览结果
    public struct ImportPreview: Sendable {
        /// 检测到的周期列表
        public let detectedCycles: [OKRCycle]
        /// 检测到的节点列表（扁平化）
        public let detectedNodes: [PreviewNode]
        /// 将会新增的节点数量
        public let newNodesCount: Int
        /// 将会冲突的节点数量
        public let conflictNodesCount: Int
        /// 将会自动创建的周期数量
        public let autoCreateCyclesCount: Int
        /// 检测到的格式
        public let detectedFormat: ImportFormat
        /// 预览警告信息
        public let warnings: [String]
    }

    /// 预览用的简化节点信息
    public struct PreviewNode: Identifiable, Sendable {
        public let id: UUID
        public let title: String
        public let nodeType: NodeType
        public let scope: Scope
        public let ownerName: String
        public let progress: Double
        public let status: NodeStatus
        public let parentTitle: String?
        public let cycleName: String?
        public let isConflict: Bool
    }

    // MARK: - Import Result Enhanced

    /// 增强版导入结果
    public struct EnhancedImportResult: Sendable {
        /// 导入的周期列表
        public let cycles: [OKRCycle]
        /// 新创建的周期列表
        public let autoCreatedCycles: [OKRCycle]
        /// 每个周期对应的根节点
        public let nodesByCycle: [UUID: OKRNode]
        /// 独立节点
        public let standaloneNodes: [OKRNode]
        /// 新增节点数
        public let importedCount: Int
        /// 跳过的节点数
        public let skippedCount: Int
        /// 覆盖的节点数
        public let overwrittenCount: Int
        /// 合并的节点数
        public let mergedCount: Int
        /// 导入过程中的警告
        public let warnings: [String]
    }

    // MARK: - Preview Import

    /// 预览导入数据（在实际导入前展示将要发生的变化）
    ///
    /// - Parameters:
    ///   - data: 导入文件的原始数据
    ///   - format: 导入格式（可选，nil 时自动检测）
    /// - Returns: 预览结果
    /// - Throws: 解析错误
    public static func previewImport(
        from data: Data,
        format: ImportFormat? = nil
    ) throws -> ImportPreview {
        let detectedFormat = format ?? detectFormat(data: data)

        switch detectedFormat {
        case .csv:
            return try previewCSVImport(from: data)
        case .json:
            return try previewJSONImport(from: data)
        case .lark:
            return try previewLarkImport(from: data)
        }
    }

    // MARK: - Import Data

    /// 导入数据
    ///
    /// - Parameters:
    ///   - data: 导入文件的原始数据
    ///   - format: 导入格式（可选，nil 时自动检测）
    ///   - conflictStrategy: 冲突处理策略
    ///   - existingNodeIds: 已存在的节点 ID 集合（用于冲突检测）
    ///   - existingCycleNames: 已存在的周期名称集合（用于自动创建检测）
    /// - Returns: 增强版导入结果
    /// - Throws: 解析或导入错误
    public static func importData(
        from data: Data,
        format: ImportFormat? = nil,
        conflictStrategy: ConflictStrategy = .skip,
        existingNodeIds: Set<UUID> = [],
        existingCycleNames: Set<String> = []
    ) throws -> EnhancedImportResult {
        let detectedFormat = format ?? detectFormat(data: data)

        switch detectedFormat {
        case .csv:
            return try importCSV(from: data, conflictStrategy: conflictStrategy,
                                 existingNodeIds: existingNodeIds,
                                 existingCycleNames: existingCycleNames)
        case .json:
            return try importJSON(from: data, conflictStrategy: conflictStrategy,
                                  existingNodeIds: existingNodeIds,
                                  existingCycleNames: existingCycleNames)
        case .lark:
            return try importLark(from: data, conflictStrategy: conflictStrategy,
                                  existingNodeIds: existingNodeIds,
                                  existingCycleNames: existingCycleNames)
        }
    }

    // MARK: - Format Detection

    /// 自动检测导入数据格式
    public static func detectFormat(data: Data) -> ImportFormat {
        // 尝试解析为 JSON
        if let _ = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 检查是否为 Lark 格式（通过特定字段判断）
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (json["data"] != nil || json["okr_data"] != nil || json["items"] != nil) {
                return .lark
            }
            return .json
        }
        // 默认为 CSV
        return .csv
    }

    // MARK: - CSV Import

    /// 预览 CSV 导入
    private static func previewCSVImport(from data: Data) throws -> ImportPreview {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else {
            throw ImportError.emptyData
        }

        let header = parseCSVLine(lines[0])
        let columnIndex = buildColumnIndex(header)

        var previewNodes: [PreviewNode] = []
        var warnings: [String] = []

        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            guard values.count >= 4 else {
                warnings.append("第 \(i + 1) 行: 列数不足，已跳过")
                continue
            }

            let title = columnValue(values, index: columnIndex["title"], fallback: values.count > 1 ? values[1] : "") ?? ""
            let ownerName = columnValue(values, index: columnIndex["owner"], fallback: values.count > 2 ? values[2] : "") ?? ""
            let progressStr = columnValue(values, index: columnIndex["progress"], fallback: values.count > 3 ? values[3] : "0") ?? "0"
            let statusStr = columnValue(values, index: columnIndex["status"], fallback: "not_started") ?? "not_started"
            let nodeTypeStr = columnValue(values, index: columnIndex["nodeType"], fallback: "objective") ?? "objective"
            let scopeStr = columnValue(values, index: columnIndex["scope"], fallback: "enterprise") ?? "enterprise"
            let parentTitle = columnValue(values, index: columnIndex["parentTitle"], fallback: nil)
            let cycleName = columnValue(values, index: columnIndex["cycleName"], fallback: nil)

            let nodeType: NodeType = nodeTypeStr == "key_result" ? .keyResult : .objective
            let scope: Scope = scopeStr == "personal" ? .personal : .enterprise
            let status = NodeStatus(rawValue: statusStr) ?? .notStarted
            let progress = Double(progressStr) ?? 0

            let previewNode = PreviewNode(
                id: UUID(),
                title: title,
                nodeType: nodeType,
                scope: scope,
                ownerName: ownerName,
                progress: progress,
                status: status,
                parentTitle: parentTitle,
                cycleName: cycleName,
                isConflict: false
            )
            previewNodes.append(previewNode)
        }

        return ImportPreview(
            detectedCycles: [],
            detectedNodes: previewNodes,
            newNodesCount: previewNodes.count,
            conflictNodesCount: 0,
            autoCreateCyclesCount: 0,
            detectedFormat: .csv,
            warnings: warnings
        )
    }

    /// 导入 CSV 数据
    private static func importCSV(
        from data: Data,
        conflictStrategy: ConflictStrategy,
        existingNodeIds: Set<UUID>,
        existingCycleNames: Set<String>
    ) throws -> EnhancedImportResult {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else {
            throw ImportError.emptyData
        }

        let header = parseCSVLine(lines[0])
        let columnIndex = buildColumnIndex(header)

        var allNodes: [OKRNode] = []
        var warnings: [String] = []
        var importedCount = 0
        var skippedCount = 0
        var overwrittenCount = 0
        var mergedCount = 0

        // 按 cycleName 分组
        var nodesByCycleName: [String?: [OKRNode]] = [:]

        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            guard values.count >= 4 else {
                warnings.append("第 \(i + 1) 行: 列数不足，已跳过")
                continue
            }

            let idStr = columnValue(values, index: columnIndex["id"], fallback: "") ?? ""
            let title = columnValue(values, index: columnIndex["title"], fallback: values.count > 1 ? values[1] : "") ?? ""
            let ownerName = columnValue(values, index: columnIndex["owner"], fallback: values.count > 2 ? values[2] : "") ?? ""
            let progressStr = columnValue(values, index: columnIndex["progress"], fallback: values.count > 3 ? values[3] : "0") ?? "0"
            let statusStr = columnValue(values, index: columnIndex["status"], fallback: "not_started") ?? "not_started"
            let parentIdStr = columnValue(values, index: columnIndex["parentId"], fallback: nil)
            let nodeTypeStr = columnValue(values, index: columnIndex["nodeType"], fallback: "objective") ?? "objective"
            let scopeStr = columnValue(values, index: columnIndex["scope"], fallback: "enterprise") ?? "enterprise"
            let cycleName = columnValue(values, index: columnIndex["cycleName"], fallback: nil)
            let description = columnValue(values, index: columnIndex["description"], fallback: nil)

            let nodeId = UUID(uuidString: idStr) ?? UUID()
            let nodeType: NodeType = nodeTypeStr == "key_result" ? .keyResult : .objective
            let scope: Scope = scopeStr == "personal" ? .personal : .enterprise
            let status = NodeStatus(rawValue: statusStr) ?? .notStarted
            let progress = Double(progressStr) ?? 0
            let parentId = parentIdStr.flatMap { UUID(uuidString: $0) }

            // 冲突检测
            if existingNodeIds.contains(nodeId) {
                switch conflictStrategy {
                case .skip:
                    skippedCount += 1
                    continue
                case .overwrite:
                    overwrittenCount += 1
                case .merge:
                    mergedCount += 1
                }
            } else {
                importedCount += 1
            }

            let node = OKRNode(
                id: nodeId,
                title: title,
                nodeDescription: description,
                nodeType: nodeType,
                scope: scope,
                currentValue: progress,
                targetValue: 100,
                progress: progress,
                status: status,
                ownerName: ownerName,
                parentId: parentId,
                cycleId: nil
            )

            allNodes.append(node)
            nodesByCycleName[cycleName, default: []].append(node)
        }

        // 自动创建缺失周期
        var autoCreatedCycles: [OKRCycle] = []
        var allCycles: [OKRCycle] = []

        for (cycleName, nodes) in nodesByCycleName {
            if let name = cycleName, !existingCycleNames.contains(name) {
                let cycle = OKRCycle(
                    name: name,
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
                )
                autoCreatedCycles.append(cycle)
                allCycles.append(cycle)

                // 为该周期下的节点设置 cycleId
                for node in nodes {
                    if let index = allNodes.firstIndex(where: { $0.id == node.id }) {
                        allNodes[index].cycleId = cycle.id
                    }
                }
            }
        }

        // 构建树结构
        var nodesByCycle: [UUID: OKRNode] = [:]
        for cycle in allCycles {
            let cycleNodes = allNodes.filter { $0.cycleId == cycle.id }
            if let root = buildTree(from: cycleNodes) {
                nodesByCycle[cycle.id] = root
            }
        }

        let standaloneNodes = allNodes.filter { $0.cycleId == nil }

        return EnhancedImportResult(
            cycles: allCycles,
            autoCreatedCycles: autoCreatedCycles,
            nodesByCycle: nodesByCycle,
            standaloneNodes: standaloneNodes,
            importedCount: importedCount,
            skippedCount: skippedCount,
            overwrittenCount: overwrittenCount,
            mergedCount: mergedCount,
            warnings: warnings
        )
    }

    // MARK: - JSON Import (Enhanced)

    /// 预览 JSON 导入
    private static func previewJSONImport(from data: Data) throws -> ImportPreview {
        let result = try OKRExportService.importFromJSON(data: data)
        var previewNodes: [PreviewNode] = []

        for (_, root) in result.nodesByCycle {
            collectPreviewNodes(root, parentTitle: nil, cycleName: nil, into: &previewNodes)
        }
        for node in result.standaloneNodes {
            collectPreviewNodes(node, parentTitle: nil, cycleName: nil, into: &previewNodes)
        }

        return ImportPreview(
            detectedCycles: result.cycles,
            detectedNodes: previewNodes,
            newNodesCount: previewNodes.count,
            conflictNodesCount: 0,
            autoCreateCyclesCount: 0,
            detectedFormat: .json,
            warnings: []
        )
    }

    /// 导入 JSON 数据（增强版）
    private static func importJSON(
        from data: Data,
        conflictStrategy: ConflictStrategy,
        existingNodeIds: Set<UUID>,
        existingCycleNames: Set<String>
    ) throws -> EnhancedImportResult {
        let result = try OKRExportService.importFromJSON(data: data)

        var importedCount = 0
        var skippedCount = 0
        var overwrittenCount = 0
        var mergedCount = 0
        var warnings: [String] = []
        var autoCreatedCycles: [OKRCycle] = []

        // 处理周期冲突
        var finalCycles: [OKRCycle] = []
        for cycle in result.cycles {
            if existingCycleNames.contains(cycle.name) {
                switch conflictStrategy {
                case .skip:
                    skippedCount += 1
                    continue
                case .overwrite, .merge:
                    finalCycles.append(cycle)
                }
            } else {
                autoCreatedCycles.append(cycle)
                finalCycles.append(cycle)
            }
        }

        // 处理节点冲突
        var filteredNodesByCycle: [UUID: OKRNode] = [:]
        for (cycleId, root) in result.nodesByCycle {
            let filtered = filterNodeTree(root, conflictStrategy: conflictStrategy,
                                          existingNodeIds: existingNodeIds,
                                          importedCount: &importedCount,
                                          skippedCount: &skippedCount,
                                          overwrittenCount: &overwrittenCount,
                                          mergedCount: &mergedCount)
            if let filteredRoot = filtered {
                filteredNodesByCycle[cycleId] = filteredRoot
            }
        }

        var filteredStandalone: [OKRNode] = []
        for node in result.standaloneNodes {
            let filtered = filterNodeTree(node, conflictStrategy: conflictStrategy,
                                          existingNodeIds: existingNodeIds,
                                          importedCount: &importedCount,
                                          skippedCount: &skippedCount,
                                          overwrittenCount: &overwrittenCount,
                                          mergedCount: &mergedCount)
            if let f = filtered {
                filteredStandalone.append(f)
            }
        }

        return EnhancedImportResult(
            cycles: finalCycles,
            autoCreatedCycles: autoCreatedCycles,
            nodesByCycle: filteredNodesByCycle,
            standaloneNodes: filteredStandalone,
            importedCount: importedCount,
            skippedCount: skippedCount,
            overwrittenCount: overwrittenCount,
            mergedCount: mergedCount,
            warnings: warnings
        )
    }

    // MARK: - Lark / Feishu Import

    /// 飞书 OKR 导出数据结构
    private struct LarkOKRExport: Codable {
        let data: LarkData?
        let okr_data: LarkData?
        let items: [LarkOKRItem]?

        enum CodingKeys: String, CodingKey {
            case data, okr_data, items
        }
    }

    private struct LarkData: Codable {
        let okr_list: [LarkOKRItem]?
        let items: [LarkOKRItem]?
        let period_list: [LarkPeriod]?
        let periods: [LarkPeriod]?
    }

    private struct LarkOKRItem: Codable {
        let id: String?
        let name: String?
        let objective: String?
        let progress: Double?
        let status: String?
        let owner: LarkOwner?
        let owner_name: String?
        let period_id: String?
        let period_name: String?
        let key_results: [LarkKeyResult]?
        let sub_objectives: [LarkOKRItem]?
    }

    private struct LarkKeyResult: Codable {
        let id: String?
        let name: String?
        let title: String?
        let progress: Double?
        let status: String?
        let owner: LarkOwner?
        let owner_name: String?
        let score: Double?
        let target_value: Double?
        let current_value: Double?
    }

    private struct LarkOwner: Codable {
        let id: String?
        let name: String?
        let user_name: String?
    }

    private struct LarkPeriod: Codable {
        let id: String?
        let name: String?
        let start_date: String?
        let end_date: String?
    }

    /// 预览 Lark 导入
    private static func previewLarkImport(from data: Data) throws -> ImportPreview {
        let nodes = try parseLarkData(data)
        var previewNodes: [PreviewNode] = []

        for node in nodes {
            collectPreviewNodes(node, parentTitle: nil, cycleName: nil, into: &previewNodes)
        }

        return ImportPreview(
            detectedCycles: [],
            detectedNodes: previewNodes,
            newNodesCount: previewNodes.count,
            conflictNodesCount: 0,
            autoCreateCyclesCount: 0,
            detectedFormat: .lark,
            warnings: []
        )
    }

    /// 导入 Lark 数据
    private static func importLark(
        from data: Data,
        conflictStrategy: ConflictStrategy,
        existingNodeIds: Set<UUID>,
        existingCycleNames: Set<String>
    ) throws -> EnhancedImportResult {
        let nodes = try parseLarkData(data)

        var importedCount = 0
        var skippedCount = 0
        var overwrittenCount = 0
        var mergedCount = 0
        var warnings: [String] = []
        var autoCreatedCycles: [OKRCycle] = []

        // 尝试提取周期信息
        let larkExport = try? JSONDecoder().decode(LarkOKRExport.self, from: data)
        var allCycles: [OKRCycle] = []

        if let periods = larkExport?.data?.period_list ?? larkExport?.data?.periods {
            for period in periods {
                let cycleName = period.name ?? "Imported Period"
                if !existingCycleNames.contains(cycleName) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let startDate = period.start_date.flatMap { formatter.date(from: $0) } ?? Date()
                    let endDate = period.end_date.flatMap { formatter.date(from: $0) } ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

                    let cycle = OKRCycle(
                        id: UUID(uuidString: period.id ?? "") ?? UUID(),
                        name: cycleName,
                        startDate: startDate,
                        endDate: endDate
                    )
                    autoCreatedCycles.append(cycle)
                    allCycles.append(cycle)
                }
            }
        }

        // 过滤节点
        var filteredNodes: [OKRNode] = []
        for node in nodes {
            let filtered = filterNodeTree(node, conflictStrategy: conflictStrategy,
                                          existingNodeIds: existingNodeIds,
                                          importedCount: &importedCount,
                                          skippedCount: &skippedCount,
                                          overwrittenCount: &overwrittenCount,
                                          mergedCount: &mergedCount)
            if let f = filtered {
                filteredNodes.append(f)
            }
        }

        var nodesByCycle: [UUID: OKRNode] = [:]
        if let firstCycle = allCycles.first, let root = buildTree(from: filteredNodes) {
            nodesByCycle[firstCycle.id] = root
        }

        return EnhancedImportResult(
            cycles: allCycles,
            autoCreatedCycles: autoCreatedCycles,
            nodesByCycle: nodesByCycle,
            standaloneNodes: allCycles.isEmpty ? filteredNodes : [],
            importedCount: importedCount,
            skippedCount: skippedCount,
            overwrittenCount: overwrittenCount,
            mergedCount: mergedCount,
            warnings: warnings
        )
    }

    /// 解析飞书 OKR 数据为 OKRNode 列表
    private static func parseLarkData(_ data: Data) throws -> [OKRNode] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidFormat
        }

        var items: [[String: Any]] = []

        // 飞书导出格式可能有多种结构
        if let dataObj = json["data"] as? [String: Any],
           let okrList = dataObj["okr_list"] as? [[String: Any]] {
            items = okrList
        } else if let dataObj = json["data"] as? [String: Any],
                  let itemList = dataObj["items"] as? [[String: Any]] {
            items = itemList
        } else if let okrData = json["okr_data"] as? [String: Any],
                  let okrList = okrData["okr_list"] as? [[String: Any]] {
            items = okrList
        } else if let itemList = json["items"] as? [[String: Any]] {
            items = itemList
        }

        var nodes: [OKRNode] = []
        for item in items {
            if let node = parseLarkOKRItem(item) {
                nodes.append(node)
            }
        }

        return nodes
    }

    /// 解析单个飞书 OKR 项
    private static func parseLarkOKRItem(_ item: [String: Any]) -> OKRNode? {
        guard let name = item["name"] as? String ?? item["objective"] as? String else {
            return nil
        }

        let idStr = item["id"] as? String ?? UUID().uuidString
        let progress = item["progress"] as? Double ?? 0
        let statusStr = item["status"] as? String ?? "in_progress"
        let ownerName: String
        if let owner = item["owner"] as? [String: Any],
           let name = owner["name"] as? String ?? owner["user_name"] as? String {
            ownerName = name
        } else {
            ownerName = item["owner_name"] as? String ?? ""
        }

        let status = parseLarkStatus(statusStr)
        let nodeId = UUID(uuidString: idStr) ?? UUID()

        // 解析子 KR
        var children: [OKRNode] = []
        if let keyResults = item["key_results"] as? [[String: Any]] {
            for kr in keyResults {
                if let krNode = parseLarkKeyResult(kr, parentId: nodeId) {
                    children.append(krNode)
                }
            }
        }

        // 解析子 Objective
        if let subObjectives = item["sub_objectives"] as? [[String: Any]] {
            for sub in subObjectives {
                if let subNode = parseLarkOKRItem(sub) {
                    var mutableSub = subNode
                    mutableSub.parentId = nodeId
                    children.append(mutableSub)
                }
            }
        }

        return OKRNode(
            id: nodeId,
            title: name,
            nodeType: .objective,
            scope: .enterprise,
            currentValue: progress,
            targetValue: 100,
            progress: progress,
            status: status,
            ownerName: ownerName,
            children: children
        )
    }

    /// 解析飞书 Key Result
    private static func parseLarkKeyResult(_ kr: [String: Any], parentId: UUID) -> OKRNode? {
        guard let name = kr["name"] as? String ?? kr["title"] as? String else {
            return nil
        }

        let idStr = kr["id"] as? String ?? UUID().uuidString
        let progress = kr["progress"] as? Double ?? kr["score"] as? Double ?? 0
        let statusStr = kr["status"] as? String ?? "in_progress"
        let ownerName: String
        if let owner = kr["owner"] as? [String: Any],
           let name = owner["name"] as? String ?? owner["user_name"] as? String {
            ownerName = name
        } else {
            ownerName = kr["owner_name"] as? String ?? ""
        }

        let status = parseLarkStatus(statusStr)
        let currentValue = kr["current_value"] as? Double ?? progress
        let targetValue = kr["target_value"] as? Double ?? 100

        return OKRNode(
            id: UUID(uuidString: idStr) ?? UUID(),
            title: name,
            nodeType: .keyResult,
            scope: .enterprise,
            currentValue: currentValue,
            targetValue: targetValue,
            progress: progress,
            status: status,
            ownerName: ownerName,
            parentId: parentId
        )
    }

    /// 解析飞书状态字符串
    private static func parseLarkStatus(_ statusStr: String) -> NodeStatus {
        switch statusStr.lowercased() {
        case "not_started", "notstarted", "未开始":
            return .notStarted
        case "in_progress", "inprogress", "进行中":
            return .inProgress
        case "at_risk", "atrisk", "有风险", "risk":
            return .atRisk
        case "completed", "done", "已完成", "完成":
            return .completed
        case "cancelled", "canceled", "已取消", "取消":
            return .cancelled
        default:
            return .inProgress
        }
    }

    // MARK: - Helper Methods

    /// 解析 CSV 行（处理引号包裹的字段）
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var chars = Array(line)

        var i = 0
        while i < chars.count {
            let char = chars[i]
            if char == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    currentField.append("\"")
                    i += 2
                    continue
                }
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
            i += 1
        }
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        return fields
    }

    /// 构建列名到索引的映射
    private static func buildColumnIndex(_ header: [String]) -> [String: Int] {
        var index: [String: Int] = [:]
        for (i, col) in header.enumerated() {
            let normalized = col.lowercased().trimmingCharacters(in: .whitespaces)
            switch normalized {
            case "id": index["id"] = i
            case "title", "name", "标题", "名称": index["title"] = i
            case "owner", "负责人", "ownername": index["owner"] = i
            case "progress", "进度": index["progress"] = i
            case "status", "状态": index["status"] = i
            case "parentid", "parent_id", "父节点": index["parentId"] = i
            case "nodetype", "node_type", "类型": index["nodeType"] = i
            case "scope", "范围": index["scope"] = i
            case "cyclename", "cycle_name", "周期": index["cycleName"] = i
            case "description", "描述": index["description"] = i
            case "parenttitle", "parent_title", "父标题": index["parentTitle"] = i
            default: break
            }
        }
        return index
    }

    /// 获取列值（带回退）
    private static func columnValue(_ values: [String], index: Int?, fallback: String?) -> String? {
        guard let idx = index, idx < values.count else { return fallback }
        let value = values[idx]
        return value.isEmpty ? fallback : value
    }

    /// 递归收集预览节点
    private static func collectPreviewNodes(
        _ node: OKRNode,
        parentTitle: String?,
        cycleName: String?,
        into previewNodes: inout [PreviewNode]
    ) {
        let preview = PreviewNode(
            id: node.id,
            title: node.title,
            nodeType: node.nodeType,
            scope: node.scope,
            ownerName: node.ownerName,
            progress: node.progress,
            status: node.status,
            parentTitle: parentTitle,
            cycleName: cycleName,
            isConflict: false
        )
        previewNodes.append(preview)

        for child in node.children {
            collectPreviewNodes(child, parentTitle: node.title, cycleName: cycleName, into: &previewNodes)
        }
    }

    /// 过滤节点树（处理冲突）
    private static func filterNodeTree(
        _ node: OKRNode,
        conflictStrategy: ConflictStrategy,
        existingNodeIds: Set<UUID>,
        importedCount: inout Int,
        skippedCount: inout Int,
        overwrittenCount: inout Int,
        mergedCount: inout Int
    ) -> OKRNode? {
        if existingNodeIds.contains(node.id) {
            switch conflictStrategy {
            case .skip:
                skippedCount += 1
                return nil
            case .overwrite:
                overwrittenCount += 1
            case .merge:
                mergedCount += 1
            }
        } else {
            importedCount += 1
        }

        var filteredChildren: [OKRNode] = []
        for child in node.children {
            if let filtered = filterNodeTree(child, conflictStrategy: conflictStrategy,
                                              existingNodeIds: existingNodeIds,
                                              importedCount: &importedCount,
                                              skippedCount: &skippedCount,
                                              overwrittenCount: &overwrittenCount,
                                              mergedCount: &mergedCount) {
                filteredChildren.append(filtered)
            }
        }

        var result = node
        result.children = filteredChildren
        return result
    }

    /// 从扁平节点列表构建树结构
    private static func buildTree(from nodes: [OKRNode]) -> OKRNode? {
        guard !nodes.isEmpty else { return nil }

        var nodeMap: [UUID: OKRNode] = [:]
        for node in nodes {
            nodeMap[node.id] = node
        }

        var rootNodes: [OKRNode] = []
        for node in nodes {
            if let parentId = node.parentId, nodeMap[parentId] != nil {
                nodeMap[parentId]?.children.append(node)
            } else {
                rootNodes.append(node)
            }
        }

        // 更新 map 中的父节点
        for (id, var node) in nodeMap {
            if let parentId = node.parentId, var parent = nodeMap[parentId] {
                if !parent.children.contains(where: { $0.id == id }) {
                    parent.children.append(node)
                    nodeMap[parentId] = parent
                }
            }
        }

        return rootNodes.first
    }

    // MARK: - Error Types

    /// 导入错误
    public enum ImportError: Error, LocalizedError {
        case invalidFormat
        case invalidEncoding
        case emptyData
        case missingData

        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "无效的导入格式"
            case .invalidEncoding:
                return "文件编码无效，请使用 UTF-8 编码"
            case .emptyData:
                return "导入文件为空或没有有效数据"
            case .missingData:
                return "导入文件中缺少必要的数据字段"
            }
        }
    }
}
