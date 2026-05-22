import XCTest
@testable import OKRAlignment

// MARK: - EntityMappingTests

/// Entity到Domain模型映射的完整测试套件
///
/// 本测试类验证Core Data Entity与Domain模型之间的双向映射逻辑，
/// 确保所有字段正确转换、可选字段安全处理、子节点递归映射无误。
///
/// ## 测试覆盖
/// - Entity到Domain正向映射 (3个测试)
/// - Domain到Entity反向映射 (2个测试)
/// - 往返映射数据一致性 (1个测试)
///
/// ## 映射规则
/// - Entity可选字段为nil时，Domain对应字段也为nil
/// - 子节点通过父子关系递归映射
/// - 日期类型直接透传（都是Date类型）
/// - 枚举类型通过rawValue转换
///
/// 总计: 6个测试方法
@MainActor
final class EntityMappingTests: XCTestCase {

    // MARK: - Properties

    /// 被测系统引用（EntityMapper实例）
    private var sut: EntityMapper!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        sut = EntityMapper()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - 测试: Entity到Domain正向映射

    /// 测试: Entity映射到Domain应正确转换所有字段
    ///
    /// Arrange: 创建一个所有字段都有值的OKRNodeEntity
    /// Act: 调用mapEntityToDomain
    /// Assert: Domain模型的所有字段与Entity一致
    func test_mapEntityToDomain_convertsAllFields() {
        // Arrange
        let entityId = UUID()
        let cycleId = UUID()
        let parentId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1700000000)
        let updatedAt = Date(timeIntervalSince1970: 1700100000)

        let entity = OKRNodeEntity(
            id: entityId,
            title: "测试目标",
            nodeDescription: "测试描述",
            nodeType: "objective",
            scope: "enterprise",
            currentValue: 50,
            targetValue: 100,
            unit: "%",
            progress: 25.5,
            status: "in_progress",
            ownerName: "Alice",
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: 3,
            parentId: parentId,
            cycleId: cycleId,
            children: []
        )

        // Act
        let domain = sut.mapEntityToDomain(entity)

        // Assert
        XCTAssertEqual(domain.id, entityId, "id应正确映射")
        XCTAssertEqual(domain.title, "测试目标", "title应正确映射")
        XCTAssertEqual(domain.nodeDescription, "测试描述", "nodeDescription应正确映射")
        XCTAssertEqual(domain.nodeType, .objective, "nodeType应正确映射为枚举")
        XCTAssertEqual(domain.scope, .enterprise, "scope应正确映射为枚举")
        XCTAssertEqual(domain.currentValue, 50, "currentValue应正确映射")
        XCTAssertEqual(domain.targetValue, 100, "targetValue应正确映射")
        XCTAssertEqual(domain.unit, "%", "unit应正确映射")
        XCTAssertEqual(domain.progress, 25.5, accuracy: 0.001, "progress应正确映射")
        XCTAssertEqual(domain.status, .inProgress, "status应正确映射为枚举")
        XCTAssertEqual(domain.ownerName, "Alice", "ownerName应正确映射")
        XCTAssertEqual(domain.createdAt, createdAt, "createdAt应正确映射")
        XCTAssertEqual(domain.updatedAt, updatedAt, "updatedAt应正确映射")
        XCTAssertEqual(domain.sortOrder, 3, "sortOrder应正确映射")
        XCTAssertEqual(domain.parentId, parentId, "parentId应正确映射")
        XCTAssertEqual(domain.cycleId, cycleId, "cycleId应正确映射")
        XCTAssertTrue(domain.children.isEmpty, "children应正确映射为空数组")
    }

    /// 测试: 带子节点的Entity应递归映射所有子节点
    ///
    /// Arrange: 创建一个父Entity，包含两个子Entity
    /// Act: 调用mapEntityToDomain
    /// Assert: Domain模型包含正确数量的子节点，且子节点字段正确
    func test_mapEntityToDomain_withChildren_recursiveMapping() {
        // Arrange
        let childEntity1 = OKRNodeEntity(
            id: UUID(),
            title: "子KR1",
            nodeDescription: nil,
            nodeType: "key_result",
            scope: "personal",
            currentValue: 30,
            targetValue: 100,
            unit: "%",
            progress: 30,
            status: "in_progress",
            ownerName: "Alice",
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: 0,
            parentId: nil,
            cycleId: UUID(),
            children: []
        )
        let childEntity2 = OKRNodeEntity(
            id: UUID(),
            title: "子KR2",
            nodeDescription: nil,
            nodeType: "key_result",
            scope: "personal",
            currentValue: 60,
            targetValue: 100,
            unit: "%",
            progress: 60,
            status: "in_progress",
            ownerName: "Bob",
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: 1,
            parentId: nil,
            cycleId: UUID(),
            children: []
        )
        let parentEntity = OKRNodeEntity(
            id: UUID(),
            title: "父Objective",
            nodeDescription: nil,
            nodeType: "objective",
            scope: "enterprise",
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 45,
            status: "in_progress",
            ownerName: "CTO",
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: 0,
            parentId: nil,
            cycleId: UUID(),
            children: [childEntity1, childEntity2]
        )

        // Act
        let domain = sut.mapEntityToDomain(parentEntity)

        // Assert
        XCTAssertEqual(domain.children.count, 2, "应正确映射2个子节点")
        XCTAssertEqual(domain.children[0].title, "子KR1", "第1个子节点title应正确")
        XCTAssertEqual(domain.children[0].nodeType, .keyResult, "第1个子节点nodeType应为keyResult")
        XCTAssertEqual(domain.children[0].currentValue, 30, "第1个子节点currentValue应正确")
        XCTAssertEqual(domain.children[1].title, "子KR2", "第2个子节点title应正确")
        XCTAssertEqual(domain.children[1].nodeType, .keyResult, "第2个子节点nodeType应为keyResult")
        XCTAssertEqual(domain.children[1].ownerName, "Bob", "第2个子节点ownerName应正确")
    }

    /// 测试: Entity的可选字段为nil时，Domain对应字段也应为nil
    ///
    /// Arrange: 创建一个nodeDescription、unit、parentId、cycleId均为nil的Entity
    /// Act: 调用mapEntityToDomain
    /// Assert: Domain模型的可选字段均为nil
    func test_mapEntityToDomain_withNilOptionalFields() {
        // Arrange
        let entity = OKRNodeEntity(
            id: UUID(),
            title: "无可选字段",
            nodeDescription: nil,
            nodeType: "objective",
            scope: "personal",
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 0,
            status: "not_started",
            ownerName: "Alice",
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: 0,
            parentId: nil,
            cycleId: nil,
            children: []
        )

        // Act
        let domain = sut.mapEntityToDomain(entity)

        // Assert
        XCTAssertNil(domain.nodeDescription, "nodeDescription为nil时应映射为nil")
        XCTAssertNil(domain.unit, "unit为nil时应映射为nil")
        XCTAssertNil(domain.parentId, "parentId为nil时应映射为nil")
        XCTAssertNil(domain.cycleId, "cycleId为nil时应映射为nil")
    }

    // MARK: - 测试: Domain到Entity反向映射

    /// 测试: Domain模型映射到Entity应创建正确的Entity对象
    ///
    /// Arrange: 创建一个所有字段都有值的Domain模型
    /// Act: 调用mapDomainToEntity
    /// Assert: Entity的所有字段与Domain一致
    func test_mapDomainToEntity_createsCorrectEntity() {
        // Arrange
        let nodeId = UUID()
        let cycleId = UUID()
        let parentId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1700000000)
        let updatedAt = Date(timeIntervalSince1970: 1700100000)

        let domain = OKRNode(
            id: nodeId,
            title: "Domain目标",
            nodeDescription: "Domain描述",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 75,
            targetValue: 150,
            unit: "个",
            progress: 50,
            status: .atRisk,
            ownerName: "Bob",
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: 5,
            parentId: parentId,
            children: [],
            cycleId: cycleId
        )

        // Act
        let entity = sut.mapDomainToEntity(domain)

        // Assert
        XCTAssertEqual(entity.id, nodeId, "id应正确映射")
        XCTAssertEqual(entity.title, "Domain目标", "title应正确映射")
        XCTAssertEqual(entity.nodeDescription, "Domain描述", "nodeDescription应正确映射")
        XCTAssertEqual(entity.nodeType, "key_result", "nodeType应映射为rawValue")
        XCTAssertEqual(entity.scope, "personal", "scope应映射为rawValue")
        XCTAssertEqual(entity.currentValue, 75, "currentValue应正确映射")
        XCTAssertEqual(entity.targetValue, 150, "targetValue应正确映射")
        XCTAssertEqual(entity.unit, "个", "unit应正确映射")
        XCTAssertEqual(entity.progress, 50, accuracy: 0.001, "progress应正确映射")
        XCTAssertEqual(entity.status, "at_risk", "status应映射为rawValue")
        XCTAssertEqual(entity.ownerName, "Bob", "ownerName应正确映射")
        XCTAssertEqual(entity.createdAt, createdAt, "createdAt应正确映射")
        XCTAssertEqual(entity.updatedAt, updatedAt, "updatedAt应正确映射")
        XCTAssertEqual(entity.sortOrder, 5, "sortOrder应正确映射")
        XCTAssertEqual(entity.parentId, parentId, "parentId应正确映射")
        XCTAssertEqual(entity.cycleId, cycleId, "cycleId应正确映射")
    }

    /// 测试: Domain到Entity映射时应更新已存在的Entity而不是创建新的
    ///
    /// Arrange: 一个已存在的Entity和一个对应的Domain模型（不同字段值）
    /// Act: 调用mapDomainToEntity传入existingEntity
    /// Assert: 已存在的Entity被更新，ID保持不变
    func test_mapDomainToEntity_updatesExistingEntity() {
        // Arrange
        let existingId = UUID()
        let existingEntity = OKRNodeEntity(
            id: existingId,
            title: "旧标题",
            nodeDescription: "旧描述",
            nodeType: "objective",
            scope: "enterprise",
            currentValue: 10,
            targetValue: 50,
            unit: "%",
            progress: 20,
            status: "not_started",
            ownerName: "OldOwner",
            createdAt: Date(timeIntervalSince1970: 1600000000),
            updatedAt: Date(timeIntervalSince1970: 1600000000),
            sortOrder: 0,
            parentId: nil,
            cycleId: nil,
            children: []
        )

        let updatedDomain = OKRNode(
            id: existingId,
            title: "新标题",
            nodeDescription: "新描述",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 80,
            targetValue: 100,
            unit: "个",
            progress: 80,
            status: .completed,
            ownerName: "NewOwner",
            createdAt: existingEntity.createdAt, // 保持创建时间
            updatedAt: Date(timeIntervalSince1970: 1700000000),
            sortOrder: 2,
            parentId: UUID(),
            children: [],
            cycleId: UUID()
        )

        // Act
        let result = sut.mapDomainToEntity(updatedDomain, existingEntity: existingEntity)

        // Assert
        XCTAssertEqual(result.id, existingId, "ID应保持不变")
        XCTAssertEqual(result.title, "新标题", "title应被更新")
        XCTAssertEqual(result.nodeDescription, "新描述", "nodeDescription应被更新")
        XCTAssertEqual(result.nodeType, "key_result", "nodeType应被更新")
        XCTAssertEqual(result.scope, "personal", "scope应被更新")
        XCTAssertEqual(result.currentValue, 80, "currentValue应被更新")
        XCTAssertEqual(result.targetValue, 100, "targetValue应被更新")
        XCTAssertEqual(result.unit, "个", "unit应被更新")
        XCTAssertEqual(result.progress, 80, accuracy: 0.001, "progress应被更新")
        XCTAssertEqual(result.status, "completed", "status应被更新")
        XCTAssertEqual(result.ownerName, "NewOwner", "ownerName应被更新")
        XCTAssertEqual(result.sortOrder, 2, "sortOrder应被更新")
        XCTAssertNotNil(result.parentId, "parentId应被更新")
        XCTAssertNotNil(result.cycleId, "cycleId应被更新")
    }

    // MARK: - 测试: 往返映射

    /// 测试: Entity->Domain->Entity往返映射应保持数据一致性
    ///
    /// Arrange: 创建一个完整的Entity（含子节点）
    /// Act: Entity->Domain->Entity往返映射
    /// Assert: 最终Entity与原始Entity的所有关键字段一致
    func test_roundTripMapping_preservesAllData() {
        // Arrange
        let childEntity = OKRNodeEntity(
            id: UUID(),
            title: "子节点",
            nodeDescription: "子描述",
            nodeType: "key_result",
            scope: .personal,
            currentValue: 40,
            targetValue: 80,
            unit: "%",
            progress: 50,
            status: "in_progress",
            ownerName: "ChildOwner",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            updatedAt: Date(timeIntervalSince1970: 1700100000),
            sortOrder: 1,
            parentId: nil,
            cycleId: UUID(),
            children: []
        )
        let originalEntity = OKRNodeEntity(
            id: UUID(),
            title: "父节点",
            nodeDescription: "父描述",
            nodeType: "objective",
            scope: .enterprise,
            currentValue: 0,
            targetValue: 0,
            unit: nil,
            progress: 50,
            status: "in_progress",
            ownerName: "ParentOwner",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            updatedAt: Date(timeIntervalSince1970: 1700100000),
            sortOrder: 0,
            parentId: nil,
            cycleId: UUID(),
            children: [childEntity]
        )

        // Act
        let domain = sut.mapEntityToDomain(originalEntity)
        let roundTripEntity = sut.mapDomainToEntity(domain)

        // Assert
        XCTAssertEqual(roundTripEntity.id, originalEntity.id, "往返后id应保持一致")
        XCTAssertEqual(roundTripEntity.title, originalEntity.title, "往返后title应保持一致")
        XCTAssertEqual(roundTripEntity.nodeDescription, originalEntity.nodeDescription, "往返后nodeDescription应保持一致")
        XCTAssertEqual(roundTripEntity.nodeType, originalEntity.nodeType, "往返后nodeType应保持一致")
        XCTAssertEqual(roundTripEntity.scope, originalEntity.scope, "往返后scope应保持一致")
        XCTAssertEqual(roundTripEntity.currentValue, originalEntity.currentValue, "往返后currentValue应保持一致")
        XCTAssertEqual(roundTripEntity.targetValue, originalEntity.targetValue, "往返后targetValue应保持一致")
        XCTAssertEqual(roundTripEntity.unit, originalEntity.unit, "往返后unit应保持一致")
        XCTAssertEqual(roundTripEntity.progress, originalEntity.progress, accuracy: 0.001, "往返后progress应保持一致")
        XCTAssertEqual(roundTripEntity.status, originalEntity.status, "往返后status应保持一致")
        XCTAssertEqual(roundTripEntity.ownerName, originalEntity.ownerName, "往返后ownerName应保持一致")
        XCTAssertEqual(roundTripEntity.sortOrder, originalEntity.sortOrder, "往返后sortOrder应保持一致")
        XCTAssertEqual(roundTripEntity.children.count, originalEntity.children.count, "往返后children数量应保持一致")

        // 验证子节点
        XCTAssertEqual(roundTripEntity.children[0].id, childEntity.id, "子节点id应保持一致")
        XCTAssertEqual(roundTripEntity.children[0].title, childEntity.title, "子节点title应保持一致")
        XCTAssertEqual(roundTripEntity.children[0].nodeType, childEntity.nodeType, "子节点nodeType应保持一致")
        XCTAssertEqual(roundTripEntity.children[0].currentValue, childEntity.currentValue, "子节点currentValue应保持一致")
    }
}

// MARK: - Supporting Types

/// Entity映射器 - 负责Entity和Domain模型之间的双向转换
///
/// 在实际项目中，这个类通常由Core Data或SwiftData的映射层提供。
/// 这里提供一个简化版本用于测试。
final class EntityMapper {

    /// 将OKRNodeEntity映射为OKRNode Domain模型
    func mapEntityToDomain(_ entity: OKRNodeEntity) -> OKRNode {
        OKRNode(
            id: entity.id,
            title: entity.title,
            nodeDescription: entity.nodeDescription,
            nodeType: NodeType(rawValue: entity.nodeType) ?? .objective,
            scope: Scope(rawValue: entity.scope) ?? .personal,
            currentValue: entity.currentValue,
            targetValue: entity.targetValue,
            unit: entity.unit,
            progress: entity.progress,
            status: NodeStatus(rawValue: entity.status) ?? .notStarted,
            ownerName: entity.ownerName,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            sortOrder: entity.sortOrder,
            parentId: entity.parentId,
            children: entity.children.map { mapEntityToDomain($0) },
            cycleId: entity.cycleId
        )
    }

    /// 将OKRNode Domain模型映射为OKRNodeEntity
    ///
    /// - Parameters:
    ///   - domain: Domain模型
    ///   - existingEntity: 可选的已存在Entity，如果提供则更新该Entity
    /// - Returns: 映射后的OKRNodeEntity
    func mapDomainToEntity(_ domain: OKRNode, existingEntity: OKRNodeEntity? = nil) -> OKRNodeEntity {
        let entity = existingEntity ?? OKRNodeEntity(
            id: domain.id,
            title: domain.title,
            nodeDescription: domain.nodeDescription,
            nodeType: domain.nodeType.rawValue,
            scope: domain.scope.rawValue,
            currentValue: domain.currentValue,
            targetValue: domain.targetValue,
            unit: domain.unit,
            progress: domain.progress,
            status: domain.status.rawValue,
            ownerName: domain.ownerName,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            sortOrder: domain.sortOrder,
            parentId: domain.parentId,
            cycleId: domain.cycleId,
            children: domain.children.map { mapDomainToEntity($0) }
        )

        if existingEntity != nil {
            entity.title = domain.title
            entity.nodeDescription = domain.nodeDescription
            entity.nodeType = domain.nodeType.rawValue
            entity.scope = domain.scope.rawValue
            entity.currentValue = domain.currentValue
            entity.targetValue = domain.targetValue
            entity.unit = domain.unit
            entity.progress = domain.progress
            entity.status = domain.status.rawValue
            entity.ownerName = domain.ownerName
            entity.updatedAt = domain.updatedAt
            entity.sortOrder = domain.sortOrder
            entity.parentId = domain.parentId
            entity.cycleId = domain.cycleId
            entity.children = domain.children.map { mapDomainToEntity($0) }
        }

        return entity
    }
}

// MARK: - Entity Type

/// 模拟Core Data Entity的简化结构，用于测试映射逻辑
///
/// 在实际项目中，这是由Core Data生成的NSManagedObject子类。
/// 这里提供一个值类型版本用于单元测试（避免依赖Core Data框架）。
final class OKRNodeEntity {
    var id: UUID
    var title: String
    var nodeDescription: String?
    var nodeType: String
    var scope: String
    var currentValue: Double
    var targetValue: Double
    var unit: String?
    var progress: Double
    var status: String
    var ownerName: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var parentId: UUID?
    var cycleId: UUID?
    var children: [OKRNodeEntity]

    init(
        id: UUID,
        title: String,
        nodeDescription: String?,
        nodeType: String,
        scope: String,
        currentValue: Double,
        targetValue: Double,
        unit: String?,
        progress: Double,
        status: String,
        ownerName: String,
        createdAt: Date,
        updatedAt: Date,
        sortOrder: Int,
        parentId: UUID?,
        cycleId: UUID?,
        children: [OKRNodeEntity]
    ) {
        self.id = id
        self.title = title
        self.nodeDescription = nodeDescription
        self.nodeType = nodeType
        self.scope = scope
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.unit = unit
        self.progress = progress
        self.status = status
        self.ownerName = ownerName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.parentId = parentId
        self.cycleId = cycleId
        self.children = children
    }
}
