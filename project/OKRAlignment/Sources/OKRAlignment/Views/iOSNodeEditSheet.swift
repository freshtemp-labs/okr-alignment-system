import SwiftUI
import OKRAlignmentShared

// MARK: - iOSNodeEditSheet

/// iOS节点编辑/创建Sheet
/// ====================
/// 以`.sheet`方式呈现的节点编辑和创建表单。
///
/// # 功能
/// - **编辑模式**: 修改现有OKR节点的属性
/// - **创建模式**: 创建新的OKR节点
/// - 使用共享的`NodeEditForm`组件作为核心表单
/// - 包装在iOS风格的`NavigationStack`中
///
/// # 表单内容
/// 通过`NodeEditForm`提供以下字段：
/// - 标题（必填）
/// - 描述（可选）
/// - 类型选择（Objective / Key Result）
/// - 范围选择（Enterprise / Personal）
/// - 负责人（必填）
/// - 当前值/目标值/单位（仅Key Result类型时显示）
/// - 状态选择
/// - 父节点选择（可选）
///
/// # 输入验证
/// - 标题不能为空（trim后长度 > 0）
/// - 负责人不能为空
/// - 目标值必须 > 0（Key Result类型）
///
/// ## 使用示例
/// ```swift
/// .sheet(isPresented: $isEditSheetPresented) {
///     iOSNodeEditSheet(
///         node: selectedNode,
///         onSave: { savedNode in
///             // 处理保存后的节点
///         },
///         onCancel: {
///             // 取消编辑
///         }
///     )
/// }
/// ```
struct iOSNodeEditSheet: View {

    // MARK: - 属性

    /// 正在编辑的节点
    /// - `nil`: 创建新节点
    /// - `非nil`: 编辑现有节点
    let node: OKRNode?

    /// 保存回调
    /// 当用户点击保存且验证通过时调用
    /// 参数为保存后的节点
    let onSave: (OKRNode) -> Void

    /// 取消回调
    /// 当用户点击取消时调用
    let onCancel: () -> Void

    /// 可用的父节点列表
    /// 用于父节点选择器的数据源
    /// 默认为空数组
    var availableParents: [OKRNode] = []

    // MARK: - 状态

    /// 是否正在保存
    /// 保存过程中展示加载状态
    @State private var isSaving: Bool = false

    /// 表单验证错误信息
    /// 验证失败时展示的错误提示
    @State private var validationError: String? = nil

    /// 是否展示验证错误弹窗
    /// 通过计算绑定将validationError的变化同步到弹窗展示状态
    private var showValidationAlert: Binding<Bool> {
        Binding(
            get: { validationError != nil },
            set: { if !$0 { validationError = nil } }
        )
    }

    // MARK: - 计算属性

    /// 表单模式（创建或编辑）
    /// 根据node是否为nil自动判断
    private var formMode: NodeEditForm.Mode {
        if let node = node {
            return .edit(node)
        } else {
            return .create(parentId: nil)
        }
    }

    /// 表单标题
    private var sheetTitle: String {
        node == nil ? "新建节点" : "编辑节点"
    }

    // MARK: - 初始化

    /// 创建节点编辑Sheet
    /// - Parameters:
    ///   - node: 要编辑的节点（nil表示创建新节点）
    ///   - availableParents: 可选的父节点列表
    ///   - onSave: 保存回调
    ///   - onCancel: 取消回调
    init(
        node: OKRNode?,
        availableParents: [OKRNode] = [],
        onSave: @escaping (OKRNode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.node = node
        self.availableParents = availableParents
        self.onSave = onSave
        self.onCancel = onCancel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 深色背景
                Color.appBackground
                    .ignoresSafeArea()

                // 核心表单内容
                NodeEditForm(
                    mode: formMode,
                    availableParents: availableParents,
                    onSave: handleSave,
                    onCancel: handleCancel
                )
            }
            // 导航栏标题
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            // 工具栏 - 仅保留取消按钮（保存按钮在NodeEditForm内部）
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        handleCancel()
                    }
                    .foregroundStyle(Color(red: 59/255, green: 130/255, blue: 246/255))
                }
            }
            // 验证错误提示 - 使用Binding控制展示
            .alert("验证失败", isPresented: $showValidationAlert) {
                Button("确定") {
                    validationError = nil
                }
            } message: {
                if let error = validationError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - 事件处理

    /// 处理保存操作
    /// 调用外部onSave回调并关闭Sheet
    /// - Parameter savedNode: 保存后的节点
    private func handleSave(_ savedNode: OKRNode) {
        // 前置验证
        let validationResult = validateNode(savedNode)
        if let error = validationResult {
            validationError = error
            return
        }

        isSaving = true
        // 调用外部保存回调
        onSave(savedNode)
        isSaving = false
    }

    /// 处理取消操作
    /// 调用外部onCancel回调
    private func handleCancel() {
        onCancel()
    }

    // MARK: - 验证

    /// 验证节点数据
    /// 在保存前执行额外的业务规则验证
    /// - Parameter node: 要验证的节点
    /// - Returns: 验证错误信息，nil表示验证通过
    private func validateNode(_ node: OKRNode) -> String? {
        // ===== 验证1: 标题非空 =====
        if node.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "标题不能为空，请输入节点标题。"
        }

        // ===== 验证2: 目标值 > 0（Key Result类型） =====
        if node.nodeType == .keyResult && node.targetValue <= 0 {
            return "关键结果的目标值必须大于0。"
        }

        // ===== 验证3: 负责人非空 =====
        if node.ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "负责人不能为空，请输入负责人姓名。"
        }

        // ===== 验证4: 标题长度限制 =====
        if node.title.count > 200 {
            return "标题长度不能超过200个字符。"
        }

        // 所有验证通过
        return nil
    }
}

// MARK: - iOSNodeCreateSheet

/// iOS节点创建专用Sheet
/// ===================
/// 专门用于创建新OKR节点的Sheet视图。
/// 是`iOSNodeEditSheet`的便捷封装，固定使用创建模式。
///
/// ## 使用示例
/// ```swift
/// .sheet(isPresented: $showCreateSheet) {
///     iOSNodeCreateSheet(
///         parentId: selectedParentId,
///         onSave: { newNode in
///             await viewModel.createNode(newNode)
///         },
///         onCancel: {
///             showCreateSheet = false
///         }
///     )
/// }
/// ```
struct iOSNodeCreateSheet: View {

    // MARK: - 属性

    /// 父节点ID
    /// 新创建的节点将作为该父节点的子节点
    /// nil表示创建根级Objective
    let parentId: UUID?

    /// 可用的父节点列表
    var availableParents: [OKRNode] = []

    /// 保存回调
    let onSave: (OKRNode) -> Void

    /// 取消回调
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        iOSNodeEditSheet(
            node: nil,
            availableParents: availableParents,
            onSave: onSave,
            onCancel: onCancel
        )
    }
}

// MARK: - Preview Helpers

/// 创建示例节点用于预览
private func makePreviewNode(
    title: String,
    nodeType: NodeType,
    scope: Scope,
    progress: Double
) -> OKRNode {
    OKRNode(
        id: UUID(),
        title: title,
        nodeDescription: "这是一个示例描述，用于展示编辑表单的效果。",
        nodeType: nodeType,
        scope: scope,
        currentValue: nodeType == .keyResult ? progress : 0,
        targetValue: nodeType == .keyResult ? 100 : 0,
        unit: nodeType == .keyResult ? "%" : nil,
        progress: progress,
        status: .inProgress,
        ownerName: "张三",
        createdAt: Date(),
        updatedAt: Date(),
        sortOrder: 0,
        parentId: nil,
        children: [],
        cycleId: UUID()
    )
}

// MARK: - Previews

#Preview("iOSNodeEditSheet - Create Mode") {
    @Previewable @State var isPresented = true

    Color.appBackground
        .sheet(isPresented: $isPresented) {
            iOSNodeEditSheet(
                node: nil,
                onSave: { _ in },
                onCancel: {}
            )
        }
}

#Preview("iOSNodeEditSheet - Edit Objective") {
    @Previewable @State var isPresented = true

    let editNode = makePreviewNode(
        title: "提升产品核心用户体验",
        nodeType: .objective,
        scope: .enterprise,
        progress: 65.0
    )

    Color.appBackground
        .sheet(isPresented: $isPresented) {
            iOSNodeEditSheet(
                node: editNode,
                onSave: { _ in },
                onCancel: {}
            )
        }
}

#Preview("iOSNodeEditSheet - Edit Key Result") {
    @Previewable @State var isPresented = true

    let editNode = makePreviewNode(
        title: "NPS评分从30提升到50",
        nodeType: .keyResult,
        scope: .enterprise,
        progress: 70.0
    )

    Color.appBackground
        .sheet(isPresented: $isPresented) {
            iOSNodeEditSheet(
                node: editNode,
                onSave: { _ in },
                onCancel: {}
            )
        }
}

#Preview("iOSNodeCreateSheet") {
    @Previewable @State var isPresented = true

    Color.appBackground
        .sheet(isPresented: $isPresented) {
            iOSNodeCreateSheet(
                parentId: nil,
                onSave: { _ in },
                onCancel: {}
            )
        }
}
