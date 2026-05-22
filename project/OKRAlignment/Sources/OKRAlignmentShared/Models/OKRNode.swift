import Foundation
import SwiftUI

/// OKR节点领域模型 - 树状结构的基本单元
/// 支持企业级Objective → 企业级KR → 个人级O → 个人级KR的层级结构
/// 每个节点代表OKR树中的一个目标或关键结果，通过parentId和children形成树形关系
/// - 企业级Objective：公司战略目标，包含多个企业级KR
/// - 企业级KR：衡量公司战略目标的关键结果，可拆分为个人级Objective
/// - 个人级Objective：员工个人目标，与上级KR对齐，包含多个个人级KR
/// - 个人级KR：衡量个人目标的关键结果，是叶子节点
public struct OKRNode: Identifiable, Equatable, Hashable, Sendable {

    // MARK: - Properties

    /// 节点唯一标识符
    public let id: UUID

    /// 节点标题（简述目标或关键结果）
    public var title: String

    /// 节点详细描述（可选，用于补充说明背景信息）
    public var nodeDescription: String?

    /// 节点类型：Objective（目标）或 Key Result（关键结果）
    public var nodeType: NodeType

    /// 范围：企业级或个人级
    public var scope: Scope

    /// 当前实际值（用于计算进度，叶子KR节点必填）
    public var currentValue: Double

    /// 目标值（用于计算进度，必须大于0）
    public var targetValue: Double

    /// 计量单位（可选，如"%"、"分"、"个"等）
    public var unit: String?

    /// 进度百分比（0.0 - 100.0），自动根据currentValue和targetValue计算
    public var progress: Double

    /// 节点当前状态
    public var status: NodeStatus

    /// 负责人姓名
    public var ownerName: String

    /// 创建时间
    public var createdAt: Date

    /// 最后更新时间
    public var updatedAt: Date

    /// 同级节点中的排序索引，用于控制显示顺序
    public var sortOrder: Int

    /// 父节点ID（可选，nil表示根节点）
    public var parentId: UUID?

    /// 子节点数组（树状结构的下级节点）
    public var children: [OKRNode]

    /// 所属周期ID（必须关联到一个OKR周期）
    public var cycleId: UUID?

    /// 节点权重（用于加权进度计算，默认1.0）
    /// 权重越大，该节点对父节点进度的影响越大
    /// 例如：权重为2.0的KR对父节点进度的贡献是权重1.0的两倍
    public var weight: Double

    /// 乐观锁版本号（用于冲突解决）
    /// 每次成功更新时自增1，用于compare-and-swap并发控制
    public var version: Int

    // MARK: - Computed Properties

    /// 是否为叶子KR节点（无子节点且类型为KR）
    /// 叶子节点是进度追踪的最小单位，必须有数值
    public var isLeaf: Bool {
        children.isEmpty && nodeType == .keyResult
    }

    /// 是否为根节点（无父节点）
    public var isRoot: Bool {
        parentId == nil
    }

    /// 是否为权重已设置（非默认值）
    public var hasCustomWeight: Bool {
        weight != 1.0
    }

    /// 格式化后的进度百分比字符串
    /// 示例："75.0%"
    public var progressPercentage: String {
        String(format: "%.1f%%", progress)
    }

    /// 格式化后的数值显示字符串
    /// 叶子节点显示具体数值："20 / 100 %"
    /// 非叶子节点显示汇总信息
    public var valueDisplayString: String {
        if isLeaf {
            return "\(Int(currentValue)) / \(Int(targetValue)) \(unit ?? "")"
        }
        // 非叶子节点显示子节点的加权平均进度
        if !children.isEmpty {
            let avgProgress = children.map(\.progress).reduce(0, +) / Double(children.count)
            return "子节点平均进度: \(String(format: "%.1f%%", avgProgress))"
        }
        return "对齐汇总完成度"
    }

    /// 节点深度（根节点为0）
    /// 用于UI缩进和视觉层级展示
    public func depth(in tree: [OKRNode]) -> Int {
        guard let parentId = parentId else { return 0 }
        // 在树中查找父节点并递归计算深度
        for node in tree {
            if node.id == parentId {
                return 1 + node.depth(in: tree)
            }
            // 在当前节点的子树中搜索
            let parentDepth = findParentDepth(parentId: parentId, in: node.children, currentDepth: 1)
            if parentDepth > 0 {
                return parentDepth
            }
        }
        return 0
    }

    // MARK: - Initializer

    /// 创建新的OKR节点
    /// - Parameters:
    ///   - id: 唯一标识符（默认自动生成）
    ///   - title: 标题
    ///   - nodeDescription: 描述（可选）
    ///   - nodeType: 节点类型
    ///   - scope: 范围
    ///   - currentValue: 当前值
    ///   - targetValue: 目标值
    ///   - unit: 单位（可选）
    ///   - progress: 进度（默认根据currentValue和targetValue计算）
    ///   - status: 状态（默认.notStarted）
    ///   - ownerName: 负责人
    ///   - sortOrder: 排序索引（默认0）
    ///   - parentId: 父节点ID（可选）
    ///   - children: 子节点数组（默认空）
    ///   - cycleId: 周期ID（可选）
    ///   - createdAt: 创建时间（默认当前时间）
    ///   - updatedAt: 更新时间（默认当前时间）
    public init(
        id: UUID = UUID(),
        title: String,
        nodeDescription: String? = nil,
        nodeType: NodeType,
        scope: Scope,
        currentValue: Double = 0,
        targetValue: Double,
        unit: String? = nil,
        progress: Double? = nil,
        status: NodeStatus = .notStarted,
        ownerName: String,
        sortOrder: Int = 0,
        parentId: UUID? = nil,
        children: [OKRNode] = [],
        cycleId: UUID? = nil,
        weight: Double = 1.0,
        version: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.nodeDescription = nodeDescription
        self.nodeType = nodeType
        self.scope = scope
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.unit = unit

        // 如果显式提供了progress则使用，否则自动计算
        if let explicitProgress = progress {
            self.progress = max(0, min(100, explicitProgress))
        } else {
            // 自动计算进度：currentValue / targetValue * 100
            if targetValue > 0 {
                self.progress = min(100, max(0, (currentValue / targetValue) * 100))
            } else {
                self.progress = 0
            }
        }

        self.status = status
        self.ownerName = ownerName
        self.sortOrder = sortOrder
        self.parentId = parentId
        self.children = children
        self.cycleId = cycleId
        self.weight = weight
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: OKRNode, rhs: OKRNode) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.progress == rhs.progress
            && lhs.status == rhs.status
            && lhs.currentValue == rhs.currentValue
            && lhs.targetValue == rhs.targetValue
            && lhs.ownerName == rhs.ownerName
            && lhs.children == rhs.children
            && lhs.weight == rhs.weight
            && lhs.version == rhs.version
    }
}

// MARK: - Private Helpers

extension OKRNode {
    /// 递归查找父节点的深度
    /// - Parameters:
    ///   - parentId: 要查找的父节点ID
    ///   - nodes: 当前搜索范围的节点数组
    ///   - currentDepth: 当前深度计数
    /// - Returns: 父节点的深度，未找到返回0
    private func findParentDepth(parentId: UUID, in nodes: [OKRNode], currentDepth: Int) -> Int {
        for node in nodes {
            if node.id == parentId {
                return currentDepth + 1
            }
            // 继续递归搜索更深层级
            let deeperDepth = findParentDepth(
                parentId: parentId,
                in: node.children,
                currentDepth: currentDepth + 1
            )
            if deeperDepth > 0 {
                return deeperDepth
            }
        }
        return 0
    }
}

// MARK: - Sample Data

extension OKRNode {
    /// 创建示例企业级Objective节点
    /// 用于SwiftUI预览和单元测试
    public static func sampleEnterpriseObjective() -> OKRNode {
        OKRNode(
            title: "提升产品核心用户体验",
            nodeDescription: "聚焦产品核心功能，提升用户满意度和留存率",
            nodeType: .objective,
            scope: .enterprise,
            targetValue: 100,
            status: .inProgress,
            ownerName: "张三（产品总监）",
            children: [
                sampleEnterpriseKeyResult()
            ],
            cycleId: UUID()
        )
    }

    /// 创建示例企业级Key Result节点
    public static func sampleEnterpriseKeyResult() -> OKRNode {
        OKRNode(
            title: "NPS评分从30提升到50",
            nodeDescription: "通过用户调研和产品改进提升净推荐值",
            nodeType: .keyResult,
            scope: .enterprise,
            currentValue: 35,
            targetValue: 50,
            unit: "分",
            status: .inProgress,
            ownerName: "李四（用户研究负责人）",
            parentId: nil,
            cycleId: UUID()
        )
    }

    /// 创建示例个人级Objective节点
    public static func samplePersonalObjective() -> OKRNode {
        OKRNode(
            title: "优化 onboarding 流程体验",
            nodeDescription: "简化新用户注册流程，提升首次使用体验",
            nodeType: .objective,
            scope: .personal,
            targetValue: 100,
            status: .inProgress,
            ownerName: "王五（产品经理）",
            cycleId: UUID()
        )
    }

    /// 创建示例个人级Key Result（叶子节点）
    public static func samplePersonalKeyResult() -> OKRNode {
        OKRNode(
            title: "新用户7日留存率提升至40%",
            nodeDescription: "通过优化引导流程和增加激励措施提升留存",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 32,
            targetValue: 40,
            unit: "%",
            status: .atRisk,
            ownerName: "王五（产品经理）",
            cycleId: UUID()
        )
    }
}
