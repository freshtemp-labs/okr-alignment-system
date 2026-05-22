import SwiftUI
import OKRAlignmentShared

#if os(macOS)
import AppKit
#endif

// MARK: - MacTreeView

/// The main macOS tree view with a three-column NavigationSplitView layout.
///
/// `MacTreeView` provides the primary macOS interface for the OKR Alignment System:
/// - **Sidebar**: Lists available OKR cycles with selection, status colors, import/export
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
    
    /// Whether an import/export operation is in progress.
    @State private var isDataOperationInProgress: Bool = false
    
    /// Status message for data operations.
    @State private var dataOperationMessage: String? = nil
    
    /// Whether the analytics view is shown.
    @State private var showAnalytics: Bool = false
    
    /// Batch operation ViewModel.
    @State private var batchViewModel = BatchOperationViewModel(
        repository: CoreDataOKRRepository(container: PersistenceController.shared.container)
    )
    
    /// Analytics ViewModel.
    @State private var analyticsViewModel = AnalyticsViewModel(
        repository: CoreDataOKRRepository(container: PersistenceController.shared.container)
    )
    
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
                onExport: { showExportPanel() },
                onImport: { showImportPanel() },
                onAnalytics: { showAnalytics = true }
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
                let warning = NodeValidator().calculateDeleteWarning(for: node)
                if let warning = warning {
                    Text("确定要删除 \"\(node.title)\" 吗？\(warning.message)。此操作不可撤销。")
                } else {
                    Text("Are you sure you want to delete \"\(node.title)\"? This action cannot be undone.")
                }
            }
        }
        .sheet(isPresented: $showNewCycleSheet) {
            newCycleSheet
        }
        .sheet(isPresented: $showAnalytics) {
            NavigationStack {
                AnalyticsView(viewModel: analyticsViewModel, cycleId: selectedCycleId)
            }
            .frame(minWidth: 700, minHeight: 500)
        }
        .alert("批量删除确认", isPresented: $batchViewModel.showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let root = viewModel.rootNode {
                    Task {
                        let refreshed = await batchViewModel.batchDelete(
                            selectedIds: batchViewModel.selectedNodeIds,
                            in: root
                        )
                        if refreshed {
                            await viewModel.refresh()
                        }
                    }
                }
            }
        } message: {
            if let root = viewModel.rootNode {
                let warning = batchViewModel.calculateDeleteWarning(
                    selectedIds: batchViewModel.selectedNodeIds,
                    in: root
                )
                Text(warning.isEmpty ? "确定要删除选中的 \(batchViewModel.selectedCount) 个节点吗？" : warning)
            }
        }
        .sheet(isPresented: $batchViewModel.showOwnerUpdateSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("批量更新负责人")
                        .font(.headline)
                    TextField("新的负责人名称", text: $batchViewModel.newOwnerName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    HStack {
                        Button("取消") {
                            batchViewModel.showOwnerUpdateSheet = false
                        }
                        .keyboardShortcut(.cancelAction)
                        Button("确认更新") {
                            if let root = viewModel.rootNode {
                                Task {
                                    let updatedRoot = await batchViewModel.batchUpdateOwner(
                                        newOwner: batchViewModel.newOwnerName,
                                        selectedIds: batchViewModel.selectedNodeIds,
                                        in: root
                                    )
                                    if updatedRoot != nil {
                                        batchViewModel.showOwnerUpdateSheet = false
                                        await viewModel.refresh()
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(batchViewModel.newOwnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(30)
                .frame(minWidth: 400)
            }
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
                .accessibilityLabel("Loading OKR tree")
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
                        .accessibilityHidden(true)
                    
                    TextField("Search OKRs...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .accessibilityLabel("Search OKRs")
                        .accessibilityHint("Type to search OKR nodes by title or owner")
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
                        .accessibilityLabel("Clear search")
                    }
                    
                    Text("\(searchResultNodeIds.count) found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(searchResultNodeIds.count) results found")
                    
                    Button("Cancel") {
                        isSearchActive = false
                        searchText = ""
                        searchResultNodeIds = []
                    }
                    .font(.caption)
                    .accessibilityLabel("Cancel search")
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
            .accessibilityLabel("Refresh tree")
            .accessibilityHint("Reloads the OKR tree data")
            
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
            .accessibilityLabel("Create new node")
            .accessibilityHint("Opens the form to create a new OKR node")
            
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
            .accessibilityLabel("Edit selected node")
            .accessibilityHint(selectedNode != nil ? "Opens the edit form for \(selectedNode!.title)" : "Select a node first")
            
            // Delete button
            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectedNode == nil || viewModel.isLoading)
            .help("Delete selected node (⌫)")
            .keyboardShortcut(.delete, modifiers: [])
            .accessibilityLabel("Delete selected node")
            .accessibilityHint(selectedNode != nil ? "Deletes \(selectedNode!.title)" : "Select a node first")
            
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
            .accessibilityLabel("Toggle search")
            .accessibilityHint(isSearchActive ? "Close search field" : "Open search field to search OKRs")
            
            Divider()
            
            // Multi-select toggle
            Button {
                batchViewModel.toggleMultiSelectMode()
            } label: {
                Label(
                    batchViewModel.isMultiSelectMode ? "Exit Select" : "Multi-Select",
                    systemImage: batchViewModel.isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            .help("Toggle multi-select mode")
            .tint(batchViewModel.isMultiSelectMode ? .blue : nil)
            
            // Batch operations (visible in multi-select mode)
            if batchViewModel.isMultiSelectMode {
                // Batch delete
                Button {
                    if let root = viewModel.rootNode {
                        let warning = batchViewModel.calculateDeleteWarning(
                            selectedIds: batchViewModel.selectedNodeIds,
                            in: root
                        )
                        batchViewModel.deleteWarningMessage = warning
                        batchViewModel.showDeleteConfirmation = true
                    }
                } label: {
                    Label("Batch Delete", systemImage: "trash")
                }
                .disabled(!batchViewModel.hasSelection)
                .help("Delete selected nodes")
                
                // Batch update owner
                Button {
                    batchViewModel.newOwnerName = ""
                    batchViewModel.showOwnerUpdateSheet = true
                } label: {
                    Label("Batch Owner", systemImage: "person.2")
                }
                .disabled(!batchViewModel.hasSelection)
                .help("Update owner for selected nodes")
                
                // Batch export
                Button {
                    if let root = viewModel.rootNode {
                        let csv = batchViewModel.batchExportCSV(
                            selectedIds: batchViewModel.selectedNodeIds,
                            in: root
                        )
                        // Use NSSavePanel to save
                        #if os(macOS)
                        let panel = NSSavePanel()
                        panel.title = "Export Selected Nodes"
                        panel.allowedContentTypes = [.commaSeparatedText]
                        panel.nameFieldStringValue = "okr-selection-export"
                        panel.begin { response in
                            guard response == .OK, let url = panel.url else { return }
                            try? csv.write(to: url, atomically: true, encoding: .utf8)
                        }
                        #endif
                    }
                } label: {
                    Label("Batch Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!batchViewModel.hasSelection)
                .help("Export selected nodes as CSV")
                
                // Selection count badge
                Text("\(batchViewModel.selectedCount) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        // Export all data (all cycles with their trees)
        let panel = NSSavePanel()
        panel.title = "Export OKR Data"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "okr-export-\(formattedDateShort(Date()))"
        panel.canCreateDirectories = true
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            // Build trees for all cycles
            var trees: [UUID: OKRNode?] = [:]
            for cycle in cycles {
                // If the current tree belongs to this cycle, include it
                if selectedCycleId == cycle.id, let root = viewModel.rootNode {
                    trees[cycle.id] = root
                }
            }
            
            if let jsonData = OKRExportService.exportFullData(cycles: cycles, trees: trees) {
                do {
                    try jsonData.write(to: url)
                    DispatchQueue.main.async {
                        dataOperationMessage = "Export completed successfully"
                    }
                } catch {
                    DispatchQueue.main.async {
                        dataOperationMessage = "Export failed: \(error.localizedDescription)"
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - Import
    
    /// Shows the macOS open panel for importing OKR data.
    private func showImportPanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Import OKR Data"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let result = try OKRExportService.importFromJSON(data: data)
                
                DispatchQueue.main.async {
                    isDataOperationInProgress = true
                    
                    Task {
                        // Import cycles and nodes into the repository
                        let repository = CoreDataOKRRepository(
                            container: PersistenceController.shared.container
                        )
                        
                        for cycle in result.cycles {
                            do {
                                _ = try await repository.createCycle(cycle)
                                if let rootNode = result.nodesByCycle[cycle.id] {
                                    try await importNodeTree(rootNode, cycleId: cycle.id, repository: repository)
                                }
                            } catch {
                                dataOperationMessage = "Failed to import cycle '\(cycle.name)': \(error.localizedDescription)"
                            }
                        }
                        
                        // Import standalone nodes (from single-tree export format)
                        for node in result.standaloneNodes {
                            if let cycleId = selectedCycleId {
                                try await importNodeTree(node, cycleId: cycleId, repository: repository)
                            }
                        }
                        
                        try await repository.save()
                        
                        // Refresh the UI
                        await cycleViewModel.loadCycles()
                        cycles = cycleViewModel.cycles
                        
                        if let firstCycle = result.cycles.first {
                            selectedCycleId = firstCycle.id
                            await viewModel.loadTree(cycleId: firstCycle.id)
                        } else {
                            await viewModel.loadTree(cycleId: selectedCycleId)
                        }
                        
                        isDataOperationInProgress = false
                        dataOperationMessage = "Import completed: \(result.cycles.count) cycle(s) imported"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    dataOperationMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
        #endif
    }
    
    /// Recursively imports a node tree into the repository.
    private func importNodeTree(_ node: OKRNode, cycleId: UUID, repository: OKRRepositoryProtocol) async throws {
        var nodeToCreate = node
        nodeToCreate.cycleId = cycleId
        _ = try await repository.createNode(nodeToCreate)
        
        for child in node.children {
            var childToCreate = child
            childToCreate.parentId = node.id
            childToCreate.cycleId = cycleId
            try await importNodeTree(childToCreate, cycleId: cycleId, repository: repository)
        }
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
        
        // If the selected cycle was archived, keep selection
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
    
    /// Formats a date for file naming (YYYY-MM-DD).
    private func formattedDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
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
