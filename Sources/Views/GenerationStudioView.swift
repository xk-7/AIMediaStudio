import SwiftUI

/// Session-based, multi-turn creation panel for text-to-image / text-to-video.
/// Each turn is a prompt + result; follow-ups can iterate on the previous result.
/// Sessions are saved locally and restored on relaunch.
struct GenerationStudioView: View {
    let kind: GenerationKind
    @EnvironmentObject private var state: AppState

    @State private var prompt: String = ""
    @State private var imageSize: ImageSize = .square
    @State private var videoSize: VideoSize = .portrait
    @State private var duration: VideoDuration = .s4
    @State private var refine: Bool = true

    private var session: GenerationSession? { state.activeGenerationSession(for: kind) }
    private var hasPreviousResult: Bool {
        guard let session else { return false }
        return state.lastSuccessfulAsset(in: session) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            sessionBar
            Divider()
            thread
            Divider()
            inputBar
        }
    }

    // MARK: - Session bar

    private var sessionBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(state.sessions(of: kind)) { s in
                    Button {
                        state.setActiveSession(s.id, for: kind)
                    } label: {
                        Label(s.title, systemImage: s.id == session?.id ? "checkmark" : "bubble.left")
                    }
                }
                if state.sessions(of: kind).isEmpty {
                    Text("暂无会话").foregroundStyle(.secondary)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: kind == .image ? "photo.stack" : "film.stack")
                    Text(session?.title ?? "未选择会话")
                        .lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9))
                }
                .font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            if let session {
                Text("\(session.turns.count) 次迭代")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button {
                    state.deleteGenerationSession(session)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("删除该会话")
            }

            Button {
                state.newGenerationSession(kind)
                prompt = ""
            } label: {
                Label("新建会话", systemImage: "plus")
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Thread

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    if let session, !session.turns.isEmpty {
                        ForEach(session.turns) { turn in
                            GenerationTurnRow(turn: turn)
                                .id(turn.id)
                        }
                    } else {
                        emptyState.padding(.top, 50)
                    }
                    Color.clear.frame(height: 1).id("BOTTOM")
                }
                .padding(20)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: session?.turns.count ?? 0) { _, _ in
                withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
            }
            .onChange(of: state.processingStatusText) { _, _ in
                withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: kind == .image ? "photo.badge.plus" : "film.stack")
                .font(.system(size: 40))
                .foregroundStyle(Theme.brandGradient)
            Text(kind == .image ? "开始创作图片" : "开始创作视频")
                .font(.system(size: 15, weight: .semibold))
            Text(kind == .image
                 ? "输入提示词生成图片。之后可以继续追加指令(如「把背景换成蓝色」),在上一张基础上迭代。"
                 : "输入提示词生成视频。开启「基于上一结果继续」可让新片段延续上一段的画面。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if kind == .image {
                    picker("尺寸", selection: $imageSize, options: ImageSize.allCases) { $0.displayName }
                } else {
                    picker("画面", selection: $videoSize, options: VideoSize.allCases) { $0.displayName }
                    picker("时长", selection: $duration, options: VideoDuration.allCases) { $0.displayName }
                }
                Spacer()
                if hasPreviousResult {
                    Toggle(isOn: $refine) {
                        Text(kind == .image ? "在上一张基础上修改" : "延续上一段画面")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(kind.capability.promptPlaceholder, text: $prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(action: run) {
                    HStack(spacing: 6) {
                        if state.isProcessing {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(runLabel)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(canRun ? AnyShapeStyle(Theme.brandGradient)
                                       : AnyShapeStyle(Color.gray.opacity(0.4)))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canRun)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
    }

    private func picker<T: Hashable & Identifiable>(_ label: String,
                                                    selection: Binding<T>,
                                                    options: [T],
                                                    title: @escaping (T) -> String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Picker("", selection: selection) {
                ForEach(options) { option in Text(title(option)).tag(option) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    private var runLabel: String {
        if state.isProcessing { return "生成中…" }
        return (session?.turns.isEmpty ?? true) ? "生成" : "继续生成"
    }

    private var canRun: Bool {
        !state.isProcessing && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func run() {
        guard canRun else { return }
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        prompt = ""
        Task {
            await state.runGeneration(kind: kind,
                                      prompt: text,
                                      refine: refine,
                                      imageSize: imageSize,
                                      videoSize: videoSize,
                                      duration: duration)
        }
    }
}

// MARK: - Turn row

private struct GenerationTurnRow: View {
    let turn: GenerationTurn
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Prompt bubble (right aligned)
            HStack {
                Spacer(minLength: 60)
                HStack(spacing: 6) {
                    if turn.refinedFromPrevious {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Text(turn.prompt)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: 460, alignment: .trailing)
            }

            // Result (left aligned)
            HStack {
                resultView
                Spacer(minLength: 40)
            }
        }
    }

    @ViewBuilder
    private var resultView: some View {
        switch turn.status {
        case .running:
            HStack(spacing: 12) {
                if let progress = state.processingProgress {
                    ProgressView(value: progress).progressViewStyle(.linear).tint(Theme.accent).frame(width: 160)
                } else {
                    ProgressView().controlSize(.small)
                }
                Text(state.processingStatusText ?? "正在生成…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(turn.errorMessage ?? "生成失败")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        case .succeeded:
            if let asset = state.asset(with: turn.resultAssetID) {
                VStack(alignment: .leading, spacing: 8) {
                    MediaPreview(asset: asset)
                        .frame(maxWidth: 380, maxHeight: 300)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    HStack(spacing: 8) {
                        Button {
                            let ext = (asset.fileName as NSString).pathExtension
                            FileActions.download(url: state.url(for: asset),
                                                 suggestedName: asset.displayName + "." + ext)
                        } label: {
                            Label("下载", systemImage: "arrow.down.circle").font(.system(size: 11))
                        }
                        ShareButton(items: [state.url(for: asset)], label: "分享")
                            .frame(width: 80, height: 26)
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            } else {
                Text("结果已删除").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}
