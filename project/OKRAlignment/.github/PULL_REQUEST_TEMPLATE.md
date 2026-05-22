# Pull Request

## 变更描述 / Description

<!-- 请用简洁清晰的语言描述本次变更的内容 -->

## 关联 Issue / Related Issue

<!-- 请关联相关的 Issue，使用 Fixes #123 或 Closes #456 格式，如果没有则删除此节 -->

Fixes #(issue number)
Closes #(issue number)

## 变更类型 / Type of Change

<!-- 请在相关选项前打 [x] -->

- [ ] 🐛 修复 Bug (Bug fix)
- [ ] ✨ 新功能 (New feature)
- [ ] 💥 破坏性变更 (Breaking change)
- [ ] 📚 文档更新 (Documentation update)
- [ ] 🎨 UI/样式变更 (UI/Style change)
- [ ] ♻️ 代码重构 (Code refactoring)
- [ ] ⚡ 性能优化 (Performance improvement)
- [ ] ✅ 测试相关 (Tests)
- [ ] 🔧 构建/CI 相关 (Build/CI)

## 测试情况 / Testing

<!-- 请描述您进行的测试 -->

- [ ] 已在 macOS 上测试
- [ ] 已在 iOS 上测试
- [ ] 已在 iPadOS 上测试
- [ ] 所有现有测试通过 (`swift test`)
- [ ] 添加了新的单元测试覆盖变更代码
- [ ] 级联引擎测试通过
- [ ] 手动测试了用户场景

### 测试详情

<!-- 请描述具体的测试步骤和结果 -->

## 代码质量检查 / Code Quality

- [ ] 代码遵循 Swift 6 语法规范
- [ ] 所有 public/internal API 都有文档注释 (DocC 格式)
- [ ] 没有引入新的编译器警告
- [ ] SwiftLint 检查通过（如有配置）
- [ ] 代码已通过 self-review
- [ ] 变量和函数命名清晰、有意义

## UI 变更检查 / UI Check (如适用)

- [ ] 深色模式适配正常
- [ ] 辅助功能 (Accessibility) 标签已添加
- [ ] 支持动态字体 (Dynamic Type)
- [ ] 布局在不同屏幕尺寸上表现正常

## 截图 / Screenshots

<!-- 如果包含 UI 变更，请提供 macOS 和 iOS 的截图 -->

| macOS | iOS |
|-------|-----|
| <!-- macOS 截图 --> | <!-- iOS 截图 --> |

## 检查清单 / Checklist

- [ ] 我的代码遵循本项目的代码规范
- [ ] 我已阅读 [CONTRIBUTING.md](../CONTRIBUTING.md) 并遵循其中的流程
- [ ] 我的提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范
- [ ] 我已将 PR 标题改为描述性的总结
- [ ] 我已提供足够的上下文供审查者理解变更
- [ ] 我已考虑向后兼容性，避免破坏性变更（如有则已明确标注）

## 附加说明 / Additional Notes

<!-- 任何审查者需要了解的其他信息 -->

---

**审查者注意**：审查时请关注以下方面：
- 代码是否符合 Clean Architecture 分层原则
- 新增功能是否有对应的单元测试
- UI 变更是否适配了双平台 (macOS/iOS)
- 文档注释是否完整
