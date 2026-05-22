# OKR 对齐管理系统

> 一款基于 SwiftUI + Core Data 的跨平台 OKR 目标管理工具，支持企业级到个人级的级联对齐与进度追踪。

## 📖 项目简介

OKR（Objectives and Key Results，目标与关键结果）是现代企业广泛采用的目标管理方法论。本系统旨在解决企业 OKR 管理中「上下对齐难、进度追踪难、可视化难」三大痛点，提供一套覆盖企业级到个人级的级联对齐管理工具。

### 核心能力

- **四级对齐树**：企业 Objective → 企业 KR → 个人 Objective → 个人 KR
- **自动级联进度**：叶子 KR 数值变更自动向上传播，加权平均计算父节点进度
- **树状可视化**：以直观的树状结构展示 OKR 对齐关系
- **多周期管理**：支持创建、切换、归档多个 OKR 执行周期
- **数据导出**：支持 CSV 和 JSON 格式导出

## ✨ 功能列表

### OKR 管理
- 创建、编辑、删除 Objective 和 Key Result 节点
- 企业级 / 个人级范围标识
- 叶子 KR 支持数值型进度追踪（currentValue / targetValue）
- 节点状态管理：未开始、进行中、有风险、已完成、已取消
- 节点权重设置（影响加权进度计算）
- 乐观锁版本控制（CAS 冲突解决）

### 树状可视化
- 交互式树状结构展示 OKR 对齐关系
- 进度条和状态标识的视觉反馈
- 节点展开/折叠控制
- 节点搜索与高亮定位

### 周期管理
- 创建 OKR 执行周期（如"2026 Q1"）
- 周期激活与归档
- 基于周期的数据隔离

### 数据操作
- CSV 格式导出
- JSON 格式导出
- DEBUG 模式下自动加载示例数据

### 平台适配
- **macOS**：三栏 NavigationSplitView 布局，完整菜单栏和快捷键支持
- **iOS**：NavigationStack 导航，下拉刷新，底部工具栏

## 🏗️ 架构说明

### 整体架构

项目采用 **MVVM + Repository** 架构模式，通过 Swift Package Manager 组织代码：

```
OKRAlignment/
├── Package.swift                    # SPM 包定义
├── Sources/
│   ├── OKRAlignmentShared/          # 共享库（模型、数据层、业务逻辑、通用视图）
│   │   ├── Models/                  # 领域模型
│   │   │   ├── OKRNode.swift        # OKR 节点模型
│   │   │   ├── OKRCycle.swift       # OKR 周期模型
│   │   │   ├── NodeType.swift       # 节点类型（O / KR）
│   │   │   ├── Scope.swift          # 范围（企业级 / 个人级）
│   │   │   └── NodeStatus.swift     # 节点状态枚举
│   │   ├── Data/                    # 数据层
│   │   │   ├── CoreData/            # Core Data 持久化
│   │   │   │   ├── PersistenceController.swift
│   │   │   │   ├── OKRNodeEntity+Extensions.swift
│   │   │   │   └── OKRCycleEntity+Extensions.swift
│   │   │   ├── Repository/          # 数据仓库
│   │   │   │   ├── OKRRepositoryProtocol.swift
│   │   │   │   └── CoreDataOKRRepository.swift
│   │   │   └── Mappers/             # 对象映射
│   │   │       ├── EntityToDomainMapper.swift
│   │   │       └── DomainToEntityMapper.swift
│   │   ├── Domain/                  # 业务逻辑
│   │   │   ├── OKRCascadeEngine.swift    # 级联进度计算引擎
│   │   │   ├── NodeValidator.swift       # 节点验证器
│   │   │   └── CascadeEngineProtocol.swift
│   │   ├── ViewModels/              # 视图模型
│   │   │   ├── TreeViewModel.swift
│   │   │   ├── CycleListViewModel.swift
│   │   │   ├── NodeDetailViewModel.swift
│   │   │   └── NodeEditViewModel.swift
│   │   ├── Views/                   # 共享视图组件
│   │   │   ├── Tree/                # 树状视图
│   │   │   ├── Shared/              # 通用组件
│   │   │   ├── Editing/             # 编辑表单
│   │   │   └── Common/              # 通用状态视图
│   │   └── Utils/                   # 工具扩展
│   ├── OKRAlignmentMac/             # macOS 应用目标
│   │   ├── OKRAlignmentMacApp.swift
│   │   └── Views/
│   │       ├── MacTreeView.swift
│   │       └── SidebarView.swift
│   └── OKRAlignment/                # iOS 应用目标
│       └── Views/
│           └── iOSTreeView.swift
└── Tests/
    └── OKRAlignmentTests/           # 单元测试
```

### 数据流

```
View ← @Observable → ViewModel → RepositoryProtocol → CoreDataOKRRepository → Core Data
                                                        ↑
                                              PersistenceController (MOM/Store)
```

### 关键设计决策

- **程序化数据模型**：由于 Swift Package 中无法使用 `.xcdatamodeld` 文件，Core Data 模型通过 `PersistenceController.createManagedObjectModel()` 在代码中定义
- **轻量级迁移**：已启用自动轻量级迁移，支持添加新可选属性和新实体
- **Swift 6 严格并发**：启用 `StrictConcurrency`，使用 `@Observable` 和 `@MainActor`
- **零外部依赖**：仅使用 Apple 原生框架（SwiftUI、CoreData、CloudKit）

## 🔧 如何构建

### 环境要求

- **macOS 14.0+**（Sonoma 或更高版本）
- **Xcode 15.0+**（需要支持 Swift 6）
- **Swift 6.0+**

### 使用 Swift Package Manager 构建

```bash
# 进入项目目录
cd project/OKRAlignment

# 构建共享库
swift build --target OKRAlignmentShared

# 运行测试
swift test
```

### 使用 Xcode 构建（推荐）

```bash
# 使用 Xcode 打开 Package.swift
open project/OKRAlignment/Package.swift
```

在 Xcode 中：
1. 选择 `OKRAlignmentMac` scheme（macOS）或 `OKRAlignment` scheme（iOS）
2. 选择目标设备或模拟器
3. 按 `Cmd+R` 运行

> **注意**：由于应用使用 SwiftUI App 生命周期，首次运行推荐使用 Xcode。`swift build` 可用于编译检查和运行测试，但无法直接启动 GUI 应用。

### 运行测试

```bash
# 命令行运行所有测试
cd project/OKRAlignment
swift test

# 或在 Xcode 中按 Cmd+U
```

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| **Swift 6.0** | 主编程语言，启用严格并发 |
| **SwiftUI** | 声明式 UI 框架 |
| **Core Data** | 本地数据持久化（程序化模型定义） |
| **CloudKit** | 可选的云端数据同步 |
| **Swift Package Manager** | 依赖管理和项目组织 |
| **MVVM** | 应用架构模式 |
| **@Observable** | SwiftUI 状态管理（iOS 17+ / macOS 14+） |
| **os.Logger** | 统一日志系统 |

## 📋 快捷键（macOS）

| 快捷键 | 功能 |
|--------|------|
| `Cmd+N` | 新建 Objective |
| `Cmd+F` | 搜索 |
| `Cmd+R` | 刷新 |
| `Cmd+E` | 编辑选中节点 |
| `Delete` | 删除选中节点 |
| `Escape` | 关闭弹窗 |
| `Cmd+Option+E` | 展开所有节点 |
| `Cmd+Option+C` | 折叠所有节点 |
| `Cmd+Shift+S` | 导出 CSV |
| `Cmd+Shift+J` | 导出 JSON |

## 📄 需求文档

项目包含完整的需求规格说明书：

- [需求规格说明书](需求规格说明书.md) — 详细的功能需求、非功能需求和平台适配需求

## 📜 许可证

本项目为内部项目，暂未开放公开许可。
