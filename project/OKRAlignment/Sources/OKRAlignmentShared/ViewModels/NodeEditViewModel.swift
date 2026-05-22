import Foundation

/// ============================================================================
/// MARK: - NodeEditViewModel
/// ============================================================================

/// 节点创建/编辑ViewModel
/// =====================
/// 管理OKR节点的创建和编辑表单。
///
/// # 职责
/// - 管理表单中正在编辑的节点数据
/// - 执行表单验证（通过NodeValidator）
/// - 保存节点（创建或更新）
/// - 加载可用的父节点列表（用于选择父节点）
/// - 管理验证错误列表
///
/// # 使用场景
/// 用于展示节点编辑表单（创建新节点或编辑现有节点）。
/// 视图绑定到此ViewModel的属性，用户修改时自动更新。
///
/// # 验证流程
/// 保存前自动执行验证，验证失败时：
/// 1. validationErrors数组会被填充
/// 2. 不会调用Repository保存
/// 3. 视图可展示验证错误提示
///
@MainActor
@Observable
public final class NodeEditViewModel {

    // MARK: - 发布状态属性

    /// 正在编辑的节点
    /// 视图直接绑定此属性的字段（如title、nodeDescription等）
    public var node: OKRNode

    /// 是否正在保存
    /// 保存过程中设为true，防止重复提交
    public var isSaving: Bool = false

    /// 验证错误列表
    /// 验证失败时填充，空数组表示当前无验证错误
    /// 视图可遍历此数组展示错误信息
    public var validationErrors: [ValidationError] = []

    /// 可用的父节点列表（用于选择父节点）
    /// 加载当前周期下的所有可作为父节点的Objective
    public var availableParents: [OKRNode] = []

    // MARK: - 计算属性

    /// 表单是否有效（无验证错误）
    public var isFormValid: Bool {
        // 当验证错误数组为空时，表单视为有效
        validationErrors.isEmpty
    }

    /// 是否有验证错误
    public var hasValidationErrors: Bool {
        // 当验证错误数组非空时，存在验证错误
        !validationErrors.isEmpty
    }

    /// 节点类型的描述文本
    public var nodeTypeDescription: String {
        switch node.nodeType {
        case .objective:
            return "目标"
        case .keyResult:
            return "关键结果"
        }
    }

    /// 是否为新创建节点（而非编辑现有节点）
    /// 通过检查创建时间和当前时间的接近程度判断
    public var isNewNode: Bool {
        // 如果节点创建时间距离现在很近（10秒内），认为是新节点
        Date().timeIntervalSince(node.createdAt) < 10.0
    }

    /// 标题是否为空（用于实时验证提示）
    public var isTitleEmpty: Bool {
        node.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 目标值是否有效
    public var isTargetValueValid: Bool {
        node.targetValue > 0
    }

    /// 进度百分比文本
    public var progressText: String {
        String(format: "%.1f%%", node.progress)
    }

    // MARK: - 依赖

    /// 数据仓库（用于持久化操作）
    private let repository: OKRRepositoryProtocol

    /// 节点验证器（用于表单验证）
    private let validator: NodeValidator

    // MARK: - 初始化

    /// 创建节点编辑ViewModel
    /// -------------------
    /// - Parameters:
    ///   - node: 正在编辑的节点（新建节点时传入默认值，编辑时传入已有节点）
    ///   - repository: OKR数据仓库协议实现
    ///   - validator: 节点验证器（默认创建新实例）
    public init(
        node: OKRNode,
        repository: OKRRepositoryProtocol,
        validator: NodeValidator = NodeValidator()
    ) {
        // 保存正在编辑的节点
        self.node = node
        // 保存数据仓库依赖
        self.repository = repository
        // 保存验证器依赖
        self.validator = validator
    }

    // MARK: - 公开接口: 表单验证

    /// 验证表单数据
    /// ----------
    /// 对当前编辑的节点执行完整的业务规则验证。
    ///
    /// # 验证规则：
    /// - 标题不能为空（trim后长度 > 0）
    /// - 叶子KR的targetValue必须 > 0
    /// - 叶子KR必须有有效的currentValue和targetValue
    /// - 周期必须已设置
    ///
    /// # 执行流程：
    /// 1. 调用validator验证当前节点
    /// 2. 将验证结果保存到validationErrors
    /// 3. 返回是否通过验证
    ///
    /// - Returns: true表示验证通过，false表示存在验证错误
    public func validate() -> Bool {
        // ===== 步骤1: 执行验证 =====
        // 调用NodeValidator对当前编辑的节点进行完整验证
        let errors = validator.validate(node)

        // ===== 步骤2: 保存验证结果 =====
        // 将验证错误更新到发布属性，视图会自动刷新
        validationErrors = errors

        // ===== 步骤3: 返回验证结果 =====
        // 空错误数组表示验证通过
        return errors.isEmpty
    }

    /// 执行实时验证（仅验证指定字段）
    /// ---------------------------
    /// 用于用户输入时的实时反馈，只验证指定字段。
    ///
    /// - Parameter field: 要验证的字段名称
    /// - Returns: 该字段的验证错误，nil表示该字段有效
    public func validateField(_ field: String) -> ValidationError? {
        switch field {
        case "title":
            // 验证标题字段
            if node.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .emptyTitle
            }
        case "targetValue":
            // 验证目标值字段（仅对叶子KR有意义）
            if node.isLeaf && node.targetValue <= 0 {
                return .invalidTargetValue
            }
        case "cycle":
            // 验证周期字段
            if node.cycleId == nil {
                return .cycleNotSet
            }
        default:
            break
        }
        // 该字段验证通过
        return nil
    }

    // MARK: - 公开接口: 保存节点

    /// 保存节点（创建或更新）
    /// -------------------
    /// 先执行验证，验证通过后持久化到Repository。
    ///
    /// # 执行流程：
    /// 1. 调用validate()进行表单验证
    /// 2. 验证失败 → 直接返回错误
    /// 3. 验证通过 → 设置isSaving = true
    /// 4. 判断是创建还是更新
    /// 5. 调用对应的Repository方法
    /// 6. 保存Repository更改
    /// 7. 设置isSaving = false
    ///
    /// - Returns: 保存后的节点（可能包含Repository生成的字段更新）
    public func save() async throws -> OKRNode {
        // ===== 步骤1: 表单验证 =====
        // 在保存前强制执行完整验证
        guard validate() else {
            // 验证失败 → 抛出验证错误
            // 取第一个验证错误作为代表
            if let firstError = validationErrors.first {
                throw firstError
            }
            throw NodeEditError.validationFailed
        }

        // ===== 步骤2: 设置保存状态 =====
        // 标记正在保存，防止重复提交
        isSaving = true

        do {
            // ===== 步骤3: 判断创建还是更新 =====
            // 对于新建节点，createdAt接近当前时间
            let savedNode: OKRNode

            if isNewNode {
                // ===== 创建新节点 =====
                // 调用Repository创建方法
                savedNode = try await repository.createNode(node)
            } else {
                // ===== 更新现有节点 =====
                // 先更新时间戳
                var nodeToUpdate = node
                nodeToUpdate.updatedAt = Date()
                // 调用Repository更新方法
                savedNode = try await repository.updateNode(nodeToUpdate)
            }

            // ===== 步骤4: 保存Repository更改 =====
            try await repository.save()

            // ===== 步骤5: 更新本地状态 =====
            // 使用Repository返回的已保存节点更新本地状态
            self.node = savedNode

            // ===== 步骤6: 结束保存状态 =====
            isSaving = false

            // 返回保存后的节点
            return savedNode

        } catch {
            // ===== 错误处理 =====
            // 结束保存状态
            isSaving = false
            // 记录错误信息
            if let validationError = error as? ValidationError {
                // 是验证错误 → 添加到验证错误列表
                if !validationErrors.contains(validationError) {
                    validationErrors.append(validationError)
                }
            }
            // 将错误向上传播
            throw error
        }
    }

    // MARK: - 公开接口: 加载可用父节点

    /// 加载可用的父节点列表
    /// ------------------
    /// 获取指定周期下所有可作为父节点的节点。
    /// 父节点选择规则：
    /// - Objective可以作为Key Result的父节点
    /// - Key Result可以作为Objective的父节点（对齐场景）
    /// - 节点不能选择自身或其子节点作为父节点
    ///
    /// - Parameter cycleId: 周期ID（nil表示所有周期）
    public func loadAvailableParents(cycleId: UUID?) async {
        do {
            // ===== 步骤1: 从Repository获取根节点列表 =====
            // 获取指定周期下的所有根节点
            let rootNodes = try await repository.fetchRootNodes(cycleId: cycleId)

            // ===== 步骤2: 收集所有可用节点 =====
            // 从根节点开始，递归收集所有可能的父节点
            var allNodes: [OKRNode] = []
            for root in rootNodes {
                // 排除正在编辑的节点自身
                if root.id != node.id {
                    allNodes.append(root)
                }
                // 递归收集子节点
                collectNodes(node: root, into: &allNodes, excluding: node.id)
            }

            // ===== 步骤3: 过滤可用的父节点 =====
            // 根据节点类型兼容性过滤
            availableParents = allNodes.filter { parent in
                // 检查类型兼容性
                validator.isCompatibleParent(
                    childType: node.nodeType,
                    parentType: parent.nodeType
                )
            }

        } catch {
            // 错误处理：加载失败时清空列表
            availableParents = []
        }
    }

    // MARK: - 公开接口: 表单操作

    /// 设置父节点
    /// ---------
    /// 为当前编辑的节点设置父节点。
    ///
    /// - Parameter parentId: 父节点ID，nil表示移除父节点（设为根节点）
    public func setParent(_ parentId: UUID?) {
        // 更新节点的parentId
        node.parentId = parentId
        // 更新时间戳
        node.updatedAt = Date()
    }

    /// 更新节点标题
    /// ----------
    /// 更新当前编辑节点的标题。
    ///
    /// - Parameter title: 新标题
    public func updateTitle(_ title: String) {
        node.title = title
        node.updatedAt = Date()
    }

    /// 更新节点描述
    /// ----------
    /// 更新当前编辑节点的描述。
    ///
    /// - Parameter description: 新描述
    public func updateDescription(_ description: String?) {
        node.nodeDescription = description
        node.updatedAt = Date()
    }

    /// 更新目标值
    /// --------
    /// 更新当前编辑节点的目标值。
    ///
    /// - Parameter targetValue: 新的目标值
    public func updateTargetValue(_ targetValue: Double) {
        node.targetValue = targetValue
        node.updatedAt = Date()
    }

    /// 更新当前值
    /// --------
    /// 更新当前编辑节点的当前值。
    ///
    /// - Parameter currentValue: 新的当前值
    public func updateCurrentValue(_ currentValue: Double) {
        node.currentValue = currentValue
        node.updatedAt = Date()
    }

    /// 更新节点类型
    /// ----------
    /// 更改节点的类型（Objective <-> Key Result）。
    /// 类型变更可能影响子节点的合法性。
    ///
    /// - Parameter nodeType: 新的节点类型
    public func updateNodeType(_ nodeType: NodeType) {
        node.nodeType = nodeType
        node.updatedAt = Date()
    }

    /// 更新节点状态
    /// ----------
    /// 更改节点的状态。
    ///
    /// - Parameter status: 新的状态
    public func updateStatus(_ status: NodeStatus) {
        node.status = status
        node.updatedAt = Date()
    }

    /// 更新节点范围
    /// ----------
    /// 更改节点的范围（企业级 <-> 个人级）。
    ///
    /// - Parameter scope: 新的范围
    public func updateScope(_ scope: Scope) {
        node.scope = scope
        node.updatedAt = Date()
    }

    /// 清除验证错误
    /// ----------
    /// 手动清除验证错误列表。
    /// 通常在用户开始修改表单时调用。
    public func clearValidationErrors() {
        validationErrors = []
    }

    // MARK: - 私有辅助方法

    /// 递归收集树中所有节点
    /// ------------------
    /// 辅助方法：从指定节点开始递归收集所有子节点。
    ///
    /// - Parameters:
    ///   - node: 当前节点
    ///   - collection: 收集结果的数组（inout参数）
    ///   - excluding: 要排除的节点ID（防止选择自己作为父节点）
    private func collectNodes(
        node: OKRNode,
        into collection: inout [OKRNode],
        excluding excludedId: UUID
    ) {
        // 遍历当前节点的所有子节点
        for child in node.children {
            // 排除自身
            if child.id != excludedId {
                // 将子节点添加到收集列表
                collection.append(child)
            }
            // 递归收集子节点的子节点
            collectNodes(node: child, into: &collection, excluding: excludedId)
        }
    }
}

// MARK: - 错误类型

/// 节点编辑ViewModel专用错误
public enum NodeEditError: Error, Sendable {
    /// 表单验证失败（通用错误）
    case validationFailed
    /// 保存操作失败
    case saveFailed
}
