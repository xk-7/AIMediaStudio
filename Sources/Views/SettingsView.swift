import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var keyDraft: String = ""
    @State private var providerDraft: APIProvider = .openai
    @State private var baseURLDraft: String = ""
    @State private var visionDraft: String = ""
    @State private var imageDraft: String = ""
    @State private var videoDraft: String = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    GradientTitle(text: "设置")
                    Text("配置 AI 接入(支持 OpenAI / OpenRouter 等兼容接口)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                connectionCard
                storageCard
                aboutCard
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .onAppear {
            keyDraft = state.apiKey
            providerDraft = state.provider
            baseURLDraft = state.baseURLString
            visionDraft = state.visionModel
            imageDraft = state.imageModel
            videoDraft = state.videoModel
            if state.isConfigured && state.availableModels.isEmpty {
                fetchModels()
            }
        }
    }

    // MARK: - Connection card

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("接入设置", systemImage: "network")
                .font(.system(size: 14, weight: .semibold))

            Picker("", selection: $providerDraft) {
                ForEach(APIProvider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: providerDraft) { _, newValue in
                if newValue != .custom {
                    baseURLDraft = newValue.defaultBaseURL
                    visionDraft = newValue.defaultVisionModel
                    imageDraft = newValue.defaultImageModel
                    videoDraft = newValue.defaultVideoModel
                }
                state.availableModels = []
                state.modelsError = nil
            }

            if let note = providerDraft.note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            fieldRow("Base URL") {
                TextField("https://api.openai.com/v1", text: $baseURLDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .disabled(providerDraft != .custom)
                    .opacity(providerDraft != .custom ? 0.7 : 1)
            }

            Divider().padding(.vertical, 2)

            // Step 1: API Key
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    stepBadge(1)
                    Text("填写 API Key")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if let help = providerDraft.helpURL {
                        Link("获取 Key", destination: help)
                            .font(.system(size: 11))
                    }
                }
                SecureField(providerDraft.keyPlaceholder, text: $keyDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                Text("Key 仅保存在本机钥匙串(Keychain),不会上传到任何服务器。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Step 2: fetch + choose models
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    stepBadge(2)
                    Text("选择模型")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button(action: fetchModels) {
                        HStack(spacing: 5) {
                            if state.isLoadingModels {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(state.availableModels.isEmpty ? "获取模型" : "刷新模型")
                        }
                        .font(.system(size: 12))
                    }
                    .disabled(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty || state.isLoadingModels)
                }

                if let err = state.modelsError {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                } else if !state.availableModels.isEmpty {
                    Text("已获取 \(state.availableModels.count) 个模型,可从下拉选择或直接输入。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("填写 API Key 后点击「获取模型」,即可下拉选择。也可手动输入模型名。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                fieldRow("图像模型") {
                    ComboBoxField(text: $imageDraft,
                                  items: state.availableModels,
                                  placeholder: "gpt-image-1")
                        .frame(height: 24)
                }
                fieldRow("视觉模型") {
                    ComboBoxField(text: $visionDraft,
                                  items: state.availableModels,
                                  placeholder: "gpt-4o")
                        .frame(height: 24)
                }
                fieldRow("视频模型") {
                    ComboBoxField(text: $videoDraft,
                                  items: state.availableModels,
                                  placeholder: "sora-2")
                        .frame(height: 24)
                }
                Text("图像模型用于「文生图 / 图片编辑」,视觉模型用于「图片理解 / 视频理解」,视频模型用于「文生视频」(如 sora-2 / sora-2-pro)。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 2)

            HStack {
                Button("保存全部设置") {
                    state.saveAPIKey(keyDraft)
                    state.saveConnection(provider: providerDraft,
                                         baseURL: baseURLDraft,
                                         vision: visionDraft,
                                         image: imageDraft,
                                         video: videoDraft)
                    baseURLDraft = state.baseURLString
                    visionDraft = state.visionModel
                    imageDraft = state.imageModel
                    videoDraft = state.videoModel
                    flashSaved()
                }
                .buttonStyle(.borderedProminent)

                if saved {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                }
                Spacer()
            }
        }
        .card(padding: 20)
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("本地存储", systemImage: "internaldrive")
                .font(.system(size: 14, weight: .semibold))
            Text("所有素材与结果均保存在本机应用支持目录,可随时在访达查看或备份。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("打开存储目录") {
                let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                       in: .userDomainMask).first!
                let url = support.appendingPathComponent("AI Media Studio")
                FileActions.reveal(url: url)
            }
        }
        .card(padding: 20)
    }

    private var aboutCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.vividGradient)
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: "sparkles").foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Media Studio")
                    .font(.system(size: 14, weight: .semibold))
                Text("版本 1.0.0 · 图片 / 视频 AI 工作台")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card(padding: 18)
    }

    // MARK: - Helpers

    private func fetchModels() {
        state.saveAPIKey(keyDraft)
        Task { await state.fetchModels(apiKey: keyDraft, baseURL: baseURLDraft) }
    }

    private func stepBadge(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Theme.brandGradient)
            .clipShape(Circle())
    }

    private func fieldRow<Content: View>(_ label: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .frame(width: 90, alignment: .leading)
            content()
        }
    }

    private func flashSaved() {
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { saved = false }
        }
    }
}
