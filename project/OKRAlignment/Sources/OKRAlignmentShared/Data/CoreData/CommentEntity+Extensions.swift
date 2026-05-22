import Foundation
import CoreData
import os

/// Comment Core Data实体类
/// 对应数据库中的评论存储，与OKRNodeEntity关联
@objc(CommentEntity)
public final class CommentEntity: NSManagedObject {

    // MARK: - Properties

    /// 评论唯一标识符
    @NSManaged public var id: UUID

    /// 关联的OKR节点ID
    @NSManaged public var nodeId: UUID

    /// 评论内容
    @NSManaged public var content: String

    /// 评论作者姓名
    @NSManaged public var authorName: String

    /// @提及的用户列表（JSON格式存储）
    @NSManaged public var mentionedUsers: String?

    /// 创建时间
    @NSManaged public var createdAt: Date

    /// 最后编辑时间
    @NSManaged public var editedAt: Date?

    /// 是否已删除（软删除）— 使用softDeleted避免与NSManagedObject.isDeleted冲突
    @NSManaged public var softDeleted: Bool

    /// 父评论ID（回复功能）
    @NSManaged public var parentCommentId: UUID?

    // MARK: - Relationships

    /// 关联的OKR节点
    @NSManaged public var node: OKRNodeEntity?

    // MARK: - Fetch Request

    @nonobjc public class func commentFetchRequest() -> NSFetchRequest<CommentEntity> {
        let request = NSFetchRequest<CommentEntity>(entityName: "CommentEntity")
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return request
    }
}

// MARK: - Domain Model Conversion

extension CommentEntity {

    /// 从领域模型更新实体
    public func fromDomainModel(_ model: Comment) {
        id = model.id
        nodeId = model.nodeId
        content = model.content
        authorName = model.authorName
        mentionedUsers = model.mentionedUsers.joined(separator: ",")
        createdAt = model.createdAt
        editedAt = model.editedAt
        softDeleted = model.isDeleted
        parentCommentId = model.parentCommentId
    }

    /// 转换为领域模型
    public func toDomainModel() -> Comment {
        let mentions: [String] = {
            guard let mentionedUsers else { return [] }
            return mentionedUsers.split(separator: ",").map { String($0) }
        }()

        return Comment(
            id: id,
            nodeId: nodeId,
            content: content,
            authorName: authorName,
            mentionedUsers: mentions,
            createdAt: createdAt,
            editedAt: editedAt,
            isDeleted: softDeleted,
            parentCommentId: parentCommentId
        )
    }
}

// MARK: - Fetch Helpers

extension CommentEntity {

    /// 获取指定节点的所有评论（按时间正序）
    public static func fetchComments(
        forNodeId nodeId: UUID,
        context: NSManagedObjectContext
    ) throws -> [CommentEntity] {
        let request = commentFetchRequest()
        request.predicate = NSPredicate(
            format: "nodeId == %@ AND softDeleted == NO",
            nodeId as CVarArg
        )
        return try context.fetch(request)
    }

    /// 获取所有评论（不含已删除的）
    public static func fetchAllActiveComments(
        context: NSManagedObjectContext
    ) throws -> [CommentEntity] {
        let request = commentFetchRequest()
        request.predicate = NSPredicate(format: "softDeleted == NO")
        return try context.fetch(request)
    }
}
