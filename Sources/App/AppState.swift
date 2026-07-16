import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Sidebar sections.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case studio
    case chat
    case library
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studio: return "创作工作台"
        case .chat: return "AI 对话"
        case .library: return "素材库"
        case .history: return "处理记录"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .studio: return "wand.and.rays"
        case .chat: return "bubble.left.and.bubble.right"
        case .library: return "square.grid.2x2"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

/// The single source of truth for the app: library contents, job history,
/// configuration and the orchestration of AI calls.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published state
    @Published var assets: [Asset] = []
    @Published var jobs: [AIJob] = []
    @Published var conversations: [Conversation] = []
    @Published var activeConversationID: UUID?
    @Published var isChatting: Bool = false

    @Published var generationSessions: [GenerationSession] = []
    @Published var activeImageSessionID: UUID?
    @Published var activeVideoSessionID: UUID?

    @Published var section: AppSection = .studio

    @Published var apiKey: String = ""
    @Published var visionModel: String = "gpt-4o"
    @Published var imageModel: String = "gpt-image-1"
    @Published var videoModel: String = "sora-2"
    @Published var provider: APIProvider = .openai
    @Published var baseURLString: String = "https://api.openai.com/v1"

    /// Models fetched from the provider's `/models` endpoint, for dropdown selection.
    @Published var availableModels: [String] = []
    @Published var isLoadingModels: Bool = false
    @Published var modelsError: String?

    /// The most recently completed / running job, surfaced in the Studio view.
    @Published var latestJob: AIJob?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    /// Progress (0...1) for long-running jobs such as video generation.
    @Published var processingProgress: Double?
    @Published var processingStatusText: String?

    private let store = AssetStore()
    private let apiKeyAccount = "openai-api-key"

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Init

    init() {
        apiKey = KeychainService.get(apiKeyAccount) ?? ""
        if let vm = UserDefaults.standard.string(forKey: "visionModel") { visionModel = vm }
        if let im = UserDefaults.standard.string(forKey: "imageModel") { imageModel = im }
        if let vdm = UserDefaults.standard.string(forKey: "videoModel") { videoModel = vdm }
        if let base = UserDefaults.standard.string(forKey: "baseURL"), !base.isEmpty {
            baseURLString = base
        }
        if let p = UserDefaults.standard.string(forKey: "provider"),
           let parsed = APIProvider(rawValue: p) {
            provider = parsed
        } else {
            provider = APIProvider.detect(from: baseURLString)
        }
        let index = store.loadIndex()
        assets = index.assets.sorted { $0.createdAt > $1.createdAt }
        jobs = index.jobs.sorted { $0.createdAt > $1.createdAt }
        conversations = index.conversations.sorted { $0.updatedAt > $1.updatedAt }
        generationSessions = index.generationSessions.sorted { $0.updatedAt > $1.updatedAt }
        activeImageSessionID = generationSessions.first { $0.kind == .image }?.id
        activeVideoSessionID = generationSessions.first { $0.kind == .video }?.id
    }

    // MARK: - Persistence

    private func persist() {
        store.saveIndex(.init(assets: assets,
                              jobs: jobs,
                              conversations: conversations,
                              generationSessions: generationSessions))
    }

    func saveAPIKey(_ key: String) {
        apiKey = key
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            KeychainService.delete(apiKeyAccount)
        } else {
            KeychainService.set(trimmed, for: apiKeyAccount)
        }
    }

    func saveModelSettings(vision: String, image: String) {
        visionModel = vision
        imageModel = image
        UserDefaults.standard.set(vision, forKey: "visionModel")
        UserDefaults.standard.set(image, forKey: "imageModel")
    }

    /// Persists the full connection configuration (provider + base URL + models).
    func saveConnection(provider: APIProvider,
                        baseURL: String,
                        vision: String,
                        image: String,
                        video: String) {
        self.provider = provider
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespaces)
        baseURLString = trimmedBase.isEmpty ? provider.defaultBaseURL : trimmedBase
        visionModel = vision.isEmpty ? provider.defaultVisionModel : vision
        imageModel = image.isEmpty ? provider.defaultImageModel : image
        videoModel = video.isEmpty ? provider.defaultVideoModel : video

        UserDefaults.standard.set(provider.rawValue, forKey: "provider")
        UserDefaults.standard.set(baseURLString, forKey: "baseURL")
        UserDefaults.standard.set(visionModel, forKey: "visionModel")
        UserDefaults.standard.set(imageModel, forKey: "imageModel")
        UserDefaults.standard.set(videoModel, forKey: "videoModel")
    }

    private var service: OpenAIService {
        let url = URL(string: baseURLString) ?? URL(string: "https://api.openai.com/v1")!
        return OpenAIService(apiKey: apiKey,
                             baseURL: url,
                             visionModel: visionModel,
                             imageModel: imageModel,
                             extraHeaders: APIProvider.extraHeaders(for: baseURLString))
    }

    /// Fetches the model list from the given key + base URL so the settings
    /// screen can offer a dropdown. Uses the drafts directly (no need to save first).
    func fetchModels(apiKey: String, baseURL: String) async {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            modelsError = "请先填写 API Key"
            return
        }
        isLoadingModels = true
        modelsError = nil
        defer { isLoadingModels = false }

        let trimmedBase = baseURL.trimmingCharacters(in: .whitespaces)
        let url = URL(string: trimmedBase.isEmpty ? "https://api.openai.com/v1" : trimmedBase)
            ?? URL(string: "https://api.openai.com/v1")!
        let svc = OpenAIService(apiKey: key,
                                baseURL: url,
                                extraHeaders: APIProvider.extraHeaders(for: trimmedBase))
        do {
            let models = try await svc.listModels()
            availableModels = models
            if models.isEmpty { modelsError = "未获取到模型列表" }
        } catch {
            availableModels = []
            modelsError = error.localizedDescription
        }
    }

    // MARK: - Library helpers

    func url(for asset: Asset) -> URL { store.url(for: asset) }

    func thumbnail(for asset: Asset) -> NSImage? { store.thumbnail(for: asset) }

    func asset(with id: UUID?) -> Asset? {
        guard let id else { return nil }
        return assets.first { $0.id == id }
    }

    /// Imports external files (from drag & drop or the open panel) into the library.
    @discardableResult
    func importFiles(_ urls: [URL]) -> [Asset] {
        var imported: [Asset] = []
        for url in urls {
            guard let kind = Self.assetKind(for: url) else { continue }
            do {
                let id = UUID()
                let fileName = try store.importFile(from: url, id: id)
                let asset = Asset(id: id,
                                  kind: kind,
                                  origin: .uploaded,
                                  fileName: fileName,
                                  displayName: url.deletingPathExtension().lastPathComponent)
                assets.insert(asset, at: 0)
                imported.append(asset)
            } catch {
                errorMessage = "导入失败:\(error.localizedDescription)"
            }
        }
        persist()
        return imported
    }

    func deleteAsset(_ asset: Asset) {
        store.deleteMedia(for: asset)
        assets.removeAll { $0.id == asset.id }
        persist()
    }

    func deleteJob(_ job: AIJob) {
        jobs.removeAll { $0.id == job.id }
        persist()
    }

    func renameAsset(_ asset: Asset, to name: String) {
        guard let idx = assets.firstIndex(where: { $0.id == asset.id }) else { return }
        assets[idx].displayName = name
        persist()
    }

    static func assetKind(for url: URL) -> AssetKind? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return nil
        }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        return nil
    }

    // MARK: - AI orchestration

    /// Runs a capability and records a job + any produced asset.
    func run(capability: AICapability,
             prompt: String,
             input: Asset?,
             size: ImageSize,
             videoSize: VideoSize = .portrait,
             duration: VideoDuration = .s4) async {
        guard isConfigured else {
            errorMessage = OpenAIError.missingAPIKey.errorDescription
            section = .settings
            return
        }

        var job = AIJob(capability: capability,
                        status: .running,
                        prompt: prompt,
                        inputAssetIDs: input.map { [$0.id] } ?? [])
        jobs.insert(job, at: 0)
        latestJob = job
        isProcessing = true
        errorMessage = nil
        processingProgress = nil
        processingStatusText = nil
        defer {
            isProcessing = false
            processingProgress = nil
            processingStatusText = nil
        }

        do {
            switch capability {
            case .generateImage:
                let data = try await service.generateImage(prompt: prompt, size: size)
                let resultAsset = try saveGeneratedMedia(data, ext: "png", kind: .image,
                                                         prompt: prompt,
                                                         capability: capability,
                                                         source: input)
                job.resultAssetID = resultAsset.id

            case .editImage:
                guard let input else { throw OpenAIError.api("请先选择要编辑的图片。") }
                let imageData = try Data(contentsOf: url(for: input))
                let data = try await service.editImage(imageData: imageData,
                                                       fileName: input.fileName,
                                                       prompt: prompt,
                                                       size: size)
                let resultAsset = try saveGeneratedMedia(data, ext: "png", kind: .image,
                                                         prompt: prompt,
                                                         capability: capability,
                                                         source: input)
                job.resultAssetID = resultAsset.id

            case .generateVideo:
                let data = try await generateVideo(prompt: prompt,
                                                   size: videoSize,
                                                   duration: duration,
                                                   reference: input)
                let resultAsset = try saveGeneratedMedia(data, ext: "mp4", kind: .video,
                                                         prompt: prompt,
                                                         capability: capability,
                                                         source: input)
                job.resultAssetID = resultAsset.id

            case .analyzeImage:
                guard let input else { throw OpenAIError.api("请先选择要分析的图片。") }
                let imageData = try Data(contentsOf: url(for: input))
                let text = try await service.analyzeImage(imageData: imageData,
                                                          fileName: input.fileName,
                                                          prompt: prompt)
                job.textResult = text

            case .analyzeVideo:
                guard let input else { throw OpenAIError.api("请先选择要分析的视频。") }
                let frames = try await VideoService.extractKeyframes(from: url(for: input))
                let text = try await service.analyzeFrames(frames, prompt: prompt)
                job.textResult = text
            }

            job.status = .succeeded
        } catch {
            job.status = .failed
            job.errorMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }

        updateJob(job)
        latestJob = job
    }

    /// Creates a Sora video job and polls until it completes, updating progress.
    private func generateVideo(prompt: String,
                               size: VideoSize,
                               duration: VideoDuration,
                               reference: Asset?) async throws -> Data {
        var referenceImage: (data: Data, fileName: String)?
        if let reference, reference.kind == .image {
            let data = try Data(contentsOf: url(for: reference))
            referenceImage = (data, reference.fileName)
        }
        return try await generateVideoData(prompt: prompt,
                                           size: size,
                                           duration: duration,
                                           referenceImage: referenceImage)
    }

    /// Lower-level video generation that accepts a raw reference image.
    private func generateVideoData(prompt: String,
                                   size: VideoSize,
                                   duration: VideoDuration,
                                   referenceImage: (data: Data, fileName: String)?) async throws -> Data {
        processingStatusText = "正在创建视频任务…"
        processingProgress = 0
        var status = try await service.createVideoJob(prompt: prompt,
                                                      model: videoModel,
                                                      seconds: duration.rawValue,
                                                      size: size.rawValue,
                                                      referenceImage: referenceImage)
        let jobID = status.id

        // Poll until completion.
        while status.status == "queued" || status.status == "in_progress" {
            processingProgress = status.progress / 100.0
            processingStatusText = status.status == "queued"
                ? "排队中…"
                : "生成中 \(Int(status.progress))%"
            try await Task.sleep(nanoseconds: 6_000_000_000)
            status = try await service.videoStatus(id: jobID)
        }

        guard status.status == "completed" else {
            throw OpenAIError.api(status.errorMessage ?? "视频生成失败。")
        }

        processingProgress = nil
        processingStatusText = "正在下载视频…"
        return try await service.downloadVideo(id: jobID)
    }

    private func saveGeneratedMedia(_ data: Data,
                                    ext: String,
                                    kind: AssetKind,
                                    prompt: String,
                                    capability: AICapability,
                                    source: Asset?) throws -> Asset {
        let id = UUID()
        let fileName = try store.writeMedia(data, ext: ext, id: id)
        let name = "AI · \(capability.title) · \(Self.shortTimestamp())"
        let asset = Asset(id: id,
                          kind: kind,
                          origin: .generated,
                          fileName: fileName,
                          displayName: name,
                          prompt: prompt,
                          sourceAssetID: source?.id,
                          capability: capability.rawValue)
        assets.insert(asset, at: 0)
        persist()
        return asset
    }

    // MARK: - Conversations (multi-turn chat)

    @discardableResult
    func newConversation() -> Conversation {
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
        activeConversationID = conversation.id
        persist()
        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if activeConversationID == conversation.id {
            activeConversationID = conversations.first?.id
        }
        persist()
    }

    func renameConversation(_ id: UUID, to title: String) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].title = title.isEmpty ? "新对话" : title
        persist()
    }

    var activeConversation: Conversation? {
        conversations.first { $0.id == activeConversationID }
    }

    /// Appends a user message (with optional image attachments) and streams back
    /// the assistant's reply, keeping the full conversation context.
    func sendChatMessage(conversationID: UUID, text: String, attachments: [Asset]) async {
        guard isConfigured else {
            errorMessage = OpenAIError.missingAPIKey.errorDescription
            section = .settings
            return
        }
        guard let idx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }

        let userMessage = ChatMessage(role: .user,
                                      text: text,
                                      imageAssetIDs: attachments.map { $0.id })
        conversations[idx].messages.append(userMessage)
        conversations[idx].updatedAt = Date()
        // Auto-title from the first user message.
        if conversations[idx].title == "新对话",
           !text.trimmingCharacters(in: .whitespaces).isEmpty {
            conversations[idx].title = String(text.prefix(24))
        }
        moveConversationToTop(conversationID)
        persist()

        isChatting = true
        errorMessage = nil
        defer { isChatting = false }

        // Build the full turn history for the request.
        guard let current = conversations.first(where: { $0.id == conversationID }) else { return }
        var turns: [OpenAIService.ChatTurn] = []
        for message in current.messages {
            var images: [OpenAIService.ChatImage] = []
            for assetID in message.imageAssetIDs {
                if let asset = asset(with: assetID),
                   let data = try? Data(contentsOf: url(for: asset)) {
                    images.append(.init(data: data,
                                        mime: OpenAIService.mimeType(forFileName: asset.fileName)))
                }
            }
            turns.append(.init(role: message.role.rawValue, text: message.text, images: images))
        }

        do {
            let reply = try await service.chat(turns: turns)
            appendAssistantMessage(reply, to: conversationID, isError: false)
        } catch {
            errorMessage = error.localizedDescription
            appendAssistantMessage(error.localizedDescription, to: conversationID, isError: true)
        }
    }

    private func appendAssistantMessage(_ text: String, to conversationID: UUID, isError: Bool) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[idx].messages.append(ChatMessage(role: .assistant, text: text, isError: isError))
        conversations[idx].updatedAt = Date()
        persist()
    }

    private func moveConversationToTop(_ id: UUID) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }), idx != 0 else { return }
        let conversation = conversations.remove(at: idx)
        conversations.insert(conversation, at: 0)
    }

    // MARK: - Generation sessions (iterative text-to-image / text-to-video)

    func sessions(of kind: GenerationKind) -> [GenerationSession] {
        generationSessions.filter { $0.kind == kind }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func activeSessionID(for kind: GenerationKind) -> UUID? {
        kind == .image ? activeImageSessionID : activeVideoSessionID
    }

    func setActiveSession(_ id: UUID?, for kind: GenerationKind) {
        if kind == .image { activeImageSessionID = id } else { activeVideoSessionID = id }
    }

    func activeGenerationSession(for kind: GenerationKind) -> GenerationSession? {
        generationSessions.first { $0.id == activeSessionID(for: kind) }
    }

    @discardableResult
    func newGenerationSession(_ kind: GenerationKind) -> GenerationSession {
        let session = GenerationSession(kind: kind)
        generationSessions.insert(session, at: 0)
        setActiveSession(session.id, for: kind)
        persist()
        return session
    }

    func deleteGenerationSession(_ session: GenerationSession) {
        generationSessions.removeAll { $0.id == session.id }
        if activeSessionID(for: session.kind) == session.id {
            setActiveSession(sessions(of: session.kind).first?.id, for: session.kind)
        }
        persist()
    }

    func lastSuccessfulAsset(in session: GenerationSession) -> Asset? {
        for turn in session.turns.reversed() where turn.status == .succeeded {
            if let asset = asset(with: turn.resultAssetID) { return asset }
        }
        return nil
    }

    /// Runs a generation turn inside a session, optionally iterating on the
    /// previous result (image edit / video visual continuity).
    func runGeneration(kind: GenerationKind,
                       prompt: String,
                       refine: Bool,
                       imageSize: ImageSize,
                       videoSize: VideoSize,
                       duration: VideoDuration) async {
        guard isConfigured else {
            errorMessage = OpenAIError.missingAPIKey.errorDescription
            section = .settings
            return
        }

        // Ensure there is an active session for this kind.
        let sessionID: UUID
        if let existing = activeGenerationSession(for: kind) {
            sessionID = existing.id
        } else {
            sessionID = newGenerationSession(kind).id
        }

        let previous = activeGenerationSession(for: kind).flatMap { lastSuccessfulAsset(in: $0) }
        let willRefine = refine && previous != nil

        var turn = GenerationTurn(prompt: prompt, status: .running, refinedFromPrevious: willRefine)
        appendTurn(turn, toSessionID: sessionID, prompt: prompt)

        isProcessing = true
        errorMessage = nil
        processingProgress = nil
        processingStatusText = nil
        defer {
            isProcessing = false
            processingProgress = nil
            processingStatusText = nil
        }

        let capability = kind.capability
        var job = AIJob(capability: capability, status: .running, prompt: prompt,
                        inputAssetIDs: previous.map { [$0.id] } ?? [])
        jobs.insert(job, at: 0)

        do {
            let resultAsset: Asset
            switch kind {
            case .image:
                let data: Data
                if willRefine, let previous {
                    let imageData = try Data(contentsOf: url(for: previous))
                    data = try await service.editImage(imageData: imageData,
                                                       fileName: previous.fileName,
                                                       prompt: prompt,
                                                       size: imageSize)
                } else {
                    data = try await service.generateImage(prompt: prompt, size: imageSize)
                }
                resultAsset = try saveGeneratedMedia(data, ext: "png", kind: .image,
                                                     prompt: prompt, capability: capability,
                                                     source: previous)

            case .video:
                var reference: (data: Data, fileName: String)?
                if willRefine, let previous, previous.kind == .video {
                    processingStatusText = "正在提取上一段视频的画面…"
                    let frame = try await VideoService.lastFrame(from: url(for: previous))
                    reference = (frame, "last_frame.jpg")
                }
                let data = try await generateVideoData(prompt: prompt,
                                                       size: videoSize,
                                                       duration: duration,
                                                       referenceImage: reference)
                resultAsset = try saveGeneratedMedia(data, ext: "mp4", kind: .video,
                                                     prompt: prompt, capability: capability,
                                                     source: previous)
            }

            turn.status = .succeeded
            turn.resultAssetID = resultAsset.id
            job.status = .succeeded
            job.resultAssetID = resultAsset.id
        } catch {
            turn.status = .failed
            turn.errorMessage = error.localizedDescription
            job.status = .failed
            job.errorMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }

        updateTurn(turn, inSessionID: sessionID)
        updateJob(job)
    }

    private func appendTurn(_ turn: GenerationTurn, toSessionID id: UUID, prompt: String) {
        guard let idx = generationSessions.firstIndex(where: { $0.id == id }) else { return }
        generationSessions[idx].turns.append(turn)
        generationSessions[idx].updatedAt = Date()
        if generationSessions[idx].title == "新创作",
           !prompt.trimmingCharacters(in: .whitespaces).isEmpty {
            generationSessions[idx].title = String(prompt.prefix(24))
        }
        moveSessionToTop(id)
        persist()
    }

    private func updateTurn(_ turn: GenerationTurn, inSessionID id: UUID) {
        guard let sIdx = generationSessions.firstIndex(where: { $0.id == id }),
              let tIdx = generationSessions[sIdx].turns.firstIndex(where: { $0.id == turn.id }) else { return }
        generationSessions[sIdx].turns[tIdx] = turn
        generationSessions[sIdx].updatedAt = Date()
        persist()
    }

    private func moveSessionToTop(_ id: UUID) {
        guard let idx = generationSessions.firstIndex(where: { $0.id == id }), idx != 0 else { return }
        let session = generationSessions.remove(at: idx)
        generationSessions.insert(session, at: 0)
    }

    private func updateJob(_ job: AIJob) {
        if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[idx] = job
        }
        persist()
    }

    private static func shortTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: Date())
    }
}
