// OKRAlignmentShared/Widget/OKRProgressWidget.swift
//
// OKR Progress Widget 主定义
// 使用 WidgetKit 框架
// 支持 small / medium / large 三种尺寸
// 点击 Widget 打开 App

#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

/// OKR 进度 Widget
/// 在主屏幕/通知中心展示当前活跃周期的 KR 进度
/// 点击 Widget 可打开 App 查看详情
@available(iOS 17.0, macOS 14.0, *)
struct OKRProgressWidget: Widget {
    let kind = "OKRProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OKRWidgetProvider()) { entry in
            OKRWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("OKR 进度")
        .description("查看当前 OKR 周期的 Top 3 关键结果进度")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Widget 入口视图
/// 根据 Widget 尺寸选择对应的子视图
@available(iOS 17.0, macOS 14.0, *)
struct OKRWidgetEntryView: View {
    let entry: OKRWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            OKRWidgetSmallView(entry: entry)
        case .systemMedium:
            OKRWidgetMediumView(entry: entry)
        case .systemLarge:
            OKRWidgetLargeView(entry: entry)
        default:
            OKRWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget URL Scheme
// 点击 Widget 时打开 App

/// Widget URL 处理
/// App 端需在 onOpenURL 中处理此 scheme
/// 示例: okralignment://widget/open
extension OKRWidgetEntry {
    /// Widget 点击时的跳转 URL
    static var deepLinkURL: URL {
        URL(string: "okralignment://widget/open")!
    }
}

// MARK: - Previews (Xcode only)

#if !SWIFT_PACKAGE && DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Small", as: .systemSmall) {
    OKRProgressWidget()
} timeline: {
    OKRWidgetEntry.sample
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Medium", as: .systemMedium) {
    OKRProgressWidget()
} timeline: {
    OKRWidgetEntry.sample
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Large", as: .systemLarge) {
    OKRProgressWidget()
} timeline: {
    OKRWidgetEntry.sample
}
#endif // !SWIFT_PACKAGE && DEBUG
#endif // canImport(WidgetKit)
