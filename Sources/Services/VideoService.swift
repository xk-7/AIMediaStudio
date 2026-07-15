import Foundation
import AVFoundation
import AppKit

/// Helpers for working with video files: thumbnails and keyframe extraction.
enum VideoService {

    /// Generates a single poster thumbnail for a video.
    static func thumbnail(for url: URL, maxDimension: CGFloat = 512) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        guard let cg = try? generator.copyCGImage(at: time, actualTime: nil) else {
            // Fall back to the very first frame if 1s is beyond the duration.
            guard let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
                return nil
            }
            return NSImage(cgImage: cg, size: .zero)
        }
        return NSImage(cgImage: cg, size: .zero)
    }

    /// Extracts up to `count` evenly-spaced keyframes from a video and returns
    /// them as JPEG data, suitable for sending to a vision model.
    static func extractKeyframes(from url: URL,
                                 count: Int = 4,
                                 maxDimension: CGFloat = 768) async throws -> [Data] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)

        let safeCount = max(1, count)
        var times: [CMTime] = []
        if seconds <= 0 || !seconds.isFinite {
            times = [.zero]
        } else {
            for i in 0..<safeCount {
                // Sample within the interior of the clip to avoid black frames.
                let fraction = (Double(i) + 0.5) / Double(safeCount)
                times.append(CMTime(seconds: seconds * fraction, preferredTimescale: 600))
            }
        }

        var frames: [Data] = []
        for time in times {
            if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
                let rep = NSBitmapImageRep(cgImage: cg)
                if let jpeg = rep.representation(using: .jpeg,
                                                 properties: [.compressionFactor: 0.8]) {
                    frames.append(jpeg)
                }
            }
        }
        if frames.isEmpty { throw AssetStoreError.fileNotFound }
        return frames
    }
}
