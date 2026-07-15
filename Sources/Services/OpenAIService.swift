import Foundation

/// Errors surfaced from the OpenAI API layer.
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case api(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "尚未配置 API Key,请到「设置」中填写 OpenAI API Key。"
        case .invalidResponse:
            return "服务器返回了无法识别的响应。"
        case .api(let message):
            return message
        case .decoding:
            return "解析 API 返回数据失败。"
        }
    }
}

/// A thin async client for the OpenAI image + vision endpoints used by the app.
struct OpenAIService {
    var apiKey: String
    var baseURL: URL
    var visionModel: String
    var imageModel: String
    /// Provider-specific extra headers (e.g. OpenRouter attribution headers).
    var extraHeaders: [String: String]

    init(apiKey: String,
         baseURL: URL = URL(string: "https://api.openai.com/v1")!,
         visionModel: String = "gpt-4o",
         imageModel: String = "gpt-image-1",
         extraHeaders: [String: String] = [:]) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.visionModel = visionModel
        self.imageModel = imageModel
        self.extraHeaders = extraHeaders
    }

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Text -> image. Returns raw PNG data of the first generated image.
    func generateImage(prompt: String, size: ImageSize) async throws -> Data {
        try requireKey()
        let url = baseURL.appendingPathComponent("images/generations")
        let body: [String: Any] = [
            "model": imageModel,
            "prompt": prompt,
            "size": size.rawValue,
            "n": 1
        ]
        var request = jsonRequest(url: url)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request)
        return try firstImageData(from: data)
    }

    /// Image(s) + prompt -> edited image. Returns raw PNG data.
    func editImage(imageData: Data,
                   fileName: String,
                   prompt: String,
                   size: ImageSize) async throws -> Data {
        try requireKey()
        let url = baseURL.appendingPathComponent("images/edits")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        applyExtraHeaders(to: &request)

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        appendField("model", imageModel)
        appendField("prompt", prompt)
        appendField("size", size.rawValue)
        appendField("n", "1")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType(for: fileName))\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let data = try await send(request)
        return try firstImageData(from: data)
    }

    /// Image -> text description / analysis.
    func analyzeImage(imageData: Data,
                      fileName: String,
                      prompt: String) async throws -> String {
        try requireKey()
        let dataURL = "data:\(mimeType(for: fileName));base64,\(imageData.base64EncodedString())"
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": dataURL]]
        ]
        return try await chat(content: content)
    }

    // MARK: - Video generation (Sora)

    struct VideoJobStatus {
        var id: String
        var status: String          // queued | in_progress | completed | failed
        var progress: Double        // 0...100
        var errorMessage: String?
    }

    /// Creates a Sora video generation job. Optionally guided by a reference image.
    func createVideoJob(prompt: String,
                        model: String,
                        seconds: String,
                        size: String,
                        referenceImage: (data: Data, fileName: String)?) async throws -> VideoJobStatus {
        try requireKey()
        let url = baseURL.appendingPathComponent("videos")
        var body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "seconds": seconds,
            "size": size
        ]
        if let ref = referenceImage {
            let dataURL = "data:\(mimeType(for: ref.fileName));base64,\(ref.data.base64EncodedString())"
            body["input_reference"] = ["image_url": dataURL]
        }
        var request = jsonRequest(url: url)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request)
        return try parseVideoStatus(data)
    }

    /// Retrieves the current status of a video job.
    func videoStatus(id: String) async throws -> VideoJobStatus {
        try requireKey()
        let url = baseURL.appendingPathComponent("videos/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        applyExtraHeaders(to: &request)
        let data = try await send(request)
        return try parseVideoStatus(data)
    }

    /// Downloads the finished MP4 bytes for a completed video job.
    func downloadVideo(id: String) async throws -> Data {
        try requireKey()
        let url = baseURL.appendingPathComponent("videos/\(id)/content")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        applyExtraHeaders(to: &request)
        return try await send(request)
    }

    private func parseVideoStatus(_ data: Data) throws -> VideoJobStatus {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String,
              let status = json["status"] as? String else {
            throw OpenAIError.decoding
        }
        let progress = (json["progress"] as? NSNumber)?.doubleValue ?? 0
        var errorMessage: String?
        if let error = json["error"] as? [String: Any] {
            errorMessage = error["message"] as? String
        }
        return VideoJobStatus(id: id, status: status, progress: progress, errorMessage: errorMessage)
    }

    /// Multiple video keyframes -> text understanding of the clip.
    func analyzeFrames(_ frames: [Data], prompt: String) async throws -> String {
        try requireKey()
        var content: [[String: Any]] = [
            ["type": "text",
             "text": prompt + "\n\n以下是从这段视频里按时间顺序抽取的若干关键帧,请结合它们进行分析。"]
        ]
        for frame in frames {
            let dataURL = "data:image/jpeg;base64,\(frame.base64EncodedString())"
            content.append(["type": "image_url", "image_url": ["url": dataURL]])
        }
        return try await chat(content: content)
    }

    /// Fetches the list of model ids available for this key / endpoint.
    /// Works with any OpenAI-compatible `GET /models` response.
    func listModels() async throws -> [String] {
        try requireKey()
        let url = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        applyExtraHeaders(to: &request)
        let data = try await send(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else {
            throw OpenAIError.decoding
        }
        let ids = items.compactMap { $0["id"] as? String }
        return Array(Set(ids)).sorted()
    }

    // MARK: - Chat helper

    private func chat(content: [[String: Any]]) async throws -> String {
        let url = baseURL.appendingPathComponent("chat/completions")
        let body: [String: Any] = [
            "model": visionModel,
            "messages": [["role": "user", "content": content]],
            "max_tokens": 1000
        ]
        var request = jsonRequest(url: url)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw OpenAIError.decoding
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Networking primitives

    private func jsonRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyExtraHeaders(to: &request)
        return request
    }

    private func applyExtraHeaders(to request: inout URLRequest) {
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenAIError.api(Self.errorMessage(from: data, status: http.statusCode))
        }
        return data
    }

    private func firstImageData(from data: Data) throws -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]],
              let first = items.first else {
            throw OpenAIError.decoding
        }
        if let b64 = first["b64_json"] as? String, let imageData = Data(base64Encoded: b64) {
            return imageData
        }
        // Some models / configurations return a URL instead of base64.
        if let urlString = first["url"] as? String, let url = URL(string: urlString),
           let imageData = try? Data(contentsOf: url) {
            return imageData
        }
        throw OpenAIError.decoding
    }

    private func requireKey() throws {
        if apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            throw OpenAIError.missingAPIKey
        }
    }

    private func mimeType(for fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "image/png"
        }
    }

    private static func errorMessage(from data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return "OpenAI 错误(\(status)):\(message)"
        }
        return "请求失败,HTTP 状态码 \(status)。"
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
