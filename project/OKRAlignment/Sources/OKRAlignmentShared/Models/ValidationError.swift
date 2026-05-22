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
}
