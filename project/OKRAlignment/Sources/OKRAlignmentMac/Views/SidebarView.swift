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
///
/// The sidebar uses the standard macOS sidebar appearance with custom styling
/// for the dark theme.
///
/// ## Example
/// ```swift
/// SidebarView(
///     cycles: viewModel.cycles,
///     selectedCycleId: $viewModel.selectedCycleId,
///     onCreateCycle: { showCreateSheet = true }
/// )
/// ```
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
    
    /// Search text for filtering cycles.
    @State private var searchText: String = ""
    
    // MARK: - Constants
    
    private let sidebarBackground = Color(red: 15/255, green: 23/255, blue: 42/255)
    private let selectionColor = Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.3)
    
    // MARK: - Initialization
    
    /// Creates a new sidebar view.
    /// - Parameters:
    ///   - cycles: The list of available cycles.
    ///   - selectedCycleId: Binding to the selected cycle ID.
    ///   - onCreateCycle: Closure called when creating a new cycle.
    ///   - onDeleteCycle: Closure called when deleting a cycle.
    public init(
        cycles: [OKRCycle],
        selectedCycleId: Binding<UUID?>,
        onCreateCycle: @escaping () -> Void,
        onDeleteCycle: @escaping (UUID) -> Void = { _ in }
    ) {
        self.cycles = cycles
        self._selectedCycleId = selectedCycleId
        self.onCreateCycle = onCreateCycle
        self.onDeleteCycle = onDeleteCycle
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
            .contextMenu {
                Button("Delete") {
                    onDeleteCycle(cycle.id)
                }
            }
            .accessibilityLabel("Cycle: \(cycle.name)")
            .accessibilityValue(cycle.isActive ? "Active" : "Inactive")
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
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                
                TextField("Filter cycles", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
                    }
                    .buttonStyle(.plain)
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
            
            Divider()
                .background(Color.white.opacity(0.08))
            
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .accessibilityLabel("Create new cycle")
        }
        .background(sidebarBackground)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
    }
}

// MARK: - CycleRow (uses shared OKRCycle from OKRAlignmentShared)

/// A single row in the sidebar cycle list.
struct CycleRow: View {
    let cycle: OKRCycle
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(cycle.isActive ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 100/255, green: 116/255, blue: 139/255))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(cycle.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : Color(red: 203/255, green: 213/255, blue: 225/255))
                    .lineLimit(1)
                
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
