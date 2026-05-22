import SwiftUI

// MARK: - NodeEditForm

/// A comprehensive form for creating or editing OKR nodes.
///
/// `NodeEditForm` provides all necessary input fields for managing an OKR node:
/// - Title text field
/// - Multi-line description editor
/// - Type picker (Objective / Key Result)
/// - Scope picker (Enterprise / Personal)
/// - Owner name input
/// - Current/target values and unit (for KR nodes)
/// - Status picker
/// - Parent node selector
///
/// The form adapts its layout based on the platform and validates input before saving.
///
/// ## Example
/// ```swift
/// NodeEditForm(
///     mode: .edit(existingNode),
///     availableParents: parentCandidates,
///     onSave: { node in await viewModel.save(node) },
///     onCancel: { dismiss() }
/// )
/// ```
public struct NodeEditForm: View {
    // MARK: - Form Mode
    
    /// Indicates whether the form is creating a new node or editing an existing one.
    public enum Mode {
        case create(parentId: UUID?)
        case edit(OKRNode)
        
        /// The title for the form navigation bar.
        var title: String {
            switch self {
            case .create: return "New OKR Node"
            case .edit: return "Edit OKR Node"
            }
        }
    }
    
    // MARK: - Properties
    
    /// The form mode (create or edit).
    let mode: Mode
    
    /// List of available parent nodes for the parent selector.
    let availableParents: [OKRNode]
    
    /// Callback when the form is saved with a valid node.
    let onSave: (OKRNode) -> Void
    
    /// Callback when the user cancels.
    let onCancel: () -> Void
    
    // MARK: - Form State
    
    @State private var title: String = ""
    @State private var nodeDescription: String = ""
    @State private var nodeType: NodeType = .objective
    @State private var scope: Scope = .enterprise
    @State private var ownerName: String = ""
    @State private var currentValue: Double = 0
    @State private var targetValue: Double = 100
    @State private var unit: String? = "%"
    @State private var status: NodeStatus = .notStarted
    @State private var selectedParentId: UUID?
    @State private var titleError: String? = nil
    @State private var ownerError: String? = nil
    @State private var isSaving: Bool = false
    
    // MARK: - Constants
    
    private let cardBackground = Color(red: 30/255, green: 41/255, blue: 59/255)
    private let inputBackground = Color.white.opacity(0.05)
    private let borderColor = Color.white.opacity(0.1)
    private let labelColor = Color(red: 148/255, green: 163/255, blue: 184/255)
    
    // MARK: - Initialization
    
    /// Creates a new node edit form.
    /// - Parameters:
    ///   - mode: Whether creating or editing.
    ///   - availableParents: Nodes available for parent selection.
    ///   - onSave: Closure called with the configured node.
    ///   - onCancel: Closure called when cancelled.
    public init(
        mode: Mode,
        availableParents: [OKRNode] = [],
        onSave: @escaping (OKRNode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.availableParents = availableParents
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    // MARK: - Computed Properties
    
    /// Whether the form has valid input.
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !ownerName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Whether value fields should be shown (only for KR nodes).
    private var showValueFields: Bool {
        nodeType == .keyResult
    }
    
    /// The original node ID when in edit mode.
    private var editingNodeId: UUID? {
        if case .edit(let node) = mode {
            return node.id
        }
        return nil
    }
    
    // MARK: - Body
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text(mode.title)
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Title field
                formField(title: "Title *", error: titleError) {
                    TextField("Enter OKR title", text: $title)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(inputBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(titleError != nil ? Color.red.opacity(0.6) : borderColor, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onChange(of: title) { validateTitle() }
                        .accessibilityLabel("Node title")
                }
                
                // Description field
                formField(title: "Description") {
                    ZStack(alignment: .topLeading) {
                        if nodeDescription.isEmpty {
                            Text("Enter a description for this OKR...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.3))
                                .padding(10)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $nodeDescription)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(minHeight: 80)
                            .padding(6)
                    }
                    .background(inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Node description")
                }
                
                // Type and Scope pickers (horizontal on macOS)
                HStack(spacing: 16) {
                    // Type picker
                    formField(title: "Type") {
                        Picker("Type", selection: $nodeType) {
                            ForEach(NodeType.allCases, id: \.self) { type in
                                Text(type == .objective ? "Objective" : "Key Result")
                                    .tag(type)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(.segmented)
                        #else
                        .pickerStyle(.menu)
                        #endif
                        .accessibilityLabel("Node type")
                    }
                    
                    // Scope picker
                    formField(title: "Scope") {
                        Picker("Scope", selection: $scope) {
                            ForEach(Scope.allCases, id: \.self) { s in
                                Text(s == .enterprise ? "Enterprise" : "Personal")
                                    .tag(s)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(.segmented)
                        #else
                        .pickerStyle(.menu)
                        #endif
                        .accessibilityLabel("Node scope")
                    }
                }
                
                // Owner field
                formField(title: "Owner *", error: ownerError) {
                    TextField("Enter owner name", text: $ownerName)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(inputBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ownerError != nil ? Color.red.opacity(0.6) : borderColor, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onChange(of: ownerName) { validateOwner() }
                        .accessibilityLabel("Owner name")
                }
                
                // Value fields (only for KR)
                if showValueFields {
                    HStack(spacing: 16) {
                        ValuePicker(
                            title: "Current Value",
                            value: $currentValue,
                            unit: $unit,
                            min: 0,
                            max: 999999
                        )
                        
                        ValuePicker(
                            title: "Target Value",
                            value: $targetValue,
                            unit: .constant(nil),
                            min: 1,
                            max: 999999
                        )
                    }
                }
                
                // Status picker
                formField(title: "Status") {
                    Picker("Status", selection: $status) {
                        ForEach(NodeStatus.allCases, id: \.self) { s in
                            statusLabel(for: s)
                                .tag(s)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.segmented)
                    #else
                    .pickerStyle(.menu)
                    #endif
                    .accessibilityLabel("Node status")
                }
                
                // Parent selector
                if !availableParents.isEmpty {
                    formField(title: "Parent (Optional)") {
                        Picker("Parent", selection: $selectedParentId) {
                            Text("No Parent (Root)").tag(UUID?.none)
                            ForEach(availableParents) { parent in
                                Text(parent.title)
                                    .tag(Optional(parent.id))
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        #endif
                        .accessibilityLabel("Parent node")
                    }
                }
                
                Spacer(minLength: 20)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel")
                    
                    Button {
                        saveNode()
                    } label: {
                        HStack(spacing: 6) {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                            Text("Save")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isValid ? Color(red: 37/255, green: 99/255, blue: 235/255) : Color.gray.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid || isSaving)
                    .accessibilityLabel("Save node")
                }
            }
            .padding(24)
        }
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        .onAppear {
            loadExistingData()
        }
    }
    
    // MARK: - Form Field Helper
    
    /// A reusable form field wrapper with label and optional error.
    @ViewBuilder
    private func formField<V: View>(title: String, error: String? = nil, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(labelColor)
            
            content()
            
            if let error = error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
    }
    
    /// Creates a status label with appropriate color.
    private func statusLabel(for status: NodeStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text(statusDisplayName(status))
                .foregroundStyle(.primary)
        }
    }
    
    /// Returns the display color for a status.
    private func statusColor(_ status: NodeStatus) -> Color {
        switch status {
        case .notStarted: return Color(red: 148/255, green: 163/255, blue: 184/255)
        case .inProgress: return Color(red: 59/255, green: 130/255, blue: 246/255)
        case .atRisk: return Color(red: 239/255, green: 68/255, blue: 68/255)
        case .completed: return Color(red: 16/255, green: 185/255, blue: 129/255)
        case .cancelled: return Color(red: 100/255, green: 100/255, blue: 100/255)
        }
    }
    
    /// Returns the human-readable name for a status.
    private func statusDisplayName(_ status: NodeStatus) -> String {
        switch status {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .atRisk: return "At Risk"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    // MARK: - Validation
    
    private func validateTitle() {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            titleError = "Title is required"
        } else {
            titleError = nil
        }
    }
    
    private func validateOwner() {
        if ownerName.trimmingCharacters(in: .whitespaces).isEmpty {
            ownerError = "Owner name is required"
        } else {
            ownerError = nil
        }
    }
    
    // MARK: - Data Loading
    
    private func loadExistingData() {
        guard case .edit(let node) = mode else {
            // Set default parent for create mode
            if case .create(let parentId) = mode {
                selectedParentId = parentId
            }
            return
        }
        
        title = node.title
        nodeDescription = node.nodeDescription ?? ""
        nodeType = node.nodeType
        scope = node.scope
        ownerName = node.ownerName
        currentValue = node.currentValue
        targetValue = node.targetValue
        unit = node.unit
        status = node.status
        selectedParentId = node.parentId
    }
    
    // MARK: - Save
    
    private func saveNode() {
        guard isValid else { return }
        
        let nodeId = editingNodeId ?? UUID()
        let now = Date()
        let createdAt: Date
        
        if case .edit(let existing) = mode {
            createdAt = existing.createdAt
        } else {
            createdAt = now
        }
        
        let progress = calculateProgress()
        
        let node = OKRNode(
            id: nodeId,
            title: title.trimmingCharacters(in: .whitespaces),
            nodeDescription: nodeDescription.isEmpty ? nil : nodeDescription,
            nodeType: nodeType,
            scope: scope,
            currentValue: showValueFields ? currentValue : 0,
            targetValue: showValueFields ? targetValue : 0,
            unit: showValueFields ? unit : nil,
            progress: progress,
            status: status,
            ownerName: ownerName.trimmingCharacters(in: .whitespaces),
            sortOrder: 0,
            parentId: selectedParentId,
            children: [], // Children are managed separately
            cycleId: nil,
            createdAt: createdAt,
            updatedAt: now
        )
        
        isSaving = true
        onSave(node)
    }
    
    private func calculateProgress() -> Double {
        guard showValueFields && targetValue > 0 else { return 0 }
        let ratio = (currentValue / targetValue) * 100
        return min(max(ratio, 0), 100)
    }
}

// MARK: - Previews

// --- Preview block commented out for SPM build ---
// #Preview("Create Mode") {
//     NodeEditForm(
//         mode: .create(parentId: nil),
//         availableParents: [
//             OKRNode(id: UUID(), title: "Parent Objective 1", nodeDescription: nil, nodeType: .objective, scope: .enterprise, currentValue: 0, targetValue: 0, unit: nil, progress: 50, status: .inProgress, ownerName: "Alice", createdAt: Date(), updatedAt: Date(), sortOrder: 0, parentId: nil, children: [], cycleId: nil),
//             OKRNode(id: UUID(), title: "Parent Objective 2", nodeDescription: nil, nodeType: .objective, scope: .personal, currentValue: 0, targetValue: 0, unit: nil, progress: 30, status: .inProgress, ownerName: "Bob", createdAt: Date(), updatedAt: Date(), sortOrder: 1, parentId: nil, children: [], cycleId: nil)
//         ],
//         onSave: { _ in },
//         onCancel: {}
//     )
//     .frame(width: 480, height: 700)
// }

// --- Preview block commented out for SPM build ---
// #Preview("Edit Mode - Objective") {
//     let existingNode = OKRNode(
//         id: UUID(),
//         title: "Increase Q4 Revenue",
//         nodeDescription: "Focus on enterprise customers",
//         nodeType: .objective,
//         scope: .enterprise,
//         currentValue: 0,
//         targetValue: 0,
//         unit: nil,
//         progress: 65.0,
//         status: .inProgress,
//         ownerName: "Alice Chen",
//         createdAt: Date(),
//         updatedAt: Date(),
//         sortOrder: 0,
//         parentId: nil,
//         children: [],
//         cycleId: nil
//     )
//     
//     NodeEditForm(
//         mode: .edit(existingNode),
//         availableParents: [],
//         onSave: { _ in },
//         onCancel: {}
//     )
//     .frame(width: 480, height: 700)
// }

// --- Preview block commented out for SPM build ---
// #Preview("Edit Mode - Key Result") {
//     let existingNode = OKRNode(
//         id: UUID(),
//         title: "Launch onboarding v2",
//         nodeDescription: "Redesign the user onboarding experience",
//         nodeType: .keyResult,
//         scope: .personal,
//         currentValue: 3,
//         targetValue: 5,
//         unit: "features",
//         progress: 60.0,
//         status: .inProgress,
//         ownerName: "Bob Smith",
//         createdAt: Date(),
//         updatedAt: Date(),
//         sortOrder: 0,
//         parentId: UUID(),
//         children: [],
//         cycleId: nil
//     )
//     
//     NodeEditForm(
//         mode: .edit(existingNode),
//         availableParents: [
//             OKRNode(id: UUID(), title: "Q4 Product Goals", nodeDescription: nil, nodeType: .objective, scope: .enterprise, currentValue: 0, targetValue: 0, unit: nil, progress: 50, status: .inProgress, ownerName: "Alice", createdAt: Date(), updatedAt: Date(), sortOrder: 0, parentId: nil, children: [], cycleId: nil)
//         ],
//         onSave: { _ in },
//         onCancel: {}
//     )
//     .frame(width: 480, height: 700)
// }
