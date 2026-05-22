// OKRAlignmentShared/Utils/LocalizationManager.swift

import SwiftUI
import os

/// 国际化管理器
/// =============
/// 管理应用的语言切换和本地化字符串。
///
/// # 支持的语言
/// - 简体中文 (zh-Hans) — 默认
/// - English (en)
///
/// # 使用方式
/// ```swift
/// // 在视图中
/// Text(LocalizationManager.shared.localized("settings.appearance"))
///
/// // 或使用扩展
/// Text("settings.appearance".localized)
/// ```
@Observable
public final class LocalizationManager: @unchecked Sendable {

    // MARK: - Types

    /// 支持的语言
    public enum Language: String, CaseIterable, Sendable {
        case zhHans = "zh-Hans"
        case en = "en"

        /// 显示名称（用该语言显示）
        public var displayName: String {
            switch self {
            case .zhHans: return "简体中文"
            case .en: return "English"
            }
        }

        /// 语言代码
        public var code: String { rawValue }
    }

    // MARK: - Properties

    nonisolated(unsafe) public static var shared = LocalizationManager()

    /// 当前语言
    public var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.storageKey)
            Logger.app.info("语言切换为: \(self.currentLanguage.displayName)")
        }
    }

    // MARK: - Private

    private static let storageKey = "okr_app_language"

    /// 本地化字符串表
    private let strings: [Language: [String: String]] = [
        .zhHans: zhHansStrings,
        .en: enStrings
    ]

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.currentLanguage = Language(rawValue: stored) ?? .zhHans
    }

    // MARK: - Public API

    /// 获取本地化字符串
    /// - Parameter key: 字符串键
    /// - Returns: 本地化后的字符串，如果找不到则返回 key 本身
    public func localized(_ key: String) -> String {
        strings[currentLanguage]?[key] ?? key
    }

    /// 获取本地化字符串（带参数替换）
    /// - Parameters:
    ///   - key: 字符串键
    ///   - arguments: 替换参数
    /// - Returns: 本地化后的字符串
    public func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - String Extension

extension String {
    /// 获取当前语言的本地化字符串
    public var localized: String {
        LocalizationManager.shared.localized(self)
    }

    /// 获取本地化字符串并格式化
    public func localized(_ arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localized(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - View Extension

extension View {
    /// 本地化文本修饰符
    func localizedText(_ key: String) -> some View {
        self.accessibilityValue(key.localized)
    }
}

// MARK: - Chinese Strings

private let zhHansStrings: [String: String] = [
    // 通用
    "common.ok": "确定",
    "common.cancel": "取消",
    "common.save": "保存",
    "common.delete": "删除",
    "common.edit": "编辑",
    "common.create": "创建",
    "common.search": "搜索",
    "common.refresh": "刷新",
    "common.loading": "加载中...",
    "common.error": "错误",
    "common.success": "成功",
    "common.confirm": "确认",
    "common.back": "返回",
    "common.close": "关闭",
    "common.export": "导出",
    "common.import": "导入",
    "common.settings": "设置",

    // 导航
    "nav.cycles": "周期",
    "nav.tree": "OKR 树",
    "nav.analytics": "分析",
    "nav.settings": "设置",

    // 设置
    "settings.appearance": "外观",
    "settings.appearance.system": "跟随系统",
    "settings.appearance.light": "始终浅色",
    "settings.appearance.dark": "始终深色",
    "settings.appearance.footer": "跟随系统将根据 iOS/macOS 系统设置自动切换浅色和深色模式。",
    "settings.icloud": "iCloud 同步",
    "settings.language": "语言",
    "settings.dataMigration": "数据迁移",
    "settings.dataManagement": "数据管理",
    "settings.notification": "通知设置",

    // 周期
    "cycle.new": "新建周期",
    "cycle.name": "周期名称",
    "cycle.startDate": "开始日期",
    "cycle.endDate": "结束日期",
    "cycle.active": "活跃",
    "cycle.archived": "已归档",
    "cycle.draft": "草稿",
    "cycle.archive": "归档",
    "cycle.activate": "激活",
    "cycle.delete.confirm": "确定要删除此周期吗？",
    "cycle.filter": "筛选周期",
    "cycle.results": "%d 个结果",

    // 节点
    "node.objective": "目标",
    "node.keyResult": "关键结果",
    "node.enterprise": "企业级",
    "node.personal": "个人级",
    "node.title": "标题",
    "node.description": "描述",
    "node.owner": "负责人",
    "node.progress": "进度",
    "node.status": "状态",
    "node.scope": "范围",
    "node.weight": "权重",
    "node.new": "新建节点",
    "node.edit": "编辑节点",
    "node.delete.confirm": "确定要删除 \"%@\" 吗？此操作不可撤销。",
    "node.notStarted": "未开始",
    "node.inProgress": "进行中",
    "node.atRisk": "风险中",
    "node.completed": "已完成",
    "node.cancelled": "已取消",

    // 树视图
    "tree.expandAll": "展开全部",
    "tree.collapseAll": "折叠全部",
    "tree.nodeCount": "%d 个节点",
    "tree.expanded": "%d 个已展开",
    "tree.empty.title": "暂无 OKR",
    "tree.empty.subtitle": "创建您的第一个目标",
    "tree.empty.action": "创建 OKR",
    "tree.noCycles.title": "暂无周期",
    "tree.noCycles.subtitle": "创建一个周期以开始",
    "tree.noCycles.action": "创建周期",
    "tree.loading": "正在加载 OKR 树...",

    // 数据迁移
    "migration.title": "数据迁移",
    "migration.currentVersion": "当前数据版本",
    "migration.latestVersion": "最新数据版本",
    "migration.status": "迁移状态",
    "migration.needsMigration": "需要迁移",
    "migration.upToDate": "已是最新",
    "migration.start": "开始迁移",
    "migration.rollback": "回滚到迁移前",
    "migration.clearLog": "清除日志",
    "migration.footer": "迁移前会自动创建数据备份。如果迁移过程中出现问题，可以回滚到备份状态。",
    "migration.completed": "迁移完成",
    "migration.failed": "迁移失败",
    "migration.rolledBack": "已回滚",
    "migration.confirmRollback": "确认回滚",
    "migration.rollbackMessage": "回滚将恢复到迁移前的数据状态，迁移过程中新增的数据将丢失。确定要继续吗？",

    // 分析
    "analytics.title": "OKR 分析",
    "analytics.overallProgress": "整体进度",
    "analytics.nodeDistribution": "节点分布",
    "analytics.statusBreakdown": "状态分布",
    "analytics.topPerformers": "表现最佳",

    // 批量操作
    "batch.select": "多选",
    "batch.deselect": "退出选择",
    "batch.delete": "批量删除",
    "batch.updateOwner": "批量更新负责人",
    "batch.export": "批量导出",
    "batch.confirmDelete": "确定要删除选中的 %d 个节点吗？",
    "batch.newOwner": "新的负责人名称",

    // 导出/导入
    "export.csv": "导出为 CSV",
    "export.json": "导出为 JSON",
    "export.success": "导出成功",
    "export.failed": "导出失败",
    "import.success": "导入成功",
    "import.failed": "导入失败",
    "import.invalidFormat": "无效的 JSON 格式",

    // 错误消息
    "error.loadTree": "加载 OKR 树失败: %@",
    "error.updateProgress": "更新进度失败: %@",
    "error.deleteNode": "删除节点失败: %@",
    "error.createCycle": "创建周期失败: %@",
    "error.loadCycles": "加载周期列表失败: %@",
    "error.nodeNotFound": "未找到指定的节点",
    "error.notLeaf": "只能更新叶子关键结果的进度",
    "error.loadFirst": "请先加载 OKR 树",

    // 菜单
    "menu.newNode": "新建 OKR 节点",
    "menu.search": "搜索 OKR",
    "menu.deleteSelected": "删除选中",
    "menu.refreshTree": "刷新树",
    "menu.exportCSV": "导出为 CSV...",
    "menu.exportJSON": "导出为 JSON...",

    // 无障碍
    "a11y.cycleList": "周期列表",
    "a11y.searchField": "搜索 OKR",
    "a11y.treeNodes": "OKR 树包含 %d 个节点，%d 个已展开",
    "a11y.createCycle": "创建新周期",
    "a11y.refresh": "刷新树",
    "a11y.newNode": "创建新节点",
    "a11y.editNode": "编辑选中的节点",
    "a11y.deleteNode": "删除选中的节点",
]

// MARK: - English Strings

private let enStrings: [String: String] = [
    // Common
    "common.ok": "OK",
    "common.cancel": "Cancel",
    "common.save": "Save",
    "common.delete": "Delete",
    "common.edit": "Edit",
    "common.create": "Create",
    "common.search": "Search",
    "common.refresh": "Refresh",
    "common.loading": "Loading...",
    "common.error": "Error",
    "common.success": "Success",
    "common.confirm": "Confirm",
    "common.back": "Back",
    "common.close": "Close",
    "common.export": "Export",
    "common.import": "Import",
    "common.settings": "Settings",

    // Navigation
    "nav.cycles": "Cycles",
    "nav.tree": "OKR Tree",
    "nav.analytics": "Analytics",
    "nav.settings": "Settings",

    // Settings
    "settings.appearance": "Appearance",
    "settings.appearance.system": "Follow System",
    "settings.appearance.light": "Always Light",
    "settings.appearance.dark": "Always Dark",
    "settings.appearance.footer": "Follow System will automatically switch between light and dark mode based on iOS/macOS system settings.",
    "settings.icloud": "iCloud Sync",
    "settings.language": "Language",
    "settings.dataMigration": "Data Migration",
    "settings.dataManagement": "Data Management",
    "settings.notification": "Notifications",

    // Cycle
    "cycle.new": "New Cycle",
    "cycle.name": "Cycle Name",
    "cycle.startDate": "Start Date",
    "cycle.endDate": "End Date",
    "cycle.active": "Active",
    "cycle.archived": "Archived",
    "cycle.draft": "Draft",
    "cycle.archive": "Archive",
    "cycle.activate": "Activate",
    "cycle.delete.confirm": "Are you sure you want to delete this cycle?",
    "cycle.filter": "Filter cycles",
    "cycle.results": "%d results",

    // Node
    "node.objective": "Objective",
    "node.keyResult": "Key Result",
    "node.enterprise": "Enterprise",
    "node.personal": "Personal",
    "node.title": "Title",
    "node.description": "Description",
    "node.owner": "Owner",
    "node.progress": "Progress",
    "node.status": "Status",
    "node.scope": "Scope",
    "node.weight": "Weight",
    "node.new": "New Node",
    "node.edit": "Edit Node",
    "node.delete.confirm": "Are you sure you want to delete \"%@\"? This action cannot be undone.",
    "node.notStarted": "Not Started",
    "node.inProgress": "In Progress",
    "node.atRisk": "At Risk",
    "node.completed": "Completed",
    "node.cancelled": "Cancelled",

    // Tree View
    "tree.expandAll": "Expand All",
    "tree.collapseAll": "Collapse All",
    "tree.nodeCount": "%d nodes",
    "tree.expanded": "%d expanded",
    "tree.empty.title": "No OKRs",
    "tree.empty.subtitle": "Create your first objective",
    "tree.empty.action": "Create OKR",
    "tree.noCycles.title": "No Cycles",
    "tree.noCycles.subtitle": "Create a cycle to get started",
    "tree.noCycles.action": "Create Cycle",
    "tree.loading": "Loading OKR tree...",

    // Data Migration
    "migration.title": "Data Migration",
    "migration.currentVersion": "Current Data Version",
    "migration.latestVersion": "Latest Data Version",
    "migration.status": "Migration Status",
    "migration.needsMigration": "Migration Needed",
    "migration.upToDate": "Up to Date",
    "migration.start": "Start Migration",
    "migration.rollback": "Rollback to Pre-Migration",
    "migration.clearLog": "Clear Log",
    "migration.footer": "A backup is automatically created before migration. If issues occur, you can rollback to the backup state.",
    "migration.completed": "Migration Completed",
    "migration.failed": "Migration Failed",
    "migration.rolledBack": "Rolled Back",
    "migration.confirmRollback": "Confirm Rollback",
    "migration.rollbackMessage": "Rollback will restore data to pre-migration state. Any new data added during migration will be lost. Continue?",

    // Analytics
    "analytics.title": "OKR Analytics",
    "analytics.overallProgress": "Overall Progress",
    "analytics.nodeDistribution": "Node Distribution",
    "analytics.statusBreakdown": "Status Breakdown",
    "analytics.topPerformers": "Top Performers",

    // Batch Operations
    "batch.select": "Multi-Select",
    "batch.deselect": "Exit Select",
    "batch.delete": "Batch Delete",
    "batch.updateOwner": "Batch Update Owner",
    "batch.export": "Batch Export",
    "batch.confirmDelete": "Are you sure you want to delete %d selected nodes?",
    "batch.newOwner": "New owner name",

    // Export/Import
    "export.csv": "Export as CSV",
    "export.json": "Export as JSON",
    "export.success": "Export successful",
    "export.failed": "Export failed",
    "import.success": "Import successful",
    "import.failed": "Import failed",
    "import.invalidFormat": "Invalid JSON format",

    // Error Messages
    "error.loadTree": "Failed to load OKR tree: %@",
    "error.updateProgress": "Failed to update progress: %@",
    "error.deleteNode": "Failed to delete node: %@",
    "error.createCycle": "Failed to create cycle: %@",
    "error.loadCycles": "Failed to load cycle list: %@",
    "error.nodeNotFound": "Node not found",
    "error.notLeaf": "Can only update progress for leaf key results",
    "error.loadFirst": "Please load the OKR tree first",

    // Menu
    "menu.newNode": "New OKR Node",
    "menu.search": "Search OKRs",
    "menu.deleteSelected": "Delete Selected",
    "menu.refreshTree": "Refresh Tree",
    "menu.exportCSV": "Export as CSV...",
    "menu.exportJSON": "Export as JSON...",

    // Accessibility
    "a11y.cycleList": "Cycle list",
    "a11y.searchField": "Search OKRs",
    "a11y.treeNodes": "OKR tree with %d nodes, %d expanded",
    "a11y.createCycle": "Create new cycle",
    "a11y.refresh": "Refresh tree",
    "a11y.newNode": "Create new node",
    "a11y.editNode": "Edit selected node",
    "a11y.deleteNode": "Delete selected node",
]
