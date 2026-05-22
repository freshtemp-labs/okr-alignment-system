import Foundation

/// OKR节点验证错误枚举
/// 在创建或编辑OKR节点时进行数据校验，确保业务规则合规
/// 校验规则包括：标题非空、目标值有效、叶子节点必须有数值、父节点类型兼容、必须关联周期
public enum ValidationError: Error, Equatable, Sendable {
    /// 标题为空
    /// 所有OKR节点必须具有非空标题
    case emptyTitle

    /// 目标值无效
    /// 目标值必须大于0，否则无法衡量进度
    case invalidTargetValue

    /// 叶子关键结果缺少数值
    /// 叶子节点（无子节点的KR）必须有当前值和目标值
    case leafMissingValues
    /// 当前值超出有效范围
    /// 叶子节点的currentValue不能为负数，也不能超过targetValue
    case currentValueOutOfRange

    /// 父节点类型不匹配
    /// KR的直接子节点必须是个人级Objective
    case parentTypeMismatch

    /// 未设置所属周期
    /// 所有OKR节点必须关联到一个OKR周期
    case cycleNotSet

    /// 周期日期范围无效
    /// 结束日期必须晚于开始日期
    case invalidCycleDateRange

    /// KR的目标值必须大于0
    /// 所有Key Result节点（无论是否叶子）的targetValue必须大于0
    case krTargetValueMustBePositive

    /// 存在关联子节点的删除警告
    /// 删除节点时，如果有子节点，需要警告用户
    case hasChildNodes(childCount: Int)

    /// 标题包含前后多余空格
    /// 标题将被自动修剪
    case titleNeedsTrimming

    /// 描述字段为空字符串（将被自动清理为nil）
    case emptyDescriptionCleanup
}

// MARK: - Error Description

extension ValidationError {
    /// 返回错误的中文描述信息
    /// 用于UI展示，向用户解释验证失败的原因
    public var message: String {
        switch self {
        case .emptyTitle:
            return "标题不能为空，请输入一个描述性的标题"
        case .invalidTargetValue:
            return "目标值必须大于0"
        case .leafMissingValues:
            return "叶子节点必须设置当前值和目标值"
        case .currentValueOutOfRange:
            return "当前值不能为负数且不能超过目标值"
        case .parentTypeMismatch:
            return "父节点类型不匹配：关键结果的子节点必须是个人级目标"
        case .cycleNotSet:
            return "请为该节点选择一个OKR周期"
        case .invalidCycleDateRange:
            return "结束日期必须晚于开始日期"
        case .krTargetValueMustBePositive:
            return "关键结果的目标值必须大于0"
        case .hasChildNodes(let count):
            return "将同时删除 \(count) 个子节点"
        case .titleNeedsTrimming:
            return "标题前后包含多余空格，将自动修剪"
        case .emptyDescriptionCleanup:
            return "描述字段为空，将自动清除"
        }
    }

    /// 返回错误的本地化标题
    public var title: String {
        switch self {
        case .emptyTitle:
            return "标题错误"
        case .invalidTargetValue:
            return "目标值错误"
        case .leafMissingValues:
            return "数值缺失"
        case .currentValueOutOfRange:
            return "当前值超出范围"
        case .parentTypeMismatch:
            return "层级结构错误"
        case .cycleNotSet:
            return "周期未设置"
        case .invalidCycleDateRange:
            return "日期范围无效"
        case .krTargetValueMustBePositive:
            return "目标值错误"
        case .hasChildNodes:
            return "存在关联子节点"
        case .titleNeedsTrimming:
            return "标题格式"
        case .emptyDescriptionCleanup:
            return "描述清理"
        }
    }

    /// 是否为严重错误（阻断保存操作）
    public var isBlocking: Bool {
        switch self {
        case .titleNeedsTrimming, .emptyDescriptionCleanup:
            return false  // 这些是自动修复的警告，不阻断保存
        default:
            return true
        }
    }
}

// MARK: - Validation Helpers

extension OKRNode {
    /// 对当前节点进行完整的业务规则验证
    /// - Returns: 验证通过返回nil，否则返回ValidationError
    public func validate() -> ValidationError? {
        // 检查标题是否为空（去除首尾空白后）
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyTitle
        }

        // 检查目标值是否有效
        if targetValue <= 0 {
            return .invalidTargetValue
        }

        // 叶子KR节点必须有数值
        if isLeaf {
            // 当前值不能为负数
            if currentValue < 0 {
                return .currentValueOutOfRange
            }
            // 当前值不能超过目标值（进度不能超过100%）
            if targetValue > 0 && currentValue > targetValue {
                return .currentValueOutOfRange
            }
        }

        // 所有KR节点的目标值必须大于0
        if nodeType == .keyResult && targetValue <= 0 {
            return .krTargetValueMustBePositive
        }

        // 检查是否关联了周期
        if cycleId == nil {
            return .cycleNotSet
        }

        // 检查父节点类型兼容性
        if let parentId = parentId {
            // 企业级KR的子节点必须是个人级Objective
            // 具体检查需要结合上下文中的父节点信息
            // 此处为基础结构验证
            if nodeType == .keyResult && !children.isEmpty {
                // KR可以有子节点（个人级O），但需要确保类型正确
                // 详细验证由调用方根据完整树结构进行
            }
        }

        // 所有验证通过
        return nil
    }

    /// 对节点进行保存前的自动清理
    /// - Returns: 清理后的节点副本，以及执行的清理操作列表
    public func autoCleanup() -> (node: OKRNode, cleanups: [ValidationError]) {
        var cleaned = self
        var cleanups: [ValidationError] = []

        // 1. 修剪标题前后空格
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle != title {
            cleaned.title = trimmedTitle
            cleanups.append(.titleNeedsTrimming)
        }

        // 2. 清理空描述字段
        if let desc = nodeDescription, desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cleaned.nodeDescription = nil
            cleanups.append(.emptyDescriptionCleanup)
        }

        return (cleaned, cleanups)
    }
}

// MARK: - OKRCycle Validation

extension OKRCycle {
    /// 验证周期数据
    /// - Returns: 验证错误数组，空数组表示验证通过
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // 名称不能为空
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle)
        }

        // 结束日期必须晚于开始日期
        if endDate <= startDate {
            errors.append(.invalidCycleDateRange)
        }

        return errors
    }
}

// MARK: - Delete Warning Helper

/// 删除警告辅助结构
public struct DeleteWarning: Sendable {
    /// 直接删除的节点数量
    public let directDeleteCount: Int
    /// 级联删除的子节点数量
    public let cascadeDeleteCount: Int
    /// 总删除数量
    public var totalCount: Int { directDeleteCount + cascadeDeleteCount }

    /// 警告消息
    public var message: String {
        if cascadeDeleteCount > 0 {
            return "将删除 \(directDeleteCount) 个节点及其 \(cascadeDeleteCount) 个子节点，共 \(totalCount) 个节点"
        }
        return "将删除 \(directDeleteCount) 个节点"
    }

    /// 是否需要显示警告（存在级联删除时需要）
    public var needsWarning: Bool {
        cascadeDeleteCount > 0
    }
}
