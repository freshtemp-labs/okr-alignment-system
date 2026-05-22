import Foundation

/// ============================================================================
/// MARK: - CycleListViewModel
/// ============================================================================

/// OKR周期列表ViewModel
/// ===================
/// 管理OKR周期的列表展示、选择和创建。
///
/// # 职责
/// - 加载所有OKR周期
/// - 管理周期选择状态
/// - 创建新周期
/// - 管理加载状态和错误信息
///
/// # 使用场景
/// 用于展示OKR周期列表（如顶部下拉选择器或侧边栏），
/// 用户可以选择当前正在查看的周期，或创建新的周期。
///
/// # 与TreeViewModel的协作
/// 当用户选择新周期时，CycleListViewModel更新selectedCycle，
/// TreeViewModel响应此变化加载对应周期的OKR树。
///
@MainActor
@Observable
public final class CycleListViewModel {

    // MARK: - 发布状态属性

    /// 所有OKR周期列表
    /// 从Repository加载后填充
    public var cycles: [OKRCycle] = []

    /// 当前选中的周期
    /// nil表示未选择任何周期
    public var selectedCycle: OKRCycle? {
        didSet {
            // 选中周期变化时，记录选中的周期ID供其他ViewModel使用
            selectedCycleId = selectedCycle?.id
        }
    }

    /// 当前选中的周期ID（内部存储）
    /// 用于在selectedCycle被设置为nil时仍保留ID引用
    private var selectedCycleId: UUID?

    /// 是否正在加载数据
    /// 视图可据此显示加载指示器
    public var isLoading: Bool = false

    /// 错误信息（如果有）
    /// nil表示没有错误
    public var errorMessage: String?

    // MARK: - 计算属性

    /// 是否有可用周期
    /// 用于视图判断是否需要展示空状态
    public var hasCycles: Bool {
        // 周期数组非空表示有可用周期
        !cycles.isEmpty
    }

    /// 周期数量
    public var cycleCount: Int {
        cycles.count
    }

    /// 活跃周期列表（未归档的周期）
    public var activeCycles: [OKRCycle] {
        // 过滤掉已归档的周期
        cycles.filter { !$0.isArchived }
    }

    /// 归档周期列表
    public var archivedCycles: [OKRCycle] {
        // 过滤出已归档的周期
        cycles.filter { $0.isArchived }
    }

    /// 当前活跃周期（isActive为true的周期）
    public var currentActiveCycle: OKRCycle? {
        // 查找标记为活跃的周期
        cycles.first { $0.isActive }
    }

    /// 选中周期的名称（用于展示）
    public var selectedCycleName: String {
        selectedCycle?.name ?? "选择周期"
    }

    // MARK: - 依赖

    /// 数据仓库（用于持久化操作）
    /// 通过协议注入，便于测试时替换
    private let repository: OKRRepositoryProtocol

    // MARK: - 初始化

    /// 创建周期列表ViewModel
    /// - Parameter repository: OKR数据仓库协议实现
    public init(repository: OKRRepositoryProtocol) {
        // 保存注入的仓库依赖
        self.repository = repository
    }

    // MARK: - 公开接口: 数据加载

    /// 加载所有OKR周期
    /// --------------
    /// 从Repository获取所有OKR周期数据。
    ///
    /// # 执行流程：
    /// 1. 设置isLoading = true
    /// 2. 调用repository.fetchCycles获取数据
    /// 3. 按开始日期降序排序（最新的在前）
    /// 4. 更新cycles数组
    /// 5. 设置isLoading = false
    public func loadCycles() async {
        // ===== 步骤1: 设置加载状态 =====
        isLoading = true
        // 清除之前的错误信息
        errorMessage = nil

        do {
            // ===== 步骤2: 从Repository获取周期列表 =====
            let fetchedCycles = try await repository.fetchCycles()

            // ===== 步骤3: 排序处理 =====
            // 按开始日期降序排列（最新的周期在前）
            // 如果开始日期相同，按名称字母顺序排列
            let sortedCycles = fetchedCycles.sorted { first, second in
                // 优先按开始日期降序
                if first.startDate != second.startDate {
                    return first.startDate > second.startDate
                }
                // 开始日期相同 → 按名称升序
                return first.name < second.name
            }

            // ===== 步骤4: 更新状态 =====
            cycles = sortedCycles

            // 如果没有选中周期但有可用周期，自动选择第一个
            if selectedCycle == nil && !sortedCycles.isEmpty {
                // 优先选择当前活跃的周期
                selectedCycle = sortedCycles.first { $0.isActive }
                    // 没有活跃周期则选择第一个
                    ?? sortedCycles.first
            }

        } catch {
            // ===== 错误处理 =====
            errorMessage = "加载周期列表失败: \(error.localizedDescription)"
            // 出错时清空周期列表
            cycles = []
        }

        // ===== 步骤5: 结束加载状态 =====
        isLoading = false
    }

    // MARK: - 公开接口: 周期选择

    /// 选择指定周期
    /// ----------
    /// 更新当前选中的周期。
    /// 此方法不会触发数据加载，仅更新选择状态。
    /// 调用方（如TreeViewModel）应监听此变化并加载对应数据。
    ///
    /// - Parameter cycle: 要选择的周期，nil表示取消选择
    public func selectCycle(_ cycle: OKRCycle?) {
        // ===== 步骤1: 更新选中状态 =====
        // 设置新的选中周期
        selectedCycle = cycle

        // ===== 步骤2: 清除错误信息 =====
        // 选择新周期时清除之前的错误
        errorMessage = nil
    }

    /// 通过ID选择周期
    /// ------------
    /// 根据周期ID查找并选择对应的周期。
    ///
    /// - Parameter cycleId: 要选择的周期ID
    public func selectCycle(byId cycleId: UUID) {
        // 在已加载的周期列表中查找匹配ID的周期
        if let cycle = cycles.first(where: { $0.id == cycleId }) {
            // 找到匹配的周期 → 选中它
            selectedCycle = cycle
        } else {
            // 未找到匹配的周期 → 仅记录ID
            selectedCycleId = cycleId
            errorMessage = "未找到指定的周期"
        }
    }

    /// 取消当前选择
    /// ----------
    /// 清除当前选中的周期。
    public func deselectCycle() {
        // 将选中状态设为nil
        selectedCycle = nil
    }

    // MARK: - 公开接口: 周期创建

    /// 创建新周期
    /// --------
    /// 创建并保存新的OKR周期。
    ///
    /// # 参数验证：
    /// - 名称不能为空（trim后长度 > 0）
    /// - 结束日期必须晚于开始日期
    ///
    /// # 执行流程：
    /// 1. 验证参数
    /// 2. 创建OKRCycle实例
    /// 3. 调用repository.createCycle保存
    /// 4. 刷新周期列表
    /// 5. 自动选中新创建的周期
    ///
    /// - Parameters:
    ///   - name: 周期名称
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    public func createCycle(
        name: String,
        startDate: Date,
        endDate: Date
    ) async throws {
        // ===== 步骤1: 参数验证 =====
        // 验证名称非空
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw CycleValidationError.emptyName
        }

        // 验证结束日期晚于开始日期
        guard endDate > startDate else {
            throw CycleValidationError.invalidDateRange
        }

        // ===== 步骤2: 设置加载状态 =====
        isLoading = true
        errorMessage = nil

        do {
            // ===== 步骤3: 创建周期实例 =====
            // 构建新的周期对象
            let newCycle = OKRCycle(
                id: UUID(),           // 生成新的唯一标识符
                name: trimmedName,    // 使用trim后的名称
                startDate: startDate, // 设置开始日期
                endDate: endDate,     // 设置结束日期
                isActive: false,      // 新周期默认不自动激活
                isArchived: false     // 新周期默认未归档
            )

            // ===== 步骤4: 持久化到Repository =====
            let savedCycle = try await repository.createCycle(newCycle)

            // 保存更改
            try await repository.save()

            // ===== 步骤5: 刷新周期列表 =====
            // 重新加载以包含新创建的周期
            await loadCycles()

            // ===== 步骤6: 自动选中新周期 =====
            // 将新创建的周期设为当前选中
            selectedCycle = savedCycle

        } catch {
            // ===== 错误处理 =====
            errorMessage = "创建周期失败: \(error.localizedDescription)"
            // 将错误向上传播
            throw error
        }

        // ===== 步骤7: 结束加载状态 =====
        isLoading = false
    }

    // MARK: - 公开接口: 周期管理

    /// 归档指定周期
    /// ----------
    /// 将周期标记为已归档。
    ///
    /// - Parameter cycleId: 要归档的周期ID
    public func archiveCycle(_ cycleId: UUID) async {
        // 在周期列表中查找目标周期
        guard let index = cycles.firstIndex(where: { $0.id == cycleId }) else {
            errorMessage = "未找到要归档的周期"
            return
        }

        // 创建更新后的周期（标记为已归档）
        var updatedCycle = cycles[index]
        updatedCycle.isArchived = true
        updatedCycle.isActive = false // 归档时同时取消激活状态

        do {
            // 持久化到Repository
            let savedCycle = try await repository.updateCycle(updatedCycle)
            try await repository.save()
            
            // 更新本地状态
            cycles[index] = savedCycle

            // 如果归档的是当前选中周期，取消选择
            if selectedCycle?.id == cycleId {
                selectedCycle = nil
            }
        } catch {
            errorMessage = "归档周期失败: \(error.localizedDescription)"
        }
    }

    /// 激活指定周期
    /// ----------
    /// 将指定周期设为当前活跃周期，同时取消其他周期的活跃状态。
    ///
    /// - Parameter cycleId: 要激活的周期ID
    public func activateCycle(_ cycleId: UUID) async {
        do {
            // 先取消所有周期的活跃状态
            for i in cycles.indices {
                if cycles[i].isActive {
                    var cycle = cycles[i]
                    cycle.isActive = false
                    let savedCycle = try await repository.updateCycle(cycle)
                    try await repository.save()
                    cycles[i] = savedCycle
                }
            }

            // 将目标周期设为活跃
            if let targetIndex = cycles.firstIndex(where: { $0.id == cycleId }) {
                var targetCycle = cycles[targetIndex]
                targetCycle.isActive = true
                let savedCycle = try await repository.updateCycle(targetCycle)
                try await repository.save()
                cycles[targetIndex] = savedCycle
            }

            // 更新选中状态为激活的周期
            selectedCycle = cycles.first { $0.id == cycleId }
        } catch {
            errorMessage = "激活周期失败: \(error.localizedDescription)"
        }
    }

    /// 获取指定ID的周期
    /// --------------
    /// 在已加载的周期列表中查找指定ID的周期。
    ///
    /// - Parameter cycleId: 要查找的周期ID
    /// - Returns: 找到的周期，nil表示未找到
    public func cycle(byId cycleId: UUID) -> OKRCycle? {
        // 在周期列表中线性查找
        cycles.first { $0.id == cycleId }
    }

    // MARK: - 公开接口: 数据清除

    /// 清除所有数据
    /// ----------
    /// 重置所有状态到初始值。
    /// 在退出视图或注销时调用。
    public func clear() {
        // 重置所有状态属性
        cycles = []
        selectedCycle = nil
        selectedCycleId = nil
        isLoading = false
        errorMessage = nil
    }
}

// MARK: - 错误类型

/// 周期验证专用错误
public enum CycleValidationError: Error, Sendable, LocalizedError {
    /// 周期名称不能为空
    case emptyName
    /// 结束日期必须晚于开始日期
    case invalidDateRange

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "周期名称不能为空"
        case .invalidDateRange:
            return "结束日期必须晚于开始日期"
        }
    }
}
