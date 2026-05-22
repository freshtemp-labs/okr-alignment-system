import Foundation
import CoreData
@testable import OKRAlignmentShared

// MARK: - Test-Only Entity Relationship Extensions
//
// The production mappers (EntityToDomainMapper / DomainToEntityMapper) reference
// `entity.children`, `entity.parent`, and `entity.cycle` as CoreData relationships,
// but these are not declared on the NSManagedObject subclasses nor in the model.
// We add them here as @NSManaged properties so the production code can work
// against our test in-memory store that defines the corresponding relationships.

extension OKRNodeEntity {
    /// Ordered to-many relationship to child nodes
    @NSManaged public var children: NSOrderedSet?
    /// To-one relationship to parent node (inverse of children)
    @NSManaged public var parent: OKRNodeEntity?
    /// To-one relationship to the owning cycle
    @NSManaged public var cycle: OKRCycleEntity?
}

extension OKRCycleEntity {
    /// To-many relationship to nodes belonging to this cycle
    @NSManaged public var nodes: NSSet?
}

// MARK: - CoreDataTestStack

/// Provides a fresh, in-memory CoreData stack for each test.
///
/// The model mirrors `PersistenceController.createManagedObjectModel()` but adds
/// the parent–children and cycle–node **relationships** that the production mappers
/// require.  Every test that needs CoreData should create a new instance so tests
/// stay isolated.
final class CoreDataTestStack {

    let container: NSPersistentContainer

    init() {
        let model = Self.createModel()
        container = NSPersistentContainer(name: "OKRTest", managedObjectModel: model)
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]

        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory CoreData store: \(error)")
            }
            semaphore.signal()
        }
        semaphore.wait()
    }

    // MARK: - Model Construction

    /// Builds the `NSManagedObjectModel` with all attributes **and** relationships.
    private static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ── OKRNodeEntity ──────────────────────────────────────────
        let nodeEntity = NSEntityDescription()
        nodeEntity.name = "OKRNodeEntity"
        nodeEntity.managedObjectClassName = "OKRAlignmentShared.OKRNodeEntity"

        func uuidAttr(_ name: String, optional: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = .UUIDAttributeType
            a.isOptional = optional
            return a
        }
        func strAttr(_ name: String, optional: Bool = false, defaultVal: String? = nil) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = .stringAttributeType
            a.isOptional = optional
            if let v = defaultVal { a.defaultValue = v }
            return a
        }
        func dblAttr(_ name: String, defaultVal: Double = 0) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = .doubleAttributeType
            a.isOptional = false
            a.defaultValue = defaultVal
            return a
        }
        func dateAttr(_ name: String) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = .dateAttributeType
            a.isOptional = false
            a.defaultValue = Date()
            return a
        }
        func int64Attr(_ name: String, defaultVal: Int64 = 0) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = .integer64AttributeType
            a.isOptional = false
            a.defaultValue = defaultVal
            return a
        }
        func boolAttr(_ name: String, defaultVal: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = .booleanAttributeType
            a.isOptional = false
            a.defaultValue = defaultVal
            return a
        }

        nodeEntity.properties = [
            uuidAttr("id"),
            strAttr("title"),
            strAttr("nodeDescription", optional: true),
            strAttr("nodeType"),
            strAttr("scope"),
            dblAttr("currentValue"),
            dblAttr("targetValue"),
            strAttr("unit", optional: true),
            dblAttr("progress"),
            strAttr("status", defaultVal: "not_started"),
            strAttr("ownerName"),
            int64Attr("sortOrder"),
            dateAttr("createdAt"),
            dateAttr("updatedAt"),
            uuidAttr("cycleId", optional: true),
            uuidAttr("parentId", optional: true),
        ]

        // ── OKRCycleEntity ─────────────────────────────────────────
        let cycleEntity = NSEntityDescription()
        cycleEntity.name = "OKRCycleEntity"
        cycleEntity.managedObjectClassName = "OKRAlignmentShared.OKRCycleEntity"

        cycleEntity.properties = [
            uuidAttr("id"),
            strAttr("name"),
            dateAttr("startDate"),
            dateAttr("endDate"),
            boolAttr("isActive"),
            boolAttr("isArchived"),
        ]

        // ── Relationships (missing from production model) ──────────

        // parent ↔ children  (self-referencing, ordered to-many)
        let childrenRel = NSRelationshipDescription()
        childrenRel.name = "children"
        childrenRel.destinationEntity = nodeEntity
        childrenRel.minCount = 0
        childrenRel.maxCount = 0          // to-many
        childrenRel.isOrdered = true
        childrenRel.deleteRule = .cascadeDeleteRule

        let parentRel = NSRelationshipDescription()
        parentRel.name = "parent"
        parentRel.destinationEntity = nodeEntity
        parentRel.minCount = 0
        parentRel.maxCount = 1
        parentRel.deleteRule = .nullifyDeleteRule

        childrenRel.inverseRelationship = parentRel
        parentRel.inverseRelationship = childrenRel

        // cycle ↔ nodes
        let cycleRel = NSRelationshipDescription()
        cycleRel.name = "cycle"
        cycleRel.destinationEntity = cycleEntity
        cycleRel.minCount = 0
        cycleRel.maxCount = 1
        cycleRel.deleteRule = .nullifyDeleteRule

        let nodesRel = NSRelationshipDescription()
        nodesRel.name = "nodes"
        nodesRel.destinationEntity = nodeEntity
        nodesRel.minCount = 0
        nodesRel.maxCount = 0
        nodesRel.deleteRule = .nullifyDeleteRule

        cycleRel.inverseRelationship = nodesRel
        nodesRel.inverseRelationship = cycleRel

        nodeEntity.properties.append(contentsOf: [childrenRel, parentRel, cycleRel])
        cycleEntity.properties.append(nodesRel)

        model.entities = [nodeEntity, cycleEntity]
        return model
    }
}
