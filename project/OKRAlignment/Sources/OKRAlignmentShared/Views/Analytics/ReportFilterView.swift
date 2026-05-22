// OKRAlignmentShared/Views/Analytics/ReportFilterView.swift

import SwiftUI

/// 报表筛选视图
///
/// 提供丰富的报表筛选选项：
/// - 时间范围选择
/// - 状态筛选
/// - Owner 筛选
/// - 进度范围筛选
/// - 模板选择
/// - 配置保存/加载
public struct ReportFilterView: View {

    // MARK: - Properties

    @ObservedObject var templateService: ReportTemplateService
    @Binding var config: ReportFilterConfig

    @State private var showSaveSheet = false
    @State private var saveConfigName = ""
    @State private var customStartDate = Date().addingTimeInterval(-30 * 86400)
    @State private var customEndDate = Date()

    /// 可用的 Owner 列表
    let availableOwners: [String]

    // MARK: - Body

    public init(
        templateService: ReportTemplateService,
        config: Binding<ReportFilterConfig>,
        availableOwners: [String] = []
    ) {
        self.templateService = templateService
        self._config = config
        self.availableOwners = availableOwners
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 模板快捷选择
            templateSection

            Divider()

            // 时间范围
            timeRangeSection

            // 状态筛选
            statusFilterSection

            // Owner 筛选
            if !availableOwners.isEmpty {
                ownerFilterSection
            }

            // 进度范围
            progressFilterSection

            Divider()

            // 报表内容选择
            contentSection

            Divider()

            // 操作按钮
            actionButtons
        }
        .padding()
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("报表模板")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReportTemplateService.builtInTemplates) { template in
                        Button {
                            config = template.defaultConfig
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: template.icon)
                                    .font(.body)
                                Text(template.name)
                                    .font(.caption2)
                            }
                            .frame(width: 72, height: 56)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 用户保存的配置
            if !templateService.savedConfigs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templateService.savedConfigs) { saved in
                            Button {
                                config = saved.config
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption2)
                                    Text(saved.name)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Time Range Section

    private var timeRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间范围")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(ReportTimeRange.allCases, id: \.self) { range in
                    Button {
                        config.timeRange = range
                    } label: {
                        Text(range.displayName)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(config.timeRange == range ? Color.blue : Color.clear)
                            .foregroundStyle(config.timeRange == range ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if config.timeRange == .custom {
                HStack {
                    DatePicker("从", selection: $customStartDate, displayedComponents: .date)
                        .font(.caption)
                    DatePicker("到", selection: $customEndDate, displayedComponents: .date)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Status Filter Section

    private var statusFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("状态筛选")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(NodeStatus.allCases, id: \.self) { status in
                    Button {
                        if config.statusFilter.contains(status) {
                            config.statusFilter.remove(status)
                        } else {
                            config.statusFilter.insert(status)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: status.iconName)
                                .font(.caption2)
                            Text(status.displayName)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(config.statusFilter.contains(status) ? status.color.opacity(0.2) : Color.clear)
                        .foregroundStyle(config.statusFilter.contains(status) ? status.color : .secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(config.statusFilter.contains(status) ? status.color.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !config.statusFilter.isEmpty {
                    Button {
                        config.statusFilter.removeAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Owner Filter Section

    private var ownerFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("负责人筛选")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !config.ownerFilter.isEmpty {
                    Text("已选 \(config.ownerFilter.count) 人")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(availableOwners, id: \.self) { owner in
                    Button {
                        if config.ownerFilter.contains(owner) {
                            config.ownerFilter.remove(owner)
                        } else {
                            config.ownerFilter.insert(owner)
                        }
                    } label: {
                        Text(owner)
                            .font(.caption2)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(config.ownerFilter.contains(owner) ? Color.blue.opacity(0.15) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Progress Filter Section

    private var progressFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("进度范围")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("最低: \(Int(config.minProgress ?? 0))%")
                        .font(.caption2)
                    Slider(value: Binding(
                        get: { config.minProgress ?? 0 },
                        set: { config.minProgress = $0 > 0 ? $0 : nil }
                    ), in: 0...100, step: 5)
                }

                VStack(alignment: .leading) {
                    Text("最高: \(Int(config.maxProgress ?? 100))%")
                        .font(.caption2)
                    Slider(value: Binding(
                        get: { config.maxProgress ?? 100 },
                        set: { config.maxProgress = $0 < 100 ? $0 : nil }
                    ), in: 0...100, step: 5)
                }

                Button("重置") {
                    config.minProgress = nil
                    config.maxProgress = nil
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("报表内容")
                .font(.caption)
                .foregroundStyle(.secondary)

            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 6) {
                ContentToggle(title: "统计概要", icon: "chart.bar", isOn: $config.includeStatistics)
                ContentToggle(title: "状态分布", icon: "chart.pie", isOn: $config.includeStatusDistribution)
                ContentToggle(title: "负责人排名", icon: "person.3", isOn: $config.includeOwnerRankings)
                ContentToggle(title: "节点明细", icon: "list.bullet", isOn: $config.includeNodeDetails)
                ContentToggle(title: "趋势图表", icon: "chart.line.uptrend.xyaxis", isOn: $config.includeTrendChart)
                ContentToggle(title: "进度分布", icon: "chart.bar.fill", isOn: $config.includeProgressDistribution)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            Button {
                showSaveSheet = true
            } label: {
                Label("保存配置", systemImage: "bookmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Spacer()

            Button {
                config = ReportFilterConfig()
            } label: {
                Label("重置筛选", systemImage: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .alert("保存报表配置", isPresented: $showSaveSheet) {
            TextField("配置名称", text: $saveConfigName)
            Button("取消", role: .cancel) { saveConfigName = "" }
            Button("保存") {
                if !saveConfigName.isEmpty {
                    templateService.saveConfig(name: saveConfigName, config: config)
                    saveConfigName = ""
                }
            }
        } message: {
            Text("输入配置名称以便日后复用")
        }
    }
}

// MARK: - Content Toggle

private struct ContentToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isOn ? .blue : .secondary)
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(isOn ? .primary : .secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isOn ? Color.blue.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
