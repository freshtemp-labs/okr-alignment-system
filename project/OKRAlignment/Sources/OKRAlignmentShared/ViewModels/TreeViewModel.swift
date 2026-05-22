import Foundation
import SwiftUI

/// ============================================================================
/// MARK: - TreeViewModel
/// ============================================================================

/// 树状视图ViewModel - 管理OKR树的展示和交互
/// =========================================
/// 负责从Repository加载数据，通过级联计算引擎自动计算进度，驱动视图更新。
///
/// # 职责
/// - 加载和管理OKR树的数据（根节点及其子树）
/// - 响应用户对叶子KR的进度更新操作
/// - 通过级联引擎自动重算受影响的所有父节点
/// - 处理节点的删除操作
/// - 管理加载状态和错误信息
///
/// # 使用方式
/// ```swift
/// let viewModel = TreeViewModel(repository: repo, engine: engine)
/// await viewModel.loadTree(cycleId: selectedCycleId)
/// ```
///
@MainActor
@Observable
public final class TreeViewModel {

    // MARK: - 发布状态属性

    /// 当前展示的OKR树根节点
    /// nil表示尚未加载数据
    public var rootNode: OKRNode?

    /// 当前选中的周期ID
    /// 用于过滤和展示特定周期下的OKR
    public var selectedCycleId: UUID?

    /// 是否正在加载数据
    /// 视图可据此显示加载指示器
    public var isLoading: Bool = false

    /// 错误信息（如果有）
    /// nil表示没有错误，非nil时应展示错误提示
    public var errorMessage: String?

    // MARK: - 依赖

    /// 数据仓库（用于持久化操作）
    /// 通过协议注入，便于单元测试中替换为Mock
    private let repository: OKRRepositoryProtocol

    /// 级联计算引擎（用于进度自动计算）
    /// 纯函数引擎，无副作用，线程安全
    private let engine: CascadeEngineProtocol

    // MARK: - 初始化

    /// 创建树视图ViewModel
    /// - Parameters:
    ///   - repository: OKR数据仓库协议实现
    ///   - engine: 级联计算引擎（默认创建新实例）
    public init(
        repository: OKRRepositoryProtocol,
        engine: CascadeEngineProtocol = OKRCascadeEngine()
    ) {
        // 保存依赖注入的仓库实例
        self.repository = repository
        // 保存依赖注入的引擎实例
        self.engine = engine
    }

    // MARK: - 公开接口: 数据加载

    /// 加载指定周期的OKR树
    /// ------------------
    /// 从Repository获取指定周期的根节点数据，
    /// 然后通过级联引擎计算整棵树的进度。
    ///
    /// # 执行流程：
    /// 1. 设置isLoading = true，清除之前的错误
    /// 2. 调用repository.fetchRootNodes获取数据
    /// 3. 如果有数据，取第一个根节点并通过引擎计算整棵树
    /// 4. 更新rootNode状态
    /// 5. 设置isLoading = false
    ///
    /// - Parameter cycleId: 要加载的周期ID，nil表示加载所有周期
    public func loadTree(cycleId: UUID?) async {
        // ===== 步骤1: 设置加载状态 =====
        // 标记开始加载，视图可据此显示加载指示器
        isLoading = true
        // 清除之前的错误信息
        errorMessage = nil

        do {
            // ===== 步骤2: 从Repository获取数据 =====
            // 异步获取指定周期的根节点列表
            let rootNodes = try await repository.fetchRootNodes(cycleId: cycleId)

            // ===== 步骤3: 处理获取的数据 =====
            if let firstRoot = rootNodes.first {
                // 使用级联引擎计算整棵树的进度
                // 这会自动递归计算所有子节点的progress
                let calculatedTree = engine.calculateTreeProgress(root: firstRoot)
                // 更新根节点状态，驱动视图刷新
                rootNode = calculatedTree
            } else {
                // 没有找到数据 → 根节点设为nil
                rootNode = nil
            }

            // 保存当前选中的周期ID
            selectedCycleId = cycleId

        } catch {
            // ===== 错误处理 =====
            // 捕获并记录错误信息
            errorMessage = "加载OKR树失败: \(error.localizedDescription)"
            // 出错时重置根节点
            rootNode = nil
        }

        // ===== 步骤4: 结束加载状态 =====
        // 无论成功或失败，都要结束加载状态
        isLoading = false
    }

    // MARK: - 公开接口: 进度更新

    /// 更新叶子KR的进度（delta为增量值，如+10%或-10%）
    /// -----------------------------------------------
    /// 用户通过视图操作更新某个叶子KR的进度时调用。
    /// 方法会将delta转换为新的currentValue，然后通过引擎级联重算。
    ///
    /// # 执行流程：
    /// 1. 验证rootNode存在
    /// 2. 在树中找到目标叶子节点
    /// 3. 计算新的currentValue = 原currentValue + (targetValue × delta / 100)
    /// 4. 通过引擎更新叶子并级联重算整棵树
    /// 5. 将结果持久化到Repository
    /// 6. 更新rootNode状态
    ///
    /// - Parameters:
    ///   - nodeId: 要更新的叶子节点ID
    ///   - delta: 增量百分比（如10.0表示增加10%，-10.0表示减少10%）
    public func updateLeafProgress(nodeId: UUID, delta: Double) async {
        // ===== 步骤1: 验证数据前提 =====
        // 确保根节点已加载
        guard let currentRoot = rootNode else {
            // 根节点不存在 → 无法执行更新
            errorMessage = "请先加载OKR树"
            return
        }

        // 设置加载状态
        isLoading = true
        // 清除之前的错误
        errorMessage = nil

        do {
            // ===== 步骤2: 在树中查找目标叶子节点 =====
            // 需要找到叶子节点以获取当前的currentValue和targetValue
            guard let leafNode = findNode(in: currentRoot, id: nodeId) else {
                // 未找到目标节点
                errorMessage = "未找到指定的节点"
                isLoading = false
                return
            }

            // 验证目标节点是叶子Key Result
            guard leafNode.isLeaf else {
                // 不是叶子节点 → 不能直接更新进度
                errorMessage = "只能更新叶子关键结果的进度"
                isLoading = false
                return
            }

            // ===== 步骤3: 计算新的currentValue =====
            // 将百分比增量转换为绝对值变化
            // deltaPercent = delta / 100.0
            // valueChange = targetValue × deltaPercent
            // newValue = currentValue + valueChange
            let deltaPercent = delta / 100.0
            let valueChange = leafNode.targetValue * deltaPercent
            let newValue = leafNode.currentValue + valueChange

            // ===== 步骤4: 通过引擎更新并级联重算 =====
            // 引擎会自动：
            // - 更新叶子的currentValue
            // - 重新计算叶子的progress
            // - 从叶子向上重算所有父节点的progress
            let updatedTree = engine.updateLeafAndRecalculate(
                treeRoot: currentRoot,
                leafId: nodeId,
                newValue: newValue
            )

            // ===== 步骤5: 持久化到Repository =====
            // 调用Repository更新叶子节点的值
            // 使用try await处理可能的持久化错误
            _ = try await repository.updateLeafValue(
                nodeId: nodeId,
                newValue: newValue
            )

            // 保存Repository的更改
            try await repository.save()

            // ===== 步骤6: 更新视图状态 =====
            // 更新rootNode以驱动视图刷新
            rootNode = updatedTree

        } catch {
            // ===== 错误处理 =====
            errorMessage = "更新进度失败: \(error.localizedDescription)"
        }

        // 结束加载状态
        isLoading = false
    }

    /// 更新叶子KR的绝对值
    /// -----------------
    /// 直接设置叶子KR的currentValue为指定值（而非增量）。
    /// 适用于用户直接输入数值的场景。
    ///
    /// - Parameters:
    ///   - nodeId: 要更新的叶子节点ID
    ///   - absoluteValue: 新的currentValue绝对值
    public func updateLeafAbsoluteValue(nodeId: UUID, absoluteValue: Double) async {
        // ===== 步骤1: 验证数据前提 =====
        guard let currentRoot = rootNode else {
            errorMessage = "请先加载OKR树"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // ===== 步骤2: 通过引擎更新并级联重算 =====
            // 直接使用absoluteValue作为newValue
            let updatedTree = engine.updateLeafAndRecalculate(
                treeRoot: currentRoot,
                leafId: nodeId,
                newValue: absoluteValue
            )

            // ===== 步骤3: 持久化到Repository =====
            _ = try await repository.updateLeafValue(
                nodeId: nodeId,
                newValue: absoluteValue
            )
            try await repository.save()

            // ===== 步骤4: 更新视图状态 =====
            rootNode = updatedTree

        } catch {
            errorMessage = "更新数值失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 公开接口: 节点删除

    /// 删除节点
    /// -------
    /// 从树中删除指定节点及其子树（或仅删除单个节点）。
    ///
    /// # 执行流程：
    /// 1. 验证rootNode存在
    /// 2. 调用Repository删除节点
    /// 3. 从本地树状态中移除被删除的节点
    /// 4. 如果删除的是叶子节点，级联重算父节点进度
    /// 5. 更新rootNode状态
    ///
    /// - Parameters:
    ///   - id: 要删除的节点ID
    ///   - cascade: 是否级联删除子节点，默认true
    public func deleteNode(id: UUID, cascade: Bool = true) async {
        // ===== 步骤1: 验证数据前提 =====
        guard rootNode != nil else {
            errorMessage = "请先加载OKR树"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // ===== 步骤2: 调用Repository删除 =====
            // 将删除操作委托给Repository处理
            try await repository.deleteNode(id: id, cascade: cascade)

            // 保存更改
            try await repository.save()

            // ===== 步骤3: 刷新树数据 =====
            // 删除后重新加载整棵树以确保数据一致性
            // 这样可以避免本地状态与远程状态不一致的问题
            await loadTree(cycleId: selectedCycleId)

        } catch {
            errorMessage = "删除节点失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 公开接口: 刷新

    /// 刷新当前树数据
    /// ------------
    /// 重新加载当前选中的周期的OKR树。
    /// 用于用户手动刷新或后台数据变更后的同步。
    public func refresh() async {
        // 使用当前选中的周期ID重新加载
        // 如果selectedCycleId为nil，则加载所有周期的数据
        await loadTree(cycleId: selectedCycleId)
    }

    // MARK: - 树操作工具方法

    /// 在树中查找指定ID的节点
    /// --------------------
    /// 递归遍历整棵树，找到匹配的节点。
    ///
    /// - Parameters:
    ///   - root: 树的根节点
    ///   - id: 要查找的节点ID
    /// - Returns: 找到的节点，nil表示未找到
    public func findNode(in root: OKRNode, id: UUID) -> OKRNode? {
        // ===== 步骤1: 检查当前节点是否匹配 =====
        if root.id == id {
            // 找到匹配的节点 → 返回
            return root
        }

        // ===== 步骤2: 递归搜索子节点 =====
        // 对每个子节点递归调用findNode
        for child in root.children {
            // 在子树中查找
            if let found = findNode(in: child, id: id) {
                // 在子树中找到 → 返回结果
                return found
            }
        }

        // ===== 步骤3: 未找到 =====
        // 遍历完整棵树仍未找到匹配节点
        return nil
    }

    /// 计算树中所有节点的总数
    /// --------------------
    /// 递归计算整棵树的节点数量。
    ///
    /// - Parameter root: 树的根节点
    /// - Returns: 节点总数（包含根节点）
    public func totalNodeCount(in root: OKRNode) -> Int {
        // 计数器初始化为1（根节点本身）
        var count = 1
        // 递归累加每个子树的节点数量
        for child in root.children {
            count += totalNodeCount(in: child)
        }
        return count
    }

    /// 计算树中所有叶子KR节点的数量
    /// --------------------------
    /// 递归统计所有叶子Key Result节点。
    ///
    /// - Parameter root: 树的根节点
    /// - Returns: 叶子KR节点数量
    public func leafNodeCount(in root: OKRNode) -> Int {
        // 如果是叶子节点 → 计1
        if root.isLeaf {
            return 1
        }
        // 如果不是叶子 → 递归累加子节点
        var count = 0
        for child in root.children {
            count += leafNodeCount(in: child)
        }
        return count
    }

    /// 获取树的整体进度
    /// --------------
    /// 返回根节点的progress作为整棵树的整体进度。
    ///
    /// - Returns: 整体进度百分比（0.0 - 100.0），nil表示树未加载
    public var overallProgress: Double? {
        rootNode?.progress
    }

    /// 获取树中所有叶子节点的列表
    /// ------------------------
    /// 扁平化收集树中所有叶子KR节点。
    ///
    /// - Parameter root: 树的根节点
    /// - Returns: 叶子节点数组
    public func allLeafNodes(in root: OKRNode) -> [OKRNode] {
        // 如果是叶子节点 → 返回包含自身的数组
        if root.isLeaf {
            return [root]
        }
        // 递归收集所有子节点的叶子
        var leaves: [OKRNode] = []
        for child in root.children {
            leaves.append(contentsOf: allLeafNodes(in: child))
        }
        return leaves
    }

    /// 展开/折叠节点（用于树形视图的展开状态管理）
    /// ----------------------------------------
    /// 注：由于OKRNode是struct值类型，此方法返回更新后的节点副本。
    /// 视图层需要自行维护哪些节点处于展开状态。
    ///
    /// 此ViewModel不维护展开状态，因为这是纯粹的UI状态，
    /// 应由视图层使用@State或其他机制管理。
}
