// OKRAlignmentShared/Data/Repository/OKRRepositoryProtocol.swift

import Foundation

/// OKR数据仓库协议
///
/// 此协议抽象了Core Data的持久化实现细节，为上层业务逻辑提供类型安全的
/// 领域模型（`OKRNode`、`OKRCycle`）读写操作。所有方法均为异步，支持Swift并发。
///
/// ## 设计原则
/// - **协议导向**：通过协议解耦业务层与具体持久化技术
/// - **类型安全**：操作对象均为强类型的领域模型，而非Core Data实体
/// - **Sendable兼容**：确保在Swift 6并发环境中安全传递
///
/// ## 使用示例
/// ```swift
/// let repository: OKRRepositoryProtocol = CoreDataOKRRepository(container: container)
/// let roots = try await repository.fetchRootNodes(cycleId: cycleId)
/// ```
protocol OKRRepositoryProtocol: Sendable {
    
    // MARK: - Node Queries
    
    /// 获取指定周期的所有根节点（无父节点的Objective）
    ///
    /// - Parameter cycleId: 周期ID，为`nil`时返回所有未关联周期的根节点
    /// - Returns: 根节点数组，按`sortOrder`升序排列
    /// - Throws: 数据库查询错误
    func fetchRootNodes(cycleId: UUID?) async throws -> [OKRNode]
    
    /// 根据ID获取单个节点（包含完整子树）
    ///
    /// 此方法会递归加载该节点下的所有子节点，构建完整的树形结构。
    ///
    /// - Parameter id: 节点唯一标识符
    /// - Returns: 完整的`OKRNode`（含子树），若不存在则返回`nil`
    /// - Throws: 数据库查询错误
    func fetchNode(id: UUID) async throws -> OKRNode?
    
    // MARK: - Node Mutations
    
    /// 创建新节点
    ///
    /// - Parameter node: 要创建的领域模型节点
    /// - Returns: 创建成功后的节点（含生成的元数据）
    /// - Throws: 验证错误或数据库写入错误
    func createNode(_ node: OKRNode) async throws -> OKRNode
    
    /// 更新现有节点
    ///
    /// - Parameter node: 包含更新数据的领域模型节点
    /// - Returns: 更新后的节点
    /// - Throws: 节点不存在错误或数据库写入错误
    func updateNode(_ node: OKRNode) async throws -> OKRNode
    
    /// 删除节点
    ///
    /// - Parameters:
    ///   - id: 要删除的节点ID
    ///   - cascade: 若为`true`，则级联删除所有子节点；若为`false`且存在子节点则抛出错误
    /// - Throws: 节点不存在错误、存在子节点错误（非级联模式）或数据库删除错误
    func deleteNode(id: UUID, cascade: Bool) async throws
    
    /// 更新叶子KR的当前值并触发级联进度重算
    ///
    /// 此方法专门用于更新叶子节点（`isLeaf == true`）的`currentValue`。
    /// 更新后会自动计算该KR的`progress`，并向上遍历所有父节点，
    /// 根据子节点进度重新计算每个父节点的总进度。
    ///
    /// - Parameters:
    ///   - nodeId: 叶子KR节点的ID
    ///   - newValue: 新的当前值
    /// - Returns: 更新后的叶子节点（`progress`已更新）
    /// - Throws: 节点不存在、非叶子节点或数据库写入错误
    func updateLeafValue(nodeId: UUID, newValue: Double) async throws -> OKRNode
    
    // MARK: - Cycle Queries
    
    /// 获取所有周期
    ///
    /// - Returns: 所有`OKRCycle`，按开始日期降序排列
    /// - Throws: 数据库查询错误
    func fetchCycles() async throws -> [OKRCycle]
    
    // MARK: - Cycle Mutations
    
    /// 创建新周期
    ///
    /// - Parameter cycle: 要创建的领域模型周期
    /// - Returns: 创建成功后的周期
    /// - Throws: 验证错误或数据库写入错误
    func createCycle(_ cycle: OKRCycle) async throws -> OKRCycle
    
    /// 更新现有周期
    ///
    /// - Parameter cycle: 包含更新数据的领域模型周期
    /// - Returns: 更新后的周期
    /// - Throws: 周期不存在错误或数据库写入错误
    func updateCycle(_ cycle: OKRCycle) async throws -> OKRCycle
    
    /// 检查指定ID的节点是否存在
    ///
    /// - Parameter id: 节点唯一标识符
    /// - Returns: 存在返回`true`，否则返回`false`
    /// - Throws: 数据库查询错误
    func nodeExists(id: UUID) async throws -> Bool
    
    // MARK: - Persistence
    
    /// 保存所有未保存的更改到持久化存储
    ///
    /// - Throws: 持久化层验证错误或I/O错误
    func save() async throws
}
