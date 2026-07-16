import Foundation

/// The medium a generation session produces.
enum GenerationKind: String, Codable, Hashable {
    case image
    case video

    var displayName: String {
        switch self {
        case .image: return "文生图"
        case .video: return "文生视频"
        }
    }

    var capability: AICapability {
        switch self {
        case .image: return .generateImage
        case .video: return .generateVideo
        }
    }
}

/// A single iteration inside a generation session: a prompt plus its result.
struct GenerationTurn: Identifiable, Codable, Hashable {
    let id: UUID
    var prompt: String
    var status: JobStatus
    var resultAssetID: UUID?
    var errorMessage: String?
    /// Whether this turn iterated on the previous result (refine / continue).
    var refinedFromPrevious: Bool
    var createdAt: Date

    init(id: UUID = UUID(),
         prompt: String,
         status: JobStatus = .running,
         resultAssetID: UUID? = nil,
         errorMessage: String? = nil,
         refinedFromPrevious: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.prompt = prompt
        self.status = status
        self.resultAssetID = resultAssetID
        self.errorMessage = errorMessage
        self.refinedFromPrevious = refinedFromPrevious
        self.createdAt = createdAt
    }
}

/// A persistent, multi-turn creation session for text-to-image / text-to-video.
/// Each turn can build on the previous result, enabling iterative refinement.
struct GenerationSession: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: GenerationKind
    var title: String
    var turns: [GenerationTurn]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         kind: GenerationKind,
         title: String = "新创作",
         turns: [GenerationTurn] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.title = title
        self.turns = turns
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
