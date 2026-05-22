# 变更日志 / Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [未发布] / [Unreleased]

### 计划中 / Planned

- 添加 iCloud 多设备实时同步冲突解决 UI
- 添加 OKR 导入/导出（JSON/CSV 格式）
- 添加季度/年度时间线视图
- 添加团队共享 OKR 协作功能
- 添加 Siri 快捷指令支持
- 添加小组件（Widget）支持
- 添加本地化支持（日文、韩文、德文、法文）
- 添加 Apple Vision Pro 空间计算版本

## [1.0.0] - 2026-05-20

### 添加 / Added

- **树状层级可视化** — 以清晰的树状结构展示企业 Objective → 企业 KR → 个人 Objective → 个人 KR 的完整对齐关系
- **级联进度计算引擎** — 自动从叶子 KR 节点向上汇总计算父节点进度，支持加权平均算法，实现 100% 分支覆盖的 52 个单元测试
- **完整的 CRUD 操作** — 支持对 Objectives 和 Key Results 的创建、读取、更新、删除
- **彩色进度条** — 使用金色（企业级）和蓝色（个人级）视觉区分不同层级的 OKR，进度条颜色根据完成度动态变化
- **快捷进度调整** — 叶子 KR 节点支持 ±10% 快捷调整按钮，实时更新级联进度
- **深色模式支持** — 全面适配 macOS 和 iOS 深色模式，自动跟随系统设置
- **双平台原生支持** — 同时为 macOS 14+ 和 iOS 17+ 优化的原生 SwiftUI 界面
- **Core Data 本地持久化** — 可靠的本地数据存储，支持数据模型版本迁移
- **CloudKit 云端同步** — 通过 Apple iCloud 实现跨设备数据同步
- **MVVM + Clean Architecture** — 清晰的分层架构，便于测试和维护
- **52 个 XCTest 单元测试** — 覆盖核心业务逻辑，级联引擎 100% 分支覆盖
- **Swift 6 语言特性** — 全面采用 Swift 6 最新语法特性和并发模型

### 技术架构 / Technical

- 采用 MVVM 架构模式，配合 Clean Architecture 分层
- Domain 层包含 Entities 和 Use Cases
- Data 层负责 Repository 实现和 Core Data/CloudKit 持久化
- Presentation 层使用 SwiftUI 构建响应式 UI
- 12,330 行代码（9,317 行源代码 + 2,917 行测试代码）

---

## 版本格式说明 / Format Guide

- **Added** — 新增功能
- **Changed** — 现有功能的变更
- **Deprecated** — 即将移除的功能
- **Removed** — 已移除的功能
- **Fixed** — 问题修复
- **Security** — 安全相关修复
