import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            Group {
                switch state.section {
                case .studio: StudioView()
                case .library: LibraryView()
                case .history: HistoryView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 20)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    SidebarRow(section: section,
                               isSelected: state.section == section) {
                        state.section = section
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            statusFooter
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.vividGradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text("AI Media Studio")
                    .font(.system(size: 15, weight: .bold))
                Text("图片 / 视频 AI 工作台")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.isConfigured ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(state.isConfigured ? "API 已连接" : "未配置 API Key")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture { state.section = .settings }
    }
}

private struct SidebarRow: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
                    .shadow(color: isSelected ? Theme.accent.opacity(0.35) : .clear,
                            radius: 8, y: 3)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var background: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Theme.brandGradient)
        } else if hovering {
            return AnyShapeStyle(Color.primary.opacity(0.06))
        }
        return AnyShapeStyle(Color.clear)
    }
}
