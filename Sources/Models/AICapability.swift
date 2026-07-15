import Foundation

/// The AI capabilities exposed by the app. Each maps onto one or more OpenAI
/// (or OpenAI-compatible) endpoints in `OpenAIService`.
enum AICapability: String, CaseIterable, Codable, Identifiable {
    case generateImage
    case generateVideo
    case editImage
    case analyzeImage
    case analyzeVideo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generateImage: return "文生图"
        case .generateVideo: return "文生视频"
        case .editImage: return "图片编辑"
        case .analyzeImage: return "图片理解"
        case .analyzeVideo: return "视频理解"
        }
    }

    var subtitle: String {
        switch self {
        case .generateImage: return "用一句话描述,生成全新图片"
        case .generateVideo: return "用文字生成视频,可选参考图(Sora)"
        case .editImage: return "上传图片 + 提示词,进行 AI 改写重绘"
        case .analyzeImage: return "让 AI 描述、分析、提取图片内容"
        case .analyzeVideo: return "抽取关键帧,让 AI 理解视频内容"
        }
    }

    var systemImage: String {
        switch self {
        case .generateImage: return "sparkles"
        case .generateVideo: return "film.stack"
        case .editImage: return "wand.and.stars"
        case .analyzeImage: return "text.viewfinder"
        case .analyzeVideo: return "eye"
        }
    }

    /// Whether this capability requires an input asset to be provided.
    var requiresInput: Bool {
        switch self {
        case .generateImage, .generateVideo: return false
        case .editImage, .analyzeImage, .analyzeVideo: return true
        }
    }

    /// The kind of input asset required (if any).
    var inputKind: AssetKind? {
        switch self {
        case .generateImage, .generateVideo: return nil
        case .editImage, .analyzeImage: return .image
        case .analyzeVideo: return .video
        }
    }

    /// Whether an optional image can be attached (e.g. image-to-video reference).
    var allowsOptionalImage: Bool {
        self == .generateVideo
    }

    /// Whether the result is a media asset (true) or plain text (false).
    var producesMedia: Bool {
        switch self {
        case .generateImage, .generateVideo, .editImage: return true
        case .analyzeImage, .analyzeVideo: return false
        }
    }

    /// The kind of media produced (nil for text results).
    var outputKind: AssetKind? {
        switch self {
        case .generateImage, .editImage: return .image
        case .generateVideo: return .video
        case .analyzeImage, .analyzeVideo: return nil
        }
    }

    var isVideoOutput: Bool { outputKind == .video }

    /// A sensible default prompt shown as a placeholder in the UI.
    var promptPlaceholder: String {
        switch self {
        case .generateImage: return "例如:赛博朋克风格的城市夜景,霓虹灯,雨天,电影质感"
        case .generateVideo: return "例如:一只柯基在海边奔跑,阳光洒在浪花上,慢镜头,电影感"
        case .editImage: return "例如:把背景换成日落海滩,保留人物"
        case .analyzeImage: return "例如:描述这张图片,并列出主要物体和风格"
        case .analyzeVideo: return "例如:这段视频讲了什么?总结主要画面和场景"
        }
    }
}

/// Supported output image sizes for generation / editing.
enum ImageSize: String, CaseIterable, Identifiable, Codable {
    case square = "1024x1024"
    case portrait = "1024x1536"
    case landscape = "1536x1024"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .square: return "正方形 1024×1024"
        case .portrait: return "竖版 1024×1536"
        case .landscape: return "横版 1536×1024"
        }
    }
}

/// Supported Sora video output sizes.
enum VideoSize: String, CaseIterable, Identifiable, Codable {
    case portrait = "720x1280"
    case landscape = "1280x720"
    case portraitHD = "1024x1792"
    case landscapeHD = "1792x1024"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .portrait: return "竖版 720×1280"
        case .landscape: return "横版 1280×720"
        case .portraitHD: return "竖版高清 1024×1792"
        case .landscapeHD: return "横版高清 1792×1024"
        }
    }
}

/// Supported Sora clip durations (seconds).
enum VideoDuration: String, CaseIterable, Identifiable, Codable {
    case s4 = "4"
    case s8 = "8"
    case s12 = "12"

    var id: String { rawValue }
    var displayName: String { "\(rawValue) 秒" }
}
