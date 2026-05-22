import SwiftUI
import CoreData
import os

// MARK: - CommentListView

/// 评论列表视图
/// 展示某个OKR节点的所有评论，支持添加新评论和@提及用户
/// 在节点详情面板底部展示
public struct CommentListView: View {

    // MARK: - Properties

    /// 关联的节点ID
    let nodeId: UUID

    /// 当前用户名称（用于评论作者）
    let currentUserName: String

    /// 可提及的用户列表
    let availableUsers: [String]

    /// Core Data上下文
    @Environment(\.managedObjectContext) private var viewContext

    /// 评论列表
    @State private var comments: [Comment] = []

    /// 新评论内容
    @State private var newCommentText: String = ""

    /// 是否显示提及建议
    @State private var showMentionSuggestions: Bool = false

    /// 过滤后的提及建议
    @State private var filteredMentionSuggestions: [String] = []

    /// 正在编辑的评论ID
    @State private var editingCommentId: UUID?

    /// 编辑中的评论文本
    @State private var editingText: String = ""

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 评论标题
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(.cyan)
                Text("评论 (\(comments.count))")
                    .font(.headline)
                Spacer()
            }

            // 评论列表
            if comments.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("暂无评论")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(comments) { comment in
                        CommentBubbleView(
                            comment: comment,
                            isEditing: editingCommentId == comment.id,
                            editingText: $editingText,
                            onEdit: { startEditing(comment) },
                            onDelete: { deleteComment(comment) },
                            onSaveEdit: { saveEdit(comment) },
                            onCancelEdit: { cancelEdit() }
                        )
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.08))

            // 添加评论输入区
            commentInputArea
        }
    }

    // MARK: - Comment Input

    @ViewBuilder
    private var commentInputArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            // @提及建议浮层
            if showMentionSuggestions && !filteredMentionSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(filteredMentionSuggestions, id: \.self) { user in
                        Button {
                            insertMention(user)
                        } label: {
                            HStack {
                                Image(systemName: "person.circle")
                                    .foregroundStyle(.blue)
                                Text(user)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 8) {
                // 文本输入
                TextField("添加评论... (输入 @ 提及他人)", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .lineLimit(1...4)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: newCommentText) { _, newValue in
                        checkForMentionTrigger(newValue)
                    }

                // 发送按钮
                Button {
                    addComment()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func addComment() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let mentions = Comment.extractMentions(from: trimmed)
        let comment = Comment(
            nodeId: nodeId,
            content: trimmed,
            authorName: currentUserName,
            mentionedUsers: mentions
        )

        // Save to CoreData
        let entity = CommentEntity(context: viewContext)
        entity.fromDomainModel(comment)
        // Set relationship
        let request = NSFetchRequest<OKRNodeEntity>(entityName: "OKRNodeEntity")
        request.predicate = NSPredicate(format: "id == %@", nodeId as CVarArg)
        request.fetchLimit = 1
        if let nodeEntity = try? viewContext.fetch(request).first {
            entity.node = nodeEntity
        }

        do {
            try viewContext.save()
            comments.append(comment)
            newCommentText = ""
            showMentionSuggestions = false
        } catch {
            Logger.app.error("保存评论失败: \(error.localizedDescription)")
        }
    }

    private func deleteComment(_ comment: Comment) {
        // Soft delete
        let request = NSFetchRequest<CommentEntity>(entityName: "CommentEntity")
        request.predicate = NSPredicate(format: "id == %@", comment.id as CVarArg)
        request.fetchLimit = 1

        if let entity = try? viewContext.fetch(request).first {
            entity.softDeleted = true
            do {
                try viewContext.save()
                comments.removeAll { $0.id == comment.id }
            } catch {
                Logger.app.error("删除评论失败: \(error.localizedDescription)")
            }
        }
    }

    private func startEditing(_ comment: Comment) {
        editingCommentId = comment.id
        editingText = comment.content
    }

    private func saveEdit(_ comment: Comment) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let request = NSFetchRequest<CommentEntity>(entityName: "CommentEntity")
        request.predicate = NSPredicate(format: "id == %@", comment.id as CVarArg)
        request.fetchLimit = 1

        if let entity = try? viewContext.fetch(request).first {
            entity.content = trimmed
            entity.editedAt = Date()
            entity.mentionedUsers = Comment.extractMentions(from: trimmed).joined(separator: ",")

            do {
                try viewContext.save()
                if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                    comments[index].content = trimmed
                    comments[index].editedAt = Date()
                    comments[index].mentionedUsers = Comment.extractMentions(from: trimmed)
                }
                editingCommentId = nil
                editingText = ""
            } catch {
                Logger.app.error("编辑评论失败: \(error.localizedDescription)")
            }
        }
    }

    private func cancelEdit() {
        editingCommentId = nil
        editingText = ""
    }

    // MARK: - @Mention Logic

    private func checkForMentionTrigger(_ text: String) {
        // Check if the last word starts with @
        guard let lastAtIndex = text.lastIndex(of: "@") else {
            showMentionSuggestions = false
            return
        }

        let afterAt = String(text[text.index(after: lastAtIndex)...])
        if afterAt.isEmpty || !afterAt.contains(" ") {
            let query = afterAt.lowercased()
            filteredMentionSuggestions = availableUsers.filter { user in
                query.isEmpty || user.lowercased().contains(query)
            }
            showMentionSuggestions = !filteredMentionSuggestions.isEmpty
        } else {
            showMentionSuggestions = false
        }
    }

    private func insertMention(_ userName: String) {
        // Replace the @query with @userName
        if let lastAtIndex = newCommentText.lastIndex(of: "@") {
            let afterAt = String(newCommentText[newCommentText.index(after: lastAtIndex)...])
            if !afterAt.contains(" ") {
                newCommentText = String(newCommentText[..<lastAtIndex]) + "@\(userName) "
            }
        }
        showMentionSuggestions = false
    }

    // MARK: - Load Comments

    func loadComments() {
        let request = NSFetchRequest<CommentEntity>(entityName: "CommentEntity")
        request.predicate = NSPredicate(
            format: "nodeId == %@ AND softDeleted == NO",
            nodeId as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]

        do {
            let entities = try viewContext.fetch(request)
            comments = entities.map { $0.toDomainModel() }
        } catch {
            Logger.app.error("加载评论失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - CommentBubbleView

/// 单个评论气泡视图
private struct CommentBubbleView: View {
    let comment: Comment
    let isEditing: Bool
    @Binding var editingText: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void

    @State private var showActions: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 作者 + 时间
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(comment.authorName)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                if comment.isEdited {
                    Text("(已编辑)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(comment.formattedCreatedAt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // 内容
            if isEditing {
                HStack(spacing: 6) {
                    TextField("", text: $editingText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(spacing: 4) {
                        Button("保存", action: onSaveEdit)
                            .font(.caption2)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        Button("取消", action: onCancelEdit)
                            .font(.caption2)
                            .buttonStyle(.bordered)
                    }
                }
            } else {
                Text(highlightedContent)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 提及标签
            if !comment.mentionedUsers.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "at")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                    ForEach(comment.mentionedUsers, id: \.self) { user in
                        Text("@\(user)")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // Highlight @mentions in content
    private var highlightedContent: AttributedString {
        var attributed = AttributedString(comment.content)
        for user in comment.mentionedUsers {
            let mention = "@\(user)"
            if let range = attributed.range(of: mention) {
                attributed[range].foregroundColor = .cyan
                attributed[range].font = .caption.bold()
            }
        }
        return attributed
    }
}
