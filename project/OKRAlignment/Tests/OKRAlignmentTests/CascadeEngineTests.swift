import XCTest
@testable import OKRAlignmentShared

// MARK: - CascadeEngineTests

/// 级联计算引擎的完整测试套件
///
/// 本测试类验证CascadeEngine的所有计算逻辑，确保100%分支覆盖。
/// 测试覆盖以下核心算法规则:
///
/// **规则1（叶子KR节点）**: progress = (currentValue / targetValue) x 100, 限制在[0, 100]
/// 如果 targetValue <= 0, 则 progress = 0
///
/// **规则2（有子节点的父节点）**: 先递归计算所有子节点, progress = 所有子节点progress的平均值
///
/// **规则3（无子节点的Objective节点）**: progress = 0
///
/// ## 测试分组
/// - 叶子KR进度计算 (7个测试)
/// - 父节点平均计算 (4个测试)
/// - 完整树计算/Demo数据验证 (2个测试)
/// - 更新叶子并重计算 (5个测试)
/// - 边界测试 (5个测试)
///
/// 总计: 23个测试方法
@MainActor
final class CascadeEngineTests: XCTestCase {

    // MARK: - Properties

    /// 被测系统（System Under Test）
    private var sut: CascadeEngineProtocol!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        sut = OKRCascadeEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - 测试组1: 叶子KR进度计算

    /// 测试: 叶子KR在current等于target时，progress应计算为100%
    ///
    /// Arrange: current=100, target=100
    /// Act: 调用calculateProgress
    /// Assert: progress == 100
    func test_leafKR_calculatesCorrectProgress_100percent() {
        // Arrange
        let node = TestDataFactory.createLeafKR(
            title: "Full Progress KR",
            current: 100,
            target: 100,
            unit: "%",
            owner: "TestOwner",
            scope: .personal
        )

        // Act
        let result = sut.calculateProgress(for: node)

        // Assert
        XCTAssertEqual(result.progress, 100.0, accuracy: 0.001,
            "当currentValue等于targetValue时，progress应为100%")
    }

    /// 测试: 叶子KR在current为target的一半时，progress应计算为50%
    ///
    /// Arrange: current=50, target=100
    /// Act: 调用calculateProgress
    /// Assert: progress == 50
    func test_leafKR_calculatesCorrectProgress_50percent() {
        // Arrange
        let node = TestDataFactory.createLeafKR(
            title: "Half Progress KR",
            current: 50,
            target: 100,
            unit: "%",
            owner: "TestOwner",
            scope: .personal
        )

        // Act
        let result = sut.calculateProgress(for: node)

        // Assert
        XCTAssertEqual(result.progress, 50.0, accuracy: 0.001,
            "当currentValue为targetValue的一半时，progress应为50%")
    }

    /// 测试: 叶子KR在current为0时，progress应计算为0%
    ///
    /// Arrange: current=0, target=100
    /// Act: 调用calculateProgress
    /// Assert: progress == 0
    func test_leafKR_calculatesCorrectProgress_0percent() {
        // Arrange
        let node = TestDataFactory.createNotStartedLeafKR()

        // Act
        let result = sut.calculateProgress(for: node)

        // Assert
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001,
            "当currentValue为0时，progress应为0%")
    }

    /// 测试: 叶子KR的progress不应超过100%
    ///
    /// Arrange: current=150, target=100 (超过目标)
    /// Act: 调用calculateProgress
    /// Assert: progress == 100 (被限制在最大值)
    func test_leafKR_clampsProgressToMax100() {
        // Arrange
        let node = TestDataFactory.createLeafKR(
            title: "Overachiever KR",
            current: 150,
            target: 100,
            unit: "%",
            owner: "TestOwner",
            scope: .personal
        )

        // Act
        let result = sut.calculateProgress(for: node)

        // Assert
        XCTAssertEqual(result.progress, 100.0, accuracy: 0.001,
            "当currentValue超过targetValue时，progress应被限制在100%")
    }

    /// 测试: 叶子KR的progress不应低于0%
    ///
    /// Arrange: current=-50, target=100 (负值)
    /// Act: 调用calculateProgress
    /// Assert: progress == 0 (被限制在最小值)
    func test_leafKR_clampsProgressToMin0() {
        // Arrange
        let node = TestDataFactory.createLeafKR(
            title: "Negative Progress KR",
            current: -50,
            target: 100,
            unit: "%",
            owner: "TestOwner",
            scope: .personal
        )

        // Act
        let result = sut.calculateProgress(for: node)

        // Assert
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001,
            "当currentValue为负数时，progress应被限制在0%")
    }

    /// 测试: 叶子KR在targetValue为0或负数时，progress应为0
    ///
    /// Arrange: current=50, target=0 (无效的目标值)
    /// Act: 调用calculateProgress
    /// Assert: progress == 0 (避免除以零)
    func test_leafKR_withZeroTarget_returnsZeroProgress() {
        // Arrange
        let node = TestDataFactory.createLeafKR(
            title: "Zero Target KR",
            current: 50,
            target: 0,
            unit: "%",
            owner: "TestOwner",
            scope: .personal
        )

        // Act
        let result = sut.calculateProgress(for: node)

        // Assert
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001,
            "当targetValue为0时，progress应为0，避免除以零错误")
    }

    /// 测试: 叶子KR使用小数值得出精确的progress计算结果
    ///
    /// Arrange: current=33.33, target=100
    /// Act: 调用calculateProgress
    /// Assert: progress约等于33.33
    func test_leafKR_withDecimalValues_calculatesAccurately() {
        // Arrange
        let node = TestDataFactory.createLeafKR(
            title: "Decimal KR",
            current: 33.33,
            target: 100,
            unit: "%",
            owner: "TestOwner",
            scope: .personal
        )

        // Act
        let result = sut.calculateProgress(for: node)

        // Assert
        XCTAssertEqual(result.progress, 33.33, accuracy: 0.01,
            "使用小数值时应精确计算progress")
    }

    // MARK: - 测试组2: 父节点平均计算

    /// 测试: 有两个相等子节点的父节点应正确平均子节点progress
    ///
    /// Arrange: 两个子节点progress均为50%
    /// Act: 调用calculateProgress
    /// Assert: 父节点progress == 50
    func test_parentWithTwoEqualChildren_averagesCorrectly() {
        // Arrange
        let child1 = TestDataFactory.createLeafKR(
            title: "KR1", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child2 = TestDataFactory.createLeafKR(
            title: "KR2", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child1, child2]
        )

        // Act
        let result = sut.calculateProgress(for: parent)

        // Assert
        XCTAssertEqual(result.progress, 50.0, accuracy: 0.001,
            "两个50%子节点的父节点progress应为50%")
        XCTAssertEqual(result.children[0].progress, 50.0, accuracy: 0.001,
            "子节点1的progress应被正确计算")
        XCTAssertEqual(result.children[1].progress, 50.0, accuracy: 0.001,
            "子节点2的progress应被正确计算")
    }

    /// 测试: 有两个不等子节点的父节点应正确平均子节点progress
    ///
    /// Arrange: 子节点progress分别为25%和75%
    /// Act: 调用calculateProgress
    /// Assert: 父节点progress == 50
    func test_parentWithTwoDifferentChildren_averagesCorrectly() {
        // Arrange
        let child1 = TestDataFactory.createLeafKR(
            title: "KR1", current: 25, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child2 = TestDataFactory.createLeafKR(
            title: "KR2", current: 75, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child1, child2]
        )

        // Act
        let result = sut.calculateProgress(for: parent)

        // Assert
        XCTAssertEqual(result.progress, 50.0, accuracy: 0.001,
            "25%和75%两个子节点的父节点progress应为50%")
    }

    /// 测试: 只有一个子节点的父节点应返回子节点的progress
    ///
    /// Arrange: 一个子节点progress为42%
    /// Act: 调用calculateProgress
    /// Assert: 父节点progress == 42
    func test_parentWithSingleChild_returnsChildProgress() {
        // Arrange
        let child = TestDataFactory.createLeafKR(
            title: "Single KR", current: 42, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child]
        )

        // Act
        let result = sut.calculateProgress(for: parent)

        // Assert
        XCTAssertEqual(result.progress, 42.0, accuracy: 0.001,
            "单个子节点42%的父节点progress应为42%")
    }

    /// 测试: 有三个子节点的父节点应正确平均所有子节点progress
    ///
    /// Arrange: 三个子节点progress分别为0%, 50%, 100%
    /// Act: 调用calculateProgress
    /// Assert: 父节点progress == 50
    func test_parentWithThreeChildren_averagesCorrectly() {
        // Arrange
        let child1 = TestDataFactory.createLeafKR(
            title: "KR1", current: 0, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child2 = TestDataFactory.createLeafKR(
            title: "KR2", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child3 = TestDataFactory.createLeafKR(
            title: "KR3", current: 100, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child1, child2, child3]
        )

        // Act
        let result = sut.calculateProgress(for: parent)

        // Assert
        let expectedAverage = (0.0 + 50.0 + 100.0) / 3.0
        XCTAssertEqual(result.progress, expectedAverage, accuracy: 0.001,
            "三个子节点0%, 50%, 100%的父节点progress应为平均值 \(expectedAverage)%")
        XCTAssertEqual(result.children.count, 3,
            "父节点应保持3个子节点")
    }

    // MARK: - 测试组3: 完整树计算 (Demo数据验证)

    /// 测试: 使用Demo数据验证完整树级联计算的正确性
    ///
    /// 验证以下计算链:
    /// - Alice的KR1: 20/100 = 20%
    /// - Alice的KR2: 5/50 = 10%
    /// - Alice的O: (20% + 10%) / 2 = 15%
    /// - Bob的KR1: 0/100 = 0%
    /// - Bob的KR2: 30/60 = 50%
    /// - Bob的O: (0% + 50%) / 2 = 25%
    /// - 企业KR1: (15% + 25%) / 2 = 20%
    /// - 企业O: 20% (只有一个子节点)
    func test_calculateTreeProgress_withDemoData_calculatesCorrectly() {
        // Arrange
        let tree = TestDataFactory.createDemoTree()

        // Act
        let result = sut.calculateTreeProgress(root: tree)

        // Assert - 企业根节点
        XCTAssertEqual(result.progress, 20.0, accuracy: 0.001,
            "企业O的progress应为20%")

        // 企业KR1
        XCTAssertEqual(result.children.count, 1,
            "企业O应有1个子节点")
        let enterpriseKR = result.children[0]
        XCTAssertEqual(enterpriseKR.progress, 20.0, accuracy: 0.001,
            "企业KR1的progress应为20%")

        // Alice的O 和 Bob的O
        XCTAssertEqual(enterpriseKR.children.count, 2,
            "企业KR1应有2个子节点(Alice和Bob的Objective)")

        let aliceObjective = enterpriseKR.children[0]
        XCTAssertEqual(aliceObjective.progress, 15.0, accuracy: 0.001,
            "Alice的O progress应为15% (KR1:20% + KR2:10%) / 2")
        XCTAssertEqual(aliceObjective.children.count, 2,
            "Alice的O应有2个KR子节点")
        XCTAssertEqual(aliceObjective.children[0].progress, 20.0, accuracy: 0.001,
            "Alice的KR1 progress应为20% (20/100)")
        XCTAssertEqual(aliceObjective.children[1].progress, 10.0, accuracy: 0.001,
            "Alice的KR2 progress应为10% (5/50)")

        let bobObjective = enterpriseKR.children[1]
        XCTAssertEqual(bobObjective.progress, 25.0, accuracy: 0.001,
            "Bob的O progress应为25% (KR1:0% + KR2:50%) / 2")
        XCTAssertEqual(bobObjective.children.count, 2,
            "Bob的O应有2个KR子节点")
        XCTAssertEqual(bobObjective.children[0].progress, 0.0, accuracy: 0.001,
            "Bob的KR1 progress应为0% (0/100)")
        XCTAssertEqual(bobObjective.children[1].progress, 50.0, accuracy: 0.001,
            "Bob的KR2 progress应为50% (30/60)")
    }

    /// 测试: 深度为4的树结构级联计算
    ///
    /// 树结构:
    /// ```
    /// Root O
    /// └── Level1 O
    ///     └── Level2 KR
    ///         └── Level3 KR (leaf)
    /// ```
    /// 验证递归能正确穿透4层深度
    func test_deepTree_fourLevels_calculatesCorrectly() {
        // Arrange
        let level3Leaf = TestDataFactory.createLeafKR(
            title: "Level3 Leaf", current: 80, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let level2Node = TestDataFactory.createObjective(
            title: "Level2 O", owner: "Bob", scope: .personal, children: [level3Leaf]
        )
        let level1Node = TestDataFactory.createObjective(
            title: "Level1 O", owner: "Bob", scope: .enterprise, children: [level2Node]
        )
        let rootNode = TestDataFactory.createEnterpriseRoot(
            title: "Root O", owner: "CEO", children: [level1Node]
        )

        // Act
        let result = sut.calculateTreeProgress(root: rootNode)

        // Assert
        XCTAssertEqual(result.progress, 80.0, accuracy: 0.001,
            "4层深度树的根节点progress应为80%")
        XCTAssertEqual(result.children[0].progress, 80.0, accuracy: 0.001,
            "第1层节点progress应为80%")
        XCTAssertEqual(result.children[0].children[0].progress, 80.0, accuracy: 0.001,
            "第2层节点progress应为80%")
        XCTAssertEqual(result.children[0].children[0].children[0].progress, 80.0, accuracy: 0.001,
            "第3层叶子节点progress应为80%")
    }

    // MARK: - 测试组4: 更新叶子并重计算

    /// 测试: 更新叶子节点的currentValue并重新计算整棵树
    ///
    /// Arrange: 一个叶子节点current=50
    /// Act: 更新为current=75
    /// Assert: 叶子节点progress更新为75%
    func test_updateLeafAndRecalculate_updatesValue() {
        // Arrange
        let leaf = TestDataFactory.createLeafKR(
            title: "Update KR", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [leaf]
        )
        let leafId = leaf.id

        // Act
        let result = sut.updateLeafAndRecalculate(treeRoot: parent, leafId: leafId, newValue: 75)

        // Assert
        XCTAssertEqual(result.children[0].currentValue, 75.0,
            "叶子节点的currentValue应更新为75")
        XCTAssertEqual(result.children[0].progress, 75.0, accuracy: 0.001,
            "叶子节点的progress应重新计算为75%")
    }

    /// 测试: 更新叶子节点的值应级联传播到根节点
    ///
    /// Arrange: 包含两个叶子的树
    /// Act: 更新其中一个叶子
    /// Assert: 父节点progress正确反映更新后的平均值
    func test_updateLeafAndRecalculate_propagatesToRoot() {
        // Arrange
        let leaf1 = TestDataFactory.createLeafKR(
            title: "KR1", current: 0, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let leaf2 = TestDataFactory.createLeafKR(
            title: "KR2", current: 0, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [leaf1, leaf2]
        )
        let leafId = leaf1.id

        // Act - 将leaf1从0更新为100
        let result = sut.updateLeafAndRecalculate(treeRoot: parent, leafId: leafId, newValue: 100)

        // Assert - parent progress应为 (100 + 0) / 2 = 50%
        XCTAssertEqual(result.children[0].progress, 100.0, accuracy: 0.001,
            "被更新的叶子progress应为100%")
        XCTAssertEqual(result.children[1].progress, 0.0, accuracy: 0.001,
            "未被更新的叶子progress应保持0%")
        XCTAssertEqual(result.progress, 50.0, accuracy: 0.001,
            "父节点的progress应级联更新为平均值50%")
    }

    /// 测试: 更新叶子的值为负数时，progress应被限制为0
    ///
    /// Arrange: 叶子节点current=50
    /// Act: 更新为newValue=-10
    /// Assert: progress == 0
    func test_updateLeafAndRecalculate_clampsToMinZero() {
        // Arrange
        let leaf = TestDataFactory.createLeafKR(
            title: "Clamp KR", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [leaf]
        )

        // Act
        let result = sut.updateLeafAndRecalculate(treeRoot: parent, leafId: leaf.id, newValue: -10)

        // Assert
        XCTAssertEqual(result.children[0].progress, 0.0, accuracy: 0.001,
            "负数currentValue的progress应被限制在0%")
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001,
            "父节点progress也应为0%")
    }

    /// 测试: 更新叶子的值超过target时，progress应被限制为100
    ///
    /// Arrange: 叶子节点target=100, current=50
    /// Act: 更新为newValue=200
    /// Assert: progress == 100
    func test_updateLeafAndRecalculate_clampsToMaxTarget() {
        // Arrange
        let leaf = TestDataFactory.createLeafKR(
            title: "Max KR", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [leaf]
        )

        // Act
        let result = sut.updateLeafAndRecalculate(treeRoot: parent, leafId: leaf.id, newValue: 200)

        // Assert
        XCTAssertEqual(result.children[0].progress, 100.0, accuracy: 0.001,
            "超过target的currentValue的progress应被限制在100%")
        XCTAssertEqual(result.progress, 100.0, accuracy: 0.001,
            "父节点progress也应为100%")
    }

    /// 测试: 更新不存在的叶子节点ID应返回原始树结构
    ///
    /// Arrange: 一个树结构
    /// Act: 使用不存在的UUID调用updateLeafAndRecalculate
    /// Assert: 返回的数与原始树相同（进度按规则重新计算）
    func test_updateLeafAndRecalculate_nonExistentLeaf_returnsOriginal() {
        // Arrange
        let leaf = TestDataFactory.createLeafKR(
            title: "Real KR", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [leaf]
        )
        let nonExistentId = UUID()

        // Act
        let result = sut.updateLeafAndRecalculate(treeRoot: parent, leafId: nonExistentId, newValue: 99)

        // Assert
        XCTAssertEqual(result.children[0].currentValue, 50.0,
            "不存在的叶子ID不应影响原始currentValue")
    }

    // MARK: - 测试组5: 边界测试

    /// 测试: 无子节点的Objective节点progress应为0
    ///
    /// Arrange: 空Objective节点
    /// Act: 调用calculateProgress
    /// Assert: progress == 0
    func test_emptyObjective_returnsZeroProgress() {
        // Arrange
        let emptyObjective = TestDataFactory.createEmptyObjective(
            title: "Empty O", owner: "Alice", scope: .personal
        )

        // Act
        let result = sut.calculateProgress(for: emptyObjective)

        // Assert
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001,
            "无子节点的Objective节点progress应为0%")
    }

    /// 测试: 非常深的树不应导致栈溢出
    ///
    /// Arrange: 深度为1000的树
    /// Act: 调用calculateTreeProgress
    /// Assert: 成功返回结果，progress为100%
    func test_veryDeepTree_noStackOverflow() {
        // Arrange
        let deepTree = TestDataFactory.createDeepTree(depth: 1000)

        // Act & Assert - 不应抛出异常或崩溃
        let result = sut.calculateTreeProgress(root: deepTree)
        XCTAssertEqual(result.progress, 100.0, accuracy: 0.001,
            "深度为1000的树应正确计算progress，不应栈溢出")
    }

    /// 测试: 单节点树（只有根节点且是叶子KR）应正确计算
    ///
    /// Arrange: 单个叶子KR作为树的根节点
    /// Act: 调用calculateTreeProgress
    /// Assert: progress按叶子KR规则计算
    func test_singleNodeTree_calculatesCorrectly() {
        // Arrange
        let singleNode = TestDataFactory.createLeafKR(
            title: "Single Node", current: 75, target: 100, unit: "%", owner: "Alice", scope: .personal
        )

        // Act
        let result = sut.calculateTreeProgress(root: singleNode)

        // Assert
        XCTAssertEqual(result.progress, 75.0, accuracy: 0.001,
            "单节点叶子KR的progress应为75%")
    }

    /// 测试: 所有子节点progress为0的父节点应返回0
    ///
    /// Arrange: 三个子节点progress均为0%
    /// Act: 调用calculateProgress
    /// Assert: 父节点progress == 0
    func test_allZeroChildren_returnsZero() {
        // Arrange
        let child1 = TestDataFactory.createLeafKR(
            title: "KR1", current: 0, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child2 = TestDataFactory.createLeafKR(
            title: "KR2", current: 0, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child3 = TestDataFactory.createLeafKR(
            title: "KR3", current: 0, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child1, child2, child3]
        )

        // Act
        let result = sut.calculateProgress(for: parent)

        // Assert
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001,
            "所有子节点progress为0时，父节点progress应为0%")
    }

    /// 测试: 所有子节点progress为100的父节点应返回100
    ///
    /// Arrange: 三个已完成子节点
    /// Act: 调用calculateProgress
    /// Assert: 父节点progress == 100
    func test_allCompletedChildren_returns100() {
        // Arrange
        let child1 = TestDataFactory.createCompletedLeafKR(title: "KR1", owner: "Alice")
        let child2 = TestDataFactory.createCompletedLeafKR(title: "KR2", owner: "Alice")
        let child3 = TestDataFactory.createCompletedLeafKR(title: "KR3", owner: "Alice")
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child1, child2, child3]
        )

        // Act
        let result = sut.calculateProgress(for: parent)

        // Assert
        XCTAssertEqual(result.progress, 100.0, accuracy: 0.001,
            "所有子节点progress为100%时，父节点progress应为100%")
    }

    // MARK: - 测试组6: 加权进度计算

    /// 测试: 不同权重的子节点应正确计算加权平均进度
    ///
    /// Arrange: KR1 progress=50 weight=2.0, KR2 progress=100 weight=1.0
    /// Act: 调用calculateProgress
    /// Assert: 父节点progress == (50×2 + 100×1) / (2+1) = 66.67
    func test_weightedProgress_calculatesCorrectly() {
        // Arrange
        var child1 = TestDataFactory.createLeafKR(
            title: "Heavy KR", current: 50, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        child1.weight = 2.0
        let child2 = TestDataFactory.createLeafKR(
            title: "Normal KR", current: 100, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child1, child2]
        )

        // Act
        let result = sut.calculateProgress(for: parent)

        // Assert: (50*2 + 100*1) / (2+1) = 200/3 ≈ 66.67
        let expected = (50.0 * 2.0 + 100.0 * 1.0) / (2.0 + 1.0)
        XCTAssertEqual(result.progress, expected, accuracy: 0.01,
            "加权平均进度应为 \(expected)%")
    }

    /// 测试: 默认权重(1.0)应退化为简单算术平均
    ///
    /// Arrange: 两个子节点progress分别为40%和80%，weight均为1.0
    /// Act: 调用calculateProgress
    /// Assert: 父节点progress == 60%（与非加权平均相同）
    func test_defaultWeight_behavesLikeSimpleAverage() {
        // Arrange
        let child1 = TestDataFactory.createLeafKR(
            title: "KR1", current: 40, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let child2 = TestDataFactory.createLeafKR(
            title: "KR2", current: 80, target: 100, unit: "%", owner: "Alice", scope: .personal
        )
        let parent = TestDataFactory.createObjective(
            title: "Parent O", owner: "Alice", scope: .personal, children: [child1, child2]
        )

        // Act
        let result = sut.calculateProgress(for: parent)

        // Assert: (40 + 80) / 2 = 60
        XCTAssertEqual(result.progress, 60.0, accuracy: 0.001,
            "默认权重1.0应退化为简单算术平均")
    }
}
