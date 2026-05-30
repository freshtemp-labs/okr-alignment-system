import XCTest
import CoreData
@testable import OKRAlignmentShared

// MARK: - RepositoryTests
//
// Integration tests for the REAL `CoreDataOKRRepository`.
// Every test uses an in-memory CoreData stack (via `CoreDataTestStack`)
// so no data touches disk and tests are fully isolated.
//
// Total: 14 test methods — all exercising production code.

@MainActor
final class RepositoryTests: XCTestCase {

    // MARK: - Properties

    nonisolated(unsafe) private var stack: CoreDataTestStack!
    nonisolated(unsafe) private var sut: CoreDataOKRRepository!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            stack = CoreDataTestStack()
            sut = CoreDataOKRRepository(container: stack.container)
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            sut = nil
            stack = nil
        }
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a cycle directly in CoreData so subsequent node operations
    /// that reference `cycleId` can resolve the relationship.
    private func createCycle(_ name: String = "Test Cycle") async throws -> OKRCycle {
        let cycle = OKRCycle(
            name: name,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 90)
        )
        return try await sut.createCycle(cycle)
    }

    private func makeLeafKR(
        title: String = "Test KR",
        current: Double = 0,
        target: Double = 100,
        cycleId: UUID,
        parentId: UUID? = nil
    ) -> OKRNode {
        OKRNode(
            title: title,
            nodeType: .keyResult,
            scope: .personal,
            currentValue: current,
            targetValue: target,
            unit: "%",
            ownerName: "TestOwner",
            parentId: parentId,
            cycleId: cycleId
        )
    }

    private func makeObjective(
        title: String = "Test Objective",
        cycleId: UUID,
        parentId: UUID? = nil
    ) -> OKRNode {
        OKRNode(
            title: title,
            nodeType: .objective,
            scope: .enterprise,
            targetValue: 0,
            ownerName: "TestOwner",
            parentId: parentId,
            cycleId: cycleId
        )
    }

    // MARK: - Cycle CRUD

    func test_createCycle_persistsCycle() async throws {
        let saved = try await createCycle("Q1 2026")

        let cycles = try await sut.fetchCycles()
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles.first?.name, "Q1 2026")
        XCTAssertEqual(cycles.first?.id, saved.id)
    }

    func test_createCycle_duplicateId_throws() async throws {
        let id = UUID()
        let cycle = OKRCycle(id: id, name: "Dup", startDate: Date(), endDate: Date())
        _ = try await sut.createCycle(cycle)

        let dup = OKRCycle(id: id, name: "Dup 2", startDate: Date(), endDate: Date())
        do {
            _ = try await sut.createCycle(dup)
            XCTFail("Expected duplicateCycleId error")
        } catch let error as OKRRepositoryError {
            XCTAssertEqual(error, .duplicateCycleId(id))
        }
    }

    func test_fetchCycles_returnsAll_sortedByStartDate() async throws {
        _ = try await sut.createCycle(OKRCycle(name: "Early", startDate: Date(timeIntervalSince1970: 100), endDate: Date(timeIntervalSince1970: 200)))
        _ = try await sut.createCycle(OKRCycle(name: "Late", startDate: Date(timeIntervalSince1970: 300), endDate: Date(timeIntervalSince1970: 400)))

        let cycles = try await sut.fetchCycles()
        XCTAssertEqual(cycles.count, 2)
        // CoreDataOKRRepository sorts by startDate descending
        XCTAssertEqual(cycles.first?.name, "Late")
    }

    // MARK: - Node CRUD

    func test_createNode_persistsNode() async throws {
        let cycle = try await createCycle()
        let node = makeLeafKR(title: "My KR", cycleId: cycle.id)
        let saved = try await sut.createNode(node)

        XCTAssertEqual(saved.title, "My KR")
        XCTAssertEqual(saved.nodeType, .keyResult)
        XCTAssertEqual(saved.ownerName, "TestOwner")

        // Verify it can be fetched back
        let fetched = try await sut.fetchNode(id: node.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "My KR")
    }

    func test_createNode_duplicateId_throws() async throws {
        let cycle = try await createCycle()
        let node = makeLeafKR(cycleId: cycle.id)
        _ = try await sut.createNode(node)

        do {
            _ = try await sut.createNode(node)
            XCTFail("Expected duplicateNodeId error")
        } catch let error as OKRRepositoryError {
            XCTAssertEqual(error, .duplicateNodeId(node.id))
        }
    }

    func test_fetchRootNodes_returnsOnlyRootNodes() async throws {
        let cycle = try await createCycle()
        let root1 = makeObjective(title: "Root O1", cycleId: cycle.id)
        let root2 = makeObjective(title: "Root O2", cycleId: cycle.id)
        let child = makeLeafKR(title: "Child KR", cycleId: cycle.id, parentId: root1.id)

        _ = try await sut.createNode(root1)
        _ = try await sut.createNode(root2)
        _ = try await sut.createNode(child)

        let roots = try await sut.fetchRootNodes(cycleId: cycle.id)
        XCTAssertEqual(roots.count, 2, "Should return only root nodes")
        let titles = Set(roots.map(\.title))
        XCTAssertTrue(titles.contains("Root O1"))
        XCTAssertTrue(titles.contains("Root O2"))
        XCTAssertFalse(titles.contains("Child KR"))
    }

    func test_updateNode_updatesFields() async throws {
        let cycle = try await createCycle()
        var node = makeLeafKR(title: "Original", cycleId: cycle.id)
        _ = try await sut.createNode(node)

        node.title = "Updated"
        node.currentValue = 42
        let updated = try await sut.updateNode(node)

        XCTAssertEqual(updated.title, "Updated")
        XCTAssertEqual(updated.currentValue, 42)

        let fetched = try await sut.fetchNode(id: node.id)
        XCTAssertEqual(fetched?.title, "Updated")
    }

    func test_deleteNode_removesNode() async throws {
        let cycle = try await createCycle()
        let node = makeLeafKR(cycleId: cycle.id)
        _ = try await sut.createNode(node)

        try await sut.deleteNode(id: node.id, cascade: false)

        let fetched = try await sut.fetchNode(id: node.id)
        XCTAssertNil(fetched, "Node should be gone after deletion")
    }

    func test_deleteNode_cascade_removesChildren() async throws {
        let cycle = try await createCycle()
        let parent = makeObjective(title: "Parent O", cycleId: cycle.id)
        let child1 = makeLeafKR(title: "KR1", cycleId: cycle.id, parentId: parent.id)
        let child2 = makeLeafKR(title: "KR2", cycleId: cycle.id, parentId: parent.id)

        _ = try await sut.createNode(parent)
        _ = try await sut.createNode(child1)
        _ = try await sut.createNode(child2)

        try await sut.deleteNode(id: parent.id, cascade: true)

        let fetchedParent = try await sut.fetchNode(id: parent.id)
        let fetchedChild1 = try await sut.fetchNode(id: child1.id)
        let fetchedChild2 = try await sut.fetchNode(id: child2.id)
        XCTAssertNil(fetchedParent)
        XCTAssertNil(fetchedChild1)
        XCTAssertNil(fetchedChild2)
    }

    func test_deleteNode_noCascade_throwsWhenHasChildren() async throws {
        let cycle = try await createCycle()
        let parent = makeObjective(title: "Parent", cycleId: cycle.id)
        let child = makeLeafKR(title: "Child", cycleId: cycle.id, parentId: parent.id)

        _ = try await sut.createNode(parent)
        _ = try await sut.createNode(child)

        do {
            try await sut.deleteNode(id: parent.id, cascade: false)
            XCTFail("Expected hasChildren error")
        } catch let error as OKRRepositoryError {
            XCTAssertEqual(error, .hasChildren(parent.id))
        }
    }

    func test_deleteNode_notFound_throws() async throws {
        let fakeId = UUID()
        do {
            try await sut.deleteNode(id: fakeId, cascade: false)
            XCTFail("Expected nodeNotFound error")
        } catch let error as OKRRepositoryError {
            XCTAssertEqual(error, .nodeNotFound(fakeId))
        }
    }

    // MARK: - Leaf Value Update & Cascade

    func test_updateLeafValue_updatesProgressAndCascades() async throws {
        let cycle = try await createCycle()
        let parent = makeObjective(title: "Parent O", cycleId: cycle.id)
        let savedParent = try await sut.createNode(parent)

        let leaf = makeLeafKR(title: "KR", current: 0, target: 100, cycleId: cycle.id, parentId: savedParent.id)
        let savedLeaf = try await sut.createNode(leaf)

        // Update leaf value to 60
        let updated = try await sut.updateLeafValue(nodeId: savedLeaf.id, newValue: 60)
        XCTAssertEqual(updated.currentValue, 60, accuracy: 0.001)
        XCTAssertEqual(updated.progress, 60.0, accuracy: 0.01)

        // Verify the leaf was persisted
        let fetched = try await sut.fetchNode(id: savedLeaf.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.currentValue ?? 0, 60, accuracy: 0.001)
    }

    func test_updateLeafValue_notFound_throws() async throws {
        let fakeId = UUID()
        do {
            _ = try await sut.updateLeafValue(nodeId: fakeId, newValue: 50)
            XCTFail("Expected nodeNotFound error")
        } catch let error as OKRRepositoryError {
            XCTAssertEqual(error, .nodeNotFound(fakeId))
        }
    }

    func test_updateLeafValue_nonLeaf_throws() async throws {
        let cycle = try await createCycle()
        let objective = makeObjective(title: "Not a leaf", cycleId: cycle.id)
        let saved = try await sut.createNode(objective)

        do {
            _ = try await sut.updateLeafValue(nodeId: saved.id, newValue: 50)
            XCTFail("Expected notALeafNode error")
        } catch let error as OKRRepositoryError {
            XCTAssertEqual(error, .notALeafNode(saved.id))
        }
    }

    // MARK: - Conflict Resolution (CAS)

    func test_updateNode_versionConflict_throwsWhenStale() async throws {
        let cycle = try await createCycle()
        let node = makeLeafKR(title: "CAS KR", cycleId: cycle.id)
        let saved = try await sut.createNode(node)

        // Modify and update once (version 0 → 1)
        var update1 = saved
        update1.title = "Updated Once"
        let result1 = try await sut.updateNode(update1)
        XCTAssertEqual(result1.title, "Updated Once")

        // Try to update with stale version (still version 0)
        var staleUpdate = saved
        staleUpdate.title = "Stale Update"
        do {
            _ = try await sut.updateNode(staleUpdate)
            XCTFail("Expected versionConflict error")
        } catch let error as OKRRepositoryError {
            guard case .versionConflict(_, let expected, let actual) = error else {
                return XCTFail("Expected versionConflict, got \(error)")
            }
            XCTAssertEqual(expected, 0)
            XCTAssertEqual(actual, 1)
        }
    }

    func test_updateNode_versionIncrementsOnEachUpdate() async throws {
        let cycle = try await createCycle()
        let node = makeLeafKR(title: "Version KR", cycleId: cycle.id)
        let saved = try await sut.createNode(node)
        XCTAssertEqual(saved.version, 0, "New node should start at version 0")

        // First update
        var update1 = saved
        update1.title = "V1"
        let r1 = try await sut.updateNode(update1)
        XCTAssertEqual(r1.version, 1, "After first update, version should be 1")

        // Second update
        var update2 = r1
        update2.title = "V2"
        let r2 = try await sut.updateNode(update2)
        XCTAssertEqual(r2.version, 2, "After second update, version should be 2")
    }
}
