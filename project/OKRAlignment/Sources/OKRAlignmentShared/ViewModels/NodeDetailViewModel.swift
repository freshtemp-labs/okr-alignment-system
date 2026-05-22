import Foundation

/// ============================================================================
/// MARK: - NodeDetailViewModel
/// ============================================================================

/// 节点详情面板ViewModel
/// ====================
/// 管理单个OKR节点的详情展示和编辑。
///
/// # 职责
/// - 加载指定节点的详细信息
/// - 支持节点数据的更新操作
/// - 管理加载状态和错误信息
/// - 提供节点的计算属性（如进度百分比显示文本）
///
/// # 使用场景
/// 用于侧边栏详情面板或弹窗中展示某个节点的完整信息，
/// 并允许用户编辑节点的标题、描述等基本属性。
///
/// # 与TreeViewModel的关系
/// NodeDetailViewModel关注单个节点的CRUD操作，
/// TreeViewModel关注整棵树的管理和级联计算。
///
@MainActor
@Observable
public final class NodeDetailViewModel {

    // MARK: - 发布状态属性

    /// 当前展示的节点详情
    /// nil表示尚未加载或节点不存在
    public var node: OKRNode?

    /// 是否正在加载数据
    /// 视图可据此显示骨架屏或加载指示器
    public var isLoading: Bool = false

    /// 错误信息（如果有）
    /// nil表示没有错误
    public var errorMessage: String?

    // MARK: - 计算属性

    /// 节点的完成度百分比文本（用于展示）
    /// 例如: "75.5%"
    public var progressText: String {
        guard let node = node else { return "--" }
        // 格式化进度为一位小数的百分比文本
        return String(format: "%.1f%%", node.progress)
    }

    /// 节点状态的中文描述
    public var statusDescription: String {
        guard let node = node else { return "未知" }
        switch node.status {
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

    /// 当前值与目标值的显示文本
    /// 例如: "75 / 100"
    public var valueDisplayText: String {
        guard let node = node else { return "--" }
        if let unit = node.unit, !unit.isEmpty {
            // 有单位 → 显示单位
            return String(
                format: "%.1f %@ / %.1f %@",
                node.currentValue, unit,
                node.targetValue, unit
            )
        } else {
            // 无单位 → 纯数值显示
            return String(format: "%.1f / %.1f", node.currentValue, node.targetValue)
        }
    }

    /// 节点是否为叶子Key Result
    public var isLeafNode: Bool {
        node?.isLeaf ?? false
    }

    /// 节点是否可编辑（未取消的节点可编辑）
    public var isEditable: Bool {
        guard let node = node else { return false }
        return node.status != .cancelled
    }

    /// 子节点列表（用于展示父节点的子项）
    public var children: [OKRNode] {
        node?.children ?? []
    }

    /// 是否有子节点
    public var hasChildren: Bool {
        !(node?.children.isEmpty ?? true)
    }

    // MARK: - 依赖

    /// 数据仓库（用于持久化操作）
    /// 通过协议注入，便于测试时替换
    private let repository: OKRRepositoryProtocol

    // MARK: - 初始化

    /// 创建节点详情ViewModel
    /// - Parameter repository: OKR数据仓库协议实现
    public init(repository: OKRRepositoryProtocol) {
        // 保存注入的仓库依赖
        self.repository = repository
    }

    // MARK: - 公开接口: 数据加载

    /// 加载指定ID的节点详情
    /// ------------------
    /// 从Repository获取单个节点的完整信息。
    ///
    /// # 执行流程：
    /// 1. 设置isLoading = true
    /// 2. 调用repository.fetchNode获取节点
    /// 3. 更新node状态
    /// 4. 设置isLoading = false
    ///
    /// - Parameter id: 要加载的节点ID
    public func loadNode(id: UUID) async {
        // ===== 步骤1: 设置加载状态 =====
        isLoading = true
        // 清除之前的错误和节点数据
        errorMessage = nil
        node = nil

        do {
            // ===== 步骤2: 从Repository获取节点 =====
            // 异步获取指定ID的节点
            let fetchedNode = try await repository.fetchNode(id: id)

            // ===== 步骤3: 更新状态 =====
            if let fetchedNode = fetchedNode {
                // 成功获取到节点 → 更新node
                node = fetchedNode
            } else {
                // 节点不存在
                errorMessage = "未找到指定节点"
            }

        } catch {
            // ===== 错误处理 =====
            errorMessage = "加载节点失败: \(error.localizedDescription)"
        }

        // ===== 步骤4: 结束加载状态 =====
        isLoading = false
    }

    // MARK: - 公开接口: 节点更新

    /// 更新节点数据
    /// -----------
    /// 将更新后的节点数据持久化到Repository，并刷新本地状态。
    ///
    /// # 执行流程：
    /// 1. 设置isLoading = true
    /// 2. 调用repository.updateNode保存更新
    /// 3. 更新本地node状态
    /// 4. 设置isLoading = false
    ///
    /// - Parameter node: 更新后的节点
    public func updateNode(_ node: OKRNode) async throws {
        // ===== 步骤1: 设置加载状态 =====
        isLoading = true
        errorMessage = nil

        do {
            // ===== 步骤2: 持久化更新 =====
            // 调用Repository保存节点更新
            let updatedNode = try await repository.updateNode(node)

            // 保存更改
            try await repository.save()

            // ===== 步骤3: 更新本地状态 =====
            // 使用Repository返回的更新后数据刷新本地状态
            self.node = updatedNode

        } catch {
            // ===== 错误处理 =====
            errorMessage = "更新节点失败: \(error.localizedDescription)"
            // 将错误向上传播，让调用者处理
            throw error
        }

        // ===== 步骤4: 结束加载状态 =====
        isLoading = false
    }

    /// 更新节点的标题和描述
    /// ------------------
    /// 便捷方法，只更新节点的基本信息字段。
    ///
    /// - Parameters:
    ///   - title: 新标题
    ///   - description: 新描述（可选）
    public func updateBasicInfo(title: String, description: String?) async throws {
        // ===== 步骤1: 验证当前节点存在 =====
        guard var currentNode = node else {
            // 没有当前节点 → 无法更新
            throw NodeDetailError.noCurrentNode
        }

        // ===== 步骤2: 验证标题非空 =====
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw NodeDetailError.emptyTitle
        }

        // ===== 步骤3: 创建更新后的节点 =====
        // 只修改标题和描述字段，其他字段保持不变
        currentNode.title = trimmedTitle
        currentNode.nodeDescription = description
        // 更新时间戳
        currentNode.updatedAt = Date()

        // ===== 步骤4: 调用updateNode持久化 =====
        try await updateNode(currentNode)
    }

    /// 更新节点的状态
    /// ------------
    /// 便捷方法，只更新节点的状态字段。
    ///
    /// - Parameter status: 新状态
    public func updateStatus(_ status: NodeStatus) async throws {
        // ===== 步骤1: 验证当前节点存在 =====
        guard var currentNode = node else {
            throw NodeDetailError.noCurrentNode
        }

        // ===== 步骤2: 更新状态 =====
        currentNode.status = status
        // 更新时间戳
        currentNode.updatedAt = Date()

        // ===== 步骤3: 持久化 =====
        try await updateNode(currentNode)
    }

    // MARK: - 公开接口: 数据清除

    /// 清除当前加载的节点数据
    /// --------------------
    /// 在关闭详情面板或切换视图时调用，
    /// 释放当前节点数据并重置所有状态。
    public func clear() {
        // 重置所有状态到初始值
        node = nil
        isLoading = false
        errorMessage = nil
    }
}

// MARK: - 错误类型

/// 节点详情ViewModel专用错误
public enum NodeDetailError: Error, Sendable {
    /// 没有当前节点（尝试操作但node为nil）
    case noCurrentNode
    /// 标题不能为空
    case emptyTitle
}
