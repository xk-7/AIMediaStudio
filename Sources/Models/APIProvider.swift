import Foundation

/// A preset for an OpenAI-compatible API provider. The app talks to any
/// endpoint that follows the OpenAI REST shape (`/chat/completions`,
/// `/images/generations`, ...), so third-party gateways such as OpenRouter or a
/// self-hosted proxy work by simply pointing the Base URL at them.
enum APIProvider: String, CaseIterable, Identifiable, Codable {
    case openai
    case openrouter
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .custom: return "自定义 / 兼容接口"
        }
    }

    /// Default Base URL for the provider (empty for custom).
    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .custom: return ""
        }
    }

    var defaultVisionModel: String {
        switch self {
        case .openai: return "gpt-4o"
        case .openrouter: return "openai/gpt-4o"
        case .custom: return "gpt-4o"
        }
    }

    var defaultImageModel: String {
        switch self {
        case .openai: return "gpt-image-1"
        case .openrouter: return "openai/gpt-image-1"
        case .custom: return "gpt-image-1"
        }
    }

    var defaultVideoModel: String {
        switch self {
        case .openai: return "sora-2"
        case .openrouter: return "sora-2"
        case .custom: return "sora-2"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openai: return "sk-…"
        case .openrouter: return "sk-or-…"
        case .custom: return "你的 API Key"
        }
    }

    var helpURL: URL? {
        switch self {
        case .openai: return URL(string: "https://platform.openai.com/api-keys")
        case .openrouter: return URL(string: "https://openrouter.ai/keys")
        case .custom: return nil
        }
    }

    var note: String? {
        switch self {
        case .openai:
            return "官方接口,支持全部四种能力。"
        case .openrouter:
            return "第三方聚合网关。文本/视觉类能力兼容良好;图片生成/编辑取决于所选模型与网关支持情况。模型名需带前缀,如 openai/gpt-4o。"
        case .custom:
            return "任意兼容 OpenAI 协议的接口。填写 Base URL(通常以 /v1 结尾)与模型名即可。"
        }
    }

    /// Provider-specific extra HTTP headers for a given base URL.
    static func extraHeaders(for baseURL: String) -> [String: String] {
        if baseURL.contains("openrouter.ai") {
            // OpenRouter recommends these for attribution / ranking (optional).
            return [
                "HTTP-Referer": "https://ai-media-studio.local",
                "X-Title": "AI Media Studio"
            ]
        }
        return [:]
    }

    /// Best-effort detection of a provider from a base URL.
    static func detect(from baseURL: String) -> APIProvider {
        if baseURL.contains("openrouter.ai") { return .openrouter }
        if baseURL.contains("api.openai.com") { return .openai }
        return .custom
    }
}
