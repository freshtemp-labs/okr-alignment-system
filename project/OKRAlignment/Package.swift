// swift-tools-version: 6.0

import PackageDescription

/// OKR Alignment System - 目标与关键结果对齐管理系统
/// 支持macOS和iOS双平台，使用Core Data + CloudKit进行数据持久化
/// 采用MVVM架构，支持企业级Objective到个人级KR的多层级对齐
let package = Package(
    name: "OKRAlignment",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        /// 共享库：包含模型、Core Data栈和工具类
        /// 被macOS和iOS两个可执行目标共用
        .library(
            name: "OKRAlignmentShared",
            targets: ["OKRAlignmentShared"]
        ),
        /// macOS可执行目标
        .executable(
            name: "OKRAlignmentMac",
            targets: ["OKRAlignmentMac"]
        ),
        /// iOS可执行目标
        .executable(
            name: "OKRAlignment",
            targets: ["OKRAlignment"]
        )
    ],
    dependencies: [
        // 当前无外部依赖，仅使用Apple原生框架
    ],
    targets: [
        // MARK: - Shared Library

        /// 共享库目标：包含所有平台无关的代码
        /// 包括领域模型、Core Data实体、持久化控制器、工具扩展
        .target(
            name: "OKRAlignmentShared",
            dependencies: [],
            path: "Sources/OKRAlignmentShared",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .define("SWIFT_PACKAGE")
            ]
        ),

        // MARK: - macOS App

        /// macOS应用目标
        /// 依赖共享库，包含macOS特定的UI和生命周期代码
        .executableTarget(
            name: "OKRAlignmentMac",
            dependencies: [
                .target(name: "OKRAlignmentShared")
            ],
            path: "Sources/OKRAlignmentMac",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - iOS App

        /// iOS应用目标
        /// 依赖共享库，包含iOS特定的UI和生命周期代码
        .executableTarget(
            name: "OKRAlignment",
            dependencies: [
                .target(name: "OKRAlignmentShared")
            ],
            path: "Sources/OKRAlignment",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - Tests

        /// 单元测试目标
        /// 覆盖共享库中的模型、验证逻辑和数据转换
        .testTarget(
            name: "OKRAlignmentTests",
            dependencies: [
                .target(name: "OKRAlignmentShared")
            ],
            path: "Tests/OKRAlignmentTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
