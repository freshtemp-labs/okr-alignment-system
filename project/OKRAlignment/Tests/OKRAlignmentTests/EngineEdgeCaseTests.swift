import XCTest
@testable import OKRAlignmentShared

// MARK: - EngineEdgeCaseTests
//
// Edge cases for CascadeEngine (NaN, infinity, extreme values, mixed trees)
// and NodeValidator (validateCycle, validateBatch, delete warnings, etc.)

@MainActor
final class EngineEdgeCaseTests: XCTestCase {

    nonisolated(unsafe) private var sut: CascadeEngineProtocol!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            sut = OKRCascadeEngine()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            sut = nil
        }
        super.tearDown()
    }

    // MARK: - NaN / Infinity Edge Cases

    func test_calculateProgress_withNaN_currentValue_returnsZero() {
        let node = OKRNode(title: "NaN KR", nodeType: .keyResult, scope: .personal,
                           currentValue: Double.nan, targetValue: 100, ownerName: "A")
        let result = sut.calculateProgress(for: node)
        // NaN comparisons always return false, so the calculation will produce NaN
        // which then gets clamped to 0 by min(max(_,0),100)
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001)
    }

    func test_calculateProgress_withInfinity_currentValue_returns100() {
        let node = OKRNode(title: "Inf KR", nodeType: .keyResult, scope: .personal,
                           currentValue: Double.infinity, targetValue: 100, ownerName: "A")
        let result = sut.calculateProgress(for: node)
        // currentValue / targetValue * 100 = inf → clamped to 100
        XCTAssertEqual(result.progress, 100.0, accuracy: 0.001)
    }

    func test_calculateProgress_withInfinity_targetValue_returnsZero() {
        let node = OKRNode(title: "Inf Tgt", nodeType: .keyResult, scope: .personal,
                           currentValue: 50, targetValue: Double.infinity, ownerName: "A")
        let result = sut.calculateProgress(for: node)
        // 50 / inf * 100 = 0
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001)
    }

    func test_calculateProgress_withNegativeInfinity_currentValue_returnsZero() {
        let node = OKRNode(title: "NegInf KR", nodeType: .keyResult, scope: .personal,
                           currentValue: -Double.infinity, targetValue: 100, ownerName: "A")
        let result = sut.calculateProgress(for: node)
        // -inf / 100 * 100 = -inf → clamped to 0
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001)
    }

    func test_updateLeafAndRecalculate_withExtremeValue_doesNotCrash() {
        let leaf = TestDataFactory.createLeafKR(title: "Extreme", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let parent = TestDataFactory.createObjective(title: "P", owner: "A", scope: .personal, children: [leaf])
        // Update with Double.greatestFiniteMagnitude — should clamp to targetValue
        let result = sut.updateLeafAndRecalculate(treeRoot: parent, leafId: leaf.id, newValue: Double.greatestFiniteMagnitude)
        XCTAssertEqual(result.children[0].progress, 100.0, accuracy: 0.001)
        XCTAssertEqual(result.children[0].currentValue, 100.0, accuracy: 0.001)
    }

    func test_updateLeafAndRecalculate_withLargeNegativeValue_returnsZero() {
        let leaf = TestDataFactory.createLeafKR(title: "Neg", current: 50, target: 100, unit: "%", owner: "A", scope: .personal)
        let parent = TestDataFactory.createObjective(title: "P", owner: "A", scope: .personal, children: [leaf])
        let result = sut.updateLeafAndRecalculate(treeRoot: parent, leafId: leaf.id, newValue: -1000)
        // Should clamp to 0
        XCTAssertEqual(result.children[0].currentValue, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.children[0].progress, 0.0, accuracy: 0.001)
    }

    // MARK: - Very Deep / Large Trees

    func test_veryDeepTree_depth2000_doesNotStackOverflow() {
        let deepTree = TestDataFactory.createDeepTree(depth: 2000)
        let result = sut.calculateTreeProgress(root: deepTree)
        XCTAssertEqual(result.progress, 100.0, accuracy: 0.001)
    }

    func test_veryDeepTree_updateLeaf_works() {
        let deepTree = TestDataFactory.createDeepTree(depth: 500)
        // Find the leaf (deepest node)
        var leaf = deepTree
        while !leaf.children.isEmpty {
            leaf = leaf.children[0]
        }
        let leafId = leaf.id
        let result = sut.updateLeafAndRecalculate(treeRoot: deepTree, leafId: leafId, newValue: 50)
        XCTAssertEqual(result.progress, 50.0, accuracy: 1.0) // Some rounding across depth
    }

    func test_balancedTree_manyNodes_notCrash() {
        let tree = TestDataFactory.createBalancedTree(levels: 8) // 2^8 - 1 = 255 nodes
        let result = sut.calculateTreeProgress(root: tree)
        XCTAssertEqual(result.progress, 100.0, accuracy: 0.001)
    }

    // MARK: - Mixed Type Trees

    func test_mixedTree_keyResultWithChildren() {
        let child = TestDataFactory.createLeafKR(title: "C", current: 50, target: 100, unit: "%", owner: "A", scope: .personal)
        let krParent = TestDataFactory.createLeafKR(title: "KR With Children", current: 0, target: 100, unit: "%", owner: "A", scope: .enterprise, children: [child])
        let result = sut.calculateProgress(for: krParent)
        // KR with children → calculated as parent (average of children)
        XCTAssertEqual(result.progress, 50.0, accuracy: 0.001)
        // Also: isLeaf should be false since it has children
        XCTAssertFalse(krParent.isLeaf)
    }

    func test_objectiveWithChildren_butNoProgress_source() {
        let child = TestDataFactory.createEmptyObjective(title: "Empty Child O", owner: "A", scope: .personal)
        let parent = TestDataFactory.createObjective(title: "Parent O", owner: "A", scope: .personal, children: [child])
        let result = sut.calculateProgress(for: parent)
        // Empty Objective has progress=0, so parent should be 0
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001)
    }

    func test_calculateTreeProgress_multipleRootsStillCalculates() {
        // Even though the engine takes one root, test that a non-root node still calculates
        let leaf = TestDataFactory.createLeafKR(title: "L", current: 75, target: 100, unit: "%", owner: "A", scope: .personal)
        let result = sut.calculateTreeProgress(root: leaf)
        XCTAssertEqual(result.progress, 75.0, accuracy: 0.001)
    }

    // MARK: - Negative weights edge case

    func test_negativeWeight_stillCalculates() {
        var child1 = TestDataFactory.createLeafKR(title: "KR1", current: 50, target: 100, unit: "%", owner: "A", scope: .personal)
        child1.weight = -1.0
        let child2 = TestDataFactory.createLeafKR(title: "KR2", current: 100, target: 100, unit: "%", owner: "A", scope: .personal)
        let parent = TestDataFactory.createObjective(title: "P", owner: "A", scope: .personal, children: [child1, child2])
        let result = sut.calculateProgress(for: parent)
        // totalWeight = -1 + 1 = 0 → falls back to simple average: (50 + 100) / 2 = 75
        XCTAssertEqual(result.progress, 75.0, accuracy: 0.001)
    }

    // MARK: - updateLeafInTree edge cases

    func test_updateLeaf_leafOnFirstChild_works() {
        let leaf = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let parent = TestDataFactory.createObjective(title: "P", owner: "A", scope: .personal, children: [leaf])
        let result = sut.updateLeafAndRecalculate(treeRoot: parent, leafId: leaf.id, newValue: 60)
        XCTAssertEqual(result.children[0].currentValue, 60)
        XCTAssertEqual(result.children[0].progress, 60, accuracy: 0.001)
        XCTAssertEqual(result.progress, 60, accuracy: 0.001)
    }

    func test_updateLeaf_leafInNestedChild_works() {
        let leaf = TestDataFactory.createLeafKR(title: "Deep KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let mid = TestDataFactory.createObjective(title: "Mid O", owner: "A", scope: .personal, children: [leaf])
        let root = TestDataFactory.createObjective(title: "Root O", owner: "A", scope: .enterprise, children: [mid])
        let result = sut.updateLeafAndRecalculate(treeRoot: root, leafId: leaf.id, newValue: 80)
        XCTAssertEqual(result.progress, 80, accuracy: 0.01)
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - NodeValidator Additional Tests
// ────────────────────────────────────────────────────────────────────────────

@MainActor
final class NodeValidatorAdditionalTests: XCTestCase {

    nonisolated(unsafe) private var validator: NodeValidator!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            validator = NodeValidator()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            validator = nil
        }
        super.tearDown()
    }

    // MARK: - validateCycle

    func test_validateCycle_valid_returnsNoErrors() {
        let cycle = OKRCycle(name: "Q1", startDate: Date(timeIntervalSince1970: 100), endDate: Date(timeIntervalSince1970: 200))
        let errors = validator.validateCycle(cycle)
        XCTAssertTrue(errors.isEmpty)
    }

    func test_validateCycle_emptyName_returnsError() {
        let cycle = OKRCycle(name: "", startDate: Date(), endDate: Date())
        let errors = validator.validateCycle(cycle)
        XCTAssertTrue(errors.contains(.emptyTitle))
    }

    func test_validateCycle_endBeforeStart_returnsError() {
        let cycle = OKRCycle(name: "Bad", startDate: Date(timeIntervalSince1970: 200), endDate: Date(timeIntervalSince1970: 100))
        let errors = validator.validateCycle(cycle)
        XCTAssertTrue(errors.contains(.invalidCycleDateRange))
    }

    func test_validateCycle_bothErrors_returnsBoth() {
        let cycle = OKRCycle(name: "", startDate: Date(timeIntervalSince1970: 200), endDate: Date(timeIntervalSince1970: 100))
        let errors = validator.validateCycle(cycle)
        XCTAssertTrue(errors.contains(.emptyTitle))
        XCTAssertTrue(errors.contains(.invalidCycleDateRange))
        XCTAssertEqual(errors.count, 2)
    }

    // MARK: - validateBatch

    func test_validateBatch_allValid_returnsNil() {
        let nodes = [
            TestDataFactory.createLeafKR(title: "KR1", current: 0, target: 100, unit: "%", owner: "A", scope: .personal),
            TestDataFactory.createLeafKR(title: "KR2", current: 50, target: 100, unit: "%", owner: "A", scope: .personal),
        ]
        XCTAssertNil(validator.validateBatch(nodes))
    }

    func test_validateBatch_firstInvalid_returnsError() {
        let invalid = OKRNode(title: "", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let valid = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let error = validator.validateBatch([invalid, valid])
        XCTAssertEqual(error, .emptyTitle)
    }

    func test_validateBatch_emptyArray_returnsNil() {
        XCTAssertNil(validator.validateBatch([]))
    }

    // MARK: - calculateDeleteWarning

    func test_calculateDeleteWarning_noChildren_returnsNil() {
        let leaf = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let warning = validator.calculateDeleteWarning(for: leaf)
        XCTAssertNil(warning)
    }

    func test_calculateDeleteWarning_withChildren_returnsWarning() {
        let child = TestDataFactory.createLeafKR(title: "C", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let parent = TestDataFactory.createObjective(title: "P", owner: "A", scope: .personal, children: [child])
        let warning = validator.calculateDeleteWarning(for: parent)
        XCTAssertNotNil(warning)
        XCTAssertEqual(warning?.cascadeDeleteCount, 1)
        XCTAssertEqual(warning?.directDeleteCount, 1)
    }

    func test_calculateDeleteWarning_deepNesting_countsAll() {
        let leaf = TestDataFactory.createLeafKR(title: "L", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let mid = TestDataFactory.createObjective(title: "M", owner: "A", scope: .personal, children: [leaf])
        let top = TestDataFactory.createObjective(title: "T", owner: "A", scope: .personal, children: [mid])
        let warning = validator.calculateDeleteWarning(for: top)
        XCTAssertEqual(warning?.cascadeDeleteCount, 2) // 2 descendants
    }

    // MARK: - calculateBatchDeleteWarning

    func test_calculateBatchDeleteWarning_multipleNodes() {
        let leaf1 = TestDataFactory.createLeafKR(title: "L1", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let leaf2 = TestDataFactory.createLeafKR(title: "L2", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let warning = validator.calculateBatchDeleteWarning(for: [leaf1, leaf2])
        XCTAssertEqual(warning.directDeleteCount, 2)
        XCTAssertEqual(warning.cascadeDeleteCount, 0)
    }

    func test_calculateBatchDeleteWarning_withChildren() {
        let child = TestDataFactory.createLeafKR(title: "C", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let parent = TestDataFactory.createObjective(title: "P", owner: "A", scope: .personal, children: [child])
        let leaf = TestDataFactory.createLeafKR(title: "L", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let warning = validator.calculateBatchDeleteWarning(for: [parent, leaf])
        XCTAssertEqual(warning.directDeleteCount, 2)
        XCTAssertEqual(warning.cascadeDeleteCount, 1) // Only parent has children
    }

    // MARK: - isValidTitle

    func test_isValidTitle_valid_returnsTrue() {
        XCTAssertTrue(validator.isValidTitle("My KR"))
    }

    func test_isValidTitle_empty_returnsFalse() {
        XCTAssertFalse(validator.isValidTitle(""))
    }

    func test_isValidTitle_whitespace_returnsFalse() {
        XCTAssertFalse(validator.isValidTitle("   \n\t  "))
    }

    // MARK: - isValidTargetValue

    func test_isValidTargetValue_positive_returnsTrue() {
        XCTAssertTrue(validator.isValidTargetValue(100))
    }

    func test_isValidTargetValue_zero_returnsFalse() {
        XCTAssertFalse(validator.isValidTargetValue(0))
    }

    func test_isValidTargetValue_negative_returnsFalse() {
        XCTAssertFalse(validator.isValidTargetValue(-1))
    }

    func test_isValidTargetValue_smallPositive_returnsTrue() {
        XCTAssertTrue(validator.isValidTargetValue(0.001))
    }

    // MARK: - isValidLeafNode

    func test_isValidLeafNode_validKR_returnsTrue() {
        let node = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        XCTAssertTrue(validator.isValidLeafNode(node))
    }

    func test_isValidLeafNode_objective_returnsFalse() {
        let node = TestDataFactory.createEmptyObjective(title: "O", owner: "A", scope: .personal)
        XCTAssertFalse(validator.isValidLeafNode(node))
    }

    func test_isValidLeafNode_krWithChildren_returnsFalse() {
        let child = TestDataFactory.createLeafKR(title: "C", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let node = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .enterprise, children: [child])
        XCTAssertFalse(validator.isValidLeafNode(node))
    }

    func test_isValidLeafNode_zeroTarget_returnsFalse() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, targetValue: 0, ownerName: "A")
        XCTAssertFalse(validator.isValidLeafNode(node))
    }

    // MARK: - isCompatibleParent

    func test_isCompatibleParent_objectiveUnderKR_allowed() {
        XCTAssertTrue(validator.isCompatibleParent(childType: .objective, parentType: .keyResult))
    }

    func test_isCompatibleParent_krUnderObjective_allowed() {
        XCTAssertTrue(validator.isCompatibleParent(childType: .keyResult, parentType: .objective))
    }

    func test_isCompatibleParent_objectiveUnderObjective_allowed() {
        XCTAssertTrue(validator.isCompatibleParent(childType: .objective, parentType: .objective))
    }

    func test_isCompatibleParent_krUnderKr_notAllowed() {
        XCTAssertFalse(validator.isCompatibleParent(childType: .keyResult, parentType: .keyResult))
    }

    // MARK: - isCompatibleParent (node version)

    func test_isCompatibleParent_nodeVersion() {
        let child = OKRNode(title: "C", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let parent = OKRNode(title: "P", nodeType: .objective, scope: .enterprise, targetValue: 0, ownerName: "A")
        XCTAssertTrue(validator.isCompatibleParent(child: child, parent: parent))
    }

    // MARK: - autoCleanup

    func test_autoCleanup_throughValidator_trimsAndRemoves() {
        let node = OKRNode(title: "  Trim  ", nodeDescription: "   ", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let cleaned = validator.autoCleanup(node)
        XCTAssertEqual(cleaned.title, "Trim")
        XCTAssertNil(cleaned.nodeDescription)
    }
}
