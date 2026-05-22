import Foundation

/// ============================================================================
/// MARK: - OKRCascadeEngine
/// ============================================================================

/// OKR级联进度计算引擎
/// ==================
/// 实现了完整的OKR树级联进度计算算法。
///
/// # 引擎特性
/// - **纯函数设计**: 所有计算方法无副作用，输入确定则输出确定
/// - **不可变性**: 基于值类型的OKRNode，每次计算返回新的节点副本
/// - **100%可测试**: 无外部依赖，无全局状态，易于单元测试
/// - **线程安全**: Sendable兼容，可在并发环境中安全使用
///
/// # 核心算法
///
/// ## 规则1 - 叶子Key Result节点
/// ```
/// progress = min(max((currentValue / targetValue) × 100, 0), 100)
/// ```
/// 当targetValue <= 0时，progress = 0（除零保护）
///
/// ## 规则2 - 有子节点的父节点
/// ```
/// 先递归计算所有子节点
/// progress = sum(子节点.progress) / 子节点数量
/// ```
///
/// ## 规则3 - 无子节点的Objective节点
/// ```progress = 0```
///
/// ## 规则4 - 更新叶子并重算
/// ```
/// 1. 在树中定位目标叶子节点（通过ID匹配）
/// 2. 更新currentValue = clamp(newValue, 0, targetValue)
/// 3. 使用规则1重新计算该叶子的progress
/// 4. 从该叶子向上回溯，使用规则2重新计算每个父节点的progress
/// 5. 返回更新后的完整树
/// ```
///
public struct OKRCascadeEngine: CascadeEngineProtocol, Sendable {

    // MARK: - 属性

    /// 节点验证器实例
    /// 用于对节点进行业务规则验证
    private let validator: NodeValidator

    // MARK: - 初始化

    /// 创建级联计算引擎实例
    /// - Parameter validator: 节点验证器（默认创建新实例）
    public init(validator: NodeValidator = NodeValidator()) {
        // 保存验证器引用，用于后续的节点验证操作
        self.validator = validator
    }

    // MARK: - CascadeEngineProtocol: 进度计算

    /// 计算单个节点及其所有子节点的进度（递归）
    /// ----------------------------------------
    /// 这是级联引擎的核心递归方法。根据节点类型和子节点状态，
    /// 应用不同的计算规则来确定节点的progress值。
    ///
    /// # 计算流程：
    /// 1. 判断节点是否为叶子Key Result → 应用规则1
    /// 2. 判断节点是否有子节点 → 有则应用规则2，无则应用规则3
    /// 3. 递归计算所有子节点后汇总
    ///
    /// - Parameter node: 要计算进度的OKR节点
    /// - Returns: 包含计算后progress的新节点副本（所有子节点也已递归更新）
    public func calculateProgress(for node: OKRNode) -> OKRNode {
        // ===== 步骤1: 判断节点类型，选择对应的计算规则 =====

        // 情况A: 节点是叶子Key Result（无子节点且类型为keyResult）
        if node.isLeaf {
            // 应用规则1: 叶子KR的进度 = (currentValue / targetValue) × 100
            let calculatedProgress = calculateLeafProgress(node: node)
            // 返回更新progress后的新节点副本
            return updateProgress(node: node, newProgress: calculatedProgress)
        }

        // 情况B: 节点有子节点（需要递归计算后取平均）
        if !node.children.isEmpty {
            // 应用规则2: 先递归计算所有子节点，再取平均值
            return calculateParentProgress(node: node)
        }

        // 情况C: 无子节点的Objective节点
        // 应用规则3: progress = 0
        return updateProgress(node: node, newProgress: 0.0)
    }

    /// 从根节点开始计算整棵树的进度
    /// ----------------------------
    /// 对整棵树执行完整的级联计算。
    /// 从根节点出发，递归遍历每个节点并应用对应的计算规则。
    ///
    /// - Parameter root: OKR树的根节点
    /// - Returns: 完整计算后的树（所有节点的progress都已级联更新）
    public func calculateTreeProgress(root: OKRNode) -> OKRNode {
        // 从根节点开始递归计算整棵树
        // calculateProgress方法会自动递归处理所有子节点
        return calculateProgress(for: root)
    }

    // MARK: - CascadeEngineProtocol: 叶子更新与重算

    /// 更新叶子KR的值并重新计算整棵树
    /// ----------------------------
    /// 这是引擎对外提供的主要交互方法。
    /// 当用户更新某个叶子KR的currentValue时，此方法会：
    /// 1. 定位目标叶子节点
    /// 2. 更新currentValue
    /// 3. 重新计算该叶子的progress
    /// 4. 向上级联重算所有受影响的父节点
    ///
    /// - Parameters:
    ///   - treeRoot: 树的根节点（用于重新计算整个树）
    ///   - leafId: 要更新的叶子节点ID
    ///   - newValue: 新的currentValue值
    /// - Returns: 更新后的完整树
    public func updateLeafAndRecalculate(
        treeRoot: OKRNode,
        leafId: UUID,
        newValue: Double
    ) -> OKRNode {
        // ===== 步骤1: 在树中查找目标叶子节点并更新其值 =====
        // 递归遍历整棵树，找到匹配leafId的叶子节点
        // 同时更新其currentValue并重新计算progress
        let updatedRoot = updateLeafInTree(
            node: treeRoot,
            leafId: leafId,
            newValue: newValue
        )

        // ===== 步骤2: 返回更新后的树 =====
        // updateLeafInTree在更新叶子后，会从该叶子向上重新计算所有父节点
        // 因此返回的updatedRoot已经是完整更新后的树
        return updatedRoot
    }

    // MARK: - CascadeEngineProtocol: 数据验证

    /// 验证节点数据的合法性
    /// ------------------
    /// 委托给NodeValidator执行完整的业务规则验证。
    ///
    /// - Parameter node: 要验证的节点
    /// - Returns: 验证错误数组，空数组表示验证通过
    public func validateNode(_ node: OKRNode) -> [ValidationError] {
        // 委托给专门的验证器执行验证逻辑
        // 这样可以将验证逻辑与计算逻辑解耦
        return validator.validate(node)
    }

    // MARK: - 私有计算辅助方法

    /// 计算叶子Key Result节点的进度
    /// ---------------------------
    /// 规则1实现: progress = (currentValue / targetValue) × 100
    ///
    /// # 计算细节：
    /// - 当targetValue > 0时: progress = (currentValue / targetValue) × 100
    /// - 当targetValue <= 0时: progress = 0（除零保护）
    /// - 结果限制在[0, 100]范围内（即使currentValue超过targetValue）
    ///
    /// - Parameter node: 叶子KR节点
    /// - Returns: 计算后的progress值（0.0 - 100.0）
    private func calculateLeafProgress(node: OKRNode) -> Double {
        // ===== 步骤1: 除零检查 =====
        // 如果targetValue <= 0，无法进行除法运算
        // 返回0作为安全默认值
        guard node.targetValue > 0 else {
            // targetValue无效（0或负数）→ 进度为0
            return 0.0
        }

        // ===== 步骤2: 计算原始进度百分比 =====
        // progress = (当前值 / 目标值) × 100
        // 例如: currentValue=75, targetValue=100 → progress=75.0%
        let rawProgress = (node.currentValue / node.targetValue) * 100.0

        // ===== 步骤3: 限制结果在有效范围内 =====
        // 使用max确保进度不低于0（currentValue为负数时）
        // 使用min确保进度不超过100（currentValue超过targetValue时）
        let clampedProgress = min(max(rawProgress, 0.0), 100.0)

        // ===== 步骤4: 返回最终结果 =====
        return clampedProgress
    }

    /// 计算有子节点的父节点的进度
    /// -------------------------
    /// 规则2实现: 先递归计算所有子节点，progress = 子节点平均值
    ///
    /// # 计算细节：
    /// 1. 对当前节点的每个子节点递归调用calculateProgress
    /// 2. 收集所有子节点计算后的progress值
    /// 3. progress = sum(子节点progress) / 子节点数量
    /// 4. 更新当前节点的progress和children数组
    ///
    /// - Parameter node: 有子节点的父节点
    /// - Returns: 包含更新后progress和递归更新后子节点的新节点
    private func calculateParentProgress(node: OKRNode) -> OKRNode {
        // ===== 步骤1: 递归计算所有子节点 =====
        // 对每个子节点调用calculateProgress进行递归计算
        // 这会确保子树中的所有节点progress都是最新的
        let calculatedChildren = node.children.map { child in
            // 递归调用：对子节点应用相同的计算逻辑
            // 如果子节点也有子节点，会继续向下递归直到叶子节点
            calculateProgress(for: child)
        }

        // ===== 步骤2: 收集所有子节点的progress值 =====
        // 从已计算的子节点中提取progress值
        let childProgressValues = calculatedChildren.map { $0.progress }

        // ===== 步骤3: 计算平均值 =====
        // progress = 所有子节点progress之和 / 子节点数量
        // 例如: 3个子节点的progress分别为[60, 80, 100]
        // 则父节点的progress = (60 + 80 + 100) / 3 = 80.0
        let averageProgress: Double
        if childProgressValues.isEmpty {
            // 防御性编程：理论上不应到达此处（已在调用前检查children非空）
            // 如果没有子节点，进度设为0
            averageProgress = 0.0
        } else {
            // 计算子节点progress的算术平均值
            let sum = childProgressValues.reduce(0.0, +)
            averageProgress = sum / Double(childProgressValues.count)
        }

        // ===== 步骤4: 限制结果在有效范围内 =====
        // 确保结果在[0, 100]范围内（防止浮点误差导致越界）
        let clampedProgress = min(max(averageProgress, 0.0), 100.0)

        // ===== 步骤5: 构建更新后的节点 =====
        // 创建新的节点副本，包含：
        // - 计算后的progress
        // - 已递归更新的子节点数组
        var updatedNode = node
        updatedNode.progress = clampedProgress
        updatedNode.children = calculatedChildren

        // ===== 步骤6: 返回更新后的节点 =====
        return updatedNode
    }

    /// 更新节点的progress值（不可变更新）
    /// --------------------------------
    /// 由于OKRNode是值类型（struct），此方法通过创建副本实现不可变更新。
    ///
    /// - Parameters:
    ///   - node: 原始节点
    ///   - newProgress: 新的progress值
    /// - Returns: 更新progress后的新节点副本
    private func updateProgress(node: OKRNode, newProgress: Double) -> OKRNode {
        // 创建节点的可变副本
        var updatedNode = node
        // 更新progress字段
        updatedNode.progress = newProgress
        // 返回更新后的副本（原始节点保持不变）
        return updatedNode
    }

    // MARK: - 私有叶子更新辅助方法

    /// 在树中查找并更新叶子节点
    /// -----------------------
    /// 递归遍历整棵树，找到匹配leafId的叶子节点并更新其值。
    /// 更新叶子后，从该叶子向上重新计算所有父节点。
    ///
    /// # 递归逻辑：
    /// 1. 如果当前节点就是要找的叶子 → 更新值并重新计算progress
    /// 2. 如果当前节点有子节点 → 递归在每个子树中查找
    /// 3. 如果在某个子树中找到并更新了叶子 → 重新计算当前父节点的progress
    ///
    /// - Parameters:
    ///   - node: 当前正在检查的节点
    ///   - leafId: 要查找的叶子节点ID
    ///   - newValue: 新的currentValue
    /// - Returns: 更新后的节点（如果找到并更新了叶子，则包含级联更新）
    private func updateLeafInTree(
        node: OKRNode,
        leafId: UUID,
        newValue: Double
    ) -> OKRNode {
        // ===== 步骤1: 检查当前节点是否就是目标叶子 =====
        if node.id == leafId {
            // 找到目标节点 → 更新其currentValue并重新计算progress
            return updateLeafNode(node: node, newValue: newValue)
        }

        // ===== 步骤2: 如果当前节点没有子节点，且不是目标 → 无需处理 =====
        if node.children.isEmpty {
            // 当前节点不是目标，且没有子节点可以搜索 → 返回原样
            return node
        }

        // ===== 步骤3: 递归在子树中查找目标叶子 =====
        // 标记是否找到了目标叶子并进行了更新
        var foundAndUpdated = false
        // 存储更新后的子节点
        var updatedChildren: [OKRNode] = []

        // 遍历每个子节点，递归查找目标叶子
        for child in node.children {
            // 在当前子树中递归查找并更新
            let updatedChild = updateLeafInTree(
                node: child,
                leafId: leafId,
                newValue: newValue
            )
            // 检查子节点是否被更新（通过比较ID相同但内容可能不同）
            // 使用progress变化或currentValue变化来判断是否更新
            if updatedChild.id == leafId {
                // 子树中找到了目标叶子 → 该子节点已被更新
                foundAndUpdated = true
            }
            // 将更新后的子节点添加到结果数组
            updatedChildren.append(updatedChild)
        }

        // ===== 步骤4: 如果子树中找到了目标叶子，重新计算当前父节点 =====
        if foundAndUpdated {
            // 子树中有叶子被更新 → 需要重新计算当前父节点的progress
            // 使用规则2: 子节点progress的平均值
            let childProgressValues = updatedChildren.map { $0.progress }
            let sum = childProgressValues.reduce(0.0, +)
            let averageProgress = sum / Double(childProgressValues.count)
            // 限制在有效范围
            let clampedProgress = min(max(averageProgress, 0.0), 100.0)

            // 构建更新后的父节点
            var updatedNode = node
            updatedNode.progress = clampedProgress
            updatedNode.children = updatedChildren
            return updatedNode
        }

        // ===== 步骤5: 子树中未找到目标 → 返回原样 =====
        // 如果遍历了所有子树都没有找到目标叶子，当前节点保持不变
        return node
    }

    /// 更新叶子节点的currentValue并重新计算progress
    /// -------------------------------------------
    /// 对找到的叶子节点执行值更新和progress重算。
    ///
    /// # 处理流程：
    /// 1. 将newValue限制在[0, targetValue]范围内
    /// 2. 更新currentValue
    /// 3. 使用规则1重新计算progress
    ///
    /// - Parameters:
    ///   - node: 找到的叶子节点
    ///   - newValue: 新的currentValue
    /// - Returns: 更新后的叶子节点
    private func updateLeafNode(node: OKRNode, newValue: Double) -> OKRNode {
        // ===== 步骤1: 将新值限制在有效范围内 =====
        // 下限: 0（进度不能为负）
        // 上限: targetValue（进度不能超过100%）
        let clampedValue: Double
        if node.targetValue > 0 {
            // targetValue有效 → 将newValue限制在[0, targetValue]
            clampedValue = min(max(newValue, 0.0), node.targetValue)
        } else {
            // targetValue无效 → 只限制下限为0
            clampedValue = max(newValue, 0.0)
        }

        // ===== 步骤2: 创建节点的可变副本 =====
        var updatedNode = node

        // ===== 步骤3: 更新currentValue =====
        updatedNode.currentValue = clampedValue

        // ===== 步骤4: 使用规则1重新计算progress =====
        // progress = (currentValue / targetValue) × 100
        let newProgress = calculateLeafProgress(node: updatedNode)
        updatedNode.progress = newProgress

        // ===== 步骤5: 返回更新后的叶子节点 =====
        return updatedNode
    }
}
