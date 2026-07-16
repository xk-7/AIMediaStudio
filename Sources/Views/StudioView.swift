import SwiftUI
import UniformTypeIdentifiers

/// The creation workbench: pick a capability, provide input + prompt, run the
/// AI, and preview / act on the result.
struct StudioView: View {
    @EnvironmentObject private var state: AppState

    @State private var capability: AICapability = .generateImage
    @State private var prompt: String = ""
    @State private var size: ImageSize = .square
    @State private var videoSize: VideoSize = .portrait
    @State private var duration: VideoDuration = .s4
    @State private var input: Asset?
    @State private var showingLibraryPicker = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                header
                capabilityGrid
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: 1200, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)

            switch capability {
            case .generateImage:
                GenerationStudioView(kind: .image)
            case .generateVideo:
                GenerationStudioView(kind: .video)
            default:
                singleShotContent
            }
        }
        .sheet(isPresented: $showingLibraryPicker) {
            AssetPickerSheet(kind: capability.inputKind ?? .image) { picked in
                input = picked
            }
            .environmentObject(state)
        }
    }

    private var singleShotContent: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                inputColumn
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                resultColumn
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(28)
            .frame(maxWidth: 1200)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.vividGradient)
            // Decorative glow
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 300, y: -40)

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("创作工作台")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("上传素材 · 调用 AI · 一键生成图片与视频")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                Spacer()
                Image(systemName: "wand.and.rays")
                    .font(.system(size: 46, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 26)
        }
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.32), radius: 18, y: 8)
    }

    // MARK: - Capability selection

    private var capabilityGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            ForEach(AICapability.allCases) { cap in
                CapabilityCard(capability: cap, isSelected: cap == capability) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        capability = cap
                        if cap.inputKind != input?.kind { input = nil }
                    }
                }
            }
        }
    }

    // MARK: - Input column

    private var inputColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("输入", systemImage: "square.and.arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if capability.requiresInput || capability.allowsOptionalImage {
                inputPicker
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(capability == .analyzeImage || capability == .analyzeVideo ? "提问 / 指令" : "提示词 Prompt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextEditor(text: $prompt)
                    .font(.system(size: 13))
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if prompt.isEmpty {
                            Text(capability.promptPlaceholder)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary.opacity(0.7))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
            }

            if capability.isVideoOutput {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("画面尺寸")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("", selection: $videoSize) {
                            ForEach(VideoSize.allCases) { s in Text(s.displayName).tag(s) }
                        }
                        .labelsHidden().pickerStyle(.menu)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("时长")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("", selection: $duration) {
                            ForEach(VideoDuration.allCases) { d in Text(d.displayName).tag(d) }
                        }
                        .labelsHidden().pickerStyle(.menu)
                    }
                    .frame(width: 110)
                }
            } else if capability.producesMedia {
                VStack(alignment: .leading, spacing: 8) {
                    Text("输出尺寸")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $size) {
                        ForEach(ImageSize.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            Button(action: run) {
                HStack(spacing: 8) {
                    if state.isProcessing {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(state.isProcessing ? "AI 处理中…" : "开始处理")
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: canRun))
            .disabled(!canRun)
        }
        .card(padding: 18)
    }

    private var inputPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let input {
                HStack(spacing: 12) {
                    AssetThumbnailView(asset: input)
                        .frame(width: 68, height: 68)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(input.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text("\(input.kind.displayName) · \(input.origin.displayName)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        self.input = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                DropZone(title: dropTitle,
                         subtitle: capability.allowsOptionalImage ? "可留空,纯文字生成视频" : "支持拖拽本地文件到此处",
                         systemImage: capability.allowsOptionalImage ? "photo" : (capability.inputKind?.systemImage ?? "doc"),
                         contentTypes: allowedTypes) { urls in
                    if let first = state.importFiles(urls).first {
                        input = first
                    }
                }
                Button {
                    showingLibraryPicker = true
                } label: {
                    Label("从素材库选择", systemImage: "square.grid.2x2")
                        .font(.system(size: 12))
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: - Result column

    private var resultColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("结果", systemImage: "wand.and.stars")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if let job = state.latestJob {
                ResultCard(job: job)
            } else {
                emptyResult
            }
        }
        .card(padding: 18)
    }

    private var emptyResult: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.brandGradient)
                .opacity(0.55)
            Text("结果会显示在这里")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("填写提示词后点击「开始处理」")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    // MARK: - Actions

    private var dropTitle: String {
        if capability.allowsOptionalImage { return "拖入参考图(可选)或点击选择" }
        return "拖入\(capability.inputKind?.displayName ?? "文件")或点击选择"
    }

    private var allowedTypes: [UTType] {
        if capability.allowsOptionalImage { return [.image] }
        switch capability.inputKind {
        case .image: return [.image]
        case .video: return [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        case .none: return [.image, .movie]
        }
    }

    private var canRun: Bool {
        guard !state.isProcessing else { return false }
        if capability.requiresInput && input == nil { return false }
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && capability != .analyzeImage && capability != .analyzeVideo {
            return false
        }
        return true
    }

    private func run() {
        let effectivePrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultPrompt()
            : prompt
        Task {
            await state.run(capability: capability,
                            prompt: effectivePrompt,
                            input: input,
                            size: size,
                            videoSize: videoSize,
                            duration: duration)
        }
    }

    private func defaultPrompt() -> String {
        switch capability {
        case .analyzeImage: return "请详细描述这张图片的内容、风格与主要元素。"
        case .analyzeVideo: return "请总结这段视频的主要内容与画面场景。"
        default: return prompt
        }
    }
}

// MARK: - Capability card

private struct CapabilityCard: View {
    let capability: AICapability
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: capability.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.brandGradient))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Color.white.opacity(0.22)) : AnyShapeStyle(Theme.accent.opacity(0.12)))
                    )
                Text(capability.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(capability.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(.regularMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Theme.hairline),
                                  lineWidth: 1)
            )
            .shadow(color: isSelected ? Theme.accent.opacity(0.35) : .black.opacity(hovering ? 0.12 : 0.06),
                    radius: isSelected ? 12 : 8, y: 4)
            .scaleEffect(hovering && !isSelected ? 1.015 : 1)
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
