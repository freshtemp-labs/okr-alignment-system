// OKRAlignmentShared/Views/Analytics/ExportDialogView.swift

import SwiftUI

/// 导出报表对话框
/// ===============
/// 提供完整的报表导出对话框，包括：
/// - 格式选择（PDF/Excel/JSON/CSV）
/// - 导出范围选择（全量/按周期/按Owner）
/// - 导出预览
/// - 导出进度和结果
///
/// ## 使用示例
/// ```swift
/// ExportDialogView(
///     cycles: cycles,
///     trees: trees,
///     isPresented: $showExport
/// )
/// ```
public struct ExportDialogView: View {

    // MARK: - Properties

    /// 所有周期
    let cycles: [OKRCycle]
    /// 每个周期对应的根节点字典
    let trees: [UUID: OKRNode?]
    /// 是否显示
    @Binding var isPresented: Bool

    /// 选中的导出格式
    @State private var selectedFormat: ReportExportService.ExportFormat = .pdf
    /// 选中的导出范围
    @State private var selectedScope: ReportExportService.ExportScope = .all
    /// 自定义周期选择
    @State private var selectedCycleIds: Set<UUID> = []
    /// 自定义 Owner 选择
    @State private var selectedOwners: Set<String> = []
    /// 是否显示预览
    @State private var showPreview = true
    /// 导出预览
    @State private var preview: ReportExportService.ExportPreview?
    /// 是否正在导出
    @State private var isExporting = false
    /// 导出结果
    @State private var exportResult: ReportExportService.ExportResult?
    /// 导出错误
    @State private var exportError: String?
    /// 是否显示保存面板
    @State private var showSavePanel = false

    /// 可用的 Owner 列表
    private var availableOwners: [String] {
        var owners = Set<String>()
        for (_, root) in trees {
            if let rootNode = root {
                collectOwners(rootNode, into: &owners)
            }
        }
        return owners.sorted()
    }

    // MARK: - Body

    public init(
        cycles: [OKRCycle],
        trees: [UUID: OKRNode?],
        isPresented: Binding<Bool>
    ) {
        self.cycles = cycles
        self.trees = trees
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            Form {
                // 格式选择
                formatSection

                // 范围选择
                scopeSection

                // 预览区域
                if showPreview {
                    previewSection
                }

                // 导出结果
                if let result = exportResult {
                    resultSection(result)
                }

                if let error = exportError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("导出报表")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        performExport()
                    } label: {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("导出")
                        }
                    }
                    .disabled(isExporting || cycles.isEmpty)
                }
            }
            .task {
                updatePreview()
            }
            .onChange(of: selectedFormat) { _, _ in
                updatePreview()
            }
            .onChange(of: selectedScope) { _, _ in
                updatePreview()
            }
            .fileExporter(
                isPresented: $showSavePanel,
                document: exportResult.map { ExportDocument(data: $0.data, fileName: $0.fileName) },
                contentType: .data,
                defaultFilename: exportResult?.fileName
            ) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    exportError = "保存失败: \(error.localizedDescription)"
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    // MARK: - Format Section

    private var formatSection: some View {
        Section {
            ForEach(ReportExportService.ExportFormat.allCases, id: \.self) { format in
                Button {
                    selectedFormat = format
                } label: {
                    HStack {
                        Image(systemName: formatIcon(format))
                            .frame(width: 24)
                            .foregroundStyle(formatColor(format))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(format.displayName)
                                .fontWeight(.medium)
                            Text(formatDescription(format))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedFormat == format {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("导出格式")
        }
    }

    // MARK: - Scope Section

    private var scopeSection: some View {
        Section {
            // 全量导出
            scopeOption("全量导出", scope: .all, icon: "doc.on.doc")

            // 按周期
            if cycles.count > 1 {
                DisclosureGroup {
                    ForEach(cycles) { cycle in
                        Button {
                            if selectedCycleIds.contains(cycle.id) {
                                selectedCycleIds.remove(cycle.id)
                            } else {
                                selectedCycleIds.insert(cycle.id)
                            }
                            updateSelectedScope()
                        } label: {
                            HStack {
                                Image(systemName: selectedCycleIds.contains(cycle.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedCycleIds.contains(cycle.id) ? .blue : .secondary)
                                Text(cycle.name)
                                Spacer()
                                Text("\(cycle.startDate, style: .date) - \(cycle.endDate, style: .date)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } label: {
                    Label("按周期选择", systemImage: "calendar")
                }
            }

            // 按负责人
            if !availableOwners.isEmpty {
                DisclosureGroup {
                    ForEach(availableOwners, id: \.self) { owner in
                        Button {
                            if selectedOwners.contains(owner) {
                                selectedOwners.remove(owner)
                            } else {
                                selectedOwners.insert(owner)
                            }
                            updateSelectedScope()
                        } label: {
                            HStack {
                                Image(systemName: selectedOwners.contains(owner) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedOwners.contains(owner) ? .blue : .secondary)
                                Text(owner)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } label: {
                    Label("按负责人选择", systemImage: "person.2")
                }
            }
        } header: {
            Text("导出范围")
        }
    }

    private func scopeOption(_ title: String, scope: ReportExportService.ExportScope, icon: String) -> some View {
        Button {
            selectedScope = scope
            selectedCycleIds.removeAll()
            selectedOwners.removeAll()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if isScopeSelected(scope) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func isScopeSelected(_ scope: ReportExportService.ExportScope) -> Bool {
        switch (selectedScope, scope) {
        case (.all, .all): return true
        case (.byCycles, .byCycles): return selectedCycleIds.count > 0
        case (.byOwners, .byOwners): return selectedOwners.count > 0
        default: return false
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section {
            if let preview = preview {
                VStack(alignment: .leading, spacing: 12) {
                    // 标题
                    Text(preview.title)
                        .font(.headline)

                    // 统计概要
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        PreviewMetric(title: "周期", value: "\(preview.cycleCount)")
                        PreviewMetric(title: "节点", value: "\(preview.totalNodesCount)")
                        PreviewMetric(title: "平均进度", value: String(format: "%.1f%%", preview.averageProgress))
                        PreviewMetric(title: "Objective", value: "\(preview.objectiveCount)")
                        PreviewMetric(title: "KR", value: "\(preview.keyResultCount)")
                        PreviewMetric(title: "已完成", value: "\(preview.statusDistribution[.completed] ?? 0)")
                    }

                    Divider()

                    // 进度分布
                    if preview.totalNodesCount > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("进度分布")
                                .font(.caption.bold())
                            ForEach(preview.progressDistribution.asArray, id: \.0) { label, count in
                                HStack {
                                    Text(label)
                                        .font(.caption2)
                                        .frame(width: 60, alignment: .leading)
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.blue.opacity(0.3))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.blue)
                                                    .frame(width: max(0, geo.size.width * (preview.totalNodesCount > 0 ? CGFloat(count) / CGFloat(max(preview.totalNodesCount, 1)) : 0)))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            )
                                    }
                                    .frame(height: 12)
                                    Text("\(count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                }
                            }
                        }
                    }

                    // 周期概要
                    if !preview.cycleSummaries.isEmpty {
                        Divider()
                        Text("包含的周期")
                            .font(.caption.bold())
                        ForEach(preview.cycleSummaries, id: \.cycleId) { summary in
                            HStack {
                                Text(summary.cycleName)
                                    .font(.caption)
                                Spacer()
                                Text("\(summary.nodeCount) 节点")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.0f%%", summary.averageProgress))
                                    .font(.caption2.bold())
                                    .foregroundStyle(summary.averageProgress >= 80 ? .green : (summary.averageProgress >= 50 ? .blue : .orange))
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Text("计算预览中...")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            }
        } header: {
            HStack {
                Text("导出预览")
                Spacer()
                Toggle("显示预览", isOn: $showPreview)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Result Section

    private func resultSection(_ result: ReportExportService.ExportResult) -> some View {
        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("导出成功")
                    .fontWeight(.medium)
            }

            HStack {
                Text("文件名")
                Spacer()
                Text(result.fileName)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            HStack {
                Text("文件大小")
                Spacer()
                Text(formatFileSize(result.fileSize))
                    .foregroundStyle(.secondary)
            }

            Button {
                showSavePanel = true
            } label: {
                Label("保存到文件", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } header: {
            Text("导出结果")
        }
    }

    // MARK: - Helpers

    private func updatePreview() {
        preview = ReportExportService.generatePreview(
            cycles: cycles,
            trees: trees,
            scope: selectedScope
        )
    }

    private func updateSelectedScope() {
        if !selectedCycleIds.isEmpty {
            selectedScope = .byCycles(cycleIds: Array(selectedCycleIds))
        } else if !selectedOwners.isEmpty {
            selectedScope = .byOwners(ownerNames: Array(selectedOwners))
        } else {
            selectedScope = .all
        }
    }

    private func performExport() {
        isExporting = true
        exportError = nil
        exportResult = nil

        do {
            let result = try ReportExportService.export(
                format: selectedFormat,
                cycles: cycles,
                trees: trees,
                scope: selectedScope
            )
            exportResult = result
        } catch {
            exportError = "导出失败: \(error.localizedDescription)"
        }
        isExporting = false
    }

    private func formatIcon(_ format: ReportExportService.ExportFormat) -> String {
        switch format {
        case .pdf: return "doc.richtext"
        case .excel: return "tablecells"
        case .json: return "doc.text"
        case .csv: return "list.bullet.rectangle"
        }
    }

    private func formatColor(_ format: ReportExportService.ExportFormat) -> Color {
        switch format {
        case .pdf: return .red
        case .excel: return .green
        case .json: return .orange
        case .csv: return .blue
        }
    }

    private func formatDescription(_ format: ReportExportService.ExportFormat) -> String {
        switch format {
        case .pdf: return "带图表和排版的 PDF 报表"
        case .excel: return "多段结构的 CSV，可用 Excel 打开"
        case .json: return "结构化 JSON 数据，含统计和明细"
        case .csv: return "扁平化 CSV，每行一个节点"
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }

    private func collectOwners(_ node: OKRNode, into owners: inout Set<String>) {
        owners.insert(node.ownerName)
        for child in node.children {
            collectOwners(child, into: &owners)
        }
    }
}

// MARK: - Preview Metric

private struct PreviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.callout.bold())
                .foregroundStyle(.blue)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Export Document

private struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data
    let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.fileName = "export"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

import UniformTypeIdentifiers
