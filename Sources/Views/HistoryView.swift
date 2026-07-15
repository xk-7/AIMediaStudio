import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var state: AppState
    @State private var selected: AIJob?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    GradientTitle(text: "处理记录", size: 22)
                    Text("\(state.jobs.count) 条 AI 处理记录")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            Divider()

            if state.jobs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(Theme.brandGradient)
                        .opacity(0.55)
                    Text("暂无处理记录")
                        .font(.system(size: 15, weight: .semibold))
                    Text("在创作工作台运行 AI 任务后,记录会出现在这里")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(state.jobs) { job in
                            JobRow(job: job) { selected = job }
                                .environmentObject(state)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .sheet(item: $selected) { job in
            JobDetailSheet(job: job).environmentObject(state)
        }
    }
}

private struct JobRow: View {
    let job: AIJob
    let onOpen: () -> Void
    @EnvironmentObject private var state: AppState
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 14) {
            thumb
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: job.capability.systemImage)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.brandGradient)
                    Text(job.capability.title)
                        .font(.system(size: 13, weight: .semibold))
                    StatusPill(status: job.status)
                }
                Text(previewText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(job.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.8))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(hovering ? 0.12 : 0.05), radius: hovering ? 10 : 6, y: 3)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("查看详情", action: onOpen)
            Button("删除记录", role: .destructive) { state.deleteJob(job) }
        }
    }

    @ViewBuilder
    private var thumb: some View {
        if let asset = state.asset(with: job.resultAssetID) {
            AssetThumbnailView(asset: asset)
        } else if let input = job.inputAssetIDs.first, let asset = state.asset(with: input) {
            AssetThumbnailView(asset: asset)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.1))
                Image(systemName: job.capability.systemImage)
                    .foregroundStyle(Theme.brandGradient)
            }
        }
    }

    private var previewText: String {
        if job.status == .failed { return job.errorMessage ?? "处理失败" }
        if let text = job.textResult { return text }
        return job.prompt ?? "—"
    }
}

private struct JobDetailSheet: View {
    let job: AIJob
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("处理详情")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let prompt = job.prompt, !prompt.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("提示词 / 指令")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(prompt)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                        }
                    }
                    ResultCard(job: job)
                }
                .padding(18)
            }
        }
        .frame(width: 640, height: 620)
    }
}
