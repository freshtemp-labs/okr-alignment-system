// OKRAlignmentShared/Widget/OKRWidgetBundle.swift
//
// OKR Widget 入口
// 支持小/中/大三种尺寸
// 显示当前活跃周期的 Top 3 KR 进度
//
// 注意：Widget 需要在 Xcode 项目中作为 App Extension 部署。
// 此文件在 SPM 中编译时会通过 #if canImport(WidgetKit) 条件编译。
// 在 Xcode 中创建 Widget Extension Target 后，将此目录的文件加入目标即可。

#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

/// Widget Bundle 定义
/// 包含所有 OKR Widget 变体
@available(iOS 17.0, macOS 14.0, *)
struct OKRWidgetBundle: WidgetBundle {
    var body: some Widget {
        OKRProgressWidget()
    }
}
#endif
