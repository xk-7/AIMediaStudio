import SwiftUI

/// A modal sheet that lets the user pick an existing asset of a given kind from
/// their library to use as AI input.
struct AssetPickerSheet: View {
    let kind: AssetKind
    let onSelect: (Asset) -> Void

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var items: [Asset] {
        state.assets.filter { $0.kind == kind }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("从素材库选择\(kind.displayName)")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding(16)
            Divider()

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("素材库暂无\(kind.displayName),请先在工作台上传。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)],
                              spacing: 12) {
                        ForEach(items) { asset in
                            Button {
                                onSelect(asset)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AssetThumbnailView(asset: asset)
                                        .frame(height: 110)
                                    Text(asset.displayName)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 620, height: 460)
    }
}
