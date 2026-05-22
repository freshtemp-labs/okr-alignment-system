# 贡献指南 / Contributing Guide

首先，感谢您考虑为 OKR Alignment System (OAMS) 做出贡献！正是像您这样的人，使得这个项目变得更加完善。

> 在开始贡献之前，请花几分钟阅读本指南，这将帮助您更顺利地进行贡献。

## 目录

- [行为准则](#行为准则)
- [贡献前准备](#贡献前准备)
- [开发环境搭建](#开发环境搭建)
- [代码规范](#代码规范)
- [开发分支策略](#开发分支策略)
- [提交信息规范](#提交信息规范)
- [Pull Request 流程](#pull-request-流程)
- [Issue 报告指南](#issue-报告指南)
- [代码审查流程](#代码审查流程)
- [发布流程](#发布流程)

## 行为准则

本项目遵循 [Contributor Covenant 行为准则](CODE_OF_CONDUCT.md)。参与本项目即表示您同意遵守其条款。请确保在所有互动中保持友善和尊重。

## 贡献前准备

### 您可以通过以下方式贡献

- **报告 Bug** — 提交详细的 Bug 报告
- **功能建议** — 提出新功能或改进建议
- **代码贡献** — 修复 Bug 或实现新功能
- **文档改进** — 完善 README、注释或文档
- **测试覆盖** — 添加单元测试提高覆盖率
- **代码审查** — 帮助审查其他贡献者的 Pull Request

## 开发环境搭建

### 系统要求

- **macOS**: 14.0 Sonoma 或更高版本
- **Xcode**: 16.0 或更高版本（包含 Swift 6 工具链）
- **Swift**: 6.0+
- **iOS 模拟器**: iPhone 15 或更新型号（用于 iOS 测试）

### 克隆与构建

```bash
# 1. Fork 本仓库，然后克隆您的 Fork
git clone https://github.com/YOUR_USERNAME/OKRAlignment.git
cd OKRAlignment

# 2. 添加上游仓库
git remote add upstream https://github.com/original-org/OKRAlignment.git

# 3. 创建并切换到开发分支
git checkout -b feature/your-feature-name

# 4. 在 Xcode 中打开项目
open OKRAlignment.xcodeproj

# 5. 构建项目
swift build

# 6. 运行测试
swift test
```

## 代码规范

### Swift 6 规范

本项目全面采用 Swift 6 语言和并发检查，请确保您的代码符合以下规范：

- 启用 **Strict Concurrency Checking** (`-strict-concurrency=complete`)
- 使用 `Sendable` 协议标记跨并发边界传递的类型
- 使用 `actor` 和 `isolated` 关键字管理可变状态
- 避免使用 `@preconcurrency` 导入，除非有充分理由
- 使用 `async/await` 替代基于回调的异步模式
- 遵循 Swift API Design Guidelines

### 文档注释

所有 `public` 和 `internal` 级别的声明都必须包含 DocC 格式的文档注释：

```swift
/// 计算级联进度值
///
/// 从叶子 KR 节点递归向上计算父节点的加权平均进度。
/// 此方法会遍历所有直接子节点，根据权重计算聚合进度值。
///
/// - Parameter node: 需要计算进度的目标节点
/// - Returns: 计算后的进度值，范围 [0.0, 1.0]
/// - Throws: `CascadingError.invalidNode` 当节点类型不支持进度计算时
///
/// - Example:
/// ```swift
/// let progress = try calculator.calculateCascadingProgress(for: objectiveNode)
/// ```
func calculateCascadingProgress(for node: OKRNode) throws -> Double
```

### 测试要求

- 所有新功能**必须**包含对应的单元测试
- 所有 Bug 修复**必须**包含回归测试
- 测试覆盖率不应低于当前水平（目标：核心逻辑 100% 分支覆盖）
- 使用 `XCTest` 框架编写测试
- 测试命名应清晰表达测试意图：`test_场景_预期行为`

```swift
func test_cascadeCalculator_leafKRUpdated_parentObjectiveReflectsWeightedAverage() {
    // Given: 一个包含两个 KR 的 Objective，权重分别为 60% 和 40%
    // When: 更新两个 KR 的进度为 50% 和 100%
    // Then: 父 Objective 的进度应为 70% (0.5*0.6 + 1.0*0.4)
}
```

### 代码风格

- 使用 4 个空格缩进
- 最大行宽 120 个字符
- 类/结构体的大括号不换行，函数的大括号不换行
- 属性之间按相关功能分组，用空行分隔
- MARK 注释用于组织代码：`// MARK: - Lifecycle`、`// MARK: - Private Methods`

## 开发分支策略

本项目采用 **Git Flow** 分支模型：

```
main        — 稳定版本分支，仅接受已通过审查的合并
  ↑
develop     — 开发主分支，新功能在此集成
  ↑
feature/*   — 功能分支，从 develop 切出，完成后合并回 develop
  ↑
hotfix/*    — 紧急修复，从 main 切出，完成后合并到 main 和 develop
  ↑
release/*   — 发布准备分支，从 develop 切出，完成后合并到 main
```

### 分支命名规范

- `feature/树状视图搜索过滤` — 新功能
- `fix/进度计算精度问题` — Bug 修复
- `docs/api文档更新` — 文档更新
- `test/级联引擎补充测试` — 测试相关
- `refactor/提取通用协议` — 代码重构

## 提交信息规范

本项目遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/) 规范。

### 格式

```
<类型>[可选的作用域]: <描述>

[可选的正文]

[可选的脚注]
```

### 类型 (Type)

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档变更 |
| `style` | 代码格式调整（不影响功能） |
| `refactor` | 代码重构 |
| `perf` | 性能优化 |
| `test` | 添加或修改测试 |
| `chore` | 构建过程或辅助工具的变动 |
| `ci` | CI 配置变更 |

### 示例

```
feat(级联引擎): 添加加权平均进度计算支持

实现了基于权重配置的级联进度计算，允许父节点根据
子节点的重要性（权重）计算聚合进度。

- 添加 WeightedCascadingCalculator 类
- 支持深度优先遍历计算
- 100% 分支覆盖的单元测试

Closes #123
```

```
fix(树状视图): 修复深色模式下进度条颜色异常

在深色模式下，低进度条的颜色对比度不足。
调整颜色算法以适配深色背景。

Fixes #456
```

## Pull Request 流程

1. **Fork 仓库** 并从 `develop` 分支创建您的功能分支 (`git checkout -b feature/ amazing-feature`)
2. **开发功能** 并确保遵循代码规范
3. **本地测试** 确保所有测试通过 (`swift test`)
4. **同步上游** 在提交 PR 前，同步上游分支的最新更改：
   ```bash
   git fetch upstream
   git rebase upstream/develop
   ```
5. **提交变更** 使用 Conventional Commits 格式
6. **创建 PR** 到 `develop` 分支（不是 `main`！）
7. **填写 PR 模板** 详细描述变更内容
8. **等待审查** 至少需要一个维护者的审查批准
9. **合并** 审查通过后，由维护者合并

### PR 审查关注点

审查者将关注以下方面：

- 代码正确性和边界情况处理
- Swift 6 并发安全性
- 测试覆盖的完整性
- 双平台 (macOS/iOS) 的兼容性
- 文档注释的质量
- UI 的辅助功能 (Accessibility) 支持

## Issue 报告指南

### 报告 Bug

请使用 GitHub 上的 [Bug 报告模板](.github/ISSUE_TEMPLATE/bug_report.yml)，提供以下信息：

- 平台（macOS/iOS）和版本号
- 清晰的问题描述
- 复现步骤
- 期望行为 vs 实际行为
- 如有截图或日志请一并提供

### 功能建议

请使用 [功能请求模板](.github/ISSUE_TEMPLATE/feature_request.yml)，描述：

- 功能的使用场景
- 期望的行为
- 您考虑过的替代方案

## 代码审查流程

### 对于审查者

- 保持友善和建设性，遵循行为准则
- 关注代码质量、安全性和性能
- 检查测试覆盖是否充分
- 验证文档注释是否完整
- 确认是否遵循 Swift 6 并发规范

### 对于作者

- 积极回应审查意见
- 如有不同意见，请礼貌地解释原因
- 审查修改后及时重新请求审查
- 保持耐心，高质量代码值得等待

## 发布流程

版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)：

- **主版本号 (MAJOR)** — 不兼容的 API 变更
- **次版本号 (MINOR)** — 向下兼容的功能新增
- **修订号 (PATCH)** — 向下兼容的问题修复

发布由维护者执行，流程如下：

1. 从 `develop` 创建 `release/vX.Y.Z` 分支
2. 更新版本号和 `CHANGELOG.md`
3. 进行最终测试
4. 合并到 `main` 并打标签 (`git tag -a v1.0.0 -m "Release version 1.0.0"`)
5. 合并回 `develop`
6. 在 GitHub 上创建 Release

---

再次感谢您的贡献！如有任何问题，欢迎在 [Discussions](https://github.com/your-org/OKRAlignment/discussions) 中提问。
