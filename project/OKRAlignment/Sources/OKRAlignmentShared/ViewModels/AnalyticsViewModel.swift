import Foundation
import SwiftUI

/// 分析视图ViewModel
/// =================
/// 负责从OKR树数据中提取统计数据，供分析视图展示。
///
/// # 职责
/// - 计算KR状态分布（已完成/进行中/滞后等）
/// - 计算各Owner的进度排名
/// - 计算整体统计指标（平均完成率、最高/最低进度）
/// - 支持多周期的进度趋势
///
@MainActor
@Observable
public final class AnalyticsViewModel {

    // MARK: - 发布状态属性

    /// KR状态分布数据（用于饼图）
    public var statusDistribution: [StatusCount] = []

    /// 各Owner的进度排名（用于柱状图）
    public var ownerRankings: [OwnerProgress] = []

    /// 多周期进度趋势数据（用于折线图）
    public var trendData: [CycleTrendPoint] = []

    /// 整体统计指标
    public var statistics: OKRStatistics = OKRStatistics()

    /// 热力图数据（各Owner进度分布）
    public var heatmapData: [HeatmapRow] = []

    /// 甘特图数据（节点时间线）
    public var ganttItems: [GanttItem] = []

    /// 网络图节点
    public var networkNodes: [NetworkNode] = []

    /// 网络图边
    public var networkEdges: [NetworkEdge] = []

    /// 是否正在计算
    public var isLoading: Bool = false

    /// 错误信息
    public var errorMessage: String?

    // MARK: - 依赖

    private let repository: OKRRepositoryProtocol

    // MARK: - 初始化

    public init(repository: OKRRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - 公开接口

    /// 加载分析数据
    /// - Parameter cycleId: 当前周期ID，用于获取当前树数据
    public func loadAnalytics(cycleId: UUID?) async {
        isLoading = true
        errorMessage = nil

        do {
            let rootNodes = try await repository.fetchRootNodes(cycleId: cycleId)
            guard let root = rootNodes.first else {
                statusDistribution = []
                ownerRankings = []
                statistics = OKRStatistics()
                isLoading = false
                return
            }

            // 收集所有节点
            let allNodes = flattenAllNodes(root)

            // 计算KR状态分布
            calculateStatusDistribution(from: allNodes)

            // 计算Owner进度排名
            calculateOwnerRankings(from: allNodes)

            // 计算整体统计
            calculateStatistics(from: allNodes)

            // 计算热力图数据
            calculateHeatmapData(from: allNodes)

            // 计算甘特图数据
            calculateGanttData(from: allNodes, cycle: nil)

            // 计算网络图数据
            calculateNetworkData(from: root, allNodes: allNodes)

            // 加载趋势数据（所有周期）
            await loadTrendData()

        } catch {
            errorMessage = "加载分析数据失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 私有方法

    /// 递归展平所有节点
    private func flattenAllNodes(_ node: OKRNode) -> [OKRNode] {
        var result = [node]
        for child in node.children {
            result.append(contentsOf: flattenAllNodes(child))
        }
        return result
    }

    /// 计算KR状态分布
    private func calculateStatusDistribution(from nodes: [OKRNode]) {
        // 只统计Key Result节点
        let krNodes = nodes.filter { $0.nodeType == .keyResult }
        var counts: [NodeStatus: Int] = [:]

        for status in NodeStatus.allCases {
            counts[status] = krNodes.filter { $0.status == status }.count
        }

        statusDistribution = NodeStatus.allCases.compactMap { status in
            let count = counts[status] ?? 0
            guard count > 0 else { return nil }
            return StatusCount(status: status, count: count)
        }
    }

    /// 计算各Owner的进度排名
    private func calculateOwnerRankings(from nodes: [OKRNode]) {
        // 按Owner分组，计算每个Owner管理的KR的平均进度
        let krNodes = nodes.filter { $0.nodeType == .keyResult && $0.isLeaf }
        var ownerGroups: [String: [OKRNode]] = [:]

        for node in krNodes {
            ownerGroups[node.ownerName, default: []].append(node)
        }

        ownerRankings = ownerGroups.map { owner, nodes in
            let avgProgress = nodes.map(\.progress).reduce(0, +) / Double(max(nodes.count, 1))
            return OwnerProgress(ownerName: owner, averageProgress: avgProgress, krCount: nodes.count)
        }
        .sorted { $0.averageProgress > $1.averageProgress }
    }

    /// 计算整体统计指标
    private func calculateStatistics(from nodes: [OKRNode]) {
        let krNodes = nodes.filter { $0.nodeType == .keyResult && $0.isLeaf }
        let allObjectives = nodes.filter { $0.nodeType == .objective }

        guard !krNodes.isEmpty else {
            statistics = OKRStatistics()
            return
        }

        let progressValues = krNodes.map(\.progress)
        let avgProgress = progressValues.reduce(0, +) / Double(progressValues.count)
        let maxProgress = progressValues.max() ?? 0
        let minProgress = progressValues.min() ?? 0

        let completedCount = krNodes.filter { $0.status == .completed }.count
        let atRiskCount = krNodes.filter { $0.status == .atRisk }.count
        let inProgressCount = krNodes.filter { $0.status == .inProgress }.count

        statistics = OKRStatistics(
            totalNodes: nodes.count,
            totalObjectives: allObjectives.count,
            totalKeyResults: krNodes.count,
            averageProgress: avgProgress,
            maxProgress: maxProgress,
            minProgress: minProgress,
            completedCount: completedCount,
            atRiskCount: atRiskCount,
            inProgressCount: inProgressCount,
            completionRate: Double(completedCount) / Double(max(krNodes.count, 1)) * 100
        )
    }

    /// 加载多周期趋势数据
    private func loadTrendData() async {
        do {
            let cycles = try await repository.fetchCycles()
            var points: [CycleTrendPoint] = []

            for cycle in cycles.sorted(by: { $0.startDate < $1.startDate }) {
                let rootNodes = try await repository.fetchRootNodes(cycleId: cycle.id)
                if let root = rootNodes.first {
                    let allNodes = flattenAllNodes(root)
                    let krNodes = allNodes.filter { $0.nodeType == .keyResult && $0.isLeaf }
                    let avg = krNodes.isEmpty ? 0 : krNodes.map(\.progress).reduce(0, +) / Double(krNodes.count)
                    points.append(CycleTrendPoint(cycleName: cycle.name, averageProgress: avg, date: cycle.startDate))
                }
            }

            trendData = points
        } catch {
            // 趋势数据加载失败不影响其他统计
            trendData = []
        }
    }

    // MARK: - 热力图数据计算

    /// 计算各Owner的热力图数据（进度、完成率、风险率、KR数）
    private func calculateHeatmapData(from nodes: [OKRNode]) {
        let krNodes = nodes.filter { $0.nodeType == .keyResult && $0.isLeaf }
        var ownerGroups: [String: [OKRNode]] = [:]

        for node in krNodes {
            ownerGroups[node.ownerName, default: []].append(node)
        }

        heatmapData = ownerGroups.map { owner, nodes in
            let avgProgress = nodes.map(\.progress).reduce(0, +) / Double(max(nodes.count, 1))
            let completedCount = nodes.filter { $0.status == .completed }.count
            let atRiskCount = nodes.filter { $0.status == .atRisk }.count
            let completedRate = Double(completedCount) / Double(max(nodes.count, 1)) * 100
            let atRiskRate = Double(atRiskCount) / Double(max(nodes.count, 1)) * 100

            return HeatmapRow(
                ownerName: owner,
                averageProgress: avgProgress,
                completedRate: completedRate,
                atRiskRate: atRiskRate,
                krCount: nodes.count
            )
        }
        .sorted { $0.averageProgress > $1.averageProgress }
    }

    // MARK: - 甘特图数据计算

    /// 计算甘特图数据（各节点的时间线）
    private func calculateGanttData(from nodes: [OKRNode], cycle: OKRCycle?) {
        // 使用节点的创建时间作为开始，当前时间或完成时间作为结束
        // 基于节点进度模拟时间线
        let objectives = nodes.filter { $0.nodeType == .objective }

        ganttItems = objectives.compactMap { node -> GanttItem? in
            let startDate = node.createdAt
            let now = Date()
            // 如果已完成，使用更新时间；否则使用当前时间
            let endDate = node.status == .completed ? node.updatedAt : now
            // 确保结束日期在开始日期之后
            let effectiveEnd = max(endDate, startDate.addingTimeInterval(86400))

            return GanttItem(
                id: node.id,
                title: String(node.title.prefix(20)),
                actualStartDate: startDate,
                actualEndDate: effectiveEnd,
                progress: node.progress,
                status: node.status
            )
        }
        .sorted { $0.actualStartDate < $1.actualStartDate }
    }

    // MARK: - 网络图数据计算

    /// 计算网络图数据（节点和连线）
    private func calculateNetworkData(from root: OKRNode, allNodes: [OKRNode]) {
        var nodes: [NetworkNode] = []
        var edges: [NetworkEdge] = []

        // 计算层级布局
        func addNodeAndChildren(_ node: OKRNode, depth: Int, index: Int, maxSiblings: Int) {
            // 计算归一化坐标
            let x: CGFloat
            let y: CGFloat

            if node.isRoot {
                x = 0.5
                y = 0.08
            } else {
                // 水平分散，垂直按深度排列
                let depthSpacing = CGFloat(depth) / CGFloat(max(4, maxTreeDepth(allNodes)))
                y = 0.08 + depthSpacing * 0.85

                let siblingCount = max(maxSiblings, 1)
                let fraction = CGFloat(index) / CGFloat(max(siblingCount - 1, 1))
                x = 0.15 + fraction * 0.7
            }

            let networkNode = NetworkNode(
                id: node.id,
                title: node.title,
                nodeType: node.nodeType,
                ownerName: node.ownerName,
                progress: node.progress,
                normalizedX: x,
                normalizedY: min(0.92, y)
            )
            nodes.append(networkNode)

            // 创建到子节点的边
            for (childIndex, child) in node.children.enumerated() {
                let edge = NetworkEdge(
                    fromId: node.id,
                    toId: child.id,
                    color: child.nodeType == .objective ? .orange : .blue
                )
                edges.append(edge)

                addNodeAndChildren(
                    child,
                    depth: depth + 1,
                    index: childIndex,
                    maxSiblings: node.children.count
                )
            }
        }

        // 计算树的最大深度
        func maxTreeDepth(_ nodes: [OKRNode]) -> Int {
            var maxDepth = 0
            func walk(_ node: OKRNode, _ depth: Int) {
                maxDepth = max(maxDepth, depth)
                for child in node.children {
                    walk(child, depth + 1)
                }
            }
            for node in nodes where node.isRoot {
                walk(node, 0)
            }
            return max(maxDepth, 1)
        }

        addNodeAndChildren(root, depth: 0, index: 0, maxSiblings: 1)

        networkNodes = nodes
        networkEdges = edges
    }
}

// MARK: - 数据模型

/// KR状态分布统计
public struct StatusCount: Identifiable, Sendable {
    public let id = UUID()
    public let status: NodeStatus
    public let count: Int

    public var displayName: String { status.displayName }
    public var color: Color { status.color }
}

/// Owner进度排名
public struct OwnerProgress: Identifiable, Sendable {
    public let id = UUID()
    public let ownerName: String
    public let averageProgress: Double
    public let krCount: Int
}

/// 周期趋势数据点
public struct CycleTrendPoint: Identifiable, Sendable {
    public let id = UUID()
    public let cycleName: String
    public let averageProgress: Double
    public let date: Date
}

/// OKR整体统计指标
public struct OKRStatistics: Sendable {
    public let totalNodes: Int
    public let totalObjectives: Int
    public let totalKeyResults: Int
    public let averageProgress: Double
    public let maxProgress: Double
    public let minProgress: Double
    public let completedCount: Int
    public let atRiskCount: Int
    public let inProgressCount: Int
    public let completionRate: Double

    public init(
        totalNodes: Int = 0,
        totalObjectives: Int = 0,
        totalKeyResults: Int = 0,
        averageProgress: Double = 0,
        maxProgress: Double = 0,
        minProgress: Double = 0,
        completedCount: Int = 0,
        atRiskCount: Int = 0,
        inProgressCount: Int = 0,
        completionRate: Double = 0
    ) {
        self.totalNodes = totalNodes
        self.totalObjectives = totalObjectives
        self.totalKeyResults = totalKeyResults
        self.averageProgress = averageProgress
        self.maxProgress = maxProgress
        self.minProgress = minProgress
        self.completedCount = completedCount
        self.atRiskCount = atRiskCount
        self.inProgressCount = inProgressCount
        self.completionRate = completionRate
    }
}
