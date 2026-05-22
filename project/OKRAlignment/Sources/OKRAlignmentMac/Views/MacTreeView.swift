import SwiftUI
import OKRAlignmentShared

// MARK: - MacTreeView

/// The main macOS tree view with a three-column NavigationSplitView layout.
///
/// `MacTreeView` provides the primary macOS interface for the OKR Alignment System:
/// - **Sidebar**: Lists available OKR cycles with selection
/// - **Main Content**: Displays the interactive OKR tree visualization
/// - **Detail Panel**: Shows detailed information for the selected node
///
/// The view includes a toolbar with actions (new, edit, delete, refresh) and
/// supports keyboard shortcuts for common operations.
///
/// ## Example
/// ```swift
/// MacTreeView()
///     .environment(treeViewModel)
/// ```
public struct MacTreeView: View {
    // MARK: - Properties
    
    /// The view model managing tree data and state.
    @State private var viewModel = TreeViewModel(
        repository: CoreDataOKRRepository(container: PersistenceController.shared.container)
    )
    
    /// The currently selected node for detail display.
    @State private var selectedNode: OKRNode? = nil
    
    /// Whether the create/edit sheet is presented.
    @State private var isEditSheetPresented: Bool = false
    
    /// Whether the delete confirmation is presented.
    @State private var isDeleteConfirmationPresented: Bool = false
    
    /// The node being edited (nil for create mode).
    @State private var editingNode: OKRNode? = nil
    
    /// Whether a new cycle sheet should be shown.
    @State private var showNewCycleSheet: Bool = false
    
    /// The ID of the currently selected cycle.
    @State private var selectedCycleId: UUID? = nil
    
    /// Available OKR cycles (sample data - would come from a cycles view model).
    @State private var cycles: [OKRCycle] = []
    
    // MARK: - Constants
    
    private let detailMinWidth: CGFloat = 260
    private let detailIdealWidth: CGFloat = 300
    
    // MARK: - Body
    
    public var body: some View {
        NavigationSplitView {
            // MARK: Sidebar
            SidebarView(
                cycles: cycles,
                selectedCycleId: $selectedCycleId,
                onCreateCycle: { showNewCycleSheet = true },
                onDeleteCycle: { id in cycles.removeAll { $0.id == id } }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            NavigationStack {
                ZStack {
                    // Background
                    Color(red: 15/255, green: 23/255, blue: 42/255)
                        .ignoresSafeArea()
                    
                    // Main content based on state
                    mainContent
                }
                .toolbar {
                    toolbarContent
                }
                #if os(macOS)
                .navigationTitle(selectedCycleName)
                #endif
            }
        }
        .task {
            await loadInitialData()
        }
        .sheet(isPresented: $isEditSheetPresented) {
            editSheetContent
        }
        .alert("Confirm Delete", isPresented: $isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let node = selectedNode {
                    Task {
                        await viewModel.deleteNode(id: node.id)
                        selectedNode = nil
                    }
                }
            }
        } message: {
            if let node = selectedNode {
                Text("Are you sure you want to delete \"\(node.title)\"? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showNewCycleSheet) {
            newCycleSheet
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading {
            LoadingView(message: "Loading OKR tree...")
        } else if let errorMessage = viewModel.errorMessage {
            ErrorView(message: errorMessage) {
                Task {
                    await viewModel.refresh()
                }
            }
        } else if let rootNode = viewModel.rootNode {
            HStack(spacing: 0) {
                // Tree visualization area
                TreeView(
                    rootNode: rootNode,
                    onNodeTap: { node in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedNode = node
                        }
                    },
                    onUpdateProgress: { nodeId, delta in
                        Task {
                            await viewModel.updateLeafProgress(nodeId: nodeId, delta: delta)
                        }
                    }
                )
                
                // Detail panel
                if let selectedNode = selectedNode {
                    detailPanel(for: selectedNode)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        } else {
            EmptyStateView(
                title: cycles.isEmpty ? "No Cycles" : "No OKRs",
                subtitle: cycles.isEmpty
                    ? "Create a cycle to get started"
                    : "Create your first objective for this cycle",
                actionTitle: cycles.isEmpty ? "Create Cycle" : "Create OKR",
                onAction: {
                    if cycles.isEmpty {
                        showNewCycleSheet = true
                    } else {
                        editingNode = nil
                        isEditSheetPresented = true
                    }
                }
            )
        }
    }
    
    // MARK: - Detail Panel
    
    /// Creates the detail panel for the selected node.
    private func detailPanel(for node: OKRNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    NodeTypeLabel(nodeType: node.nodeType)
                    Spacer()
                    ScopeBadge(ownerName: node.ownerName, scope: node.scope)
                }
                
                // Title
                Text(node.title)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Description
                if let desc = node.nodeDescription {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                            .tracking(0.5)
                        
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 203/255, green: 213/255, blue: 225/255))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                }
                
                // Progress section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                        .tracking(0.5)
                    
                    ProgressBar(
                        progress: node.progress,
                        scope: node.scope,
                        nodeType: node.nodeType
                    )
                    
                    HStack {
                        Text(node.valueDisplayString)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                        Spacer()
                        Text(node.progressPercentage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Details grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    DetailItem(title: "Status", value: statusDisplayName(node.status))
                    DetailItem(title: "Scope", value: node.scope == .enterprise ? "Enterprise" : "Personal")
                    DetailItem(title: "Type", value: node.nodeType == .objective ? "Objective" : "Key Result")
                    DetailItem(title: "Children", value: "\(node.children.count)")
                }
                
                // Leaf controls for KR nodes
                if node.isLeaf {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Adjust Progress")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                            .tracking(0.5)
                        
                        LeafControls(
                            node: node,
                            isVisible: true,
                            onUpdate: { nodeId, delta in
                                Task {
                                    await viewModel.updateLeafProgress(nodeId: nodeId, delta: delta)
                                }
                            }
                        )
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Timestamps
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created: \(formattedDate(node.createdAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                    Text("Updated: \(formattedDate(node.updatedAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                }
                
                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .frame(minWidth: detailMinWidth, idealWidth: detailIdealWidth)
        .background(Color(red: 30/255, green: 41/255, blue: 59/255))
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Refresh button
            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
            .help("Refresh tree (⌘R)")
            .keyboardShortcut("r", modifiers: .command)
            
            Divider()
            
            // Add button
            Button {
                editingNode = nil
                isEditSheetPresented = true
            } label: {
                Label("New", systemImage: "plus")
            }
            .disabled(viewModel.isLoading)
            .help("Create new OKR node (⌘N)")
            .keyboardShortcut("n", modifiers: .command)
            
            // Edit button
            Button {
                editingNode = selectedNode
                isEditSheetPresented = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(selectedNode == nil || viewModel.isLoading)
            .help("Edit selected node (⌘E)")
            .keyboardShortcut("e", modifiers: .command)
            
            // Delete button
            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectedNode == nil || viewModel.isLoading)
            .help("Delete selected node (⌘⌫)")
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }
    
    // MARK: - Edit Sheet
    
    @ViewBuilder
    private var editSheetContent: some View {
        let allNodes = flattenNodes(from: viewModel.rootNode)
        let availableParents = allNodes.filter { $0.nodeType == .objective }
        
        let mode: NodeEditForm.Mode = {
            if let node = editingNode {
                return .edit(node)
            }
            return .create(parentId: selectedNode?.id)
        }()

        NodeEditForm(
            mode: mode,
            availableParents: availableParents,
            onSave: { node in
                isEditSheetPresented = false
                // Would call viewModel.saveNode(node) here
            },
            onCancel: {
                isEditSheetPresented = false
            }
        )
        .frame(minWidth: 480, minHeight: 600)
        #if os(macOS)
        .presentationDetents([.height(700)])
        #endif
    }
    
    // MARK: - New Cycle Sheet
    
    private var newCycleSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Create New Cycle")
                    .font(.title2)
                    .foregroundStyle(.white)
                
                Text("Cycle creation form would go here")
                    .foregroundStyle(.secondary)
                
                Button("Close") {
                    showNewCycleSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(minWidth: 400, minHeight: 300)
            .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        }
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() async {
        // Load sample cycles
        let calendar = Calendar.current
        guard let oct1 = calendar.date(from: DateComponents(year: 2024, month: 10, day: 1)),
              let dec31 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31)),
              let jul1 = calendar.date(from: DateComponents(year: 2024, month: 7, day: 1)),
              let sep30 = calendar.date(from: DateComponents(year: 2024, month: 9, day: 30))
        else { return }
        cycles = [
            OKRCycle(
                id: UUID(),
                name: "Q4 2024",
                startDate: oct1,
                endDate: dec31,
                isActive: true
            ),
            OKRCycle(
                id: UUID(),
                name: "Q3 2024",
                startDate: jul1,
                endDate: sep30,
                isActive: false
            )
        ]
        
        // Select first cycle and load tree
        if let firstCycle = cycles.first {
            selectedCycleId = firstCycle.id
            await viewModel.loadTree(cycleId: firstCycle.id)
        }
    }
    
    // MARK: - Helpers
    
    /// The name of the currently selected cycle.
    private var selectedCycleName: String {
        cycles.first { $0.id == selectedCycleId }?.name ?? "OKR Alignment"
    }
    
    /// Flattens the tree into an array of all nodes.
    private func flattenNodes(from root: OKRNode?) -> [OKRNode] {
        guard let root = root else { return [] }
        var result = [root]
        for child in root.children {
            result.append(contentsOf: flattenNodes(from: child))
        }
        return result
    }
    
    /// Formats a date for display.
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Returns the display name for a status.
    private func statusDisplayName(_ status: NodeStatus) -> String {
        switch status {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .atRisk: return "At Risk"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - DetailItem

/// A small key-value display component for the detail panel.
struct DetailItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if !SWIFT_PACKAGE
// MARK: - Previews

#Preview("MacTreeView") {
    MacTreeView()
}
#endif
