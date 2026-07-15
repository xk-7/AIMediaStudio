import SwiftUI
import AVKit

/// Full-resolution preview for an asset: fitted image or an inline video player.
struct MediaPreview: View {
    let asset: Asset
    @EnvironmentObject private var state: AppState
    @State private var image: NSImage?

    var body: some View {
        Group {
            switch asset.kind {
            case .image:
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
            case .video:
                VideoPlayer(player: AVPlayer(url: state.url(for: asset)))
            }
        }
        .task(id: asset.id) {
            guard asset.kind == .image else { return }
            let url = state.url(for: asset)
            image = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
        }
    }
}
