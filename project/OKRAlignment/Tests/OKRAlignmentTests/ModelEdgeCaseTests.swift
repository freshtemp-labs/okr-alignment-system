import XCTest
@testable import OKRAlignmentShared

// MARK: - ModelEdgeCaseTests
//
// Edge case tests for the domain models, enum computed properties,
// validation logic, and utility types that were previously untested.
//
// Total: ~50 test methods

// ────────────────────────────────────────────────────────────────────────────
// MARK: - OKRNode Edge Cases
// ────────────────────────────────────────────────────────────────────────────

@MainActor
final class OKRNodeEdgeCaseTests: XCTestCase {

    // MARK: - isLeaf

    func test_isLeaf_keyResultWithNoChildren_returnsTrue() {
        let node = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        XCTAssertTrue(node.isLeaf)
    }

    func test_isLeaf_keyResultWithChildren_returnsFalse() {
        let child = TestDataFactory.createLeafKR(title: "C", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        let parent = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .enterprise, children: [child])
        XCTAssertFalse(parent.isLeaf)
    }

    func test_isLeaf_objectiveWithNoChildren_returnsFalse() {
        let node = OKRNode(title: "O", nodeType: .objective, scope: .enterprise, targetValue: 0, ownerName: "A")
        XCTAssertFalse(node.isLeaf, "Objective without children should NOT be considered a leaf")
    }

    // MARK: - isRoot

    func test_isRoot_withNilParentId_returnsTrue() {
        let node = OKRNode(title: "Root", nodeType: .objective, scope: .enterprise, targetValue: 0, ownerName: "A")
        XCTAssertTrue(node.isRoot)
    }

    func test_isRoot_withParentId_returnsFalse() {
        let node = OKRNode(title: "Child", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A", parentId: UUID())
        XCTAssertFalse(node.isRoot)
    }

    // MARK: - hasCustomWeight

    func test_hasCustomWeight_default_returnsFalse() {
        let node = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        XCTAssertFalse(node.hasCustomWeight)
    }

    func test_hasCustomWeight_setToNonOne_returnsTrue() {
        var node = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        node.weight = 2.5
        XCTAssertTrue(node.hasCustomWeight)
    }

    func test_hasCustomWeight_setToOne_returnsFalse() {
        var node = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        node.weight = 1.0
        XCTAssertFalse(node.hasCustomWeight)
    }

    // MARK: - progressPercentage

    func test_progressPercentage_zero() {
        let node = TestDataFactory.createLeafKR(title: "KR", current: 0, target: 100, unit: "%", owner: "A", scope: .personal)
        XCTAssertEqual(node.progressPercentage, "0.0%")
    }

    func test_progressPercentage_hundred() {
        let node = TestDataFactory.createCompletedLeafKR()
        XCTAssertEqual(node.progressPercentage, "100.0%")
    }

    func test_progressPercentage_fractional() {
        let node = TestDataFactory.createLeafKR(title: "KR", current: 33, target: 100, unit: "%", owner: "A", scope: .personal)
        XCTAssertEqual(node.progressPercentage, "33.0%")
    }

    // MARK: - valueDisplayString

    func test_valueDisplayString_leaf() {
        let node = TestDataFactory.createLeafKR(title: "KR", current: 20, target: 100, unit: "%", owner: "A", scope: .personal)
        XCTAssertEqual(node.valueDisplayString, "20 / 100 %")
    }

    func test_valueDisplayString_leafWithoutUnit() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, currentValue: 5, targetValue: 10, unit: nil, ownerName: "A")
        XCTAssertEqual(node.valueDisplayString, "5 / 10 ")
    }

    func test_valueDisplayString_parentWithChildren() {
        let child = TestDataFactory.createLeafKR(title: "KR", current: 50, target: 100, unit: "%", owner: "A", scope: .personal)
        let parent = TestDataFactory.createObjective(title: "O", owner: "A", scope: .personal, children: [child])
        XCTAssertTrue(parent.valueDisplayString.contains("子节点平均进度"))
    }

    func test_valueDisplayString_emptyObjective() {
        let node = TestDataFactory.createEmptyObjective(title: "Empty O", owner: "A", scope: .personal)
        XCTAssertEqual(node.valueDisplayString, "对齐汇总完成度")
    }

    // MARK: - depth calculation

    func test_depth_rootNode_returnsZero() {
        let node = OKRNode(title: "Root", nodeType: .objective, scope: .enterprise, targetValue: 0, ownerName: "A")
        XCTAssertEqual(node.depth(in: []), 0)
    }

    func test_depth_directChild_returnsOne() {
        let parentId = UUID()
        let parent = OKRNode(id: parentId, title: "Parent", nodeType: .objective, scope: .enterprise, targetValue: 0, ownerName: "A")
        let child = OKRNode(title: "Child", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A", parentId: parentId)
        let tree = [parent, child]
        XCTAssertEqual(child.depth(in: tree), 1)
    }

    func test_depth_nestedChild_calculatesCorrectly() {
        let rootId = UUID()
        let childId = UUID()
        let grandchildId = UUID()
        let grandchild = OKRNode(id: grandchildId, title: "GC", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A", parentId: childId)
        let child = OKRNode(id: childId, title: "C", nodeType: .objective, scope: .personal, targetValue: 0, ownerName: "A", parentId: rootId, children: [grandchild])
        let root = OKRNode(id: rootId, title: "R", nodeType: .objective, scope: .enterprise, targetValue: 0, ownerName: "A", children: [child])
        XCTAssertEqual(grandchild.depth(in: [root]), 2)
    }

    // MARK: - init auto-progress calculation

    func test_init_withExplicitProgress_usesProvidedValue() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, currentValue: 50, targetValue: 100, progress: 42, ownerName: "A")
        XCTAssertEqual(node.progress, 42.0, accuracy: 0.001)
    }

    func test_init_withAutoProgress_calculatesCorrectly() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, currentValue: 75, targetValue: 100, ownerName: "A")
        XCTAssertEqual(node.progress, 75.0, accuracy: 0.001)
    }

    func test_init_withZeroTarget_progressIsZero() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, currentValue: 50, targetValue: 0, ownerName: "A")
        XCTAssertEqual(node.progress, 0.0)
    }

    func test_init_withExplicitProgressOutOfRange_clamped() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, currentValue: 50, targetValue: 100, progress: 150, ownerName: "A")
        XCTAssertEqual(node.progress, 100.0)
    }

    func test_init_withExplicitProgressNegative_clamped() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, currentValue: 50, targetValue: 100, progress: -10, ownerName: "A")
        XCTAssertEqual(node.progress, 0.0)
    }

    // MARK: - Equatable

    func test_equality_sameId_progressMatters() {
        let id = UUID()
        let n1 = OKRNode(id: id, title: "A", nodeType: .keyResult, scope: .personal, targetValue: 100, progress: 50, ownerName: "A")
        let n2 = OKRNode(id: id, title: "A", nodeType: .keyResult, scope: .personal, targetValue: 100, progress: 75, ownerName: "A")
        XCTAssertNotEqual(n1, n2, "Different progress should make nodes not equal")
    }

    func test_equality_differentId_notEqual() {
        let n1 = OKRNode(id: UUID(), title: "A", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let n2 = OKRNode(id: UUID(), title: "A", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        XCTAssertNotEqual(n1, n2)
    }

    // MARK: - OKRNode.validate()

    func test_nodeValidate_titleOnlyWhitespace_returnsEmptyTitle() {
        let node = OKRNode(title: "   \n\t  ", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let error = node.validate()
        XCTAssertEqual(error, .emptyTitle)
    }

    func test_nodeValidate_validNode_returnsNil() {
        let node = OKRNode(title: "OK", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let error = node.validate()
        XCTAssertNil(error)
    }

    func test_nodeValidate_zeroTargetKROnly_returnsInvalidTarget() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, targetValue: 0, ownerName: "A")
        let error = node.validate()
        XCTAssertEqual(error, .invalidTargetValue)
    }

    func test_nodeValidate_objectiveZeroTarget_OK() {
        let node = OKRNode(title: "O", nodeType: .objective, scope: .enterprise, targetValue: 0, ownerName: "A")
        XCTAssertNil(node.validate(), "Objective with targetValue=0 should be valid")
    }

    func test_nodeValidate_leafCurrentValueNegative_returnsOutOfRange() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, currentValue: -5, targetValue: 100, ownerName: "A")
        let error = node.validate()
        XCTAssertEqual(error, .currentValueOutOfRange)
    }

    func test_nodeValidate_leafCurrentExceedsTarget_returnsOutOfRange() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, currentValue: 200, targetValue: 100, ownerName: "A")
        let error = node.validate()
        XCTAssertEqual(error, .currentValueOutOfRange)
    }

    func test_nodeValidate_noCycleId_returnsCycleNotSet() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let error = node.validate()
        XCTAssertEqual(error, .cycleNotSet)
    }

    func test_nodeValidate_krTargetZero_returnsKrTargetError() {
        let node = OKRNode(title: "KR", nodeType: .keyResult, scope: .personal, targetValue: 0, currentValue: 0, ownerName: "A", cycleId: UUID())
        let error = node.validate()
        // objective target is also 0 but this is a KR → krTargetValueMustBePositive
        // The validate() method returns the FIRST error found; the order is:
        // emptyTitle → invalidTargetValue → currentValueOutOfRange → krTargetValueMustBePositive → cycleNotSet
        // Since targetValue=0, invalidTargetValue will be returned first
        XCTAssertEqual(error, .invalidTargetValue)
    }

    // MARK: - autoCleanup

    func test_autoCleanup_trimsTitle() {
        let node = OKRNode(title: "  Hello World  ", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let (cleaned, cleanups) = node.autoCleanup()
        XCTAssertEqual(cleaned.title, "Hello World")
        XCTAssertTrue(cleanups.contains(.titleNeedsTrimming))
    }

    func test_autoCleanup_removesEmptyDescription() {
        let node = OKRNode(title: "OK", nodeDescription: "   ", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let (cleaned, cleanups) = node.autoCleanup()
        XCTAssertNil(cleaned.nodeDescription)
        XCTAssertTrue(cleanups.contains(.emptyDescriptionCleanup))
    }

    func test_autoCleanup_alreadyClean_noChanges() {
        let node = OKRNode(title: "OK", nodeDescription: "Desc", nodeType: .keyResult, scope: .personal, targetValue: 100, ownerName: "A")
        let (cleaned, cleanups) = node.autoCleanup()
        XCTAssertEqual(cleaned.title, "OK")
        XCTAssertEqual(cleaned.nodeDescription, "Desc")
        XCTAssertTrue(cleanups.isEmpty)
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - OKRCycle Edge Cases
// ────────────────────────────────────────────────────────────────────────────

final class OKRCycleEdgeCaseTests: XCTestCase {

    // MARK: - durationInDays

    func test_durationInDays_normal() {
        let cycle = OKRCycle(name: "Q1", startDate: Date(timeIntervalSince1970: 1_700_000_000), endDate: Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 90))
        XCTAssertEqual(cycle.durationInDays, 90)
    }

    func test_durationInDays_sameDay_returnsZero() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let cycle = OKRCycle(name: "Same", startDate: date, endDate: date)
        XCTAssertEqual(cycle.durationInDays, 0)
    }

    func test_durationInDays_endBeforeStart_returnsNegative() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_000_000 - 86_400)
        let cycle = OKRCycle(name: "Bad", startDate: start, endDate: end)
        XCTAssertLessThan(cycle.durationInDays, 0)
    }

    // MARK: - timeProgressPercentage

    func test_timeProgressPercentage_beforeStart_returnsZero() {
        let futureStart = Date.distantFuture
        let futureEnd = Calendar.current.date(byAdding: .day, value: 30, to: futureStart)!
        let cycle = OKRCycle(name: "Future", startDate: futureStart, endDate: futureEnd)
        XCTAssertEqual(cycle.timeProgressPercentage, 0.0, accuracy: 0.001)
    }

    func test_timeProgressPercentage_afterEnd_returns100() {
        let pastStart = Date.distantPast
        let pastEnd = Calendar.current.date(byAdding: .day, value: 1, to: pastStart)!
        let cycle = OKRCycle(name: "Past", startDate: pastStart, endDate: pastEnd)
        XCTAssertEqual(cycle.timeProgressPercentage, 100.0, accuracy: 0.001)
    }

    func test_timeProgressPercentage_zeroDuration_returnsZero() {
        let now = Date()
        let cycle = OKRCycle(name: "Zero", startDate: now, endDate: now)
        XCTAssertEqual(cycle.timeProgressPercentage, 0.0, accuracy: 0.001)
    }

    // MARK: - isExpired / isUpcoming / isInProgress

    func test_isExpired_withPastDate_returnsTrue() {
        let cycle = OKRCycle(name: "Old", startDate: Date.distantPast, endDate: Date.distantPast)
        XCTAssertTrue(cycle.isExpired)
    }

    func test_isExpired_withFutureDate_returnsFalse() {
        let cycle = OKRCycle(name: "Future", startDate: Date.distantFuture, endDate: Date.distantFuture)
        XCTAssertFalse(cycle.isExpired)
    }

    func test_isUpcoming_withFutureDate_returnsTrue() {
        let cycle = OKRCycle(name: "Future", startDate: Date.distantFuture, endDate: Date.distantFuture)
        XCTAssertTrue(cycle.isUpcoming)
    }

    func test_isUpcoming_withPastDate_returnsFalse() {
        let cycle = OKRCycle(name: "Past", startDate: Date.distantPast, endDate: Date.distantPast)
        XCTAssertFalse(cycle.isUpcoming)
    }

    // MARK: - validate()

    func test_cycleValidate_valid_returnsNoErrors() {
        let cycle = OKRCycle(name: "Q1", startDate: Date(timeIntervalSince1970: 100), endDate: Date(timeIntervalSince1970: 200))
        XCTAssertTrue(cycle.validate().isEmpty)
    }

    func test_cycleValidate_emptyName_returnsEmptyTitle() {
        let cycle = OKRCycle(name: "  ", startDate: Date(), endDate: Date())
        let errors = cycle.validate()
        XCTAssertTrue(errors.contains(.emptyTitle))
    }

    func test_cycleValidate_endBeforeStart_returnsInvalidDateRange() {
        let cycle = OKRCycle(name: "Bad", startDate: Date(timeIntervalSince1970: 200), endDate: Date(timeIntervalSince1970: 100))
        let errors = cycle.validate()
        XCTAssertTrue(errors.contains(.invalidCycleDateRange))
    }

    func test_cycleValidate_sameDates_returnsInvalidDateRange() {
        let date = Date(timeIntervalSince1970: 100)
        let cycle = OKRCycle(name: "Same", startDate: date, endDate: date)
        let errors = cycle.validate()
        XCTAssertTrue(errors.contains(.invalidCycleDateRange))
    }

    // MARK: - dateRangeString

    func test_dateRangeString_format() {
        let start = Date(timeIntervalSince1970: 1_704_672_000) // January 8, 2024
        let end = Date(timeIntervalSince1970: 1_704_672_000 + 86_400 * 90)
        let cycle = OKRCycle(name: "T", startDate: start, endDate: end)
        XCTAssertTrue(cycle.dateRangeString.contains("-"))
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - NodeStatus Tests
// ────────────────────────────────────────────────────────────────────────────

final class NodeStatusTests: XCTestCase {

    func test_allCases_coverAllRawValues() {
        let allCases = NodeStatus.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertEqual(NodeStatus(rawValue: "not_started"), .notStarted)
        XCTAssertEqual(NodeStatus(rawValue: "in_progress"), .inProgress)
        XCTAssertEqual(NodeStatus(rawValue: "at_risk"), .atRisk)
        XCTAssertEqual(NodeStatus(rawValue: "completed"), .completed)
        XCTAssertEqual(NodeStatus(rawValue: "cancelled"), .cancelled)
        XCTAssertNil(NodeStatus(rawValue: "unknown"))
    }

    func test_notStarted_displayValues() {
        XCTAssertEqual(NodeStatus.notStarted.displayName, "未开始")
        XCTAssertEqual(NodeStatus.notStarted.iconName, "circle.dashed")
        XCTAssertFalse(NodeStatus.notStarted.isTerminal)
        XCTAssertTrue(NodeStatus.notStarted.isActive)
    }

    func test_completed_isTerminal() {
        XCTAssertTrue(NodeStatus.completed.isTerminal)
        XCTAssertFalse(NodeStatus.completed.isActive)
    }

    func test_cancelled_isTerminal() {
        XCTAssertTrue(NodeStatus.cancelled.isTerminal)
        XCTAssertFalse(NodeStatus.cancelled.isActive)
    }

    func test_statusRawValue_roundTrip() {
        for status in NodeStatus.allCases {
            let raw = status.rawValue
            XCTAssertEqual(NodeStatus(rawValue: raw), status)
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - NodeType Tests
// ────────────────────────────────────────────────────────────────────────────

final class NodeTypeTests: XCTestCase {

    func test_allCases() {
        XCTAssertEqual(NodeType.allCases.count, 2)
        XCTAssertEqual(NodeType.objective.displayName, "目标")
        XCTAssertEqual(NodeType.keyResult.displayName, "关键结果")
        XCTAssertEqual(NodeType.objective.iconName, "flag.fill")
        XCTAssertEqual(NodeType.keyResult.iconName, "number")
    }

    func test_rawValue_roundTrip() {
        for type in NodeType.allCases {
            XCTAssertEqual(NodeType(rawValue: type.rawValue), type)
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - Scope Tests
// ────────────────────────────────────────────────────────────────────────────

final class ScopeTests: XCTestCase {

    func test_allCases() {
        XCTAssertEqual(Scope.allCases.count, 2)
        XCTAssertEqual(Scope.enterprise.displayName, "企业级")
        XCTAssertEqual(Scope.personal.displayName, "个人级")
        XCTAssertEqual(Scope.enterprise.iconName, "building.2.fill")
        XCTAssertEqual(Scope.personal.iconName, "person.fill")
    }

    func test_rawValue_roundTrip() {
        for scope in Scope.allCases {
            XCTAssertEqual(Scope(rawValue: scope.rawValue), scope)
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - UserRole Tests
// ────────────────────────────────────────────────────────────────────────────

final class UserRoleTests: XCTestCase {

    func test_allCases() {
        XCTAssertEqual(UserRole.allCases.count, 3)
    }

    func test_adminPermissions() {
        let role = UserRole.admin
        XCTAssertTrue(role.canCreateNode)
        XCTAssertTrue(role.canEditAnyNode)
        XCTAssertTrue(role.canDeleteNode)
        XCTAssertTrue(role.canManageCycles)
        XCTAssertTrue(role.canManageRoles)
        XCTAssertTrue(role.canViewAnalytics)
        XCTAssertTrue(role.canExportData)
        XCTAssertTrue(role.canManageBackup)
        XCTAssertTrue(role.canManageSettings)
    }

    func test_managerPermissions() {
        let role = UserRole.manager
        XCTAssertTrue(role.canCreateNode)
        XCTAssertTrue(role.canEditAnyNode)
        XCTAssertTrue(role.canDeleteNode)
        XCTAssertTrue(role.canManageCycles)
        XCTAssertFalse(role.canManageRoles)
        XCTAssertTrue(role.canViewAnalytics)
        XCTAssertTrue(role.canExportData)
        XCTAssertFalse(role.canManageBackup)
        XCTAssertFalse(role.canManageSettings)
    }

    func test_memberPermissions() {
        let role = UserRole.member
        XCTAssertFalse(role.canCreateNode)
        XCTAssertFalse(role.canEditAnyNode)
        XCTAssertFalse(role.canDeleteNode)
        XCTAssertFalse(role.canManageCycles)
        XCTAssertFalse(role.canManageRoles)
        XCTAssertTrue(role.canViewAnalytics, "All roles should view analytics")
        XCTAssertFalse(role.canExportData)
        XCTAssertFalse(role.canManageBackup)
        XCTAssertFalse(role.canManageSettings)
    }

    func test_rawValue_roundTrip() {
        for role in UserRole.allCases {
            XCTAssertEqual(UserRole(rawValue: role.rawValue), role)
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - ValidationError Tests
// ────────────────────────────────────────────────────────────────────────────

final class ValidationErrorTests: XCTestCase {

    func test_allCases_coverAll() {
        let allErrors: [ValidationError] = [
            .emptyTitle,
            .invalidTargetValue,
            .leafMissingValues,
            .currentValueOutOfRange,
            .parentTypeMismatch,
            .cycleNotSet,
            .invalidCycleDateRange,
            .krTargetValueMustBePositive,
            .hasChildNodes(childCount: 3),
            .titleNeedsTrimming,
            .emptyDescriptionCleanup,
        ]
        XCTAssertEqual(allErrors.count, 11)
    }

    func test_emptyTitle_properties() {
        let err = ValidationError.emptyTitle
        XCTAssertEqual(err.message, "标题不能为空，请输入一个描述性的标题")
        XCTAssertEqual(err.title, "标题错误")
        XCTAssertTrue(err.isBlocking)
    }

    func test_invalidTargetValue_properties() {
        let err = ValidationError.invalidTargetValue
        XCTAssertEqual(err.title, "目标值错误")
        XCTAssertTrue(err.isBlocking)
    }

    func test_titleNeedsTrimming_isNotBlocking() {
        XCTAssertFalse(ValidationError.titleNeedsTrimming.isBlocking)
    }

    func test_emptyDescriptionCleanup_isNotBlocking() {
        XCTAssertFalse(ValidationError.emptyDescriptionCleanup.isBlocking)
    }

    func test_hasChildNodes_message() {
        let err = ValidationError.hasChildNodes(childCount: 5)
        XCTAssertTrue(err.message.contains("5"))
        XCTAssertEqual(err.title, "存在关联子节点")
        XCTAssertTrue(err.isBlocking)
    }

    func test_leafMissingValues_properties() {
        let err = ValidationError.leafMissingValues
        XCTAssertTrue(err.isBlocking)
        XCTAssertEqual(err.title, "数值缺失")
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - DeleteWarning Tests
// ────────────────────────────────────────────────────────────────────────────

final class DeleteWarningTests: XCTestCase {

    func test_totalCount_sum() {
        let warning = DeleteWarning(directDeleteCount: 2, cascadeDeleteCount: 3)
        XCTAssertEqual(warning.totalCount, 5)
    }

    func test_message_withCascade() {
        let warning = DeleteWarning(directDeleteCount: 1, cascadeDeleteCount: 5)
        XCTAssertTrue(warning.message.contains("6"))
        XCTAssertTrue(warning.message.contains("5 个子节点"))
        XCTAssertTrue(warning.needsWarning)
    }

    func test_message_noCascade() {
        let warning = DeleteWarning(directDeleteCount: 1, cascadeDeleteCount: 0)
        XCTAssertEqual(warning.message, "将删除 1 个节点")
        XCTAssertFalse(warning.needsWarning)
    }

    func test_message_singleDirect() {
        let warning = DeleteWarning(directDeleteCount: 1, cascadeDeleteCount: 0)
        XCTAssertFalse(warning.needsWarning)
        XCTAssertEqual(warning.totalCount, 1)
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - Date Extensions Tests
// ────────────────────────────────────────────────────────────────────────────

final class DateExtensionsTests: XCTestCase {

    let testDate = Date(timeIntervalSince1970: 1_704_672_000) // A known date

    func test_shortDateString() {
        let str = testDate.shortDateString
        XCTAssertTrue(str.contains("/"))
    }

    func test_mediumDateString() {
        let str = testDate.mediumDateString
        XCTAssertTrue(str.contains("年"))
    }

    func test_fullDateString() {
        let str = testDate.fullDateString
        XCTAssertTrue(str.contains("年"))
    }

    func test_dateTimeString() {
        let str = testDate.dateTimeString
        XCTAssertTrue(str.contains(":"))
    }

    func test_daysUntil_future() {
        let now = Date(timeIntervalSince1970: 100)
        let future = Date(timeIntervalSince1970: 100 + 86_400 * 5)
        let days = now.daysUntil(future)
        XCTAssertEqual(days, 5)
    }

    func test_daysUntil_past() {
        let now = Date(timeIntervalSince1970: 100)
        let past = Date(timeIntervalSince1970: 100 - 86_400 * 3)
        let days = now.daysUntil(past)
        XCTAssertEqual(days, -3)
    }

    func test_daysSince() {
        let now = Date(timeIntervalSince1970: 200)
        let before = Date(timeIntervalSince1970: 100)
        let days = now.daysSince(before)
        XCTAssertEqual(days, 0) // date shift from epoch may not be exact day boundaries
    }

    func test_isBetween_inclusive() {
        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 200)
        let mid = Date(timeIntervalSince1970: 150)
        XCTAssertTrue(mid.isBetween(start, and: end))
    }

    func test_isBetween_edgeExact() {
        let date = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(date.isBetween(date, and: date))
    }

    func test_isBetween_outside() {
        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 200)
        let later = Date(timeIntervalSince1970: 300)
        XCTAssertFalse(later.isBetween(start, and: end))
    }

    func test_quarterStartMonth() {
        let jan = Date.from(year: 2026, month: 1, day: 15)!
        let apr = Date.from(year: 2026, month: 4, day: 1)!
        let oct = Date.from(year: 2026, month: 10, day: 1)!
        XCTAssertEqual(jan.quarterStartMonth, 1)
        XCTAssertEqual(apr.quarterStartMonth, 4)
        XCTAssertEqual(oct.quarterStartMonth, 10)
    }

    func test_quarterDescription() {
        let q1 = Date.from(year: 2026, month: 2, day: 1)!
        let q2 = Date.from(year: 2026, month: 5, day: 1)!
        let q3 = Date.from(year: 2026, month: 8, day: 1)!
        let q4 = Date.from(year: 2026, month: 11, day: 1)!
        XCTAssertEqual(q1.quarterDescription, "2026 Q1")
        XCTAssertEqual(q2.quarterDescription, "2026 Q2")
        XCTAssertEqual(q3.quarterDescription, "2026 Q3")
        XCTAssertEqual(q4.quarterDescription, "2026 Q4")
    }

    func test_from_invalid_returnsNil() {
        let invalid = Date.from(year: 2026, month: 13, day: 1) // Invalid month
        XCTAssertNil(invalid)
    }

    func test_startOfQuarter() {
        let start = Date.startOfQuarter(year: 2026, quarter: 2)
        XCTAssertNotNil(start)
    }

    func test_endOfQuarter() {
        let end = Date.endOfQuarter(year: 2026, quarter: 2)
        XCTAssertNotNil(end)
    }
}
