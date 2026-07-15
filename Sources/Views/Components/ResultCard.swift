import SwiftUI

/// Displays the outcome of an AI job: media preview or text, plus actions to
/// download, share and manage the result.
struct ResultCard: View {
    let job: AIJob
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusBadge

            switch job.status {
            case .running:
                runningView
            case .failed:
                failedView
            case .succeeded:
                succeededView
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: job.capability.systemImage)
                .foregroundStyle(Theme.brandGradient)
            Text(job.capability.title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            StatusPill(status: job.status)
        }
    }

    private var runningView: some View {
        VStack(spacing: 14) {
            if let progress = state.processingProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .frame(maxWidth: 240)
            } else {
                ProgressView()
            }
            Text(state.processingStatusText ?? "正在调用 AI,请稍候…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if job.capability.isVideoOutput {
                Text("视频生成通常需要 30 秒 ~ 数分钟,请保持应用打开。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var failedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(job.errorMessage ?? "处理失败")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    @ViewBuilder
    private var succeededView: some View {
        if let asset = state.asset(with: job.resultAssetID) {
            VStack(alignment: .leading, spacing: 12) {
                MediaPreview(asset: asset)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                actionBar(for: asset)
            }
        } else if let text = job.textResult {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView {
                    Text(text)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 10) {
                    Button {
                        FileActions.copyText(text)
                    } label: {
                        Label("复制文本", systemImage: "doc.on.doc")
                    }
                    ShareButton(items: [text], label: "分享")
                        .frame(width: 92, height: 30)
                }
            }
        } else {
            Text("没有可显示的结果")
                .foregroundStyle(.secondary)
        }
    }

    private func actionBar(for asset: Asset) -> some View {
        HStack(spacing: 10) {
            Button {
                let ext = (asset.fileName as NSString).pathExtension
                FileActions.download(url: state.url(for: asset),
                                     suggestedName: asset.displayName + "." + ext)
            } label: {
                Label("下载", systemImage: "arrow.down.circle")
            }
            Button {
                state.section = .library
            } label: {
                Label("到素材库", systemImage: "square.grid.2x2")
            }
            Spacer()
            ShareButton(items: [state.url(for: asset)], label: "分享")
                .frame(width: 92, height: 30)
        }
    }
}

/// A coloured status pill.
struct StatusPill: View {
    let status: JobStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(status.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.14))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .orange
        }
    }
}
