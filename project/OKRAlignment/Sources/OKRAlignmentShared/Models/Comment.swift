import Foundation

/// OKR节点评论模型
/// 支持对OKR节点添加评论，@提及用户，以及评论历史记录
public struct Comment: Identifiable, Equatable, Hashable, Sendable {

    // MARK: - Properties

    /// 评论唯一标识符
    public let id: UUID

    /// 关联的OKR节点ID
    public let nodeId: UUID

    /// 评论内容
    public var content: String

    /// 评论作者姓名
    public var authorName: String

    /// @提及的用户列表
    public var mentionedUsers: [String]

    /// 创建时间
    public var createdAt: Date

    /// 最后编辑时间（nil表示未编辑）
    public var editedAt: Date?

    /// 是否已删除（软删除）
    public var isDeleted: Bool

    /// 父评论ID（用于回复功能，nil表示顶级评论）
    public var parentCommentId: UUID?

    // MARK: - Computed Properties

    /// 是否已被编辑
    public var isEdited: Bool {
        editedAt != nil
    }

    /// 是否为回复
    public var isReply: Bool {
        parentCommentId != nil
    }

    /// 格式化后的创建时间
    public var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// 提取内容中的@提及用户名
    /// 从评论文本中解析 @用户名 格式的提及
    public static func extractMentions(from text: String) -> [String] {
        let pattern = #"@(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return results.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        nodeId: UUID,
        content: String,
        authorName: String,
        mentionedUsers: [String] = [],
        createdAt: Date = Date(),
        editedAt: Date? = nil,
        isDeleted: Bool = false,
        parentCommentId: UUID? = nil
    ) {
        self.id = id
        self.nodeId = nodeId
        self.content = content
        self.authorName = authorName
        self.mentionedUsers = mentionedUsers
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.isDeleted = isDeleted
        self.parentCommentId = parentCommentId
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.id == rhs.id
            && lhs.content == rhs.content
            && lhs.editedAt == rhs.editedAt
            && lhs.isDeleted == rhs.isDeleted
    }
}
