import Foundation
import SwiftUI

// MARK: - Card Styling
/// SwiftUI View 扩展 - 卡片样式
/// 提供OKR对齐系统中常用的视图修饰符
/// 统一UI风格，减少重复代码
extension View {

    /// 应用标准卡片背景样式
    /// 包括半透明背景、圆角和边框
    /// 适用于OKR节点卡片、周期选择器等组件
    public func cardBackground() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
    }

    /// 应用可交互卡片的悬浮样式
    /// 在cardBackground基础上增加悬停效果
    /// 适用于可点击的卡片组件
    public func interactiveCardBackground() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 应用选中状态的卡片样式
    /// 使用更亮的边框和背景来指示选中状态
    /// - Parameter isSelected: 是否为选中状态
    public func selectedCardBackground(isSelected: Bool) -> some View {
        self
            .padding()
            .background(isSelected ? Color.cardBackgroundHover : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.cardBorderHover : Color.cardBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
    }
}

// MARK: - Scope Indicators

extension View {

    /// 添加范围指示条（左侧彩色竖条）
    /// 用于区分企业级和个人级节点
    /// - Parameter scope: 节点范围
    public func scopeIndicator(scope: Scope) -> some View {
        self.overlay(
            // 左侧彩色指示条
            Rectangle()
                .fill(Color.scopeColor(for: scope))
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2)),
            alignment: .leading
        )
    }

    /// 添加节点类型标签修饰
    /// - Parameters:
    ///   - nodeType: 节点类型
    ///   - scope: 范围
    public func nodeTypeBadge(nodeType: NodeType, scope: Scope) -> some View {
        self.overlay(
            HStack(spacing: 6) {
                // 范围标识（企业/个人）
                HStack(spacing: 2) {
                    Image(systemName: scope.iconName)
                        .font(.caption2)
                    Text(scope.displayName)
                        .font(.caption2)
                }
                .foregroundColor(scope.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(scope.color.opacity(0.15))
                .clipShape(Capsule())

                // 类型标识（O/KR）
                Text(nodeType == .objective ? "O" : "KR")
                    .font(.caption2.bold())
                    .foregroundColor(nodeType.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(nodeType.color.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding([.top, .leading], 12),
            alignment: .topLeading
        )
    }
}

// MARK: - Progress Styling

extension View {

    /// 应用进度条颜色修饰
    /// 根据范围和节点类型选择合适的进度条颜色
    /// - Parameters:
    ///   - scope: 节点范围
    ///   - isLeaf: 是否为叶子KR节点
    public func progressColor(scope: Scope, isLeaf: Bool) -> some View {
        self.foregroundColor(
            isLeaf ? Color.krProgress : Color.progressColor(for: scope)
        )
    }
}

// MARK: - Typography

extension View {

    /// 应用标题文本样式
    /// 用于卡片标题和section标题
    public func titleStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.primaryText)
    }

    /// 应用正文文本样式
    /// 用于描述和说明文本
    public func bodyStyle() -> some View {
        self
            .font(.body)
            .foregroundColor(.primaryText)
    }

    /// 应用次级文本样式
    /// 用于元信息、时间戳等次要内容
    public func secondaryTextStyle() -> some View {
        self
            .font(.caption)
            .foregroundColor(.secondaryText)
    }

    /// 应用标签文本样式
    /// 用于小标签和状态标识
    public func labelStyle() -> some View {
        self
            .font(.caption2)
            .foregroundColor(.tertiaryText)
    }
}

// MARK: - Animation

extension View {

    /// 应用标准动画修饰
    /// 用于状态变化时的平滑过渡
    public func standardAnimation() -> some View {
        self.animation(.easeInOut(duration: 0.25), value: UUID())
    }

    /// 应用展开/收起动画
    /// 用于树状节点的展开收起交互
    public func expandAnimation() -> some View {
        self.animation(.spring(response: 0.3, dampingFraction: 0.8), value: UUID())
    }
}

// MARK: - Conditional Modifiers

extension View {

    /// 条件性地应用视图修饰符
    /// 简化条件修饰的语法
    /// - Parameters:
    ///   - condition: 条件
    ///   - transform: 条件为true时应用的变换
    /// - Returns: 可能经过变换的视图
    @ViewBuilder
    public func modifyIf<Content: View>(
        _ condition: Bool,
        @ViewBuilder transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
