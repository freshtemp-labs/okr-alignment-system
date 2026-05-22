// OKRAlignmentShared/Widget/OKRWidgetTimelineProvider.swift
//
// Widget Timeline Provider
// 为 OKR Progress Widget 提供数据
// 从 Core Data 读取当前活跃周期的 Top 3 KR 进度

#if canImport(WidgetKit)
import WidgetKit
import SwiftUI
import CoreData

/// Widget 数据条目
/// 包含 Widget 展示所需的所有数据
struct OKRWidgetEntry: TimelineEntry {
    /// 条目时间
    let date: Date
    /// 周期名称
    let cycleName: String
    /// Top 3 KR 数据
    let topKRs: [KRDisplayData]
    /// 总体进度
    let overallProgress: Double
    /// 是否有数据
    let hasData: Bool

    /// KR 展示数据
    struct KRDisplayData: Identifiable {
        let id: UUID
        let title: String
        let progress: Double
        let ownerName: String
        let status: String
    }

    /// 空数据占位
    static var placeholder: OKRWidgetEntry {
        OKRWidgetEntry(
            date: Date(),
            cycleName: "暂无周期",
            topKRs: [],
            overallProgress: 0,
            hasData: false
        )
    }

    /// 示例数据（用于 Widget 预览和加载中状态）
    static var sample: OKRWidgetEntry {
        OKRWidgetEntry(
            date: Date(),
            cycleName: "2026 Q1",
            topKRs: [
                KRDisplayData(
                    id: UUID(),
                    title: "NPS评分提升至50分",
                    progress: 70.0,
                    ownerName: "李四",
                    status: "in_progress"
                ),
                KRDisplayData(
                    id: UUID(),
                    title: "新用户7日留存率40%",
                    progress: 80.0,
                    ownerName: "王五",
                    status: "in_progress"
                ),
                KRDisplayData(
                    id: UUID(),
                    title: "月活跃用户增长25%",
                    progress: 45.0,
                    ownerName: "赵六",
                    status: "at_risk"
                )
            ],
            overallProgress: 65.0,
            hasData: true
        )
    }
}

/// Widget Timeline Provider
/// 负责提供和刷新 Widget 数据
struct OKRWidgetProvider: TimelineProvider {

    /// 占位视图（Widget 加载时展示）
    func placeholder(in context: Context) -> OKRWidgetEntry {
        .sample
    }

    /// 快照（Widget 预览和配置时展示）
    func getSnapshot(in context: Context, completion: @escaping (OKRWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
        } else {
            completion(loadCurrentData())
        }
    }

    /// 时间线条目（决定 Widget 何时刷新）
    func getTimeline(in context: Context, completion: @escaping (Timeline<OKRWidgetEntry>) -> Void) {
        let entry = loadCurrentData()
        // 每 30 分钟刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Data Loading

    /// 从 Core Data 加载当前活跃周期的 Top 3 KR 数据
    private func loadCurrentData() -> OKRWidgetEntry {
        let persistence = PersistenceController.shared
        let context = persistence.viewContext

        // 查找活跃周期
        let cycleRequest = NSFetchRequest<OKRCycleEntity>(entityName: "OKRCycleEntity")
        cycleRequest.predicate = NSPredicate(format: "isActive == true")
        cycleRequest.fetchLimit = 1

        guard let activeCycle = try? context.fetch(cycleRequest).first else {
            return .placeholder
        }

        let cycleId = activeCycle.id
        let cycleName = activeCycle.name

        // 查找该周期下的所有 KR 节点（叶子节点），按进度排序
        let nodeRequest = NSFetchRequest<OKRNodeEntity>(entityName: "OKRNodeEntity")
        nodeRequest.predicate = NSPredicate(
            format: "cycleId == %@ AND nodeType == %@ AND children.@count == 0",
            cycleId as CVarArg,
            "keyResult"
        )
        nodeRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \OKRNodeEntity.progress, ascending: false)
        ]
        nodeRequest.fetchLimit = 3

        let nodes = (try? context.fetch(nodeRequest)) ?? []

        let topKRs = nodes.map { node -> OKRWidgetEntry.KRDisplayData in
            OKRWidgetEntry.KRDisplayData(
                id: node.id,
                title: node.title,
                progress: node.progress,
                ownerName: node.ownerName,
                status: node.status
            )
        }

        // 计算总体进度（所有 KR 平均）
        let allKRRequest = NSFetchRequest<OKRNodeEntity>(entityName: "OKRNodeEntity")
        allKRRequest.predicate = NSPredicate(
            format: "cycleId == %@ AND nodeType == %@ AND children.@count == 0",
            cycleId as CVarArg,
            "keyResult"
        )
        let allKRs = (try? context.fetch(allKRRequest)) ?? []
        let overallProgress: Double
        if allKRs.isEmpty {
            overallProgress = 0
        } else {
            overallProgress = allKRs.map(\.progress).reduce(0, +) / Double(allKRs.count)
        }

        return OKRWidgetEntry(
            date: Date(),
            cycleName: cycleName,
            topKRs: topKRs,
            overallProgress: overallProgress,
            hasData: !topKRs.isEmpty
        )
    }
}
#endif
