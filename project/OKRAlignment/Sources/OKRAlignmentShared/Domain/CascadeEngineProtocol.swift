import Foundation

/// ============================================================================
/// MARK: - CascadeEngineProtocol
/// ============================================================================

/// 级联进度计算引擎协议
/// ====================
/// 该协议定义了OKR树中进度自动向上汇总计算的核心能力。
///
/// # 级联计算规则概述
/// - **叶子KR节点**: progress = (currentValue / targetValue) × 100
/// - **有子节点的父节点**: progress = 所有子节点progress的加权平均值（权重为weight字段）
/// - **无子节点的Objective节点**: progress = 0
///
/// # 使用场景
/// 当用户更新某个叶子关键结果（Key Result）的当前值时，引擎会自动
/// 重新计算该叶子节点的进度，并沿着父节点链一直向上汇总，直到根节点。
///
/// # 线程安全
/// 所有实现必须是纯函数（无副作用），100%可测试，线程安全。
///
public protocol CascadeEngineProtocol: Sendable {

    // MARK: - 进度计算

    /// 计算单个节点及其所有子节点的进度（递归）
    /// ----------------------------------------
    /// 根据节点类型应用不同的计算规则：
    /// - 如果是叶子KR节点 → 规则1: (currentValue / targetValue) × 100
    /// - 如果是有子节点的父节点 → 规则2: 子节点progress平均值
    /// - 如果是无子节点的Objective → 规则3: progress = 0
    ///
    /// - Parameter node: 要计算进度的节点
    /// - Returns: 更新后的节点（包含计算后的progress和所有已递归更新的子节点）
    func calculateProgress(for node: OKRNode) -> OKRNode

    /// 从根节点开始计算整棵树的进度
    /// ----------------------------
    /// 遍历树中的所有节点，对每个节点应用级联计算规则。
    /// 这是完整的树级联计算方法，通常在初次加载数据时调用。
    ///
    /// - Parameter root: OKR树的根节点
    /// - Returns: 完整计算后的树（所有节点的progress都已更新）
    func calculateTreeProgress(root: OKRNode) -> OKRNode

    // MARK: - 叶子更新与重算

    /// 更新叶子KR的值并重新计算整棵树
    /// ----------------------------
    /// 这是引擎的核心交互方法，用于响应用户更新叶子KR的操作。
    ///
    /// # 执行流程：
    /// 1. 在树中定位要更新的叶子节点（通过leafId匹配）
    /// 2. 更新该叶子的currentValue（自动限制在[0, targetValue]范围内）
    /// 3. 使用规则1重新计算该叶子的progress
    /// 4. 从该叶子向上遍历所有父节点，使用规则2重新计算每个父节点的progress
    /// 5. 返回更新后的完整树
    ///
    /// - Parameters:
    ///   - treeRoot: 树的根节点（用于重新计算整个树）
    ///   - leafId: 要更新的叶子节点ID
    ///   - newValue: 新的currentValue值
    /// - Returns: 更新后的完整树（包含所有级联更新的节点）
    func updateLeafAndRecalculate(
        treeRoot: OKRNode,
        leafId: UUID,
        newValue: Double
    ) -> OKRNode

    // MARK: - 数据验证

    /// 验证节点数据的合法性
    /// ------------------
    /// 对节点进行业务规则验证，返回所有发现的验证错误。
    /// 空数组表示节点数据完全合法。
    ///
    /// # 验证规则：
    /// - 标题不能为空（trim后长度必须 > 0）
    /// - 叶子KR的targetValue必须 > 0
    /// - 叶子KR必须有有效的currentValue和targetValue
    /// - 父节点类型检查
    /// - 周期必须已设置
    ///
    /// - Parameter node: 要验证的节点
    /// - Returns: 验证错误数组，空数组表示验证通过
    func validateNode(_ node: OKRNode) -> [ValidationError]
}
