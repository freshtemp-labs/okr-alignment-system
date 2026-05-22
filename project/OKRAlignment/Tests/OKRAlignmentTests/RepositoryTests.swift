import XCTest
@testable import OKRAlignment

// MARK: - RepositoryTests

/// Repository层的集成测试套件
///
/// 本测试类验证OKRRepository的所有数据操作，包括CRUD操作、
/// 级联删除、叶子值更新、Cycle查询以及事务提交。
///
/// 使用MockRepositoryContext模拟数据持久化上下文，避免依赖实际的Core Data栈，
/// 确保测试快速、可重复、无外部依赖。
///
/// ## 测试覆盖
/// - 查询根节点 (1个测试)
/// - 创建节点 (1个测试)
/// - 更新节点 (1个测试)
/// - 删除节点 (1个测试)
/// - 级联删除 (1个测试)
/// - 叶子值更新及级联计算 (1个测试)
/// - Cycle查询 (1个测试)
/// - 事务提交 (1个测试)
///
/// 总计: 8个测试方法
@MainActor
final class RepositoryTests: XCTestCase {

    // MARK: - Properties

    /// 被测系统（OKRRepository实例）
    private var sut: OKRRepository!

    /// 模拟数据上下文
    private var mockContext: MockRepositoryContext!

    /// 级联计算引擎
    private var engine: CascadeEngineProtocol!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockContext = MockRepositoryContext()
        engine = CascadeEngine()
        sut = OKRRepository(context: mockContext, engine: engine)
    }

    override func tearDown() {
        sut = nil
        engine = nil
        mockContext = nil
        super.tearDown()
    }

    // MARK: - 测试: 查询根节点

    /// 测试: fetchRootNodes应仅返回parentId为nil的根节点
    ///
    /// Arrange: 在MockContext中插入2个根节点和1个子节点
    /// Act: 调用fetchRootNodes
    /// Assert: 返回2个根节点，不包含子节点
    func test_fetchRootNodes_returnsOnlyRootNodes() {
        // Arrange
        let root1 = TestDataFactory.createEnterpriseRoot(
            title: "企业O1", owner: "CEO", children: []
        )
        let root2 = TestDataFactory.createEnterpriseRoot(
            title: "企业O2", owner: "CEO", children: []
        )
        let child = TestDataFactory.createLeafKR(
            title: "子KR", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        mockContext.insertNodes([root1, root2, child])

        // Act
        let roots = sut.fetchRootNodes()

        // Assert
        XCTAssertEqual(roots.count, 2, "应只返回2个根节点")
        XCTAssertTrue(roots.contains { $0.title == "企业O1" }, "应包含根节点1")
        XCTAssertTrue(roots.contains { $0.title == "企业O2" }, "应包含根节点2")
        XCTAssertFalse(roots.contains { $0.title == "子KR" }, "不应包含子节点")
    }

    // MARK: - 测试: 创建节点

    /// 测试: createNode应将节点持久化到存储
    ///
    /// Arrange: 一个待创建的OKRNode
    /// Act: 调用createNode
    /// Assert: 存储中包含该节点，且字段一致
    func test_createNode_persistsNode() {
        // Arrange
        let node = TestDataFactory.createLeafKR(
            title: "新创建的KR",
            current: 0,
            target: 100,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )

        // Act
        sut.createNode(node)

        // Assert
        let persisted = mockContext.fetchNode(byId: node.id)
        XCTAssertNotNil(persisted, "节点应被持久化")
        XCTAssertEqual(persisted?.title, "新创建的KR", "title应一致")
        XCTAssertEqual(persisted?.currentValue, 0, "currentValue应一致")
        XCTAssertEqual(persisted?.targetValue, 100, "targetValue应一致")
        XCTAssertEqual(persisted?.nodeType, .keyResult, "nodeType应一致")
        XCTAssertEqual(persisted?.ownerName, "Alice", "ownerName应一致")
    }

    // MARK: - 测试: 更新节点

    /// 测试: updateNode应更新指定节点的字段
    ///
    /// Arrange: 先创建节点，然后修改其字段
    /// Act: 调用updateNode
    /// Assert: 存储中的节点字段已更新
    func test_updateNode_updatesFields() {
        // Arrange
        let originalNode = TestDataFactory.createLeafKR(
            title: "原始标题",
            current: 20,
            target: 100,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )
        sut.createNode(originalNode)

        var updatedNode = originalNode
        updatedNode.title = "更新后的标题"
        updatedNode.currentValue = 50
        updatedNode.status = .completed

        // Act
        sut.updateNode(updatedNode)

        // Assert
        let persisted = mockContext.fetchNode(byId: originalNode.id)
        XCTAssertNotNil(persisted, "节点应存在")
        XCTAssertEqual(persisted?.title, "更新后的标题", "title应被更新")
        XCTAssertEqual(persisted?.currentValue, 50, "currentValue应被更新")
        XCTAssertEqual(persisted?.status, .completed, "status应被更新")
    }

    // MARK: - 测试: 删除节点

    /// 测试: deleteNode应从存储中移除指定节点
    ///
    /// Arrange: 创建一个节点并持久化
    /// Act: 调用deleteNode
    /// Assert: 存储中不再包含该节点
    func test_deleteNode_removesNode() {
        // Arrange
        let node = TestDataFactory.createLeafKR(
            title: "待删除的KR",
            current: 50,
            target: 100,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )
        sut.createNode(node)
        XCTAssertNotNil(mockContext.fetchNode(byId: node.id), "删除前应存在")

        // Act
        sut.deleteNode(node)

        // Assert
        XCTAssertNil(mockContext.fetchNode(byId: node.id), "删除后不应存在")
    }

    // MARK: - 测试: 级联删除

    /// 测试: deleteNode带级联标志应同时删除所有子节点
    ///
    /// Arrange: 创建一个父节点，包含两个子节点
    /// Act: 调用deleteNode(cascade: true)
    /// Assert: 父节点和子节点都被删除
    func test_deleteNode_withCascade_removesChildren() {
        // Arrange
        let child1 = TestDataFactory.createLeafKR(
            title: "子KR1", current: 20, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child2 = TestDataFactory.createLeafKR(
            title: "子KR2", current: 40, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "父O", owner: "Alice", scope: .personal, children: [child1, child2]
        )
        sut.createNode(parent)
        sut.createNode(child1)
        sut.createNode(child2)

        // Act
        sut.deleteNode(parent, cascade: true)

        // Assert
        XCTAssertNil(mockContext.fetchNode(byId: parent.id), "父节点应被删除")
        XCTAssertNil(mockContext.fetchNode(byId: child1.id), "子节点1应被级联删除")
        XCTAssertNil(mockContext.fetchNode(byId: child2.id), "子节点2应被级联删除")
    }

    // MARK: - 测试: 叶子值更新

    /// 测试: updateLeafValue应更新叶子currentValue并重新计算progress
    ///
    /// Arrange: 一个叶子节点(current=20, target=100)
    /// Act: 调用updateLeafValue更新为60
    /// Assert: currentValue=60, progress=60%
    func test_updateLeafValue_updatesProgress() {
        // Arrange
        let leaf = TestDataFactory.createLeafKR(
            title: "进度KR", current: 20, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        sut.createNode(leaf)

        // Act
        sut.updateLeafValue(nodeId: leaf.id, newValue: 60)

        // Assert
        let updated = mockContext.fetchNode(byId: leaf.id)
        XCTAssertNotNil(updated, "节点应存在")
        XCTAssertEqual(updated?.currentValue, 60, "currentValue应更新为60")
        XCTAssertEqual(updated?.progress, 60.0, accuracy: 0.001, "progress应重新计算为60%")
        XCTAssertEqual(updated?.status, .inProgress, "状态应为inProgress")
    }

    // MARK: - 测试: Cycle查询

    /// 测试: fetchCycles应返回所有已存储的Cycle
    ///
    /// Arrange: 预置3个Cycle
    /// Act: 调用fetchCycles
    /// Assert: 返回所有3个Cycle
    func test_fetchCycles_returnsAllCycles() {
        // Arrange
        let cycle1 = OKRCycle(id: UUID(), name: "2024 Q1", startDate: Date(), endDate: Date())
        let cycle2 = OKRCycle(id: UUID(), name: "2024 Q2", startDate: Date(), endDate: Date())
        let cycle3 = OKRCycle(id: UUID(), name: "2024 Q3", startDate: Date(), endDate: Date())
        mockContext.insertCycles([cycle1, cycle2, cycle3])

        // Act
        let cycles = sut.fetchCycles()

        // Assert
        XCTAssertEqual(cycles.count, 3, "应返回3个Cycle")
        XCTAssertTrue(cycles.contains { $0.name == "2024 Q1" }, "应包含2024 Q1")
        XCTAssertTrue(cycles.contains { $0.name == "2024 Q2" }, "应包含2024 Q2")
        XCTAssertTrue(cycles.contains { $0.name == "2024 Q3" }, "应包含2024 Q3")
    }

    // MARK: - 测试: 事务提交

    /// 测试: save应提交所有未保存的更改
    ///
    /// Arrange: 创建若干节点（未保存状态）
    /// Act: 调用save
    /// Assert: 所有更改被提交，save计数增加
    func test_save_commitsChanges() {
        // Arrange
        let node1 = TestDataFactory.createLeafKR(
            title: "KR1", current: 10, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let node2 = TestDataFactory.createLeafKR(
            title: "KR2", current: 20, target: 100, unit: "%", owner: "Bob", scope: .personal
        )
        sut.createNode(node1)
        sut.createNode(node2)
        XCTAssertEqual(mockContext.saveCount, 0, "保存前应无save记录")

        // Act
        sut.save()

        // Assert
        XCTAssertGreaterThanOrEqual(mockContext.saveCount, 1, "save应至少被调用1次")
        XCTAssertTrue(mockContext.hasUnsavedChanges == false, "保存后不应有未保存更改")
    }
}

// MARK: - Mock Types

/// 模拟的Repository上下文，用于测试
///
/// 在内存中存储OKRNode和OKRCycle，模拟Core Data的持久化行为。
/// 提供完整的CRUD操作和查询功能，无需实际数据库。
final class MockRepositoryContext: RepositoryContextProtocol {

    /// 内存中的节点存储 [ID: Node]
    private var nodes: [UUID: OKRNode] = [:]

    /// 内存中的Cycle存储 [ID: Cycle]
    private var cycles: [UUID: OKRCycle] = [:]

    /// save调用计数
    private(set) var saveCount: Int = 0

    /// 是否有未保存的更改
    private(set) var hasUnsavedChanges: Bool = false

    /// 插入选项标记 - 用于模拟事务状态
    private var pendingInsertions: [OKRNode] = []

    // MARK: - RepositoryContextProtocol

    func insert(_ node: OKRNode) {
        nodes[node.id] = node
        hasUnsavedChanges = true
        pendingInsertions.append(node)
    }

    func insert(_ cycle: OKRCycle) {
        cycles[cycle.id] = cycle
        hasUnsavedChanges = true
    }

    func delete(_ node: OKRNode) {
        nodes.removeValue(forKey: node.id)
        hasUnsavedChanges = true
    }

    func fetchNode(byId id: UUID) -> OKRNode? {
        nodes[id]
    }

    func fetchNodes(predicate: (OKRNode) -> Bool) -> [OKRNode] {
        nodes.values.filter(predicate)
    }

    func fetchAllCycles() -> [OKRCycle] {
        Array(cycles.values)
    }

    func save() {
        saveCount += 1
        hasUnsavedChanges = false
        pendingInsertions.removeAll()
    }

    // MARK: - Helper Methods

    /// 批量插入节点（用于测试数据准备）
    func insertNodes(_ nodesToInsert: [OKRNode]) {
        for node in nodesToInsert {
            nodes[node.id] = node
        }
    }

    /// 批量插入Cycle（用于测试数据准备）
    func insertCycles(_ cyclesToInsert: [OKRCycle]) {
        for cycle in cyclesToInsert {
            cycles[cycle.id] = cycle
        }
    }

    /// 清空所有数据
    func reset() {
        nodes.removeAll()
        cycles.removeAll()
        saveCount = 0
        hasUnsavedChanges = false
        pendingInsertions.removeAll()
    }
}

/// Repository上下文协议 - 定义数据操作接口
protocol RepositoryContextProtocol: Sendable {
    func insert(_ node: OKRNode)
    func insert(_ cycle: OKRCycle)
    func delete(_ node: OKRNode)
    func fetchNode(byId id: UUID) -> OKRNode?
    func fetchNodes(predicate: (OKRNode) -> Bool) -> [OKRNode]
    func fetchAllCycles() -> [OKRCycle]
    func save()
}

/// OKR Cycle模型 - OKR周期
struct OKRCycle: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
}

/// OKR仓库 - 负责所有OKR数据操作
final class OKRRepository: Sendable {
    private let context: RepositoryContextProtocol
    private let engine: CascadeEngineProtocol

    init(context: RepositoryContextProtocol, engine: CascadeEngineProtocol) {
        self.context = context
        self.engine = engine
    }

    /// 获取所有根节点（parentId为nil的节点）
    func fetchRootNodes() -> [OKRNode] {
        context.fetchNodes { $0.parentId == nil }
    }

    /// 创建新节点
    func createNode(_ node: OKRNode) {
        context.insert(node)
    }

    /// 更新节点
    func updateNode(_ node: OKRNode) {
        context.delete(node) // 先删除旧的
        context.insert(node) // 插入更新后的
    }

    /// 删除节点
    /// - Parameters:
    ///   - node: 要删除的节点
    ///   - cascade: 是否级联删除子节点
    func deleteNode(_ node: OKRNode, cascade: Bool = false) {
        if cascade {
            // 递归删除所有子节点
            for child in node.children {
                deleteNode(child, cascade: true)
            }
        }
        context.delete(node)
    }

    /// 更新叶子节点的值并重新计算progress
    func updateLeafValue(nodeId: UUID, newValue: Double) {
        guard var node = context.fetchNode(byId: nodeId) else { return }
        node.currentValue = max(0, newValue) // 确保非负
        let calculated = engine.calculateProgress(for: node)
        context.insert(calculated)
    }

    /// 获取所有Cycle
    func fetchCycles() -> [OKRCycle] {
        context.fetchAllCycles()
    }

    /// 保存所有未保存的更改
    func save() {
        context.save()
    }
}
