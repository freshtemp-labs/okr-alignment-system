import Foundation
import SwiftUI

/// OKR节点类型枚举
/// 表示节点是Objective（目标）还是Key Result（关键结果）
/// Objective用于描述定性的目标，Key Result用于描述定量的衡量指标
/// 在树状结构中，Objective可以包含多个Key Result，也可以包含下级Objective
public enum NodeType: String, CaseIterable, Codable, Sendable {
    /// 目标节点 - 描述要达成的定性目标
    /// 例："提升产品用户体验"
    case objective = "objective"

    /// 关键结果节点 - 描述可量化的衡量指标
    /// 例："NPS评分从30提升到50"
    case keyResult = "key_result"
}

// MARK: - Display Helpers

extension NodeType {
    /// 返回节点类型的中文显示名称
    public var displayName: String {
        switch self {
        case .objective:
            return "目标"
        case .keyResult:
            return "关键结果"
        }
    }

    /// 返回节点类型的图标名称（SF Symbols）
    public var iconName: String {
        switch self {
        case .objective:
            return "flag.fill"
        case .keyResult:
            return "number"
        }
    }

    /// 返回节点类型对应的颜色标识
    public var color: Color {
        switch self {
        case .objective:
            return .orange
        case .keyResult:
            return .green
        }
    }
}
