import Foundation

/// The kind of media an asset represents.
enum AssetKind: String, Codable, Hashable {
    case image
    case video

    var displayName: String {
        switch self {
        case .image: return "图片"
        case .video: return "视频"
        }
    }

    var systemImage: String {
        switch self {
        case .image: return "photo"
        case .video: return "film"
        }
    }
}

/// Where an asset came from.
enum AssetOrigin: String, Codable, Hashable {
    case uploaded
    case generated

    var displayName: String {
        switch self {
        case .uploaded: return "上传"
        case .generated: return "AI 生成"
        }
    }
}

/// A single media item stored in the user's library. Both user uploads and
/// AI generated results are represented as assets so they can be browsed,
/// downloaded, shared and managed uniformly.
struct Asset: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: AssetKind
    var origin: AssetOrigin
    /// File name (relative to the media directory) of the stored media file.
    var fileName: String
    var displayName: String
    var createdAt: Date
    /// Prompt used when the asset was generated / edited (if any).
    var prompt: String?
    var tags: [String]
    /// The source asset this one was derived from (edit / analysis input).
    var sourceAssetID: UUID?
    /// The capability that produced this asset (if generated).
    var capability: String?

    init(id: UUID = UUID(),
         kind: AssetKind,
         origin: AssetOrigin,
         fileName: String,
         displayName: String,
         createdAt: Date = Date(),
         prompt: String? = nil,
         tags: [String] = [],
         sourceAssetID: UUID? = nil,
         capability: String? = nil) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.fileName = fileName
        self.displayName = displayName
        self.createdAt = createdAt
        self.prompt = prompt
        self.tags = tags
        self.sourceAssetID = sourceAssetID
        self.capability = capability
    }
}
