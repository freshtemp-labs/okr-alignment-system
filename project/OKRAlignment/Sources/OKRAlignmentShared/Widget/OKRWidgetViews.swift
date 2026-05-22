// OKRAlignmentShared/Widget/OKRWidgetViews.swift
//
// Widget 视图定义
// 支持 small / medium / large 三种尺寸
// 小尺寸: 总体进度环
// 中尺寸: Top 3 KR 列表
// 大尺寸: Top 3 KR 列表 + 总体进度 + 周期信息

#if canImport(WidgetKit)
import SwiftUI

// MARK: - Small Widget View

/// 小尺寸 Widget
/// 显示总体进度环和周期名称
@available(iOS 17.0, macOS 14.0, *)
struct OKRWidgetSmallView: View {
    let entry: OKRWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: entry.overallProgress / 100.0)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 59/255, green: 130/255, blue: 246/255),
                                Color(red: 139/255, green: 92/255, blue: 246/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(entry.overallProgress))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 70, height: 70)

            Text(entry.cycleName)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 15/255, green: 23/255, blue: 42/255)
        }
    }
}

// MARK: - Medium Widget View

/// 中尺寸 Widget
/// 显示 Top 3 KR 进度列表
@available(iOS 17.0, macOS 14.0, *)
struct OKRWidgetMediumView: View {
    let entry: OKRWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack {
                Image(systemName: "tree.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 59/255, green: 130/255, blue: 246/255),
                                Color(red: 139/255, green: 92/255, blue: 246/255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("OKR 进度")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(entry.cycleName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }

            if entry.hasData {
                // Top KR 列表
                ForEach(entry.topKRs) { kr in
                    krRow(kr)
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    Text("暂无活跃 KR")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                Spacer()
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 15/255, green: 23/255, blue: 42/255)
        }
    }

    private func krRow(_ kr: OKRWidgetEntry.KRDisplayData) -> some View {
        HStack(spacing: 10) {
            // 状态指示器
            Circle()
                .fill(statusColor(kr.status))
                .frame(width: 8, height: 8)

            // KR 标题
            Text(kr.title)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // 进度
            Text("\(Int(kr.progress))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor(kr.status))
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "in_progress": return Color(red: 59/255, green: 130/255, blue: 246/255)
        case "at_risk": return .orange
        default: return .gray
        }
    }
}

// MARK: - Large Widget View

/// 大尺寸 Widget
/// 显示 Top 3 KR 进度列表 + 总体进度 + 周期详情
@available(iOS 17.0, macOS 14.0, *)
struct OKRWidgetLargeView: View {
    let entry: OKRWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "tree.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 59/255, green: 130/255, blue: 246/255),
                                Color(red: 139/255, green: 92/255, blue: 246/255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("OKR 对齐管理")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            // 周期信息 + 总体进度
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.cycleName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("总体进度")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // 进度环
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: entry.overallProgress / 100.0)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 59/255, green: 130/255, blue: 246/255),
                                    Color(red: 139/255, green: 92/255, blue: 246/255)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(entry.overallProgress))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 55, height: 55)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 分隔线
            Divider()
                .background(Color.white.opacity(0.1))

            // Top KR 列表
            Text("关键结果 Top 3")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))

            if entry.hasData {
                ForEach(entry.topKRs) { kr in
                    largeKRRow(kr)
                }
            } else {
                HStack {
                    Spacer()
                    Text("暂无活跃 KR，打开 App 创建 OKR")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .padding(.top, 16)
            }

            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 15/255, green: 23/255, blue: 42/255)
        }
    }

    private func largeKRRow(_ kr: OKRWidgetEntry.KRDisplayData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(statusColor(kr.status))
                    .frame(width: 8, height: 8)
                Text(kr.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(kr.ownerName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    statusColor(kr.status),
                                    statusColor(kr.status).opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, min(
                                CGFloat(kr.progress / 100.0) * geometry.size.width,
                                geometry.size.width
                            )),
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(kr.progress))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor(kr.status))
                Spacer()
                Text(statusText(kr.status))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "in_progress": return Color(red: 59/255, green: 130/255, blue: 246/255)
        case "at_risk": return .orange
        default: return .gray
        }
    }

    private func statusText(_ status: String) -> String {
        switch status {
        case "completed": return "已完成"
        case "in_progress": return "进行中"
        case "at_risk": return "有风险"
        case "not_started": return "未开始"
        default: return ""
        }
    }
}
#endif
