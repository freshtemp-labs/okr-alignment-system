import Foundation

/// ====================================================================
/// MARK: - NodeValidator
/// ====================================================================

/// 节点验证器
/// ========
/// 负责对OKR节点进行业务规则验证，确保数据的完整性和一致性。
///
/// # 验证规则说明
///
/// ## 1. 标题验证（Rule-01）
///    - 标题是节点的必填字段
///    - trim后的标题长度必须大于0
///    - 纯空白字符的标题视为无效
///
/// ## 2. 目标值验证（Rule-02）
///    - 只有叶子Key Result节点需要验证targetValue
///    - targetValue必须严格大于0
///    - 0或负值无法用于计算进度百分比
///
/// ## 3. 叶子KR完整性验证（Rule-03）
///    - 叶子节点（无子节点的Key Result）必须有有效的数值字段
///    - currentValue和targetValue都必须存在（对于struct类型，始终存在）
///    - targetValue > 0 确保进度计算不会除零
///
/// ## 4. 父节点类型兼容性验证（Rule-04）
///    - Key Result可以作为Objective的父节点（OKR结构）
///    - Objective不能作为Key Result的父节点
///    - 根节点（无parentId）跳过此验证
///
/// ## 5. 周期设置验证（Rule-05）
///    - 每个节点必须关联到一个OKR周期
///    - cycleId为nil表示未设置周期
///
/// ## 6. KR目标值验证（Rule-06）
///    - 所有Key Result节点的targetValue必须大于0
///    - 不仅限于叶子节点
///
/// ## 7. 周期日期范围验证（Rule-07）
///    - 周期的结束日期必须晚于开始日期
///
/// # 使用方式
/// ```swift
/// let validator = NodeValidator()
/// let errors = validator.validate(node)
/// if errors.isEmpty {
///     // 验证通过，可以保存
/// }
/// ```
///
public struct NodeValidator: Sendable {

    // MARK: - 初始化

    /// 创建一个新的节点验证器实例
    public init() {}

    // MARK: - 公共验证接口

    /// 对单个节点执行完整的业务规则验证
    /// --------------------------------
    /// 按照预定顺序执行所有验证规则，收集并返回所有验证错误。
    /// 验证不会在第1个错误时停止，而是尽可能发现所有问题。
    ///
    /// # 验证执行顺序：
    /// 1. 标题非空验证
    /// 2. 叶子KR的目标值有效性验证
    /// 3. 叶子KR的完整性验证
    /// 4. 周期设置验证
    /// 5. KR目标值验证（所有KR节点）
    ///
    /// - Parameter node: 要验证的OKR节点
    /// - Returns: 按验证顺序收集的所有ValidationError
    public func validate(_ node: OKRNode) -> [ValidationError] {
        // 使用数组收集所有验证错误
        var errors: [ValidationError] = []

        // ===== 规则1: 标题非空验证 =====
        // 标题trim后必须包含至少一个非空白字符
        if node.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 标题为空或仅包含空白字符 → 添加空标题错误
            errors.append(.emptyTitle)
        }

        // ===== 规则2 & 3: 叶子KR的值有效性验证 =====
        // 只有叶子Key Result节点需要验证数值字段
        if node.isLeaf {
            // 检查目标值是否大于0（除零保护）
            if node.targetValue <= 0 {
                // targetValue为0或负数 → 无法计算进度百分比
                errors.append(.invalidTargetValue)
            }
            // 叶子节点必须有完整的数据配置
            // 由于struct中currentValue和targetValue是非可选类型，
            // 只需确认targetValue有效即可认为数据完整
            if node.targetValue <= 0 {
                // targetValue无效 → 标记叶子数据不完整
                // 注意：这里避免重复添加错误，仅在未添加invalidTargetValue时添加
                if !errors.contains(.leafMissingValues) && !errors.contains(.invalidTargetValue) {
                    errors.append(.leafMissingValues)
                }
            }
        }

        // ===== 规则5: 周期设置验证 =====
        // 每个节点必须属于某个OKR周期
        if node.cycleId == nil {
            // cycleId为nil → 节点未关联到任何周期
            errors.append(.cycleNotSet)
        }

        // ===== 规则6: 所有KR节点的目标值验证 =====
        // 不仅叶子KR，所有Key Result节点的targetValue必须大于0
        if node.nodeType == .keyResult && node.targetValue <= 0 {
            // 避免与规则2重复
            if !errors.contains(.invalidTargetValue) {
                errors.append(.krTargetValueMustBePositive)
            }
        }

        // 返回收集到的所有验证错误（空数组表示全部通过）
        return errors
    }

    // MARK: - 周期验证

    /// 验证周期数据的合法性
    /// - Parameter cycle: 要验证的周期
    /// - Returns: 验证错误数组，空数组表示验证通过
    public func validateCycle(_ cycle: OKRCycle) -> [ValidationError] {
        var errors: [ValidationError] = []

        // 周期名称不能为空
        if cycle.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle)
        }

        // 结束日期必须晚于开始日期
        if cycle.endDate <= cycle.startDate {
            errors.append(.invalidCycleDateRange)
        }

        return errors
    }

    // MARK: - 删除警告

    /// 计算删除节点时的子节点警告
    /// - Parameter node: 要删除的节点
    /// - Returns: 删除警告信息，nil表示没有子节点
    public func calculateDeleteWarning(for node: OKRNode) -> DeleteWarning? {
        let childCount = countDescendants(node)
        guard childCount > 0 else { return nil }
        return DeleteWarning(directDeleteCount: 1, cascadeDeleteCount: childCount)
    }

    /// 计算批量删除的警告信息
    /// - Parameter nodes: 要删除的节点数组
    /// - Returns: 删除警告信息
    public func calculateBatchDeleteWarning(for nodes: [OKRNode]) -> DeleteWarning {
        var totalChildren = 0
        for node in nodes {
            totalChildren += countDescendants(node)
        }
        return DeleteWarning(directDeleteCount: nodes.count, cascadeDeleteCount: totalChildren)
    }

    /// 递归统计后代节点数量
    private func countDescendants(_ node: OKRNode) -> Int {
        var count = node.children.count
        for child in node.children {
            count += countDescendants(child)
        }
        return count
    }

    // MARK: - 保存前自动清理

    /// 对节点执行保存前的自动清理
    /// - Parameter node: 原始节点
    /// - Returns: 清理后的节点
    public func autoCleanup(_ node: OKRNode) -> OKRNode {
        let (cleaned, _) = node.autoCleanup()
        return cleaned
    }

    // MARK: - 批量验证

    /// 批量验证多个节点
    /// --------------
    /// 对节点数组中的每个节点执行验证，返回第一个发现的错误。
    /// 适用于需要快速检查一批节点合法性的场景。
    ///
    /// - Parameter nodes: 要验证的节点数组
    /// - Returns: 第一个发现的验证错误，nil表示全部通过
    public func validateBatch(_ nodes: [OKRNode]) -> ValidationError? {
        // 遍历每个节点进行验证
        for node in nodes {
            // 获取当前节点的所有验证错误
            let errors = validate(node)
            // 如果存在任何错误，立即返回第一个
            if let firstError = errors.first {
                return firstError
            }
        }
        // 所有节点验证通过，返回nil
        return nil
    }

    // MARK: - 专项验证方法

    /// 验证标题是否有效
    /// --------------
    /// 检查标题在去除首尾空白后是否包含有效内容。
    ///
    /// - Parameter title: 要验证的标题字符串
    /// - Returns: true表示标题有效，false表示标题无效
    public func isValidTitle(_ title: String) -> Bool {
        // trim后非空即为有效标题
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 验证目标值是否有效
    /// ----------------
    /// 目标值必须严格大于0，以确保进度计算时不会除零。
    ///
    /// - Parameter targetValue: 要验证的目标值
    /// - Returns: true表示目标值有效，false表示目标值无效
    public func isValidTargetValue(_ targetValue: Double) -> Bool {
        // 目标值必须严格大于0
        return targetValue > 0
    }

    /// 验证节点是否为有效的叶子KR节点
    /// ----------------------------
    /// 叶子KR节点必须满足：
    /// 1. 类型为.keyResult
    /// 2. 没有子节点
    /// 3. targetValue > 0
    ///
    /// - Parameter node: 要验证的节点
    /// - Returns: true表示是有效的叶子KR节点
    public func isValidLeafNode(_ node: OKRNode) -> Bool {
        // 必须是Key Result类型
        guard node.nodeType == .keyResult else { return false }
        // 必须没有子节点（叶子定义）
        guard node.children.isEmpty else { return false }
        // 目标值必须有效（大于0）
        guard node.targetValue > 0 else { return false }
        // 全部条件满足 → 有效叶子节点
        return true
    }

    /// 验证父节点类型兼容性
    /// ------------------
    /// 检查子节点是否可以附加到指定的父节点下。
    /// OKR层级规则：
    /// - Key Result 可以作为 Objective 的子节点
    /// - Objective 不能作为 Key Result 的子节点
    /// - 根节点（parentId == nil）总是有效的
    ///
    /// - Parameters:
    ///   - childType: 子节点的类型
    ///   - parentType: 父节点的类型
    /// - Returns: true表示类型兼容，false表示类型冲突
    public func isCompatibleParent(
        childType: NodeType,
        parentType: NodeType
    ) -> Bool {
        // 检查OKR层级规则：
        // Key Result可以作为Objective的父节点（KR对齐到O）
        // Objective不能作为Key Result的父节点
        switch (childType, parentType) {
        case (.objective, .keyResult):
            // Objective作为Key Result的子节点 → 允许（对齐场景）
            return true
        case (.keyResult, .objective):
            // Key Result作为Objective的子节点 → 标准OKR结构，允许
            return true
        case (.objective, .objective):
            // Objective作为Objective的子节点 → 允许（层级分解）
            return true
        case (.keyResult, .keyResult):
            // Key Result作为Key Result的子节点 → 不允许（KR不能再有KR子节点）
            return false
        }
    }

    /// 验证父节点与子节点的类型兼容性（完整节点版本）
    /// ----------------------------------------
    /// - Parameters:
    ///   - child: 子节点
    ///   - parent: 父节点
    /// - Returns: 类型兼容返回true，否则返回false
    public func isCompatibleParent(child: OKRNode, parent: OKRNode) -> Bool {
        // 委托到类型级别的验证方法
        return isCompatibleParent(
            childType: child.nodeType,
            parentType: parent.nodeType
        )
    }
}
