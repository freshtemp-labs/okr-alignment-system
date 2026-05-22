import Foundation
import SwiftUI

/// OKR节点状态枚举
/// 描述节点当前的生命周期状态，用于进度追踪和风险预警
/// 状态流转：notStarted → inProgress → [atRisk] → completed / cancelled
public enum NodeStatus: String, CaseIterable, Codable, Sendable {
    /// 未开始 - 节点已创建但尚未开始执行
    case notStarted = "not_started"

    /// 进行中 - 节点正在正常推进
    case inProgress = "in_progress"

    /// 有风险 - 节点进度滞后或遇到阻碍，需要关注
    case atRisk = "at_risk"

    /// 已完成 - 节点目标已达成
    case completed = "completed"

    /// 已取消 - 节点不再执行（目标变更或资源调整等原因）
    case cancelled = "cancelled"
}

// MARK: - Display Helpers

extension NodeStatus {
    /// 返回状态的中文显示名称
    public var displayName: String {
        switch self {
        case .notStarted:
            return "未开始"
        case .inProgress:
            return "进行中"
        case .atRisk:
            return "有风险"
        case .completed:
            return "已完成"
        case .cancelled:
            return "已取消"
        }
    }

    /// 返回状态对应的UI颜色
    /// 用于状态指示器、标签和进度条的着色
    public var color: Color {
        switch self {
        case .notStarted:
            return Color.gray
        case .inProgress:
            return Color.blue
        case .atRisk:
            return Color.orange
        case .completed:
            return Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669 绿色
        case .cancelled:
            return Color.red.opacity(0.7)
        }
    }

    /// 返回状态对应的图标名称（SF Symbols）
    public var iconName: String {
        switch self {
        case .notStarted:
            return "circle.dashed"
        case .inProgress:
            return "arrow.triangle.2.circlepath"
        case .atRisk:
            return "exclamationmark.triangle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    /// 判断状态是否为终态（不可再变更）
    public var isTerminal: Bool {
        self == .completed || self == .cancelled
    }

    /// 判断状态是否活跃（需要持续跟踪）
    public var isActive: Bool {
        self == .notStarted || self == .inProgress || self == .atRisk
    }
}
