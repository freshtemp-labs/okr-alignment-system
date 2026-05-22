<div align="center">

# OKR Alignment System / OKR 对齐管理系统

<p align="center">
  <strong>Native macOS/iOS OKR alignment management tool</strong><br/>
  <strong>原生 macOS/iOS OKR 对齐管理工具</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#testing">Testing</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20iOS%2017%2B-blue.svg" alt="Platform: macOS 14+ | iOS 17+" />
  <img src="https://img.shields.io/badge/license-Apache%202.0%20%7C%20MIT-green.svg" alt="License: Apache 2.0 | MIT" />
  <img src="https://img.shields.io/badge/tests-52%20cases-brightgreen.svg" alt="Tests: 52 cases" />
  <img src="https://img.shields.io/badge/coverage-100%25%20cascade%20engine-success.svg" alt="Coverage: 100% cascade engine" />
</p>

</div>

---

## [EN] Overview / [中文] 项目简介

**OKR Alignment System (OAMS)** is a native macOS/iOS application for managing OKR (Objectives and Key Results) hierarchies with visual tree alignment. It helps organizations and individuals track goals and their alignment relationships through an intuitive, interactive tree visualization.

**OKR 对齐管理系统 (OAMS)** 是一款原生的 macOS/iOS 应用，用于通过可视化树状对齐方式管理 OKR（目标与关键结果）层级。它帮助组织和个人通过直观的交互式树状可视化来追踪目标及其对齐关系。

### 核心理念 / Core Philosophy

> **让团队和个人 OKR 在一张可视化的树状图上对齐**
>
> Let team and personal OKRs align on a single visual tree map.

传统 OKR 工具往往将企业级目标和个人目标割裂展示，导致对齐关系难以直观感知。OAMS 创新性地采用树状层级可视化，将企业 Objective → 企业 KR → 个人 Objective → 个人 KR 的完整链条呈现在一张视图中，让目标对齐一目了然。

### 解决的痛点 / Pain Points Solved

| 痛点 / Pain Point | 解决方案 / Solution |
|-------------------|---------------------|
| OKR 对齐关系不可见 | 树状层级可视化，父子关系清晰展示 |
| 进度更新繁琐 | 叶子 KR 快捷调整（±10%），级联自动计算 |
| 手动计算汇总进度 | 级联进度自动计算引擎，加权平均 |
| 企业与个人目标割裂 | 金色/蓝色视觉区分，同屏展示 |
| 数据丢失风险 | Core Data 本地持久化 + CloudKit 云端同步 |
| 多设备无法同步 | Apple iCloud 自动同步 |

---

## [EN] Features / [中文] 功能特性

### 树状层级可视化 / Tree Hierarchy Visualization

- 清晰的四级树状结构：企业 Objective → 企业 KR → 个人 Objective → 个人 KR
- 可折叠/展开的节点交互
- 父子关系的直观连线展示
- 实时反映对齐关系和依赖结构

### 级联进度计算 / Cascading Progress Calculation

- 从叶子 KR 节点自动向上汇总计算父节点进度
- 加权平均算法，支持自定义权重
- 实时更新，无需手动刷新
- 100% 分支覆盖的单元测试保障

### 完整的 CRUD 操作 / Full CRUD Operations

- **创建 (Create)** — 添加新的 Objective 或 Key Result
- **读取 (Read)** — 浏览和查看完整的 OKR 树
- **更新 (Update)** — 编辑目标描述、进度、权重等
- **删除 (Delete)** — 移除节点及其子树

### 快捷进度调整 / Quick Progress Adjustment

- 叶子 KR 节点支持 ±10% 快捷按钮
- 点击即更新，无需键盘输入
- 级联引擎实时向上传播变更

### 双平台原生支持 / Dual-Platform Native Support

- **macOS 14+** — 优化的桌面体验，支持键盘快捷键
- **iOS 17+** — 适配移动端的触摸交互
- 统一的 SwiftUI 代码库，共享核心逻辑

### 深色模式 / Dark Mode

- 全面适配 macOS/iOS 深色模式
- 自动跟随系统设置切换
- 精心调校的颜色对比度

### 数据持久化与同步 / Data Persistence & Sync

- **Core Data** — 可靠的本地数据持久化
- **CloudKit** — 通过 Apple iCloud 跨设备同步
- 支持离线使用和在线自动同步

### 视觉区分 / Visual Differentiation

| 层级 | 颜色标识 | 说明 |
|------|----------|------|
| 企业级 Objective | 金色 (Gold) | 组织层面的战略目标 |
| 企业级 KR | 金色 (Gold) | 组织关键结果 |
| 个人级 Objective | 蓝色 (Blue) | 个人层面的目标 |
| 个人级 KR | 蓝色 (Blue) | 个人关键结果 |

---

## [EN] Screenshots / [中文] 界面预览

### macOS / macOS 版本

<p align="center">
  <img src="docs/screenshots/macos-okr-tree.png" alt="macOS OKR Tree View" width="720" />
  <br/>
  <em>macOS 树状 OKR 视图 — 展示企业目标与个人目标的完整对齐关系</em>
</p>

<p align="center">
  <img src="docs/screenshots/macos-dark-mode.png" alt="macOS Dark Mode" width="720" />
  <br/>
  <em>macOS 深色模式适配</em>
</p>

### iOS / iOS 版本

<p align="center">
  <img src="docs/screenshots/ios-okr-tree.png" alt="iOS OKR Tree View" width="280" />
  <img src="docs/screenshots/ios-progress-edit.png" alt="iOS Progress Edit" width="280" />
  <br/>
  <em>iOS OKR 树状视图（左）与进度编辑（右）</em>
</p>

> **提示**：截图将在首次 Release 时替换为实际应用截图。/ Screenshots will be replaced with actual app screenshots upon first release.

---

## [EN] Architecture / [中文] 架构设计

### 架构图 / Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Presentation Layer                          │
│                    (SwiftUI Views + ViewModels)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │   OKRTree    │  │  ProgressBar │  │   NodeEditorSheet    │   │
│  │    View      │  │     View     │  │       View           │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘   │
│         │                  │                      │               │
│  ┌──────▼──────────────────▼──────────────────────▼───────┐      │
│  │              OKRTreeViewModel (MVVM)                   │      │
│  │         @Published var treeNodes: [OKRNode]            │      │
│  │         @Published var selectedNode: OKRNode?          │      │
│  └──────┬──────────────────────────────────────────────────┘      │
└─────────┼────────────────────────────────────────────────────────┘
          │                                                         
┌─────────▼────────────────────────────────────────────────────────┐
│                        Domain Layer                               │
│              (Entities + Use Cases + Protocols)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │   OKRNode    │  │  Calculate   │  │   OKRRepository      │   │
│  │   Entity     │  │   Cascade    │  │   Protocol           │   │
│  │              │  │   Progress   │  │                      │   │
│  │ - id: UUID   │  │   Use Case   │  │ - getAllNodes()      │   │
│  │ - title: Str │  │              │  │ - saveNode()         │   │
│  │ - progress   │  │ - weighted   │  │ - deleteNode()       │   │
│  │ - weight     │  │   average    │  │ - updateProgress()   │   │
│  │ - children   │  │   algorithm  │  │                      │   │
│  └──────────────┘  └──────┬───────┘  └──────────┬───────────┘   │
│                           │                      │               │
│  ┌────────────────────────┘                      └──────────┐    │
│  │              OKRNodeType Enum                             │    │
│  │   .companyObjective / .companyKR /                       │    │
│  │   .personalObjective / .personalKR                        │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
          │                                                          
┌─────────▼────────────────────────────────────────────────────────┐
│                         Data Layer                                │
│           (Repository Impl + Core Data + CloudKit)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  CoreData    │  │   CloudKit   │  │   CascadeCalculator  │   │
│  │  OKRRepository│ │   SyncService│  │   (Engine)           │   │
│  │              │  │              │  │                      │   │
│  │ - NSManaged  │  │ - NSPersist │  │ - calculateProgress()│   │
│  │   Object ctx │  │   entCloudKit│  │ - traverseTree()     │   │
│  │ - fetch/save │  │ - sync conf  │  │ - aggregateWeights() │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Core Data Model (OKRModel.xcdatamodeld)      │    │
│  │   ObjectiveEntity <-->> KREntity                         │    │
│  │        ↑                       ↑                          │    │
│  │   companyType              krType                         │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

### 架构说明 / Architecture Description

本项目采用 **MVVM + Clean Architecture** 分层架构：

- **Presentation Layer** — SwiftUI 构建的声明式 UI，ViewModel 管理视图状态
- **Domain Layer** — 核心业务逻辑，包含 Entities、Use Cases 和 Repository Protocols
- **Data Layer** — 数据持久化实现，包括 Core Data 和 CloudKit 同步服务

### 技术栈 / Tech Stack

| 技术 / Technology | 用途 / Purpose |
|-------------------|----------------|
| **Swift 6** | 编程语言，完整启用 Strict Concurrency Checking |
| **SwiftUI** | 声明式 UI 框架，双平台共享 |
| **Core Data** | 本地数据持久化 |
| **CloudKit** | 云端数据同步 |
| **MVVM** | 视图层架构模式 |
| **Clean Architecture** | 业务逻辑分层 |
| **XCTest** | 单元测试框架 |
| **GitHub Actions** | CI/CD 自动化 |

---

## [EN] Installation / [中文] 安装说明

### 系统要求 / System Requirements

| 平台 | 最低版本 | 说明 |
|------|----------|------|
| macOS | 14.0 (Sonoma) | 支持 SwiftUI 最新特性 |
| iOS | 17.0 | 支持 iPhone 和 iPad |
| Xcode | 16.0 | 包含 Swift 6 工具链 |
| Apple ID | — | 用于 CloudKit 同步 |

### 从源码构建 / Build from Source

```bash
# 1. 克隆仓库
$ git clone https://github.com/your-org/OKRAlignment.git
$ cd OKRAlignment

# 2. 打开 Xcode 项目
$ open OKRAlignment.xcodeproj

# 3. 等待 Swift Package Manager 解析依赖

# 4. 选择目标平台
#    - macOS: Product > Destination > My Mac
#    - iOS: Product > Destination > iPhone 16

# 5. 构建并运行 (Cmd+R)

# 6. 运行测试 (Cmd+U)
```

### 依赖管理 / Dependency Management

本项目主要依赖 Apple 原生框架，无需第三方库：

- `SwiftUI` — UI 框架
- `CoreData` — 本地持久化
- `CloudKit` — 云端同步
- `Combine` — 响应式编程
- `Foundation` — 基础功能

---

## [EN] Usage / [中文] 使用指南

### 创建 OKR 树 / Creating an OKR Tree

1. 打开应用，点击顶部工具栏的 **"+"** 按钮
2. 选择节点类型：
   - 🏢 **企业 Objective** — 组织的战略目标
   - 🏢 **企业 KR** — 组织的关键结果
   - 👤 **个人 Objective** — 个人的工作目标
   - 👤 **个人 KR** — 个人的关键结果
3. 输入标题和描述
4. 如为子节点，选择父节点建立关联

### 更新进度 / Updating Progress

**方式一：快捷调整（推荐）**
1. 找到叶子 KR 节点（显示 ±10% 按钮的节点）
2. 点击 **"+10%"** 或 **"-10%"** 按钮
3. 级联引擎自动向上更新所有父节点进度

**方式二：精确输入**
1. 点击目标节点打开编辑器
2. 拖动滑块或直接输入百分比
3. 保存后级联计算自动触发

### 查看对齐关系 / Viewing Alignment

- 在树状视图中，父子节点通过缩进和连线展示关系
- 点击节点可展开/折叠其子树
- 金色节点为企业级，蓝色节点为个人级
- 进度条颜色反映完成度：绿色（高）→ 黄色（中）→ 红色（低）

### 数据同步 / Data Synchronization

- 使用您的 Apple ID 登录 iCloud
- 数据自动同步到 CloudKit
- 在其他设备上使用相同 Apple ID 即可查看同步数据
- 支持离线编辑，联网后自动合并

---

## [EN] Testing / [中文] 测试

### 测试统计 / Test Statistics

| 指标 | 数值 |
|------|------|
| 测试用例总数 | **52** 个 XCTest 测试 |
| 源代码行数 | 9,317 行 |
| 测试代码行数 | 2,917 行 |
| 测试代码占比 | 31.2% |
| 级联引擎覆盖率 | **100%** 分支覆盖 |

### 运行测试 / Running Tests

```bash
# 命令行运行
$ swift test

# 或在 Xcode 中: Cmd+U
```

### 测试覆盖范围 / Test Coverage

- ✅ `CascadeCalculator` — 级联进度计算（100% 分支覆盖）
- ✅ `OKRNode` — 实体模型验证
- ✅ `OKRRepository` — 数据持久化操作
- ✅ `OKRTreeViewModel` — 视图模型状态管理
- ✅ `CloudKitSyncService` — 云端同步逻辑
- ✅ `ProgressAggregation` — 加权聚合算法

### 持续集成 / Continuous Integration

本项目使用 GitHub Actions 进行 CI：

- ✅ macOS 平台构建与测试
- ✅ iOS 模拟器构建与测试
- ✅ 代码质量检查
- ✅ 测试覆盖率报告

---

## [EN] Project Structure / [中文] 项目结构

```
OKRAlignment/
├── README.md                          # 项目说明（本文件）
├── LICENSE-APACHE-2.0                 # Apache 2.0 许可证
├── LICENSE-MIT                        # MIT 许可证
├── CONTRIBUTING.md                    # 贡献指南
├── CHANGELOG.md                       # 变更日志
├── SECURITY.md                        # 安全政策
├── CODE_OF_CONDUCT.md                 # 行为准则
├── .gitignore                         # Git 忽略配置
│
├── .github/
│   ├── workflows/
│   │   └── ci.yml                     # GitHub Actions CI 配置
│   ├── PULL_REQUEST_TEMPLATE.md       # PR 模板
│   └── ISSUE_TEMPLATE/
│       ├── config.yml                 # Issue 模板配置
│       ├── bug_report.yml             # Bug 报告模板
│       └── feature_request.yml        # 功能请求模板
│
├── OKRAlignment/
│   ├── App/
│   │   └── OKRAlignmentApp.swift      # App 入口
│   │
│   ├── Presentation/
│   │   ├── Views/
│   │   │   ├── OKRTreeView.swift      # 主树状视图
│   │   │   ├── NodeRowView.swift      # 节点行视图
│   │   │   ├── ProgressBarView.swift  # 进度条视图
│   │   │   └── NodeEditorSheet.swift  # 节点编辑器
│   │   └── ViewModels/
│   │       └── OKRTreeViewModel.swift # 树视图模型
│   │
│   ├── Domain/
│   │   ├── Entities/
│   │   │   └── OKRNode.swift          # OKR 节点实体
│   │   ├── UseCases/
│   │   │   └── CalculateCascadeProgressUseCase.swift
│   │   └── Protocols/
│   │       └── OKRRepositoryProtocol.swift
│   │
│   ├── Data/
│   │   ├── Repositories/
│   │   │   └── CoreDataOKRRepository.swift
│   │   ├── Services/
│   │   │   ├── CascadeCalculator.swift    # 级联计算引擎
│   │   │   └── CloudKitSyncService.swift
│   │   └── CoreData/
│   │       ├── OKRModel.xcdatamodeld      # 数据模型
│   │       ├── ObjectiveEntity.swift
│   │       └── KREntity.swift
│   │
│   └── Resources/
│       └── Assets.xcassets
│
├── OKRAlignmentTests/
│   ├── CascadeCalculatorTests.swift       # 级联引擎测试
│   ├── OKRRepositoryTests.swift           # 仓库层测试
│   ├── OKRTreeViewModelTests.swift        # 视图模型测试
│   ├── CloudKitSyncServiceTests.swift     # 同步服务测试
│   └── TestHelpers/
│       └── MockRepository.swift           # 测试替身
│
├── docs/
│   └── screenshots/                       # 应用截图
│
└── Package.swift                          # Swift Package Manager 配置
```

---

## [EN] Roadmap / [中文] 路线图

### V1.0 MVP ✅ — 2026-05-20

- ✅ 树状层级可视化
- ✅ 级联进度计算引擎
- ✅ 完整 CRUD 操作
- ✅ 快捷进度调整 (±10%)
- ✅ 深色模式支持
- ✅ macOS/iOS 双平台
- ✅ Core Data 本地持久化
- ✅ CloudKit 云端同步
- ✅ 52 个单元测试

### V1.5 — 2026 Q3

- 🔄 iCloud 多设备实时同步冲突解决 UI
- 🔄 OKR 导入/导出（JSON/CSV 格式）
- 🔄 季度/年度时间线视图
- 🔄 Siri 快捷指令支持
- 🔄 小组件 (Widget) 支持
- 🔄 多语言本地化（日文、韩文、德文、法文）

### V2.0 — 2026 Q4

- 📋 团队共享 OKR 协作功能
- 📋 Apple Vision Pro 空间计算版本
- 📋 AI 辅助目标建议
- 📋 数据分析和趋势图表
- 📋 与 Calendar/Reminders 集成
- 📋 导出 PDF 报告

---

## [EN] License / [中文] 许可证

本项目采用双许可证模式，您可以根据自己的需求选择其中一种：

This project is dual-licensed. You may choose either license at your option:

### Apache License 2.0

```
Copyright 2026 OKR Alignment System Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

完整许可证文本见 [LICENSE-APACHE-2.0](LICENSE-APACHE-2.0) 文件。

### MIT License

```
Copyright (c) 2026 OKR Alignment System Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files...
```

完整许可证文本见 [LICENSE-MIT](LICENSE-MIT) 文件。

> 双许可证意味着您可以自由选择 Apache 2.0 或 MIT 许可证中的任意一种来使用本软件。如果您不确定该选择哪一种，请参考 [Apache 2.0 vs MIT 许可证对比指南](https://choosealicense.com/licenses/)。

---

## [EN] Contributing / [中文] 贡献指南

我们欢迎所有形式的贡献！在开始之前，请阅读我们的 [CONTRIBUTING.md](CONTRIBUTING.md) 文件了解详细信息。

### 快速开始

```bash
# Fork 并克隆仓库
git clone https://github.com/YOUR_USERNAME/OKRAlignment.git
cd OKRAlignment

# 创建功能分支
git checkout -b feature/your-feature

# 提交更改
git commit -m "feat(功能域): 描述"

# 推送到您的 Fork
git push origin feature/your-feature

# 创建 Pull Request
```

### 贡献方式

- 🐛 [报告 Bug](.github/ISSUE_TEMPLATE/bug_report.yml)
- 💡 [功能建议](.github/ISSUE_TEMPLATE/feature_request.yml)
- 📝 改进文档
- ✅ 添加测试
- 🔧 提交代码修复或新功能

---

## [EN] Acknowledgements / [中文] 致谢

本项目得益于以下优秀的开源技术和 Apple 框架：

- **[Swift](https://swift.org/)** — 强大、直观的编程语言
- **[SwiftUI](https://developer.apple.com/xcode/swiftui/)** — 现代化的声明式 UI 框架
- **[Core Data](https://developer.apple.com/documentation/coredata)** — 成熟的对象图管理和持久化框架
- **[CloudKit](https://developer.apple.com/icloud/cloudkit/)** — 与 Apple 生态系统深度集成的云服务
- **[Combine](https://developer.apple.com/documentation/combine)** — 处理随时间变化值的框架
- **[XCTest](https://developer.apple.com/documentation/xctest)** — Apple 原生测试框架
- **[GitHub Actions](https://github.com/features/actions)** — CI/CD 自动化平台

---

## 联系方式 / Contact

如有问题或建议，欢迎通过以下方式联系我们：

- 📧 发送邮件至项目维护团队
- 💬 在 [Discussions](https://github.com/your-org/OKRAlignment/discussions) 中发起讨论
- 🐛 提交 [Issue](https://github.com/your-org/OKRAlignment/issues)

---

<p align="center">
  <sub>Built with ❤️ by the OKR Alignment System Contributors</sub>
  <br/>
  <sub>使用 Swift 6 + SwiftUI 构建</sub>
</p>
