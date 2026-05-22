import SwiftUI
import OKRAlignmentShared

// MARK: - SidebarView

/// The macOS sidebar displaying cycle selection and management.
///
/// `SidebarView` provides a NavigationSplitView-compatible sidebar with:
/// - A list of available OKR cycles
/// - Selection state with highlighted active cycle
/// - New cycle creation button at the bottom
/// - Search/filter functionality for cycles
/// - Export and Import buttons
/// - Cycle status color indicators
///
public struct SidebarView: View {
    // MARK: - Properties
    
    /// The list of available cycles to display.
    let cycles: [OKRCycle]
    
    /// Binding to the currently selected cycle ID.
    @Binding var selectedCycleId: UUID?
    
    /// Callback when the create cycle button is tapped.
    let onCreateCycle: () -> Void
    
    /// Callback when a cycle is deleted.
    let onDeleteCycle: (UUID) -> Void
    
    /// Callback when a cycle is archived (with confirmation).
    let onArchiveCycle: ((UUID) -> Void)?
    
    /// Callback when a cycle is activated.
    let onActivateCycle: ((UUID) -> Void)?
    
    /// Callback when the export button is tapped.
    let onExport: (() -> Void)?
    
    /// Callback when the import button is tapped.
    let onImport: (() -> Void)?
    
    /// Callback when the analytics button is tapped.
    let onAnalytics: (() -> Void)?
    
    /// Search text for filtering cycles.
    @State private var searchText: String = ""
    
    /// Whether the archive confirmation dialog is shown.
    @State private var showArchiveConfirmation: Bool = false
    
    /// The cycle ID pending archive confirmation.
    @State private var pendingArchiveCycleId: UUID? = nil
    
    // MARK: - Constants
    
    private let sidebarBackground = Color(red: 15/255, green: 23/255, blue: 42/255)
    private let selectionColor = Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.3)
    
    // MARK: - Initialization
    
    /// Creates a new sidebar view.
    public init(
        cycles: [OKRCycle],
        selectedCycleId: Binding<UUID?>,
        onCreateCycle: @escaping () -> Void,
        onDeleteCycle: @escaping (UUID) -> Void = { _ in },
        onArchiveCycle: ((UUID) -> Void)? = nil,
        onActivateCycle: ((UUID) -> Void)? = nil,
        onExport: (() -> Void)? = nil,
        onImport: (() -> Void)? = nil,
        onAnalytics: (() -> Void)? = nil
    ) {
        self.cycles = cycles
        self._selectedCycleId = selectedCycleId
        self.onCreateCycle = onCreateCycle
        self.onDeleteCycle = onDeleteCycle
        self.onArchiveCycle = onArchiveCycle
        self.onActivateCycle = onActivateCycle
        self.onExport = onExport
        self.onImport = onImport
        self.onAnalytics = onAnalytics
    }
    
    // MARK: - Computed Properties
    
    /// Cycles filtered by search text.
    private var filteredCycles: [OKRCycle] {
        if searchText.isEmpty {
            return cycles
        }
        return cycles.filter { cycle in
            cycle.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Row Builder
    
    /// Extracted row builder to reduce type-checker complexity.
    @ViewBuilder
    private func cycleListRow(for cycle: OKRCycle) -> some View {
        let isSelected = selectedCycleId == cycle.id
        let rowBackground: Color = isSelected ? selectionColor : Color.clear
        
        CycleRow(cycle: cycle, isSelected: isSelected)
            .tag(cycle.id)
            .listRowBackground(rowBackground)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            .animation(.easeInOut(duration: 0.25), value: isSelected)
            .contextMenu {
                if !cycle.isArchived {
                    Button("Activate") {
                        onActivateCycle?(cycle.id)
                    }
                    .disabled(cycle.isActive)
                    
                    Divider()
                    
                    Button("Archive") {
                        pendingArchiveCycleId = cycle.id
                        showArchiveConfirmation = true
                    }
                    
                    Divider()
                }
                
                Button("Delete", role: .destructive) {
                    onDeleteCycle(cycle.id)
                }
            }
            .accessibilityLabel("Cycle: \(cycle.name)")
            .accessibilityValue(cycleStatusText(cycle))
            .accessibilityHint("Select to view OKR tree for this cycle")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cycles")
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                    .tracking(0.5)
                
                Spacer()
                
                Text("\(cycles.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cycles header, \(cycles.count) cycles available")
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                    .accessibilityHidden(true)
                
                TextField("Filter cycles", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Filter cycles")
                    .accessibilityHint("Type to filter the cycle list")
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Cycle list
            List(selection: $selectedCycleId) {
                Section {
                    ForEach(filteredCycles) { cycle in
                        cycleListRow(for: cycle)
                    }
                } header: {
                    if !searchText.isEmpty {
                        let resultCount = filteredCycles.count
                        let suffix = resultCount == 1 ? "" : "s"
                        Text("\(resultCount) result\(suffix)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(sidebarBackground)
            .accessibilityLabel("Cycle list")
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Bottom buttons
            VStack(spacing: 6) {
                // Create cycle button
                Button {
                    onCreateCycle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("New Cycle")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 147/255, green: 197/255, blue: 253/255))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create new cycle")
                .accessibilityHint("Opens a form to create a new OKR cycle")
                
                // Import/Export row
                HStack(spacing: 6) {
                    // Import button
                    if onImport != nil {
                        Button {
                            onImport?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 12))
                                Text("Import")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Import OKR data")
                        .accessibilityHint("Opens a file dialog to import OKR data from a JSON file")
                    }
                    
                    // Export button
                    if onExport != nil {
                        Button {
                            onExport?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12))
                                Text("Export")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Export OKR data")
                        .accessibilityHint("Opens a save dialog to export OKR data as JSON or CSV")
                    }
                }
                
                // Analytics button
                if onAnalytics != nil {
                    Button {
                        onAnalytics?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 12))
                            Text("Analytics")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View analytics")
                    .accessibilityHint("Opens the analytics dashboard")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(sidebarBackground)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
        .confirmationDialog(
            "Archive Cycle",
            isPresented: $showArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) {
                if let cycleId = pendingArchiveCycleId {
                    onArchiveCycle?(cycleId)
                }
                pendingArchiveCycleId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingArchiveCycleId = nil
            }
        } message: {
            Text("Are you sure you want to archive this cycle? Archived cycles become read-only.")
        }
    }
    
    // MARK: - Helpers
    
    /// Returns a human-readable status text for accessibility.
    private func cycleStatusText(_ cycle: OKRCycle) -> String {
        if cycle.isArchived { return "Archived" }
        if cycle.isActive { return "Active" }
        return "Draft"
    }
}

// MARK: - CycleRow (uses shared OKRCycle from OKRAlignmentShared)

/// A single row in the sidebar cycle list.
struct CycleRow: View {
    let cycle: OKRCycle
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // Status indicator with color coding
            // Active = green, Draft (inactive) = gray, Archived = blue
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(cycle.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : Color(red: 203/255, green: 213/255, blue: 225/255))
                        .lineLimit(1)
                    
                    // Archived badge
                    if cycle.isArchived {
                        Text("ARCHIVED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                
                Text(formattedDateRange)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
    
    /// Cycle status color:
    /// - Active (isActive): green
    /// - Archived (isArchived): blue
    /// - Draft (neither): gray
    private var statusColor: Color {
        if cycle.isArchived {
            return Color(red: 59/255, green: 130/255, blue: 246/255) // blue
        }
        if cycle.isActive {
            return Color(red: 16/255, green: 185/255, blue: 129/255) // green
        }
        return Color(red: 100/255, green: 116/255, blue: 139/255) // gray (draft)
    }
    
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: cycle.startDate)) - \(formatter.string(from: cycle.endDate))"
    }
}

// MARK: - Preview Helpers (shared OKRCycle)

private func makeSampleCycles() -> [OKRCycle] {
    let calendar = Calendar.current
    guard let oct1 = calendar.date(from: DateComponents(year: 2024, month: 10, day: 1))
    else { return [] }
    let dec31 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))!
    guard let jul1 = calendar.date(from: DateComponents(year: 2024, month: 7, day: 1)),
          let sep30 = calendar.date(from: DateComponents(year: 2024, month: 9, day: 30)),
          let jan1 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)),
          let nov4 = calendar.date(from: DateComponents(year: 2024, month: 11, day: 4)),
          let nov15 = calendar.date(from: DateComponents(year: 2024, month: 11, day: 15))
    else { return [] }
    return [
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
        ),
        OKRCycle(
            id: UUID(),
            name: "Annual 2024",
            startDate: jan1,
            endDate: dec31,
            isActive: false
        ),
        OKRCycle(
            id: UUID(),
            name: "Sprint 42",
            startDate: nov4,
            endDate: nov15,
            isActive: true
        )
    ]
}

#if !SWIFT_PACKAGE
// MARK: - Previews

#Preview("Sidebar with Cycles") {
    @Previewable @State var selectedId: UUID?
    
    let cycles = makeSampleCycles()
    
    SidebarView(
        cycles: cycles,
        selectedCycleId: $selectedId,
        onCreateCycle: {},
        onDeleteCycle: { _ in }
    )
}

#Preview("Sidebar - Empty") {
    @Previewable @State var selectedId: UUID?
    
    SidebarView(
        cycles: [],
        selectedCycleId: $selectedId,
        onCreateCycle: {},
        onDeleteCycle: { _ in }
    )
}
#endif
