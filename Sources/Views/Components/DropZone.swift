import SwiftUI
import UniformTypeIdentifiers

/// A drag-and-drop + click-to-browse area for importing media files.
struct DropZone: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var contentTypes: [UTType]
    var onPicked: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: browse) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.brandGradient)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isTargeted ? Theme.accent.opacity(0.12) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                    .foregroundStyle(isTargeted ? Theme.accent : Color.primary.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }

    private func browse() {
        let urls = FileActions.pickFiles(contentTypes: contentTypes)
        if !urls.isEmpty { onPicked(urls) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let filtered = urls.filter { AppState.assetKind(for: $0) != nil }
            if !filtered.isEmpty { onPicked(filtered) }
        }
    }
}
