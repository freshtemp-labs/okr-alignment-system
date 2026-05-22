# OKR Alignment System - Technical Specification (SPEC.md)

> **Version**: 1.0  
> **Date**: 2026-05-20  
> **Tech Stack**: Swift 6 + SwiftUI + Core Data + CloudKit  
> **Platforms**: macOS 14+, iOS 17+

---

## 1. Architecture Overview

### 1.1 Architecture Pattern
- **UI Layer**: SwiftUI Views (platform-specific)
- **Presentation Layer**: MVVM ViewModels (shared)
- **Domain Layer**: Use Cases + Entities (shared)
- **Data Layer**: Repository + Core Data (shared)

### 1.2 Module Division

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ macOS Views  │  │  iOS Views   │  │   Shared Views   │  │
│  │ - TreeView   │  │ - TreeView   │  │ - NodeCard       │  │
│  │ - Sidebar    │  │ - Navigation │  │ - ProgressBar    │  │
│  │ - Toolbar    │  │ - Sheets     │  │ - Controls       │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         └─────────────────┬────────────────────┘              │
├───────────────────────────┼───────────────────────────────────┤
│       DOMAIN LAYER        │      DATA LAYER                   │
│  ┌─────────────────────┐  │  ┌─────────────────────────────┐ │
│  │ CascadeEngine       │  │  │ OKRRepository (Protocol)    │ │
│  │ - calculateProgress │  │  │ CoreDataOKRRepository       │ │
│  │ - rollupAlgorithm   │  │  │ - CRUD operations           │ │
│  └─────────────────────┘  │  │ - NSPersistentContainer     │ │
│  ┌─────────────────────┐  │  └─────────────────────────────┘ │
│  │ OKR ViewModels      │  │  ┌─────────────────────────────┐ │
│  │ - TreeViewModel     │  │  │ Core Data Models            │ │
│  │ - NodeViewModel     │  │  │ - OKRNodeEntity             │ │
│  │ - DetailViewModel   │  │  │ - ObjectiveEntity           │ │
│  │ - EditViewModel     │  │  │ - KeyResultEntity           │ │
│  └─────────────────────┘  │  │ - PersonEntity              │ │
│                           │  │ - OKRCycleEntity            │ │
│                           │  └─────────────────────────────┘ │
└───────────────────────────┴───────────────────────────────────┘
```

### 1.3 Technology Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| UI Framework | SwiftUI | Native, declarative, cross-platform macOS/iOS |
| Persistence | Core Data | Native ORM, SwiftUI @FetchRequest integration |
| Cloud Sync | CloudKit | Native Apple solution, no backend needed |
| Language | Swift 6 | Modern concurrency, strict memory safety |
| Architecture | MVVM + Clean | Testable, maintainable, scalable |
| Testing | XCTest | Native, CI/CD friendly |

---

## 2. Data Model

### 2.1 Core Data Entities

```swift
// OKRNodeEntity - Base entity for all OKR nodes
@objc(OKRNodeEntity)
class OKRNodeEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var nodeDescription: String?
    @NSManaged var nodeType: String // "objective" | "key_result"
    @NSManaged var scope: String // "enterprise" | "personal"
    @NSManaged var currentValue: Double
    @NSManaged var targetValue: Double
    @NSManaged var unit: String?
    @NSManaged var progress: Double // 0.0 - 100.0, computed
    @NSManaged var status: String // "not_started" | "in_progress" | "at_risk" | "completed" | "cancelled"
    @NSManaged var ownerName: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var sortOrder: Int32
    
    // Relationships
    @NSManaged var parent: OKRNodeEntity?
    @NSManaged var children: NSSet? // Ordered set of child nodes
    @NSManaged var cycle: OKRCycleEntity?
}

// OKRCycleEntity - Represents an OKR cycle (e.g., Q1 2026)
@objc(OKRCycleEntity)
class OKRCycleEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var isActive: Bool
    @NSManaged var isArchived: Bool
    @NSManaged var createdAt: Date
    
    @NSManaged var nodes: NSSet?
}

// PersonEntity - Represents a user/person
@objc(PersonEntity)
class PersonEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var email: String?
    @NSManaged var role: String // "admin" | "manager" | "member"
    @NSManaged var avatarData: Data?
    @NSManaged var createdAt: Date
}
```

### 2.2 Domain Models (structs, non-Core Data)

```swift
// MARK: - OKRNode (Domain Model)
struct OKRNode: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var nodeDescription: String?
    var nodeType: NodeType
    var scope: Scope
    var currentValue: Double
    var targetValue: Double
    var unit: String?
    var progress: Double // Computed property (0-100)
    var status: NodeStatus
    var ownerName: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var parentId: UUID?
    var children: [OKRNode]
    var cycleId: UUID?
    
    var isLeaf: Bool { children.isEmpty && nodeType == .keyResult }
    var progressPercentage: String { String(format: "%.1f%%", progress) }
}

enum NodeType: String, CaseIterable {
    case objective = "objective"
    case keyResult = "key_result"
}

enum Scope: String, CaseIterable {
    case enterprise = "enterprise"
    case personal = "personal"
}

enum NodeStatus: String, CaseIterable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case atRisk = "at_risk"
    case completed = "completed"
    case cancelled = "cancelled"
}
```

---

## 3. Interface Contracts

### 3.1 Repository Protocol

```swift
// MARK: - OKRRepositoryProtocol
/// Data access contract for OKR operations.
/// Abstracts Core Data implementation from domain layer.
protocol OKRRepositoryProtocol: Sendable {
    /// Fetch all root nodes (objectives with no parent) for a given cycle
    func fetchRootNodes(cycleId: UUID?) async throws -> [OKRNode]
    
    /// Fetch a single node by ID with all children
    func fetchNode(id: UUID) async throws -> OKRNode?
    
    /// Create a new OKR node
    func createNode(_ node: OKRNode) async throws -> OKRNode
    
    /// Update an existing OKR node
    func updateNode(_ node: OKRNode) async throws -> OKRNode
    
    /// Delete a node and optionally cascade to children
    func deleteNode(id: UUID, cascade: Bool) async throws
    
    /// Update current value of a leaf KR (triggers cascade recalculation)
    func updateLeafValue(nodeId: UUID, newValue: Double) async throws -> OKRNode
    
    /// Fetch all cycles
    func fetchCycles() async throws -> [OKRCycle]
    
    /// Save changes to persistent store
    func save() async throws
}

// MARK: - OKRCycle
struct OKRCycle: Identifiable, Equatable {
    let id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    var isArchived: Bool
}
```

### 3.2 Cascade Engine Protocol

```swift
// MARK: - CascadeEngineProtocol
/// Handles automatic progress calculation and propagation.
protocol CascadeEngineProtocol: Sendable {
    /// Calculate progress for a node and all its children recursively
    func calculateProgress(for node: OKRNode) -> OKRNode
    
    /// Calculate progress for an entire tree from root
    func calculateTreeProgress(root: OKRNode) -> OKRNode
    
    /// Update a leaf KR value and recalculate entire tree
    func updateLeafAndRecalculate(
        treeRoot: OKRNode,
        leafId: UUID,
        newValue: Double
    ) -> OKRNode
    
    /// Get validation errors for a node
    func validateNode(_ node: OKRNode) -> [ValidationError]
}

enum ValidationError: Error, Equatable {
    case emptyTitle
    case invalidTargetValue
    case leafMissingValues
    case parentTypeMismatch
    case cycleNotSet
}
```

### 3.3 ViewModel Protocols

```swift
// MARK: - TreeViewModelProtocol
@MainActor
protocol TreeViewModelProtocol: ObservableObject {
    var rootNode: OKRNode? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func loadTree(cycleId: UUID?) async
    func updateLeafProgress(nodeId: UUID, delta: Double) async
    func deleteNode(id: UUID) async
    func refresh() async
}

// MARK: - NodeEditViewModelProtocol
@MainActor
protocol NodeEditViewModelProtocol: ObservableObject {
    var node: OKRNode { get set }
    var isSaving: Bool { get }
    var validationErrors: [ValidationError] { get }
    
    func save() async throws -> OKRNode
    func validate() -> Bool
}
```

---

## 4. File Structure

```
OKRAlignment/
├── Package.swift                          # SPM manifest
├── Info.plist                            # App metadata
│
├── Sources/
│   ├── OKRAlignmentShared/               # Shared code (macOS + iOS)
│   │   ├── Models/
│   │   │   ├── OKRNode.swift            # Domain model
│   │   │   ├── OKRCycle.swift           # Cycle domain model
│   │   │   ├── NodeType.swift           # NodeType enum
│   │   │   ├── Scope.swift              # Scope enum
│   │   │   ├── NodeStatus.swift         # NodeStatus enum
│   │   │   └── ValidationError.swift    # Validation errors
│   │   │
│   │   ├── Data/
│   │   │   ├── CoreData/
│   │   │   │   ├── OKRAlignment.xcdatamodeld/
│   │   │   │   │   └── Contents        # Core Data model definition
│   │   │   │   ├── OKRNodeEntity+Extensions.swift
│   │   │   │   ├── OKRCycleEntity+Extensions.swift
│   │   │   │   └── PersistenceController.swift
│   │   │   │
│   │   │   ├── Repository/
│   │   │   │   ├── OKRRepositoryProtocol.swift
│   │   │   │   └── CoreDataOKRRepository.swift
│   │   │   │
│   │   │   └── Mappers/
│   │   │       ├── EntityToDomainMapper.swift
│   │   │       └── DomainToEntityMapper.swift
│   │   │
│   │   ├── Domain/
│   │   │   ├── CascadeEngineProtocol.swift
│   │   │   ├── OKRCascadeEngine.swift   # Progress calculation engine
│   │   │   └── NodeValidator.swift      # Validation logic
│   │   │
│   │   ├── ViewModels/
│   │   │   ├── TreeViewModel.swift
│   │   │   ├── NodeDetailViewModel.swift
│   │   │   ├── NodeEditViewModel.swift
│   │   │   └── CycleListViewModel.swift
│   │   │
│   │   ├── Views/
│   │   │   ├── Shared/
│   │   │   │   ├── OKRNodeCard.swift    # Reusable node card
│   │   │   │   ├── ProgressBar.swift    # Progress bar component
│   │   │   │   ├── ScopeBadge.swift     # Enterprise/Personal badge
│   │   │   │   ├── NodeTypeLabel.swift  # Objective/KR label
│   │   │   │   └── LeafControls.swift   # +/- controls for leaf KR
│   │   │   │
│   │   │   ├── Tree/
│   │   │   │   ├── TreeView.swift       # Shared tree logic
│   │   │   │   ├── TreeNodeRow.swift    # Row in tree
│   │   │   │   └── TreeConnector.swift  # Visual connectors
│   │   │   │
│   │   │   ├── Editing/
│   │   │   │   ├── NodeEditForm.swift   # Create/Edit form
│   │   │   │   ├── DeleteConfirmView.swift
│   │   │   │   └── ValuePicker.swift    # current/target value input
│   │   │   │
│   │   │   └── Common/
│   │   │       ├── EmptyStateView.swift
│   │   │       ├── ErrorView.swift
│   │   │       └── LoadingView.swift
│   │   │
│   │   ├── Services/
│   │   │   ├── NotificationService.swift
│   │   │   ├── ExportService.swift
│   │   │   └── SyncMonitor.swift        # CloudKit sync monitoring
│   │   │
│   │   └── Utils/
│   │       ├── Color+Theme.swift        # App color theme
│   │       ├── View+Extensions.swift
│   │       └── Date+Extensions.swift
│   │
│   ├── OKRAlignmentMac/                  # macOS-specific
│   │   ├── OKRAlignmentMacApp.swift      # App entry point
│   │   ├── Views/
│   │   │   ├── MacTreeView.swift         # macOS tree view
│   │   │   ├── SidebarView.swift         # macOS sidebar
│   │   │   ├── ToolbarContent.swift      # macOS toolbar
│   │   │   ├── MacNodeDetailView.swift   # macOS detail panel
│   │   │   └── MacNodeEditSheet.swift    # macOS edit sheet
│   │   └── ViewModels/
│   │       └── MacTreeViewModel.swift    # macOS-specific VM if needed
│   │
│   └── OKRAlignment/                     # iOS-specific
│       ├── OKRAlignmentApp.swift         # App entry point
│       ├── Views/
│       │   ├── iOSTreeView.swift         # iOS tree view
│       │   ├── iOSNodeDetailView.swift   # iOS detail
│       │   ├── iOSNodeEditSheet.swift    # iOS edit sheet
│       │   └── TabBarView.swift          # iOS tab bar
│       └── ViewModels/
│           └── iOSTreeViewModel.swift    # iOS-specific VM if needed
│
└── Tests/
    ├── OKRAlignmentTests/
    │   ├── CascadeEngineTests.swift       # Progress calculation tests
    │   ├── NodeValidatorTests.swift       # Validation logic tests
    │   ├── EntityMappingTests.swift       # Core Data mapping tests
    │   ├── RepositoryTests.swift          # Repository CRUD tests
    │   └── TestDataFactory.swift          # Test data builders
    │
    └── OKRAlignmentUITests/
        ├── MacUITests.swift               # macOS UI tests
        ├── iOSUITests.swift               # iOS UI tests
        ├── TreeInteractionTests.swift     # Tree view interaction
        └── CRUDFlowTests.swift            # End-to-end CRUD tests
```

---

## 5. Cascade Algorithm Specification

### 5.1 Progress Calculation Rules

```
Rule 1: Leaf KR
  progress = (currentValue / targetValue) * 100
  clamped to [0, 100]

Rule 2: Node with children (Objective or parent KR)
  progress = average(children.progress)
  
Rule 3: Empty Objective (no children)
  progress = 0

Rule 4: Invalid leaf KR (targetValue <= 0)
  progress = 0, flag as error
```

### 5.2 Algorithm Pseudocode

```swift
func calculateProgress(_ node: OKRNode) -> OKRNode {
    var updated = node
    
    if node.children.isEmpty && node.nodeType == .keyResult {
        // Rule 1: Leaf KR - direct calculation
        guard node.targetValue > 0 else { 
            updated.progress = 0
            return updated 
        }
        updated.progress = min(100, max(0, (node.currentValue / node.targetValue) * 100))
    } else if !node.children.isEmpty {
        // Rule 2: Has children - recursive average
        updated.children = node.children.map { calculateProgress($0) }
        let total = updated.children.reduce(0) { $0 + $1.progress }
        updated.progress = total / Double(updated.children.count)
    } else {
        // Rule 3: Empty objective
        updated.progress = 0
    }
    
    return updated
}
```

---

## 6. Color Theme

```swift
extension Color {
    // MARK: - Scope Colors
    static let enterpriseScope = Color(red: 234/255, green: 179/255, blue: 8/255)   // Gold #EAB308
    static let personalScope = Color(red: 59/255, green: 130/255, blue: 246/255)    // Blue #3B82F6
    
    // MARK: - Progress Colors
    static let enterpriseProgress = Color(red: 202/255, green: 138/255, blue: 4/255)  // Dark gold #CA8A04
    static let personalProgress = Color(red: 59/255, green: 130/255, blue: 246/255)   // Blue #3B82F6
    static let krProgress = Color(red: 5/255, green: 150/255, blue: 105/255)          // Green #059669
    
    // MARK: - Semantic Colors
    static let statusNotStarted = Color.gray
    static let statusInProgress = Color.blue
    static let statusAtRisk = Color.orange
    static let statusCompleted = Color.green
    static let statusCancelled = Color.red
    
    // MARK: - Background Colors
    static let appBackground = Color(red: 15/255, green: 23/255, blue: 42/255)        // Dark slate #0F172A
    static let cardBackground = Color.white.opacity(0.05)
    static let cardBorder = Color.white.opacity(0.1)
}
```

---

## 7. Development Conventions

### 7.1 Code Style
- Swift 6 with strict concurrency checking enabled
- All ViewModels marked with `@MainActor`
- All Services/Repository conform to `Sendable`
- Use `async/await` for asynchronous operations
- Use `@Observable` (Swift 6) instead of `ObservableObject` where possible

### 7.2 Comment Requirements
- Every public type and member must have documentation comments (`///`)
- Every function must describe: purpose, parameters, return value, throws
- Complex algorithms must have inline comments explaining the logic
- All `// MARK:` sections must be used to organize code

### 7.3 Testing Requirements
- Unit test coverage >= 80%
- Every ViewModel must have corresponding unit tests
- Cascade engine must have 100% branch coverage
- UI tests for all CRUD flows
- Integration tests for end-to-end scenarios

---

## 8. Platform-Specific Adaptations

### 8.1 macOS
- Three-column layout: Sidebar | Tree View | Detail Panel
- Keyboard shortcuts (Cmd+N new, Cmd+Delete delete, Cmd+S save)
- Menu bar integration
- Window management (multiple windows for different cycles)
- Touch Bar support (optional)

### 8.2 iOS
- Two-panel layout: Tree List | Detail
- Bottom sheet for editing
- Swipe actions on rows (edit/delete)
- Pull-to-refresh
- Haptic feedback on progress changes

---

## 9. MVP Scope Checklist

### P0 - Must Have
- [ ] Core Data model and persistence
- [ ] Cascade progress calculation engine
- [ ] Tree view visualization (macOS + iOS)
- [ ] Node card component with progress bar
- [ ] Leaf KR +/- controls
- [ ] CRUD operations (Create, Read, Update, Delete)
- [ ] Enterprise (gold) / Personal (blue) scope styling
- [ ] Owner badge display
- [ ] Dark mode support
- [ ] Unit tests for cascade engine (100% branch coverage)
- [ ] Unit tests for repository operations
- [ ] UI tests for CRUD flows

### P1 - Should Have
- [ ] CloudKit synchronization
- [ ] Search and filtering
- [ ] Import/Export JSON
- [ ] Empty state views
- [ ] Drag-and-drop reordering

### P2 - Could Have
- [ ] Widget support
- [ ] Notifications
- [ ] Trend analysis
- [ ] Multiple cycle management
