import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Shared file operations: download (save copy), reveal, copy to pasteboard.
enum FileActions {

    /// Presents a save panel so the user can download a copy of a media file.
    static func download(url: URL, suggestedName: String) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        if let type = UTType(filenameExtension: url.pathExtension) {
            panel.allowedContentTypes = [type]
        }
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
        }
    }

    static func reveal(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func copyToPasteboard(url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([url as NSURL])
        if let image = NSImage(contentsOf: url) {
            pb.writeObjects([image])
        }
    }

    static func copyText(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// Opens an NSOpenPanel for the given content types and returns picked URLs.
    static func pickFiles(contentTypes: [UTType], allowsMultiple: Bool = true) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = allowsMultiple
        panel.allowedContentTypes = contentTypes
        return panel.runModal() == .OK ? panel.urls : []
    }
}

/// A button that presents the macOS share sheet for the given items.
struct ShareButton: NSViewRepresentable {
    let items: [Any]
    var label: String = "分享"
    var systemImage: String = "square.and.arrow.up"

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: label,
                              image: NSImage(systemSymbolName: systemImage,
                                             accessibilityDescription: label) ?? NSImage(),
                              target: context.coordinator,
                              action: #selector(Coordinator.share(_:)))
        button.imagePosition = .imageLeading
        button.bezelStyle = .rounded
        button.controlSize = .large
        context.coordinator.items = items
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.items = items
        nsView.title = " " + label
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var items: [Any] = []
        @objc func share(_ sender: NSButton) {
            guard !items.isEmpty else { return }
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
