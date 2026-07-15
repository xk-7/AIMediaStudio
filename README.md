# AI Media Studio

一个原生 macOS（SwiftUI）应用,把「图片 / 视频 AI 能力」接入本地工作流。用户可以上传图片/视频、调用 OpenAI 的 AI 能力、查看处理结果、下载、分享,并统一管理自己的素材。

![状态](https://img.shields.io/badge/platform-macOS%2014%2B-blue) ![语言](https://img.shields.io/badge/Swift-5-orange)

## 功能

| 需求 | 实现 |
| --- | --- |
| 上传图片 | 拖拽 / 文件选择器导入,进入素材库 |
| 上传视频 | 拖拽 / 文件选择器导入,自动生成缩略图 |
| 调用 AI 能力 | 文生图、**文生视频(Sora)**、图片编辑、图片理解、视频理解(抽帧) |
| 查看处理结果 | 工作台实时预览 + 「处理记录」历史 |
| 下载结果 | 保存面板导出到任意位置 |
| 分享结果 | 调用系统分享面板(NSSharingServicePicker) |
| 管理素材 | 素材库网格:筛选、搜索、重命名、删除、在访达显示、复制 |

### 五种 AI 能力

- **文生图**:输入提示词 → OpenAI `images/generations`(默认 `gpt-image-1`)。
- **文生视频**:提示词(可选参考图)→ OpenAI Sora `POST /videos` 异步任务 → 轮询 `GET /videos/{id}` → 下载 `GET /videos/{id}/content`(默认 `sora-2`,可选 `sora-2-pro`,时长 4/8/12 秒)。
- **图片编辑**:上传图片 + 提示词 → OpenAI `images/edits`。
- **图片理解**:上传图片 + 问题 → OpenAI `chat/completions` 视觉模型(默认 `gpt-4o`)。
- **视频理解**:上传视频 → 本地用 AVFoundation 抽取关键帧 → 交给视觉模型分析。

## 运行要求

- macOS 14.0+
- Xcode 16 / 26(项目用 Xcode 26.3 验证通过)
- 一个 OpenAI API Key

## 快速开始

### 方式一:Xcode(推荐)

```bash
cd AIMediaStudio
open AIMediaStudio.xcodeproj
```

在 Xcode 里选择 `AIMediaStudio` scheme,点击运行(⌘R)。

### 方式二:命令行构建

```bash
cd AIMediaStudio
xcodebuild -project AIMediaStudio.xcodeproj -scheme AIMediaStudio \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath ./.build CODE_SIGNING_ALLOWED=NO build

open ".build/Build/Products/Debug/AI Media Studio.app"
```

> 工程文件由 [XcodeGen](https://github.com/yonyz/XcodeGen) 从 `project.yml` 生成。修改 `project.yml` 后执行 `xcodegen generate` 重新生成。

### 配置接入(支持第三方)

首次启动后进入「设置 → 接入方式」,可选择:

- **OpenAI**:官方接口,支持全部四种能力。
- **OpenRouter**:第三方聚合网关,Key 形如 `sk-or-…`,模型名需带前缀(如 `openai/gpt-4o`)。文本/视觉能力兼容良好;图片生成/编辑取决于所选模型与网关支持情况。
- **自定义 / 兼容接口**:任意兼容 OpenAI 协议的接口,自行填写 Base URL(通常以 `/v1` 结尾)与模型名,即可对接自建网关或其他服务商。

API Key 只保存在本机钥匙串(Keychain),不会上传到任何服务器。切换到 OpenRouter 时会自动附带推荐的 `HTTP-Referer` / `X-Title` 请求头。

## 使用流程

1. 在「创作工作台」选择一种 AI 能力。
2. 需要输入的能力:拖入 / 选择本地文件,或「从素材库选择」。
3. 填写提示词 / 问题,(图片输出)选择尺寸。
4. 点击「开始处理」,右侧实时显示结果。
5. 对结果进行 **下载 / 分享**;生成的图片会自动进入素材库。
6. 「素材库」统一管理所有上传与生成的素材;「处理记录」可回看每一次调用。

## 项目结构

```
AIMediaStudio/
├── project.yml                 # XcodeGen 工程定义
├── Sources/
│   ├── App/                    # 入口、AppState、主题样式
│   ├── Models/                 # Asset / AIJob / AICapability
│   ├── Services/               # OpenAI 客户端、本地存储、Keychain、视频抽帧
│   └── Views/                  # 工作台 / 素材库 / 记录 / 设置 + 复用组件
└── README.md
```

## 数据与隐私

- 所有素材、生成结果与索引保存在:`~/Library/Application Support/AI Media Studio/`(设置里可一键打开)。
- API Key 存储于 macOS 钥匙串。
- 图片/视频仅在调用 AI 时上传给 OpenAI,其余操作全部在本地完成。

## 说明与后续可扩展

- 视频理解采用「本地抽取关键帧 → 视觉模型分析」的方案(OpenAI 标准 API 暂无通用视频生成)。后续可接入视频生成 / 语音转写(Whisper)等能力。
- 接入层(`OpenAIService` + `APIProvider`)面向「OpenAI 兼容协议」设计:内置 OpenAI / OpenRouter 预设,也支持任意自定义 Base URL 与额外请求头。
- 未启用 App Sandbox,便于本地读写与分享;如需上架 App Store 可再补充 entitlements。
