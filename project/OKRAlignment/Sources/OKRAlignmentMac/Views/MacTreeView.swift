import SwiftUI
import OKRAlignmentShared

#if os(macOS)
import AppKit
#endif

// MARK: - MacTreeView

/// The main macOS tree view with a three-column NavigationSplitView layout.
///
/// `MacTreeView` provides the primary macOS interface for the OKR Alignment System:
/// - **Sidebar**: Lists available OKR cycles with selection, status colors, and export
/// - **Main Content**: Displays the interactive OKR tree visualization
/// - **Detail Panel**: Shows detailed information for the selected node
/// - **Toolbar**: Search, new, edit, delete actions with keyboard shortcuts
///
public struct MacTreeView: View {
    // MARK: - Properties
    
    /// The view model managing tree data and state.
    @State private var viewModel = TreeViewModel(
        repository: CoreDataOKRRepository(container: PersistenceController.shared.container)
    )
    
    /// The cycle list view model.
    @State private var cycleViewModel = CycleListViewModel(
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
    
    /// Available OKR cycles.
    @State private var cycles: [OKRCycle] = []
    
    /// Search text for filtering OKR nodes.
    @State private var searchText: String = ""
    
    /// Whether the search field is active.
    @State private var isSearchActive: Bool = false
    
    /// The set of node IDs matching the search.
    @State private var searchResultNodeIds: Set<UUID> = []
    
    /// The set of expanded node IDs (for search result navigation).
    @State private var expandedNodeIds: Set<UUID> = []
    
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
                onDeleteCycle: { id in cycles.removeAll { $0.id == id } },
                onArchiveCycle: { cycleId in
                    Task {
                        await cycleViewModel.archiveCycle(cycleId)
                        await refreshCyclesAndTree()
                    }
                },
                onActivateCycle: { cycleId in
                    Task {
                        await cycleViewModel.activateCycle(cycleId)
                        await refreshCyclesAndTree()
                    }
                },
                onExport: { showExportPanel() }
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
        .onChange(of: selectedCycleId) { _, newCycleId in
            // Auto-refresh tree when cycle selection changes
            if let cycleId = newCycleId {
                Task {
                    // Fade out current content, load new tree, fade back in
                    await viewModel.loadTree(cycleId: cycleId)
                    selectedNode = nil
                }
            }
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
        // Escape key to dismiss sheets/alerts
        .onExitCommand {
            if isEditSheetPresented {
                isEditSheetPresented = false
            } else if isDeleteConfirmationPresented {
                isDeleteConfirmationPresented = false
            } else if isSearchActive {
                isSearchActive = false
                searchText = ""
                searchResultNodeIds = []
            }
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
                
                // Detail panel with slide animation
                if let selectedNode = selectedNode {
                    NodeDetailView(
                        node: selectedNode,
                        onEdit: { node in
                            editingNode = node
                            isEditSheetPresented = true
                        },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                self.selectedNode = nil
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedNode.id)
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
    
    // Note: Detail panel is now handled by NodeDetailView from OKRAlignmentShared

    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Search field in toolbar
        ToolbarItemGroup(placement: .automatic) {
            if isSearchActive {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                    
                    TextField("Search OKRs...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onChange(of: searchText) { _, newValue in
                            performSearch(query: newValue)
                        }
                        .onSubmit {
                            // Jump to first search result
                            if let firstMatchId = searchResultNodeIds.first {
                                expandToNode(firstMatchId)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResultNodeIds = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("\(searchResultNodeIds.count) found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Cancel") {
                        isSearchActive = false
                        searchText = ""
                        searchResultNodeIds = []
                    }
                    .font(.caption)
                }
            }
        }
        
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
            .help("Delete selected node (⌫)")
            .keyboardShortcut(.delete, modifiers: [])
            
            // Search toggle button
            Button {
                withAnimation {
                    isSearchActive.toggle()
                    if !isSearchActive {
                        searchText = ""
                        searchResultNodeIds = []
                    }
                }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .help("Search OKRs (⌘F)")
            .keyboardShortcut("f", modifiers: .command)
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
                .keyboardShortcut(.cancelAction)
            }
            .frame(minWidth: 400, minHeight: 300)
            .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        }
    }
    
    // MARK: - Search
    
    /// Performs a search across all OKR nodes for title and ownerName matches.
    private func performSearch(query: String) {
        guard !query.isEmpty, let root = viewModel.rootNode else {
            searchResultNodeIds = []
            return
        }
        
        let matchingIds = findMatchingNodeIds(in: root, query: query)
        searchResultNodeIds = matchingIds
        
        // Auto-expand parent paths for all matching nodes
        for nodeId in matchingIds {
            expandToNode(nodeId)
        }
    }
    
    /// Recursively finds all node IDs whose title or ownerName matches the query.
    private func findMatchingNodeIds(in node: OKRNode, query: String) -> Set<UUID> {
        var result: Set<UUID> = []
        let lowerQuery = query.lowercased()
        
        if node.title.lowercased().contains(lowerQuery) ||
           node.ownerName.lowercased().contains(lowerQuery) {
            result.insert(node.id)
        }
        
        for child in node.children {
            result.formUnion(findMatchingNodeIds(in: child, query: query))
        }
        
        return result
    }
    
    /// Expands all ancestor nodes so the given node becomes visible in the tree.
    private func expandToNode(_ nodeId: UUID) {
        guard let root = viewModel.rootNode else { return }
        let path = findPath(to: nodeId, in: root, currentPath: [])
        for id in path {
            expandedNodeIds.insert(id)
        }
    }
    
    /// Finds the path of ancestor node IDs from root to the target node.
    private func findPath(to targetId: UUID, in node: OKRNode, currentPath: [UUID]) -> [UUID] {
        let newPath = currentPath + [node.id]
        
        if node.id == targetId {
            return newPath
        }
        
        for child in node.children {
            let found = findPath(to: targetId, in: child, currentPath: newPath)
            if !found.isEmpty {
                return found
            }
        }
        
        return []
    }
    
    // MARK: - Export
    
    /// Shows the macOS save panel for exporting OKR data.
    private func showExportPanel() {
        #if os(macOS)
        guard let rootNode = viewModel.rootNode else { return }
        
        let panel = NSSavePanel()
        panel.title = "Export OKR Data"
        panel.allowedContentTypes = [.commaSeparatedText, .json]
        panel.nameFieldStringValue = "okr-export"
        panel.canCreateDirectories = true
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            let fileExtension = url.pathExtension.lowercased()
            
            if fileExtension == "json" {
                if let jsonData = OKRExportService.exportToJSON(rootNode: rootNode) {
                    try? jsonData.write(to: url)
                }
            } else {
                // Default to CSV
                let csvString = OKRExportService.exportToCSV(rootNode: rootNode)
                try? csvString.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        #endif
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() async {
        // DEBUG模式下：首次启动时加载示例数据
        #if DEBUG
        PersistenceController.shared.loadSampleDataIfNeeded()
        #endif

        // 从Core Data加载周期列表
        await cycleViewModel.loadCycles()
        cycles = cycleViewModel.cycles

        // 选中第一个周期并加载对应的OKR树
        if let firstCycle = cycles.first {
            selectedCycleId = firstCycle.id
            await viewModel.loadTree(cycleId: firstCycle.id)
        }
    }
    
    /// Refreshes cycles list and reloads the tree for the current cycle.
    private func refreshCyclesAndTree() async {
        await cycleViewModel.loadCycles()
        cycles = cycleViewModel.cycles
        
        // If the selected cycle was archived, clear selection
        if let selectedId = selectedCycleId,
           let updatedCycle = cycles.first(where: { $0.id == selectedId }),
           updatedCycle.isArchived {
            // Keep selection but tree should still refresh
        }
        
        await viewModel.loadTree(cycleId: selectedCycleId)
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


#if !SWIFT_PACKAGE
// MARK: - Previews

#Preview("MacTreeView") {
    MacTreeView()
}
#endif
