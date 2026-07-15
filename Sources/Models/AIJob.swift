import Foundation

/// Lifecycle status of an AI job.
enum JobStatus: String, Codable, Hashable {
    case running
    case succeeded
    case failed

    var displayName: String {
        switch self {
        case .running: return "处理中"
        case .succeeded: return "已完成"
        case .failed: return "失败"
        }
    }
}

/// A record of a single AI processing request. Kept in history so the user can
/// review, re-open, download or share past results.
struct AIJob: Identifiable, Codable, Hashable {
    let id: UUID
    var capability: AICapability
    var status: JobStatus
    var createdAt: Date
    var prompt: String?
    var inputAssetIDs: [UUID]
    /// The generated media asset (for image outputs).
    var resultAssetID: UUID?
    /// The textual result (for analysis outputs).
    var textResult: String?
    var errorMessage: String?

    init(id: UUID = UUID(),
         capability: AICapability,
         status: JobStatus = .running,
         createdAt: Date = Date(),
         prompt: String? = nil,
         inputAssetIDs: [UUID] = [],
         resultAssetID: UUID? = nil,
         textResult: String? = nil,
         errorMessage: String? = nil) {
        self.id = id
        self.capability = capability
        self.status = status
        self.createdAt = createdAt
        self.prompt = prompt
        self.inputAssetIDs = inputAssetIDs
        self.resultAssetID = resultAssetID
        self.textResult = textResult
        self.errorMessage = errorMessage
    }
}
