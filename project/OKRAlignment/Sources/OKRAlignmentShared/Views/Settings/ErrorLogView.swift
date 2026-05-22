// OKRAlignmentShared/Views/Settings/ErrorLogView.swift

import SwiftUI

/// 错误日志查看视图
///
/// 功能：
/// - 显示所有错误日志条目
/// - 按严重程度筛选
/// - 支持清除日志
/// - 显示日志详情
public struct ErrorLogView: View {

    // MARK: - Properties

    @State private var errorHandler = AppErrorHandler.shared
    @State private var logs: [AppErrorHandler.ErrorLogEntry] = []
    @State private var selectedSeverity: AppErrorHandler.ErrorSeverity?
    @State private var showClearAlert = false
    @State private var selectedLog: AppErrorHandler.ErrorLogEntry?

    // MARK: - Body

    public init() {}

    public var body: some View {
        List {
            // 筛选器
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "全部",
                            isSelected: selectedSeverity == nil
                        ) {
                            selectedSeverity = nil
                            refreshLogs()
                        }

                        ForEach(
                            [AppErrorHandler.ErrorSeverity.critical, .error, .warning, .info],
                            id: \.self
                        ) { severity in
                            FilterChip(
                                title: severityLabel(severity),
                                isSelected: selectedSeverity == severity
                            ) {
                                selectedSeverity = severity
                                refreshLogs()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // 日志统计
            Section {
                HStack {
                    Label("总日志数", systemImage: "doc.text")
                    Spacer()
                    Text("\(logs.count)")
                        .foregroundStyle(.secondary)
                }

                if let criticalCount = severityCount(.critical), criticalCount > 0 {
                    HStack {
                        Label("严重错误", systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        Text("\(criticalCount)")
                            .foregroundStyle(.red)
                    }
                }

                if let errorCount = severityCount(.error), errorCount > 0 {
                    HStack {
                        Label("错误", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("\(errorCount)")
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("统计")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 日志列表
            if logs.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("暂无错误日志")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("一切运行正常")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach(logs) { log in
                        Button {
                            selectedLog = log
                        } label: {
                            LogEntryRow(log: log)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("错误日志")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 清除日志
            if !logs.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Label("清除所有日志", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("错误日志")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            refreshLogs()
        }
        .alert("清除日志", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                errorHandler.clearLogs()
                refreshLogs()
            }
        } message: {
            Text("确定要清除所有错误日志吗？此操作不可撤销。")
        }
        .sheet(item: $selectedLog) { log in
            LogDetailView(log: log)
        }
    }

    // MARK: - Private Methods

    private func refreshLogs() {
        let allLogs = errorHandler.allLogs()
        if let severity = selectedSeverity {
            logs = allLogs.filter { $0.severity == severity.rawValue }
        } else {
            logs = allLogs
        }
    }

    private func severityCount(_ severity: AppErrorHandler.ErrorSeverity) -> Int? {
        let allLogs = errorHandler.allLogs()
        return allLogs.filter { $0.severity == severity.rawValue }.count
    }

    private func severityLabel(_ severity: AppErrorHandler.ErrorSeverity) -> String {
        switch severity {
        case .critical: return "严重"
        case .error: return "错误"
        case .warning: return "警告"
        case .info: return "信息"
        }
    }
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let log: AppErrorHandler.ErrorLogEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: severityIcon)
                .foregroundStyle(severityColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(log.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(log.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(log.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let context = log.context {
                        Text("· \(context)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var severityIcon: String {
        switch log.severity {
        case "CRITICAL": return "xmark.octagon.fill"
        case "ERROR": return "xmark.circle.fill"
        case "WARNING": return "exclamationmark.triangle.fill"
        case "INFO": return "info.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private var severityColor: Color {
        switch log.severity {
        case "CRITICAL": return .red
        case "ERROR": return .orange
        case "WARNING": return .yellow
        case "INFO": return .blue
        default: return .gray
        }
    }
}

// MARK: - Log Detail View

private struct LogDetailView: View {
    let log: AppErrorHandler.ErrorLogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    LabeledContent("严重程度", value: log.severity)
                    LabeledContent("标题", value: log.title)
                    LabeledContent("消息", value: log.message)
                }

                Section("详细信息") {
                    LabeledContent("时间", value: formatDate(log.timestamp))
                    if let context = log.context {
                        LabeledContent("上下文", value: context)
                    }
                    LabeledContent("文件", value: log.file)
                    LabeledContent("行号", value: "\(log.line)")
                }
            }
            .navigationTitle("日志详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected
                            ? Color(red: 59/255, green: 130/255, blue: 246/255)
                            : Color.secondary.opacity(0.15))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if !SWIFT_PACKAGE
#Preview {
    NavigationStack {
        ErrorLogView()
    }
    .preferredColorScheme(.dark)
}
#endif
