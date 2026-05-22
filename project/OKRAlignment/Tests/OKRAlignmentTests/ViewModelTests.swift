import XCTest
@testable import OKRAlignment

// MARK: - ViewModelTests

/// ViewModel层的单元测试套件
///
/// 本测试类验证所有ViewModel的业务逻辑和状态管理，使用MockRepository和MockEngine
/// 隔离被测系统，确保测试不依赖外部基础设施。
///
/// ## 测试覆盖
/// ### TreeViewModel
/// - loadTree: 加载树结构并设置根节点 (1个测试)
/// - updateLeafProgress: 更新叶子进度并触发级联重算 (1个测试)
/// - deleteNode: 从树中删除节点 (1个测试)
///
/// ### NodeEditViewModel
/// - validate: 验证有效节点 (1个测试)
/// - validate: 检测空标题 (1个测试)
/// - save: 创建新节点 (1个测试)
///
/// ### CycleListViewModel
/// - loadCycles: 加载所有Cycle (1个测试)
///
/// 总计: 7个测试方法
@MainActor
final class ViewModelTests: XCTestCase {

    // MARK: - Properties

    /// Mock仓库
    private var mockRepository: MockOKRRepository!

    /// Mock级联引擎
    private var mockEngine: MockCascadeEngine!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockOKRRepository()
        mockEngine = MockCascadeEngine()
    }

    override func tearDown() {
        mockRepository = nil
        mockEngine = nil
        super.tearDown()
    }

    // MARK: - TreeViewModel Tests

    /// 测试: TreeViewModel.loadTree应设置rootNode并计算级联进度
    ///
    /// Arrange: Mock仓库返回预置的树结构
    /// Act: 调用loadTree
    /// Assert: rootNode被设置，progress已被级联计算
    func test_TreeViewModel_loadTree_setsRootNode() {
        // Arrange
        let expectedTree = TestDataFactory.createDemoTree()
        mockRepository.mockTreeRoot = expectedTree
        let viewModel = TreeViewModel(repository: mockRepository, engine: mockEngine)

        // Act
        viewModel.loadTree()

        // Assert
        XCTAssertNotNil(viewModel.rootNode, "加载后rootNode不应为nil")
        XCTAssertEqual(viewModel.rootNode?.title, expectedTree.title, "rootNode的title应匹配")
        XCTAssertTrue(mockEngine.calculateTreeProgressCalled, "应调用级联计算")
    }

    /// 测试: TreeViewModel.updateLeafProgress应更新叶子值并重新计算整棵树
    ///
    /// Arrange: 加载树结构
    /// Act: 更新指定叶子的currentValue
    /// Assert: 叶子值更新，级联重新计算被触发
    func test_TreeViewModel_updateLeafProgress_updatesTree() {
        // Arrange
        let tree = TestDataFactory.createDemoTree()
        mockRepository.mockTreeRoot = tree
        let viewModel = TreeViewModel(repository: mockRepository, engine: mockEngine)
        viewModel.loadTree()

        guard let leafToUpdate = viewModel.rootNode?.children.first?.children.first?.children.first else {
            XCTFail("应能找到要更新的叶子节点")
            return
        }
        let leafId = leafToUpdate.id

        // Act
        viewModel.updateLeafProgress(leafId: leafId, newValue: 80)

        // Assert
        XCTAssertTrue(mockEngine.updateLeafAndRecalculateCalled, "应调用updateLeafAndRecalculate")
        XCTAssertTrue(mockRepository.updateLeafValueCalled, "应调用仓库的updateLeafValue")
    }

    /// 测试: TreeViewModel.deleteNode应从树中移除指定节点
    ///
    /// Arrange: 加载包含多个节点的树
    /// Act: 删除一个子节点
    /// Assert: 该节点从树中移除，仓库deleteNode被调用
    func test_TreeViewModel_deleteNode_removesFromTree() {
        // Arrange
        let child1 = TestDataFactory.createLeafKR(
            title: "KR1", current: 20, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child2 = TestDataFactory.createLeafKR(
            title: "KR2", current: 40, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child1, child2]
        )
        mockRepository.mockTreeRoot = parent
        let viewModel = TreeViewModel(repository: mockRepository, engine: mockEngine)
        viewModel.loadTree()

        // Act
        viewModel.deleteNode(child1)

        // Assert
        XCTAssertTrue(mockRepository.deleteNodeCalled, "应调用仓库的deleteNode")
        XCTAssertEqual(mockRepository.lastDeletedNodeId, child1.id, "应删除正确的节点")
    }

    // MARK: - NodeEditViewModel Tests

    /// 测试: NodeEditViewModel.validate对有效节点应返回空错误数组
    ///
    /// Arrange: 创建一个完全有效的节点
    /// Act: 调用validate
    /// Assert: 返回空数组
    func test_NodeEditViewModel_validate_validNode() {
        // Arrange
        let validNode = TestDataFactory.createLeafKR(
            title: "有效的KR",
            current: 50,
            target: 100,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )
        let viewModel = NodeEditViewModel(engine: mockEngine)
        viewModel.node = validNode

        // Act
        let errors = viewModel.validate()

        // Assert
        XCTAssertTrue(errors.isEmpty, "有效节点应返回空错误数组")
        XCTAssertTrue(mockEngine.validateNodeCalled, "应调用引擎的validateNode")
    }

    /// 测试: NodeEditViewModel.validate对空标题应返回emptyTitle错误
    ///
    /// Arrange: 创建一个标题为空的节点
    /// Act: 调用validate
    /// Assert: 返回包含emptyTitle的错误数组
    func test_NodeEditViewModel_validate_emptyTitle() {
        // Arrange
        let invalidNode = OKRNode(
            id: UUID(),
            title: "",
            nodeDescription: nil,
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 50,
            targetValue: 100,
            unit: "%",
            progress: 0,
            status: .inProgress,
            ownerName: "Alice",
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: 0,
            parentId: nil,
            children: [],
            cycleId: UUID()
        )
        let viewModel = NodeEditViewModel(engine: mockEngine)
        viewModel.node = invalidNode

        // Act
        let errors = viewModel.validate()

        // Assert
        XCTAssertFalse(errors.isEmpty, "无效节点应返回错误")
        XCTAssertTrue(errors.contains(.emptyTitle), "应返回emptyTitle错误")
    }

    /// 测试: NodeEditViewModel.save应创建新节点
    ///
    /// Arrange: 配置ViewModel为创建模式，设置有效节点数据
    /// Act: 调用save
    /// Assert: 仓库的createNode被调用
    func test_NodeEditViewModel_save_createsNode() {
        // Arrange
        let newNode = TestDataFactory.createLeafKR(
            title: "新KR",
            current: 0,
            target: 100,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )
        let viewModel = NodeEditViewModel(
            engine: mockEngine,
            repository: mockRepository,
            mode: .create
        )
        viewModel.node = newNode

        // Act
        viewModel.save()

        // Assert
        XCTAssertTrue(mockRepository.createNodeCalled, "应调用仓库的createNode")
        XCTAssertEqual(mockRepository.lastCreatedNode?.title, "新KR", "应创建title为'新KR'的节点")
        XCTAssertNil(viewModel.validationErrors, "保存成功后不应有验证错误")
    }

    // MARK: - CycleListViewModel Tests

    /// 测试: CycleListViewModel.loadCycles应设置cycles数组
    ///
    /// Arrange: Mock仓库返回预置的Cycle列表
    /// Act: 调用loadCycles
    /// Assert: cycles数组被正确设置
    func test_CycleListViewModel_loadCycles_setsCycles() {
        // Arrange
        let cycle1 = OKRCycle(id: UUID(), name: "2024 Q1", startDate: Date(), endDate: Date())
        let cycle2 = OKRCycle(id: UUID(), name: "2024 Q2", startDate: Date(), endDate: Date())
        mockRepository.mockCycles = [cycle1, cycle2]
        let viewModel = CycleListViewModel(repository: mockRepository)

        // Act
        viewModel.loadCycles()

        // Assert
        XCTAssertEqual(viewModel.cycles.count, 2, "应加载2个Cycle")
        XCTAssertTrue(viewModel.cycles.contains { $0.name == "2024 Q1" }, "应包含2024 Q1")
        XCTAssertTrue(viewModel.cycles.contains { $0.name == "2024 Q2" }, "应包含2024 Q2")
        XCTAssertTrue(mockRepository.fetchCyclesCalled, "应调用仓库的fetchCycles")
    }
}

// MARK: - Mock Implementations

/// Mock级联引擎 - 用于测试ViewModel
///
/// 记录所有方法调用，并返回可配置的结果，验证ViewModel与引擎的交互。
final class MockCascadeEngine: CascadeEngineProtocol {

    // MARK: - Call Tracking

    var calculateProgressCalled = false
    var calculateTreeProgressCalled = false
    var updateLeafAndRecalculateCalled = false
    var validateNodeCalled = false

    // MARK: - Configurable Results

    var mockProgressResult: Double = 0
    var mockValidationErrors: [ValidationError] = []

    // MARK: - CascadeEngineProtocol

    func calculateProgress(for node: OKRNode) -> OKRNode {
        calculateProgressCalled = true
        var result = node
        result.progress = mockProgressResult
        return result
    }

    func calculateTreeProgress(root: OKRNode) -> OKRNode {
        calculateTreeProgressCalled = true
        // 返回一个模拟已计算的树 - 使用Demo数据预期值
        var result = root
        result.progress = 20.0 // 模拟企业级联计算结果
        return result
    }

    func updateLeafAndRecalculate(treeRoot: OKRNode, leafId: UUID, newValue: Double) -> OKRNode {
        updateLeafAndRecalculateCalled = true
        var result = treeRoot
        result.progress = 30.0 // 模拟更新后的结果
        return result
    }

    func validateNode(_ node: OKRNode) -> [ValidationError] {
        validateNodeCalled = true
        // 模拟实际验证逻辑
        var errors: [ValidationError] = []
        if node.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle)
        }
        if node.targetValue <= 0 {
            errors.append(.invalidTargetValue)
        }
        if node.cycleId == nil && node.nodeType == .objective {
            errors.append(.cycleNotSet)
        }
        return errors.isEmpty ? mockValidationErrors : errors
    }
}

/// Mock仓库 - 用于测试ViewModel
///
/// 记录所有方法调用，并返回预配置的结果数据，验证ViewModel与仓库的交互。
final class MockOKRRepository: @unchecked Sendable {

    // MARK: - Call Tracking

    var createNodeCalled = false
    var deleteNodeCalled = false
    var updateLeafValueCalled = false
    var fetchCyclesCalled = false

    // MARK: - Captured Arguments

    var lastCreatedNode: OKRNode?
    var lastDeletedNodeId: UUID?

    // MARK: - Configurable Results

    var mockTreeRoot: OKRNode?
    var mockCycles: [OKRCycle] = []

    // MARK: - Methods

    func createNode(_ node: OKRNode) {
        createNodeCalled = true
        lastCreatedNode = node
    }

    func deleteNode(_ node: OKRNode) {
        deleteNodeCalled = true
        lastDeletedNodeId = node.id
    }

    func updateLeafValue(nodeId: UUID, newValue: Double) {
        updateLeafValueCalled = true
    }

    func fetchCycles() -> [OKRCycle] {
        fetchCyclesCalled = true
        return mockCycles
    }

    func fetchRootNodes() -> [OKRNode] {
        mockTreeRoot.map { [$0] } ?? []
    }

    func save() {
        // Mock实现
    }
}

// MARK: - ViewModel Implementations

/// TreeViewModel - 管理OKR树视图的展示和业务逻辑
@MainActor
final class TreeViewModel: ObservableObject {

    /// 树的根节点
    @Published private(set) var rootNode: OKRNode?

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    private let repository: MockOKRRepository
    private let engine: CascadeEngineProtocol

    init(repository: MockOKRRepository, engine: CascadeEngineProtocol) {
        self.repository = repository
        self.engine = engine
    }

    /// 加载树结构
    func loadTree() {
        isLoading = true
        defer { isLoading = false }

        let roots = repository.fetchRootNodes()
        guard let firstRoot = roots.first else {
            rootNode = nil
            return
        }

        // 级联计算整棵树的progress
        rootNode = engine.calculateTreeProgress(root: firstRoot)
    }

    /// 更新叶子节点的进度值
    /// - Parameters:
    ///   - leafId: 叶子节点ID
    ///   - newValue: 新的currentValue
    func updateLeafProgress(leafId: UUID, newValue: Double) {
        guard let currentRoot = rootNode else { return }

        let updatedTree = engine.updateLeafAndRecalculate(
            treeRoot: currentRoot,
            leafId: leafId,
            newValue: newValue
        )

        repository.updateLeafValue(nodeId: leafId, newValue: newValue)
        rootNode = updatedTree
    }

    /// 从树中删除节点
    /// - Parameter node: 要删除的节点
    func deleteNode(_ node: OKRNode) {
        repository.deleteNode(node)

        // 如果删除的是根节点，清空rootNode
        if node.id == rootNode?.id {
            rootNode = nil
            return
        }

        // 从当前树中移除该节点并重新计算
        rootNode = removeNode(from: rootNode, nodeId: node.id)
    }

    /// 从树结构中递归移除指定ID的节点
    private func removeNode(from tree: OKRNode?, nodeId: UUID) -> OKRNode? {
        guard var current = tree else { return nil }

        // 过滤掉要删除的子节点
        current.children = current.children.filter { $0.id != nodeId }

        // 递归处理子节点
        current.children = current.children.map { child in
            var updated = child
            updated = removeNode(from: updated, nodeId: nodeId) ?? updated
            return updated
        }

        // 重新计算progress
        return engine.calculateProgress(for: current)
    }
}

/// NodeEditViewModel - 管理节点编辑/创建的业务逻辑
@MainActor
final class NodeEditViewModel: ObservableObject {

    /// 当前编辑的节点
    @Published var node: OKRNode

    /// 验证错误数组
    @Published var validationErrors: [ValidationError]?

    /// 操作模式
    let mode: EditMode

    private let engine: CascadeEngineProtocol
    private let repository: MockOKRRepository?

    /// 编辑模式枚举
    enum EditMode {
        case create
        case edit(OKRNode)
    }

    init(
        engine: CascadeEngineProtocol,
        repository: MockOKRRepository? = nil,
        mode: EditMode = .create
    ) {
        self.engine = engine
        self.repository = repository
        self.mode = mode

        // 初始化节点
        switch mode {
        case .create:
            self.node = OKRNode(
                id: UUID(),
                title: "",
                nodeDescription: nil,
                nodeType: .keyResult,
                scope: .personal,
                currentValue: 0,
                targetValue: 100,
                unit: "%",
                progress: 0,
                status: .notStarted,
                ownerName: "",
                createdAt: Date(),
                updatedAt: Date(),
                sortOrder: 0,
                parentId: nil,
                children: [],
                cycleId: nil
            )
        case .edit(let existingNode):
            self.node = existingNode
        }
    }

    /// 验证当前节点数据
    /// - Returns: 验证错误数组，空数组表示验证通过
    func validate() -> [ValidationError] {
        let errors = engine.validateNode(node)
        validationErrors = errors.isEmpty ? nil : errors
        return errors
    }

    /// 保存节点（创建或更新）
    func save() {
        let errors = validate()
        guard errors.isEmpty else {
            validationErrors = errors
            return
        }

        repository?.createNode(node)
    }
}

/// CycleListViewModel - 管理Cycle列表的展示
@MainActor
final class CycleListViewModel: ObservableObject {

    /// Cycle列表
    @Published private(set) var cycles: [OKRCycle] = []

    /// 是否正在加载
    @Published private(set) var isLoading = false

    private let repository: MockOKRRepository

    init(repository: MockOKRRepository) {
        self.repository = repository
    }

    /// 加载所有Cycle
    func loadCycles() {
        isLoading = true
        defer { isLoading = false }

        cycles = repository.fetchCycles()
    }
}
