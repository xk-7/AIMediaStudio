import Foundation
import AppKit

/// Errors thrown while persisting or loading assets.
enum AssetStoreError: LocalizedError {
    case couldNotCreateDirectory
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .couldNotCreateDirectory: return "无法创建本地存储目录"
        case .fileNotFound: return "找不到对应的素材文件"
        }
    }
}

/// Handles on-disk persistence of media files and the metadata index
/// (assets + jobs). Everything lives under Application Support so the library
/// survives app restarts.
final class AssetStore {

    struct Index: Codable {
        var assets: [Asset]
        var jobs: [AIJob]
    }

    let rootURL: URL
    let mediaURL: URL
    private let indexURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first!
        rootURL = support.appendingPathComponent("AI Media Studio", isDirectory: true)
        mediaURL = rootURL.appendingPathComponent("media", isDirectory: true)
        indexURL = rootURL.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: mediaURL,
                                                 withIntermediateDirectories: true)
    }

    // MARK: - Index

    func loadIndex() -> Index {
        guard let data = try? Data(contentsOf: indexURL) else {
            return Index(assets: [], jobs: [])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Index.self, from: data)) ?? Index(assets: [], jobs: [])
    }

    func saveIndex(_ index: Index) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(index) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    // MARK: - Media files

    func url(for asset: Asset) -> URL {
        mediaURL.appendingPathComponent(asset.fileName)
    }

    /// Stores raw data as a new media file, returning the relative file name.
    @discardableResult
    func writeMedia(_ data: Data, ext: String, id: UUID = UUID()) throws -> String {
        let fileName = "\(id.uuidString).\(ext)"
        let dest = mediaURL.appendingPathComponent(fileName)
        try data.write(to: dest, options: .atomic)
        return fileName
    }

    /// Copies an external file into the media directory, returning the relative name.
    func importFile(from source: URL, id: UUID = UUID()) throws -> String {
        let ext = source.pathExtension.isEmpty ? "dat" : source.pathExtension
        let fileName = "\(id.uuidString).\(ext)"
        let dest = mediaURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        return fileName
    }

    func deleteMedia(for asset: Asset) {
        let url = url(for: asset)
        try? FileManager.default.removeItem(at: url)
    }

    /// Produces a thumbnail image for an asset for display in the UI.
    func thumbnail(for asset: Asset, maxDimension: CGFloat = 512) -> NSImage? {
        let fileURL = url(for: asset)
        switch asset.kind {
        case .image:
            return NSImage(contentsOf: fileURL)
        case .video:
            return VideoService.thumbnail(for: fileURL, maxDimension: maxDimension)
        }
    }
}
