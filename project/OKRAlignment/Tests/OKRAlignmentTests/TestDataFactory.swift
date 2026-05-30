import Foundation
@testable import OKRAlignmentShared

// MARK: - TestDataFactory

/// 测试数据工厂 - 集中管理所有测试数据的创建
///
/// 本工厂提供标准化的测试数据构造方法，确保所有测试使用一致的测试数据。
/// 遵循工厂模式设计，避免测试代码中重复创建数据，提高可维护性。
///
/// ## 使用方式
/// ```swift
/// let leafNode = TestDataFactory.createLeafKR(title: "Test KR", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal)
/// let tree = TestDataFactory.createDemoTree()
/// ```
enum TestDataFactory {

    // MARK: - Demo Tree

    /// 创建测试用的OKR树结构（匹配Demo数据）
    ///
    /// 树结构:
    /// ```
    /// 企业O: "打造极具竞争力的商业化工具" (scope: enterprise, type: objective)
    /// └── 企业KR1: "完成跨平台MVP版本并获得1000内测用户" (scope: enterprise, type: key_result)
    ///     ├── 个人O(Alice): "确保MVP产品体验达到行业顶尖" (scope: personal, type: objective)
    ///     │   ├── KR: "完成深色模式与流畅动画设计" (current: 20, target: 100, unit: "%")
    ///     │   └── KR: "招募并访谈50名种子用户" (current: 5, target: 50, unit: "人")
    ///     └── 个人O(Bob): "攻克Expo + Skia的技术难点" (scope: personal, type: objective)
    ///         ├── KR: "完成原生模型桥接" (current: 0, target: 100, unit: "%")
    ///         └── KR: "将渲染性能优化至60fps" (current: 30, target: 60, unit: "fps")
    /// ```
    ///
    /// 预期级联计算结果:
    /// - Alice的KR1: 20/100 = 20%
    /// - Alice的KR2: 5/50 = 10%
    /// - Alice的O: (20% + 10%) / 2 = 15%
    /// - Bob的KR1: 0/100 = 0%
    /// - Bob的KR2: 30/60 = 50%
    /// - Bob的O: (0% + 50%) / 2 = 25%
    /// - 企业KR1: (15% + 25%) / 2 = 20%
    /// - 企业O: 20% (只有一个子节点)
    ///
    /// - Returns: 完整的OKR树根节点
    static func createDemoTree() -> OKRNode {
        // Alice 的个人 KRs
        let aliceKR1 = createLeafKR(
            title: "完成深色模式与流畅动画设计",
            current: 20,
            target: 100,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )
        let aliceKR2 = createLeafKR(
            title: "招募并访谈50名种子用户",
            current: 5,
            target: 50,
            unit: "人",
            owner: "Alice",
            scope: .personal
        )

        // Alice 的 Objective
        let aliceObjective = createObjective(
            title: "确保MVP产品体验达到行业顶尖",
            owner: "Alice",
            scope: .personal,
            children: [aliceKR1, aliceKR2]
        )

        // Bob 的个人 KRs
        let bobKR1 = createLeafKR(
            title: "完成原生模型桥接",
            current: 0,
            target: 100,
            unit: "%",
            owner: "Bob",
            scope: .personal
        )
        let bobKR2 = createLeafKR(
            title: "将渲染性能优化至60fps",
            current: 30,
            target: 60,
            unit: "fps",
            owner: "Bob",
            scope: .personal
        )

        // Bob 的 Objective
        let bobObjective = createObjective(
            title: "攻克Expo + Skia的技术难点",
            owner: "Bob",
            scope: .personal,
            children: [bobKR1, bobKR2]
        )

        // 企业 KR
        let enterpriseKR1 = createLeafKR(
            title: "完成跨平台MVP版本并获得1000内测用户",
            current: 150,
            target: 1000,
            unit: "人",
            owner: "CTO",
            scope: .enterprise,
            children: [aliceObjective, bobObjective]
        )

        // 企业根节点
        let enterpriseRoot = createEnterpriseRoot(
            title: "打造极具竞争力的商业化工具",
            owner: "CEO",
            children: [enterpriseKR1]
        )

        return enterpriseRoot
    }

    // MARK: - Leaf KR Factory Methods

    /// 创建叶子KR节点（Key Result，无子节点的成果指标）
    ///
    /// - Parameters:
    ///   - title: 节点标题
    ///   - current: 当前值
    ///   - target: 目标值
    ///   - unit: 单位（如 "%", "人", "fps"）
    ///   - owner: 负责人名称
    ///   - scope: 范围（企业或个人）
    ///   - children: 可选的子节点（用于创建带有子节点的KR，如企业KR关联个人O）
    /// - Returns: 配置好的叶子KR节点
    static func createLeafKR(
        title: String,
        current: Double,
        target: Double,
        unit: String,
        owner: String,
        scope: Scope,
        children: [OKRNode] = []
    ) -> OKRNode {
        OKRNode(
            id: UUID(),
            title: title,
            nodeDescription: "\(title) 的描述",
            nodeType: .keyResult,
            scope: scope,
            currentValue: current,
            targetValue: target,
            unit: unit,
            progress: 0,
            status: current >= target ? .completed : (current > 0 ? .inProgress : .notStarted),
            ownerName: owner,
            sortOrder: 0,
            parentId: nil,
            children: children,
            cycleId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1700000000),
            updatedAt: Date(timeIntervalSince1970: 1700000000)
        )
    }

    // MARK: - Objective Factory Methods

    /// 创建Objective节点（带子节点的目标节点）
    ///
    /// - Parameters:
    ///   - title: 节点标题
    ///   - owner: 负责人名称
    ///   - scope: 范围（企业或个人）
    ///   - children: 子节点数组（通常是KR节点或其他Objective节点）
    /// - Returns: 配置好的Objective节点
    static func createObjective(
        title: String,
        owner: String,
        scope: Scope,
        children: [OKRNode]
    ) -> OKRNode {
        OKRNode(
            id: UUID(),
            title: title,
            nodeDescription: "\(title) 的描述",
            nodeType: .objective,
            scope: scope,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 0,
            status: .notStarted,
            ownerName: owner,
            sortOrder: 0,
            parentId: nil,
            children: children,
            cycleId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1700000000),
            updatedAt: Date(timeIntervalSince1970: 1700000000)
        )
    }

    /// 创建空Objective（无子节点的目标节点）
    ///
    /// 空的Objective节点没有子节点，根据级联规则其进度应为0。
    /// 用于测试边界条件。
    ///
    /// - Parameters:
    ///   - title: 节点标题
    ///   - owner: 负责人名称
    ///   - scope: 范围（企业或个人）
    /// - Returns: 配置好的空Objective节点
    static func createEmptyObjective(
        title: String,
        owner: String,
        scope: Scope
    ) -> OKRNode {
        OKRNode(
            id: UUID(),
            title: title,
            nodeDescription: nil,
            nodeType: .objective,
            scope: scope,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 0,
            status: .notStarted,
            ownerName: owner,
            sortOrder: 0,
            parentId: nil,
            children: [],
            cycleId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1700000000),
            updatedAt: Date(timeIntervalSince1970: 1700000000)
        )
    }

    // MARK: - Enterprise Root Factory Methods

    /// 创建企业级根节点
    ///
    /// 企业级根节点是整个OKR树的顶层节点，通常只有一个企业Objective，
    /// 其下包含多个企业级别的KR，每个KR再关联到个人的Objective。
    ///
    /// - Parameters:
    ///   - title: 节点标题
    ///   - owner: 负责人名称（通常是CEO或CTO）
    ///   - children: 子节点数组（企业级别的KR节点）
    /// - Returns: 配置好的企业级根节点
    static func createEnterpriseRoot(
        title: String,
        owner: String,
        children: [OKRNode]
    ) -> OKRNode {
        OKRNode(
            id: UUID(),
            title: title,
            nodeDescription: "\(title) 的企业级目标描述",
            nodeType: .objective,
            scope: .enterprise,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 0,
            status: .inProgress,
            ownerName: owner,
            sortOrder: 0,
            parentId: nil,
            children: children,
            cycleId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1700000000),
            updatedAt: Date(timeIntervalSince1970: 1700000000)
        )
    }

    // MARK: - Special Case Factory Methods

    /// 创建已完成状态的叶子KR节点
    ///
    /// - Parameters:
    ///   - title: 节点标题
    ///   - owner: 负责人名称
    /// - Returns: currentValue == targetValue 的已完成KR节点
    static func createCompletedLeafKR(
        title: String = "已完成的KR",
        owner: String = "TestOwner"
    ) -> OKRNode {
        createLeafKR(
            title: title,
            current: 100,
            target: 100,
            unit: "%",
            owner: owner,
            scope: .personal
        )
    }

    /// 创建尚未开始的叶子KR节点
    ///
    /// - Parameters:
    ///   - title: 节点标题
    ///   - owner: 负责人名称
    /// - Returns: currentValue == 0 的未开始KR节点
    static func createNotStartedLeafKR(
        title: String = "未开始的KR",
        owner: String = "TestOwner"
    ) -> OKRNode {
        createLeafKR(
            title: title,
            current: 0,
            target: 100,
            unit: "%",
            owner: owner,
            scope: .personal
        )
    }

    /// 创建深度嵌套的树结构（用于测试递归深度）
    ///
    /// 创建一个指定深度的树，每个节点只有一个子节点，
    /// 最底层是一个叶子KR节点，progress为100%。
    ///
    /// - Parameter depth: 树的深度（最小为1）
    /// - Returns: 深度嵌套的树结构的根节点
    static func createDeepTree(depth: Int) -> OKRNode {
        guard depth > 0 else {
            fatalError("Tree depth must be greater than 0")
        }

        // 从叶子节点开始构建
        var currentNode: OKRNode = createLeafKR(
            title: "深度 \(depth) 的KR",
            current: 100,
            target: 100,
            unit: "%",
            owner: "DeepOwner",
            scope: .personal
        )

        // 逐层向上构建
        for level in (1..<depth).reversed() {
            let parentNode = createObjective(
                title: "深度 \(level) 的Objective",
                owner: "DeepOwner",
                scope: .enterprise,
                children: [currentNode]
            )
            currentNode = parentNode
        }

        return currentNode
    }

    /// 创建平衡二叉树结构的OKR树
    ///
    /// 创建一个指定层数的完全二叉树，所有叶子节点progress均为100%，
    /// 用于测试大量子节点的平均计算性能。
    ///
    /// - Parameter levels: 树的层数
    /// - Returns: 平衡二叉树的根节点
    static func createBalancedTree(levels: Int) -> OKRNode {
        guard levels > 0 else {
            return createLeafKR(
                title: "叶子节点",
                current: 100,
                target: 100,
                unit: "%",
                owner: "BalancedOwner",
                scope: .personal
            )
        }

        let children = [
            createBalancedSubtree(levels: levels - 1, index: 1),
            createBalancedSubtree(levels: levels - 1, index: 2)
        ]

        return createObjective(
            title: "根节点",
            owner: "BalancedOwner",
            scope: .enterprise,
            children: children
        )
    }

    /// 递归创建平衡子树
    private static func createBalancedSubtree(levels: Int, index: Int) -> OKRNode {
        guard levels > 0 else {
            return createLeafKR(
                title: "KR-\(index)",
                current: 100,
                target: 100,
                unit: "%",
                owner: "BalancedOwner",
                scope: .personal
            )
        }

        let children = [
            createBalancedSubtree(levels: levels - 1, index: index * 2),
            createBalancedSubtree(levels: levels - 1, index: index * 2 + 1)
        ]

        return createObjective(
            title: "O-\(index)",
            owner: "BalancedOwner",
            scope: .enterprise,
            children: children
        )
    }
}
