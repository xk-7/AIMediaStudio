import SwiftUI

struct AssetDetailView: View {
    let asset: Asset
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(alignment: .top, spacing: 0) {
                MediaPreview(asset: asset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.04))
                Divider()
                sidebar
                    .frame(width: 280)
            }
        }
        .frame(width: 900, height: 600)
        .onAppear { name = asset.displayName }
        .confirmationDialog("确定删除该素材?", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                state.deleteAsset(asset)
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack {
            Text(asset.displayName)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("名称") {
                    TextField("名称", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { state.renameAsset(asset, to: name) }
                }

                section("信息") {
                    infoRow("类型", asset.kind.displayName)
                    infoRow("来源", asset.origin.displayName)
                    infoRow("创建时间",
                            asset.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let cap = asset.capability,
                       let capability = AICapability(rawValue: cap) {
                        infoRow("AI 能力", capability.title)
                    }
                }

                if let prompt = asset.prompt, !prompt.isEmpty {
                    section("提示词") {
                        Text(prompt)
                            .font(.system(size: 12))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                actions
            }
            .padding(16)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                FileActions.download(url: state.url(for: asset),
                                     suggestedName: name + "." + (asset.fileName as NSString).pathExtension)
            } label: {
                Label("下载到本地", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            ShareButton(items: [state.url(for: asset)], label: "分享")
                .frame(height: 32)

            Button {
                FileActions.reveal(url: state.url(for: asset))
            } label: {
                Label("在访达中显示", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除素材", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(.top, 4)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
    }
}
