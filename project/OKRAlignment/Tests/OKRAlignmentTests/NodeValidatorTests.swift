import XCTest
@testable import OKRAlignment

// MARK: - NodeValidatorTests

/// 节点验证器的完整测试套件
///
/// 本测试类验证OKR节点的验证逻辑，确保所有ValidationError分支都被覆盖。
/// 验证规则包括:
/// - 标题不能为空
/// - KeyResult节点targetValue必须大于0
/// - 叶子节点必须有有效的currentValue和targetValue
/// - Objective节点必须设置cycleId
/// - 支持同时返回多个验证错误
///
/// ## 测试覆盖
/// - 有效节点验证 (1个测试)
/// - 标题验证边界 (2个测试)
/// - 目标值验证 (2个测试)
/// - 叶子节点值验证 (1个测试)
/// - Cycle关联验证 (1个测试)
/// - 多错误组合验证 (1个测试)
///
/// 总计: 8个测试方法
@MainActor
final class NodeValidatorTests: XCTestCase {

    // MARK: - Properties

    /// 被测系统（System Under Test）
    private var sut: CascadeEngineProtocol!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        sut = CascadeEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - 测试: 有效节点

    /// 测试: 完全有效的节点应返回空错误数组
    ///
    /// Arrange: 创建一个所有字段都有效的叶子KR节点
    /// Act: 调用validateNode
    /// Assert: 返回空数组，无错误
    func test_validateNode_withValidNode_returnsNoErrors() {
        // Arrange
        let validNode = TestDataFactory.createLeafKR(
            title: "有效的KR",
            current: 50,
            target: 100,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )

        // Act
        let errors = sut.validateNode(validNode)

        // Assert
        XCTAssertTrue(errors.isEmpty,
            "有效节点应返回空错误数组")
    }

    // MARK: - 测试: 标题验证

    /// 测试: 空标题的节点应返回emptyTitle错误
    ///
    /// Arrange: 创建一个标题为空字符串的节点
    /// Act: 调用validateNode
    /// Assert: 返回[.emptyTitle]
    func test_validateNode_withEmptyTitle_returnsEmptyTitleError() {
        // Arrange
        let invalidNode = OKRNode(
            id: UUID(),
            title: "",
            nodeDescription: "描述",
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

        // Act
        let errors = sut.validateNode(invalidNode)

        // Assert
        XCTAssertTrue(errors.contains(.emptyTitle),
            "空标题应返回emptyTitle错误")
    }

    /// 测试: 仅包含空白字符的标题应返回emptyTitle错误
    ///
    /// Arrange: 创建一个标题只有空格的节点
    /// Act: 调用validateNode
    /// Assert: 返回[.emptyTitle]
    func test_validateNode_withWhitespaceTitle_returnsEmptyTitleError() {
        // Arrange
        let invalidNode = OKRNode(
            id: UUID(),
            title: "   \t\n  ",
            nodeDescription: "描述",
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

        // Act
        let errors = sut.validateNode(invalidNode)

        // Assert
        XCTAssertTrue(errors.contains(.emptyTitle),
            "仅包含空白字符的标题应返回emptyTitle错误")
    }

    // MARK: - 测试: 目标值验证

    /// 测试: targetValue为0的KeyResult应返回invalidTargetValue错误
    ///
    /// Arrange: 创建一个targetValue=0的KeyResult节点
    /// Act: 调用validateNode
    /// Assert: 返回包含.invalidTargetValue的错误数组
    func test_validateNode_withZeroTarget_returnsInvalidTargetError() {
        // Arrange
        let invalidNode = TestDataFactory.createLeafKR(
            title: "零目标KR",
            current: 0,
            target: 0,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )

        // Act
        let errors = sut.validateNode(invalidNode)

        // Assert
        XCTAssertTrue(errors.contains(.invalidTargetValue),
            "targetValue为0时应返回invalidTargetValue错误")
    }

    /// 测试: 负数的targetValue应返回invalidTargetValue错误
    ///
    /// Arrange: 创建一个targetValue=-10的KeyResult节点
    /// Act: 调用validateNode
    /// Assert: 返回包含.invalidTargetValue的错误数组
    func test_validateNode_withNegativeTarget_returnsInvalidTargetError() {
        // Arrange
        let invalidNode = TestDataFactory.createLeafKR(
            title: "负目标KR",
            current: 0,
            target: -10,
            unit: "%",
            owner: "Alice",
            scope: .personal
        )

        // Act
        let errors = sut.validateNode(invalidNode)

        // Assert
        XCTAssertTrue(errors.contains(.invalidTargetValue),
            "targetValue为负数时应返回invalidTargetValue错误")
    }

    // MARK: - 测试: 叶子节点值验证

    /// 测试: 叶子节点缺少有效currentValue时应返回leafMissingValues错误
    ///
    /// Arrange: 创建一个currentValue为NaN的叶子节点
    /// Act: 调用validateNode
    /// Assert: 返回包含.leafMissingValues的错误数组
    func test_validateNode_leafWithMissingCurrentValue_returnsLeafMissingValuesError() {
        // Arrange
        let invalidNode = OKRNode(
            id: UUID(),
            title: "无效叶子KR",
            nodeDescription: nil,
            nodeType: .keyResult,
            scope: .personal,
            currentValue: .nan,
            targetValue: 100,
            unit: "%",
            progress: 0,
            status: .notStarted,
            ownerName: "Alice",
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: 0,
            parentId: nil,
            children: [],
            cycleId: UUID()
        )

        // Act
        let errors = sut.validateNode(invalidNode)

        // Assert
        XCTAssertTrue(errors.contains(.leafMissingValues),
            "叶子节点currentValue无效时应返回leafMissingValues错误")
    }

    // MARK: - 测试: Cycle关联验证

    /// 测试: Objective节点未设置cycleId时应返回cycleNotSet错误
    ///
    /// Arrange: 创建一个cycleId为nil的Objective节点
    /// Act: 调用validateNode
    /// Assert: 返回包含.cycleNotSet的错误数组
    func test_validateNode_objectiveWithNoCycle_returnsCycleNotSetError() {
        // Arrange
        let invalidNode = OKRNode(
            id: UUID(),
            title: "无Cycle的O",
            nodeDescription: nil,
            nodeType: .objective,
            scope: .personal,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 0,
            status: .notStarted,
            ownerName: "Alice",
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: 0,
            parentId: nil,
            children: [],
            cycleId: nil  // 未设置Cycle
        )

        // Act
        let errors = sut.validateNode(invalidNode)

        // Assert
        XCTAssertTrue(errors.contains(.cycleNotSet),
            "Objective节点未设置cycleId时应返回cycleNotSet错误")
    }

    // MARK: - 测试: 多错误组合

    /// 测试: 同时存在多个验证错误的节点应返回所有错误
    ///
    /// Arrange: 创建一个同时违反多个规则的节点（空标题 + 无效target + 未设置cycle）
    /// Act: 调用validateNode
    /// Assert: 返回包含所有对应错误的数组
    func test_validateNode_withMultipleErrors_returnsAllErrors() {
        // Arrange
        let invalidNode = OKRNode(
            id: UUID(),
            title: "",           // 空标题
            nodeDescription: nil,
            nodeType: .objective, // Objective需要cycleId
            scope: .personal,
            currentValue: 0,
            targetValue: 0,      // 无效target
            unit: nil,
            progress: 0,
            status: .notStarted,
            ownerName: "Alice",
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: 0,
            parentId: nil,
            children: [],
            cycleId: nil          // 未设置Cycle
        )

        // Act
        let errors = sut.validateNode(invalidNode)

        // Assert
        XCTAssertTrue(errors.contains(.emptyTitle),
            "应返回emptyTitle错误")
        XCTAssertTrue(errors.contains(.invalidTargetValue),
            "应返回invalidTargetValue错误")
        XCTAssertTrue(errors.contains(.cycleNotSet),
            "应返回cycleNotSet错误")
        XCTAssertGreaterThanOrEqual(errors.count, 3,
            "应返回至少3个错误")
    }
}
