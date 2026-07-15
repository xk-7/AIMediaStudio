import SwiftUI

/// Asynchronously loads and displays a thumbnail for an asset with a graceful
/// placeholder while loading.
struct AssetThumbnailView: View {
    let asset: Asset
    var cornerRadius: CGFloat = 10
    @EnvironmentObject private var state: AppState
    @State private var image: NSImage?
    @State private var loading = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.05))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if loading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: asset.kind.systemImage)
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }

            if asset.kind == .video {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .shadow(radius: 3)
                        Spacer()
                    }
                    .padding(8)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: asset.id) {
            loading = true
            let url = state.url(for: asset)
            let kind = asset.kind
            let loaded = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                switch kind {
                case .image: return NSImage(contentsOf: url)
                case .video: return VideoService.thumbnail(for: url)
                }
            }.value
            image = loaded
            loading = false
        }
    }
}
