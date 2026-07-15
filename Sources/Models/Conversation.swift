import Foundation

enum ChatRole: String, Codable, Hashable {
    case user
    case assistant
}

/// A single message in a conversation. User messages may carry attached images.
struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var role: ChatRole
    var text: String
    var imageAssetIDs: [UUID]
    var createdAt: Date
    /// Marks an assistant message that failed (rendered as an error bubble).
    var isError: Bool

    init(id: UUID = UUID(),
         role: ChatRole,
         text: String,
         imageAssetIDs: [UUID] = [],
         createdAt: Date = Date(),
         isError: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.imageAssetIDs = imageAssetIDs
        self.createdAt = createdAt
        self.isError = isError
    }
}

/// A persistent, multi-turn AI conversation. Keeps full history so the user can
/// keep asking follow-up questions with context retained across turns.
struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String = "新对话",
         messages: [ChatMessage] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var lastPreview: String {
        messages.last?.text ?? "开始一段新的对话…"
    }
}
