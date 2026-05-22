import Foundation

/// Date 扩展 - 格式化工具
/// 提供OKR对齐系统中常用的日期格式化方法
/// 所有方法使用中文本地化（zh_CN）
extension Date {

    // MARK: - Formatting

    /// 格式化为短日期字符串
    /// 格式："yyyy/M/d"
    /// 示例："2026/1/15"
    public var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }

    /// 格式化为中等长度日期字符串
    /// 格式："yyyy年M月d日"
    /// 示例："2026年1月15日"
    public var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }

    /// 格式化为完整日期字符串（包含星期）
    /// 格式："yyyy年M月d日 EEEE"
    /// 示例："2026年1月15日 星期四"
    public var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }

    /// 格式化为日期时间字符串
    /// 格式："yyyy/M/d HH:mm"
    /// 示例："2026/1/15 14:30"
    public var dateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }

    /// 格式化为相对时间描述
    /// 示例："刚刚"、"5分钟前"、"2小时前"、"昨天"、"3天前"
    public var relativeTimeString: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: self,
            to: now
        )

        // 刚刚（1分钟内）
        if let second = components.second, second < 60 && components.hour == 0 && components.day == 0 {
            return "刚刚"
        }

        // 分钟前
        if let minute = components.minute, minute < 60 && components.hour == 0 && components.day == 0 {
            return "\(minute)分钟前"
        }

        // 小时前
        if let hour = components.hour, hour < 24 && components.day == 0 {
            return "\(hour)小时前"
        }

        // 昨天
        if let day = components.day, day == 1 {
            return "昨天"
        }

        // 天前
        if let day = components.day, day < 30 {
            return "\(day)天前"
        }

        // 月前
        if let month = components.month, month < 12 {
            return "\(month)个月前"
        }

        // 年前
        if let year = components.year, year > 0 {
            return "\(year)年前"
        }

        // 默认返回短日期格式
        return shortDateString
    }
}

// MARK: - Date Calculations

extension Date {

    /// 计算到指定日期的剩余天数
    /// - Parameter endDate: 结束日期
    /// - Returns: 剩余天数（可为负数，表示已过期）
    public func daysUntil(_ endDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: endDate)
        return components.day ?? 0
    }

    /// 计算从指定日期开始已过去的天数
    /// - Parameter startDate: 开始日期
    /// - Returns: 已过去天数（可为负数，表示尚未开始）
    public func daysSince(_ startDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: self)
        return components.day ?? 0
    }

    /// 判断日期是否在指定范围内（包含边界）
    /// - Parameters:
    ///   - startDate: 范围开始
    ///   - endDate: 范围结束
    /// - Returns: 是否在范围内
    public func isBetween(_ startDate: Date, and endDate: Date) -> Bool {
        self >= startDate && self <= endDate
    }

    /// 获取当前日期所在季度的起始月份（1、4、7、10）
    public var quarterStartMonth: Int {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        return ((month - 1) / 3) * 3 + 1
    }

    /// 获取当前日期的季度描述
    /// 示例："2026 Q1"、"2026 Q2"
    public var quarterDescription: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: self)
        let month = calendar.component(.month, from: self)
        let quarter = ((month - 1) / 3) + 1
        return "\(year) Q\(quarter)"
    }
}

// MARK: - Static Helpers

extension Date {

    /// 从年月日创建日期
    /// - Parameters:
    ///   - year: 年
    ///   - month: 月
    ///   - day: 日
    /// - Returns: 创建的日期，无效参数返回nil
    public static func from(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)
    }

    /// 创建指定季度的第一天
    /// - Parameters:
    ///   - year: 年份
    ///   - quarter: 季度（1-4）
    /// - Returns: 该季度的第一天日期
    public static func startOfQuarter(year: Int, quarter: Int) -> Date? {
        let startMonth = ((quarter - 1) * 3) + 1
        return from(year: year, month: startMonth, day: 1)
    }

    /// 创建指定季度的最后一天
    /// - Parameters:
    ///   - year: 年份
    ///   - quarter: 季度（1-4）
    /// - Returns: 该季度的最后一天日期
    public static func endOfQuarter(year: Int, quarter: Int) -> Date? {
        let endMonth = quarter * 3
        let calendar = Calendar.current
        // 获取下个月的第一天，再往前推一天
        guard let nextMonth = from(year: year, month: endMonth + 1, day: 1) else {
            return nil
        }
        return calendar.date(byAdding: .day, value: -1, to: nextMonth)
    }
}
