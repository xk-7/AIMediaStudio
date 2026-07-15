import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var state: AppState

    enum Filter: String, CaseIterable, Identifiable {
        case all, image, video, generated
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "全部"
            case .image: return "图片"
            case .video: return "视频"
            case .generated: return "AI 生成"
            }
        }
    }

    @State private var filter: Filter = .all
    @State private var search: String = ""
    @State private var selected: Asset?
    @State private var isTargeted = false

    private var filtered: [Asset] {
        state.assets.filter { asset in
            switch filter {
            case .all: return true
            case .image: return asset.kind == .image
            case .video: return asset.kind == .video
            case .generated: return asset.origin == .generated
            }
        }
        .filter { asset in
            search.isEmpty
                || asset.displayName.localizedCaseInsensitiveContains(search)
                || (asset.prompt?.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .sheet(item: $selected) { asset in
            AssetDetailView(asset: asset).environmentObject(state)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers); return true
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Theme.accent.opacity(0.08))
                    .overlay(Text("松手导入素材").font(.title3.weight(.semibold)))
                    .allowsHitTesting(false)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                GradientTitle(text: "素材库", size: 22)
                Text("\(state.assets.count) 个素材")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $filter) {
                ForEach(Filter.allCases) { f in Text(f.title).tag(f) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 320)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索", text: $search)
                    .textFieldStyle(.plain)
                    .frame(width: 130)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .clipShape(Capsule())

            Button(action: importFiles) {
                Label("导入", systemImage: "plus")
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Theme.brandGradient)
                    .opacity(0.55)
                Text(state.assets.isEmpty ? "还没有素材" : "没有符合条件的素材")
                    .font(.system(size: 15, weight: .semibold))
                Text("把图片或视频拖到这里,或点击右上角「导入」")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)],
                          spacing: 16) {
                    ForEach(filtered) { asset in
                        AssetGridCard(asset: asset) { selected = asset }
                            .environmentObject(state)
                    }
                }
                .padding(20)
            }
        }
    }

    private func importFiles() {
        let urls = FileActions.pickFiles(contentTypes: [.image, .movie, .video])
        if !urls.isEmpty { state.importFiles(urls) }
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
            if !filtered.isEmpty { state.importFiles(filtered) }
        }
    }
}

// MARK: - Grid card

private struct AssetGridCard: View {
    let asset: Asset
    let onOpen: () -> Void
    @EnvironmentObject private var state: AppState
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AssetThumbnailView(asset: asset)
                .frame(height: 150)
                .overlay(alignment: .topTrailing) {
                    if asset.origin == .generated {
                        Text("AI")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.brandGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(asset.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 8)
        .scaleEffect(hovering ? 1.01 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("打开", action: onOpen)
            Button("下载…") {
                FileActions.download(url: state.url(for: asset),
                                     suggestedName: asset.displayName + "." + (asset.fileName as NSString).pathExtension)
            }
            Button("在访达中显示") {
                FileActions.reveal(url: state.url(for: asset))
            }
            Button("复制") {
                FileActions.copyToPasteboard(url: state.url(for: asset))
            }
            Divider()
            Button("删除", role: .destructive) {
                state.deleteAsset(asset)
            }
        }
    }
}
