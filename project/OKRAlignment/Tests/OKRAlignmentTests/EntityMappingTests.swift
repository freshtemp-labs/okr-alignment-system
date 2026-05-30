import XCTest
import CoreData
@testable import OKRAlignmentShared

// MARK: - EntityMappingTests
//
// Tests the REAL `EntityToDomainMapper` and `DomainToEntityMapper` against
// actual `NSManagedObject` instances backed by an in-memory CoreData store.
//
// Total: 12 test methods — all exercising production mapper code.

@MainActor
final class EntityMappingTests: XCTestCase {

    // MARK: - Properties

    nonisolated(unsafe) private var stack: CoreDataTestStack!
    nonisolated(unsafe) private var context: NSManagedObjectContext!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            stack = CoreDataTestStack()
            context = stack.container.viewContext
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            context = nil
            stack = nil
        }
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a real `OKRNodeEntity` in the context with all fields set.
    private func makeNodeEntity(
        id: UUID = UUID(),
        title: String = "Test Node",
        nodeType: String = "objective",
        scope: String = "enterprise",
        status: String = "in_progress",
        currentValue: Double = 0,
        targetValue: Double = 0,
        unit: String? = nil,
        progress: Double = 0,
        ownerName: String = "Alice",
        parentId: UUID? = nil,
        cycleId: UUID? = nil,
        sortOrder: Int64 = 0
    ) -> OKRNodeEntity {
        let entity = OKRNodeEntity(context: context)
        entity.id = id
        entity.title = title
        entity.nodeDescription = "\(title) description"
        entity.nodeType = nodeType
        entity.scope = scope
        entity.currentValue = currentValue
        entity.targetValue = targetValue
        entity.unit = unit
        entity.progress = progress
        entity.status = status
        entity.ownerName = ownerName
        entity.sortOrder = sortOrder
        entity.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        entity.updatedAt = Date(timeIntervalSince1970: 1_700_100_000)
        entity.parentId = parentId
        entity.cycleId = cycleId
        return entity
    }

    private func makeCycleEntity(
        id: UUID = UUID(),
        name: String = "Q1 2026"
    ) -> OKRCycleEntity {
        let entity = OKRCycleEntity(context: context)
        entity.id = id
        entity.name = name
        entity.startDate = Date(timeIntervalSince1970: 1_700_000_000)
        entity.endDate = Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 90)
        entity.isActive = true
        entity.isArchived = false
        return entity
    }

    // MARK: - Entity → Domain (Node)

    func test_entityToDomain_convertsAllFields() throws {
        let id = UUID()
        let cycleId = UUID()
        let parentId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_100_000)

        let entity = makeNodeEntity(
            id: id,
            title: "My Objective",
            nodeType: "objective",
            scope: "enterprise",
            status: "in_progress",
            currentValue: 50,
            targetValue: 100,
            unit: "%",
            progress: 50,
            ownerName: "Bob",
            parentId: parentId,
            cycleId: cycleId,
            sortOrder: 3
        )
        entity.nodeDescription = "Detailed description"
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt

        let domain = try EntityToDomainMapper.map(entity: entity)

        XCTAssertEqual(domain.id, id)
        XCTAssertEqual(domain.title, "My Objective")
        XCTAssertEqual(domain.nodeDescription, "Detailed description")
        XCTAssertEqual(domain.nodeType, .objective)
        XCTAssertEqual(domain.scope, .enterprise)
        XCTAssertEqual(domain.currentValue, 50)
        XCTAssertEqual(domain.targetValue, 100)
        XCTAssertEqual(domain.unit, "%")
        XCTAssertEqual(domain.progress, 50, accuracy: 0.001)
        XCTAssertEqual(domain.status, .inProgress)
        XCTAssertEqual(domain.ownerName, "Bob")
        XCTAssertEqual(domain.createdAt, createdAt)
        XCTAssertEqual(domain.updatedAt, updatedAt)
        XCTAssertEqual(domain.sortOrder, 3)
        XCTAssertEqual(domain.parentId, parentId)
        XCTAssertEqual(domain.cycleId, cycleId)
        XCTAssertEqual(domain.weight, 1.0, accuracy: 0.001)
        XCTAssertEqual(domain.version, 0)
    }

    func test_entityToDomain_withChildren_recursiveMapping() throws {
        let child1 = makeNodeEntity(title: "KR1", nodeType: "key_result", scope: "personal", currentValue: 30, targetValue: 100, progress: 30)
        let child2 = makeNodeEntity(title: "KR2", nodeType: "key_result", scope: "personal", currentValue: 60, targetValue: 100, progress: 60)
        let parent = makeNodeEntity(title: "Parent O", nodeType: "objective", scope: "enterprise")
        parent.children = NSOrderedSet(array: [child1, child2])
        child1.parent = parent
        child2.parent = parent

        let domain = try EntityToDomainMapper.map(entity: parent)

        XCTAssertEqual(domain.children.count, 2)
        XCTAssertEqual(domain.children[0].title, "KR1")
        XCTAssertEqual(domain.children[0].nodeType, .keyResult)
        XCTAssertEqual(domain.children[0].currentValue, 30)
        XCTAssertEqual(domain.children[1].title, "KR2")
        XCTAssertEqual(domain.children[1].currentValue, 60)
    }

    func test_entityToDomain_withNilOptionalFields() throws {
        let entity = makeNodeEntity(title: "Sparse Node", unit: nil)
        entity.nodeDescription = nil
        entity.cycleId = nil
        entity.parentId = nil

        let domain = try EntityToDomainMapper.map(entity: entity)

        XCTAssertNil(domain.nodeDescription)
        XCTAssertNil(domain.unit)
        XCTAssertNil(domain.parentId)
        XCTAssertNil(domain.cycleId)
        XCTAssertTrue(domain.children.isEmpty)
    }

    func test_entityToDomain_invalidNodeType_throws() {
        let entity = makeNodeEntity(nodeType: "bogus_type")

        XCTAssertThrowsError(try EntityToDomainMapper.map(entity: entity)) { error in
            guard case EntityToDomainMapper.MappingError.invalidEnumValue = error else {
                return XCTFail("Expected MappingError.invalidEnumValue, got \(error)")
            }
        }
    }

    func test_entityToDomain_invalidScope_throws() {
        let entity = makeNodeEntity(scope: "galaxy")

        XCTAssertThrowsError(try EntityToDomainMapper.map(entity: entity)) { error in
            guard case EntityToDomainMapper.MappingError.invalidEnumValue = error else {
                return XCTFail("Expected MappingError.invalidEnumValue, got \(error)")
            }
        }
    }

    func test_entityToDomain_invalidStatus_throws() {
        let entity = makeNodeEntity(status: "unknown_status")

        XCTAssertThrowsError(try EntityToDomainMapper.map(entity: entity)) { error in
            guard case EntityToDomainMapper.MappingError.invalidEnumValue = error else {
                return XCTFail("Expected MappingError.invalidEnumValue, got \(error)")
            }
        }
    }

    // MARK: - Domain → Entity (Node)

    func test_domainToEntity_createsNewEntity() throws {
        let cycleEntity = makeCycleEntity()
        try context.save()

        let domain = OKRNode(
            title: "Domain Node",
            nodeDescription: "Description",
            nodeType: .keyResult,
            scope: .personal,
            currentValue: 75,
            targetValue: 150,
            unit: "个",
            progress: 50,
            status: .atRisk,
            ownerName: "Charlie",
            sortOrder: 5,
            cycleId: cycleEntity.id
        )

        let entity = try DomainToEntityMapper.map(domain: domain, context: context)

        XCTAssertEqual(entity.id, domain.id)
        XCTAssertEqual(entity.title, "Domain Node")
        XCTAssertEqual(entity.nodeDescription, "Description")
        XCTAssertEqual(entity.nodeType, "key_result")
        XCTAssertEqual(entity.scope, "personal")
        XCTAssertEqual(entity.currentValue, 75)
        XCTAssertEqual(entity.targetValue, 150)
        XCTAssertEqual(entity.unit, "个")
        XCTAssertEqual(entity.progress, 50, accuracy: 0.001)
        XCTAssertEqual(entity.status, "at_risk")
        XCTAssertEqual(entity.ownerName, "Charlie")
        XCTAssertEqual(entity.sortOrder, 5)
        XCTAssertEqual(entity.cycle?.id, cycleEntity.id)
        XCTAssertEqual(entity.weight, 1.0, accuracy: 0.001)
        XCTAssertEqual(entity.version, 0)
    }

    func test_domainToEntity_cycleNotFound_throws() {
        let missingCycleId = UUID()
        let domain = OKRNode(
            title: "No Cycle",
            nodeType: .objective,
            scope: .enterprise,
            targetValue: 0,
            ownerName: "Alice",
            cycleId: missingCycleId
        )

        XCTAssertThrowsError(try DomainToEntityMapper.map(domain: domain, context: context)) { error in
            guard case DomainToEntityMapper.MappingError.cycleNotFound(let id) = error else {
                return XCTFail("Expected cycleNotFound, got \(error)")
            }
            XCTAssertEqual(id, missingCycleId)
        }
    }

    func test_domainToEntity_parentNotFound_throws() {
        let missingParentId = UUID()
        let domain = OKRNode(
            title: "Orphan",
            nodeType: .keyResult,
            scope: .personal,
            targetValue: 100,
            ownerName: "Alice",
            parentId: missingParentId
        )

        XCTAssertThrowsError(try DomainToEntityMapper.map(domain: domain, context: context)) { error in
            guard case DomainToEntityMapper.MappingError.parentNotFound(let id) = error else {
                return XCTFail("Expected parentNotFound, got \(error)")
            }
            XCTAssertEqual(id, missingParentId)
        }
    }

    // MARK: - Cycle Mapping

    func test_cycleEntityToDomain_convertsAllFields() {
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 90)

        let entity = OKRCycleEntity(context: context)
        entity.id = id
        entity.name = "2026 Q1"
        entity.startDate = start
        entity.endDate = end
        entity.isActive = true
        entity.isArchived = false

        let domain = EntityToDomainMapper.map(entity: entity)

        XCTAssertEqual(domain.id, id)
        XCTAssertEqual(domain.name, "2026 Q1")
        XCTAssertEqual(domain.startDate, start)
        XCTAssertEqual(domain.endDate, end)
        XCTAssertTrue(domain.isActive)
        XCTAssertFalse(domain.isArchived)
    }

    func test_domainToEntity_cycle_createsNewEntity() throws {
        let domain = OKRCycle(
            name: "New Cycle",
            startDate: Date(timeIntervalSince1970: 100),
            endDate: Date(timeIntervalSince1970: 200),
            isActive: false,
            isArchived: false
        )

        let entity = try DomainToEntityMapper.map(domain: domain, context: context)

        XCTAssertEqual(entity.id, domain.id)
        XCTAssertEqual(entity.name, "New Cycle")
        XCTAssertEqual(entity.startDate, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(entity.endDate, Date(timeIntervalSince1970: 200))
        XCTAssertFalse(entity.isActive)
        XCTAssertFalse(entity.isArchived)
    }

    // MARK: - Batch Mapping

    func test_mapEntities_array() throws {
        let e1 = makeNodeEntity(title: "N1", nodeType: "objective", scope: "enterprise")
        let e2 = makeNodeEntity(title: "N2", nodeType: "key_result", scope: "personal", targetValue: 100)

        let domains = try EntityToDomainMapper.map(entities: [e1, e2])

        XCTAssertEqual(domains.count, 2)
        XCTAssertEqual(domains[0].title, "N1")
        XCTAssertEqual(domains[1].title, "N2")
    }

    func test_mapCycleEntities_array() {
        let c1 = makeCycleEntity(name: "C1")
        let c2 = makeCycleEntity(name: "C2")

        let domains = EntityToDomainMapper.map(cycleEntities: [c1, c2])

        XCTAssertEqual(domains.count, 2)
        XCTAssertTrue(domains.contains { $0.name == "C1" })
        XCTAssertTrue(domains.contains { $0.name == "C2" })
    }
}
