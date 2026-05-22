import XCTest
import CoreData
@testable import OKRAlignmentShared

// MARK: - ViewModelTests
//
// Integration tests for the REAL ViewModels (`TreeViewModel`, `NodeEditViewModel`,
// `CycleListViewModel`) backed by a real `CoreDataOKRRepository` on an in-memory
// store and a real `OKRCascadeEngine`.
//
// Total: 15 test methods — all exercising production ViewModel + Repository code.

@MainActor
final class ViewModelTests: XCTestCase {

    // MARK: - Properties

    private var stack: CoreDataTestStack!
    private var repository: CoreDataOKRRepository!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        stack = CoreDataTestStack()
        repository = CoreDataOKRRepository(container: stack.container)
    }

    override func tearDown() {
        repository = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Seeds the repository with a cycle and a small OKR tree, then returns the cycle.
    @discardableResult
    private func seedTree() async throws -> (cycle: OKRCycle, root: OKRNode, leaf1: OKRNode, leaf2: OKRNode) {
        let cycle = try await repository.createCycle(
            OKRCycle(name: "Test Cycle", startDate: Date(timeIntervalSince1970: 1_700_000_000), endDate: Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 90))
        )

        let root = try await repository.createNode(OKRNode(
            title: "Enterprise O",
            nodeType: .objective,
            scope: .enterprise,
            targetValue: 0,
            ownerName: "CEO",
            cycleId: cycle.id
        ))

        let leaf1 = try await repository.createNode(OKRNode(
            title: "KR1",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 20,
            targetValue: 100,
            unit: "%",
            ownerName: "Alice",
            parentId: root.id,
            cycleId: cycle.id
        ))

        let leaf2 = try await repository.createNode(OKRNode(
            title: "KR2",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 60,
            targetValue: 100,
            unit: "%",
            ownerName: "Bob",
            parentId: root.id,
            cycleId: cycle.id
        ))

        try await repository.save()
        return (cycle, root, leaf1, leaf2)
    }

    // MARK: - TreeViewModel Tests

    func test_loadTree_setsRootNode() async throws {
        let (cycle, _, _, _) = try await seedTree()

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        XCTAssertNotNil(vm.rootNode, "rootNode should be set after loadTree")
        XCTAssertEqual(vm.rootNode?.title, "Enterprise O")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadTree_nilWhenEmpty() async throws {
        let cycle = try await repository.createCycle(
            OKRCycle(name: "Empty", startDate: Date(), endDate: Date())
        )

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        XCTAssertNil(vm.rootNode, "rootNode should be nil when no data exists")
    }

    func test_loadTree_calculatesCascadeProgress() async throws {
        let (cycle, root, _, _) = try await seedTree()

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        // root has 2 children: KR1 (20/100=20%) and KR2 (60/100=60%)
        // Expected root progress: (20+60)/2 = 40%
        XCTAssertEqual(vm.rootNode?.progress, 40.0, accuracy: 0.5,
            "Root progress should be the average of children")
    }

    func test_findNode_locatesChild() async throws {
        let (cycle, _, leaf1, _) = try await seedTree()

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        let found = vm.findNode(in: vm.rootNode!, id: leaf1.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "KR1")
    }

    func test_totalNodeCount_countsAll() async throws {
        let (cycle, _, _, _) = try await seedTree()

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        let count = vm.totalNodeCount(in: vm.rootNode!)
        // root + 2 children = 3
        XCTAssertEqual(count, 3)
    }

    func test_leafNodeCount_countsLeaves() async throws {
        let (cycle, _, _, _) = try await seedTree()

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        let leaves = vm.leafNodeCount(in: vm.rootNode!)
        XCTAssertEqual(leaves, 2, "Should count 2 leaf KRs")
    }

    func test_allLeafNodes_returnsLeaves() async throws {
        let (cycle, _, _, _) = try await seedTree()

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        let leaves = vm.allLeafNodes(in: vm.rootNode!)
        XCTAssertEqual(leaves.count, 2)
        XCTAssertTrue(leaves.contains { $0.title == "KR1" })
        XCTAssertTrue(leaves.contains { $0.title == "KR2" })
    }

    func test_overallProgress_matchesRoot() async throws {
        let (cycle, _, _, _) = try await seedTree()

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        XCTAssertNotNil(vm.overallProgress)
        XCTAssertEqual(vm.overallProgress, vm.rootNode?.progress)
    }

    func test_deleteNode_removesFromTree() async throws {
        let (cycle, _, leaf1, _) = try await seedTree()

        let vm = TreeViewModel(repository: repository)
        await vm.loadTree(cycleId: cycle.id)

        XCTAssertEqual(vm.rootNode?.children.count, 2)

        await vm.deleteNode(id: leaf1.id, cascade: true)

        XCTAssertNil(vm.errorMessage, "Delete should not produce an error")
        // After deletion + reload, the tree should have 1 child left
        XCTAssertEqual(vm.rootNode?.children.count, 1)
    }

    // MARK: - NodeEditViewModel Tests

    func test_validate_validNode_returnsTrue() async throws {
        let (_, _, leaf, _) = try await seedTree()

        let vm = NodeEditViewModel(node: leaf, repository: repository)
        let result = vm.validate()

        XCTAssertTrue(result, "Valid leaf node should pass validation")
        XCTAssertTrue(vm.validationErrors.isEmpty)
    }

    func test_validate_emptyTitle_returnsFalse() async throws {
        var node = OKRNode(
            title: "",
            nodeType: .keyResult,
            scope: .personal,
            targetValue: 100,
            ownerName: "Alice",
            cycleId: UUID()
        )

        let vm = NodeEditViewModel(node: node, repository: repository)
        let result = vm.validate()

        XCTAssertFalse(result, "Empty title should fail validation")
        XCTAssertTrue(vm.validationErrors.contains(.emptyTitle))
    }

    func test_validate_cycleNotSet_returnsFalse() {
        let node = OKRNode(
            title: "No Cycle",
            nodeType: .objective,
            scope: .enterprise,
            targetValue: 0,
            ownerName: "Alice"
            // cycleId defaults to nil
        )

        let vm = NodeEditViewModel(node: node, repository: repository)
        let result = vm.validate()

        XCTAssertFalse(result)
        XCTAssertTrue(vm.validationErrors.contains(.cycleNotSet))
    }

    func test_validateField_title_empty() {
        let node = OKRNode(
            title: "  ",
            nodeType: .objective,
            scope: .enterprise,
            targetValue: 0,
            ownerName: "Alice",
            cycleId: UUID()
        )
        let vm = NodeEditViewModel(node: node, repository: repository)

        let error = vm.validateField("title")
        XCTAssertEqual(error, .emptyTitle)
    }

    func test_validateField_targetValue_invalid() {
        // Create a leaf KR with targetValue <= 0
        let node = OKRNode(
            title: "Bad KR",
            nodeType: .keyResult,
            scope: .personal,
            targetValue: 0,
            ownerName: "Alice",
            cycleId: UUID()
        )
        let vm = NodeEditViewModel(node: node, repository: repository)

        let error = vm.validateField("targetValue")
        XCTAssertEqual(error, .invalidTargetValue)
    }

    func test_save_createsNewNode() async throws {
        let cycle = try await repository.createCycle(
            OKRCycle(name: "Save Cycle", startDate: Date(), endDate: Date())
        )

        let newNode = OKRNode(
            title: "Brand New KR",
            nodeType: .keyResult,
            scope: .personal,
            targetValue: 100,
            unit: "%",
            ownerName: "Alice",
            cycleId: cycle.id
            // createdAt defaults to Date() → isNewNode == true
        )

        let vm = NodeEditViewModel(node: newNode, repository: repository)
        let saved = try await vm.save()

        XCTAssertEqual(saved.title, "Brand New KR")

        // Verify persisted in repository
        let fetched = try await repository.fetchNode(id: saved.id)
        XCTAssertNotNil(fetched, "Saved node should be fetchable from repository")
        XCTAssertEqual(fetched?.title, "Brand New KR")
    }
}

// MARK: - CycleListViewModel Tests

@MainActor
final class CycleListViewModelTests: XCTestCase {

    private var stack: CoreDataTestStack!
    private var repository: CoreDataOKRRepository!

    override func setUp() {
        super.setUp()
        stack = CoreDataTestStack()
        repository = CoreDataOKRRepository(container: stack.container)
    }

    override func tearDown() {
        repository = nil
        stack = nil
        super.tearDown()
    }

    func test_loadCycles_setsCycles() async throws {
        _ = try await repository.createCycle(OKRCycle(name: "C1", startDate: Date(timeIntervalSince1970: 100), endDate: Date(timeIntervalSince1970: 200)))
        _ = try await repository.createCycle(OKRCycle(name: "C2", startDate: Date(timeIntervalSince1970: 300), endDate: Date(timeIntervalSince1970: 400)))

        let vm = CycleListViewModel(repository: repository)
        await vm.loadCycles()

        XCTAssertEqual(vm.cycles.count, 2)
        XCTAssertTrue(vm.cycles.contains { $0.name == "C1" })
        XCTAssertTrue(vm.cycles.contains { $0.name == "C2" })
        XCTAssertFalse(vm.isLoading)
    }

    func test_loadCycles_emptyWhenNoData() async throws {
        let vm = CycleListViewModel(repository: repository)
        await vm.loadCycles()

        XCTAssertTrue(vm.cycles.isEmpty)
        XCTAssertFalse(vm.hasCycles)
    }

    func test_selectCycle_updatesSelection() async throws {
        let cycle = try await repository.createCycle(OKRCycle(name: "Selectable", startDate: Date(), endDate: Date()))

        let vm = CycleListViewModel(repository: repository)
        await vm.loadCycles()

        XCTAssertNil(vm.selectedCycle, "Nothing selected initially")

        vm.selectCycle(cycle)
        XCTAssertEqual(vm.selectedCycle?.id, cycle.id)
        XCTAssertEqual(vm.selectedCycleName, "Selectable")
    }

    func test_createCycle_addsToList() async throws {
        let vm = CycleListViewModel(repository: repository)

        try await vm.createCycle(
            name: "Brand New",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(vm.cycles.count, 1)
        XCTAssertEqual(vm.cycles.first?.name, "Brand New")
        XCTAssertEqual(vm.selectedCycle?.name, "Brand New")
    }

    func test_createCycle_emptyName_throws() async throws {
        let vm = CycleListViewModel(repository: repository)

        do {
            try await vm.createCycle(name: "  ", startDate: Date(), endDate: Date())
            XCTFail("Expected emptyName error")
        } catch let error as CycleValidationError {
            XCTAssertEqual(error, .emptyName)
        }
    }

    func test_createCycle_invalidDateRange_throws() async throws {
        let vm = CycleListViewModel(repository: repository)

        do {
            try await vm.createCycle(
                name: "Bad Dates",
                startDate: Date(timeIntervalSince1970: 2_000),
                endDate: Date(timeIntervalSince1970: 1_000)
            )
            XCTFail("Expected invalidDateRange error")
        } catch let error as CycleValidationError {
            XCTAssertEqual(error, .invalidDateRange)
        }
    }

    func test_deselectCycle_clearsSelection() async throws {
        _ = try await repository.createCycle(OKRCycle(name: "C", startDate: Date(), endDate: Date()))

        let vm = CycleListViewModel(repository: repository)
        await vm.loadCycles()
        vm.selectCycle(vm.cycles.first)
        XCTAssertNotNil(vm.selectedCycle)

        vm.deselectCycle()
        XCTAssertNil(vm.selectedCycle)
    }
}
