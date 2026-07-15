import SwiftUI
import UniformTypeIdentifiers

/// Multi-turn AI conversation: keep asking follow-up questions with full context
/// retained, optionally attaching images. Conversations are saved and restored.
struct ChatView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                ConversationListColumn()
                    .frame(width: 260)
                Divider()
                ThreadColumn()
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if state.activeConversationID == nil {
                state.activeConversationID = state.conversations.first?.id
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                GradientTitle(text: "AI 对话", size: 22)
                Text("多轮上下文对话,可追问、可带图")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                state.newConversation()
            } label: {
                Label("新建对话", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
}

// MARK: - Conversation list

private struct ConversationListColumn: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Group {
            if state.conversations.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.brandGradient)
                        .opacity(0.6)
                    Text("还没有对话")
                        .font(.system(size: 12, weight: .medium))
                    Text("点击右上角「新建对话」开始")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(state.conversations) { conversation in
                            ConversationRow(conversation: conversation,
                                            isSelected: conversation.id == state.activeConversationID) {
                                state.activeConversationID = conversation.id
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(.thinMaterial)
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var state: AppState
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                Text(conversation.lastPreview)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.brandGradient)
                                     : AnyShapeStyle(hovering ? Color.primary.opacity(0.06) : Color.clear))
                    .shadow(color: isSelected ? Theme.accent.opacity(0.3) : .clear, radius: 6, y: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("删除对话", role: .destructive) {
                state.deleteConversation(conversation)
            }
        }
    }
}

// MARK: - Thread + input

private struct ThreadColumn: View {
    @EnvironmentObject private var state: AppState
    @State private var input: String = ""
    @State private var attachments: [Asset] = []

    var body: some View {
        if let conversation = state.activeConversation {
            VStack(spacing: 0) {
                messages(for: conversation)
                Divider()
                inputBar(conversationID: conversation.id)
            }
        } else {
            emptyState
        }
    }

    private func messages(for conversation: Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if conversation.messages.isEmpty {
                        starter
                            .padding(.top, 40)
                    }
                    ForEach(conversation.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if state.isChatting {
                        TypingIndicator()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .id("typing")
                    }
                    Color.clear.frame(height: 1).id("BOTTOM")
                }
                .padding(20)
            }
            .onChange(of: conversation.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
            }
            .onChange(of: state.isChatting) { _, _ in
                withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
            }
        }
    }

    private var starter: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(Theme.brandGradient)
            Text("开始对话")
                .font(.system(size: 15, weight: .semibold))
            Text("输入问题,或用回形针附上图片让 AI 结合图片回答。\n对话上下文会一直保留,可以持续追问。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.brandGradient)
                .opacity(0.55)
            Text("选择或新建一个对话")
                .font(.system(size: 15, weight: .semibold))
            Button {
                state.newConversation()
            } label: {
                Label("新建对话", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inputBar(conversationID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { asset in
                            attachmentChip(asset)
                        }
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button(action: attachImages) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("附加图片")

                TextField("输入消息…(⌘↩ 发送)", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(action: { send(conversationID: conversationID) }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(canSend ? AnyShapeStyle(Theme.brandGradient)
                                            : AnyShapeStyle(Color.gray.opacity(0.4)))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
    }

    private func attachmentChip(_ asset: Asset) -> some View {
        ZStack(alignment: .topTrailing) {
            AssetThumbnailView(asset: asset, cornerRadius: 8)
                .frame(width: 56, height: 56)
            Button {
                attachments.removeAll { $0.id == asset.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
        }
    }

    private var canSend: Bool {
        guard !state.isChatting else { return false }
        return !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    private func attachImages() {
        let urls = FileActions.pickFiles(contentTypes: [.image])
        guard !urls.isEmpty else { return }
        let imported = state.importFiles(urls)
        attachments.append(contentsOf: imported)
    }

    private func send(conversationID: UUID) {
        guard canSend else { return }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let atts = attachments
        input = ""
        attachments = []
        Task {
            await state.sendChatMessage(conversationID: conversationID,
                                        text: text,
                                        attachments: atts)
        }
    }
}

// MARK: - Bubbles

private struct MessageBubble: View {
    let message: ChatMessage
    @EnvironmentObject private var state: AppState

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            VStack(alignment: .leading, spacing: 8) {
                if !message.imageAssetIDs.isEmpty {
                    let assets = message.imageAssetIDs.compactMap { state.asset(with: $0) }
                    HStack(spacing: 6) {
                        ForEach(assets) { asset in
                            AssetThumbnailView(asset: asset, cornerRadius: 8)
                                .frame(width: 120, height: 90)
                        }
                    }
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 13))
                        .foregroundStyle(textColor)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isUser ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Theme.hairline),
                                  lineWidth: 1)
            )
            .frame(maxWidth: 480, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var textColor: Color {
        if isUser { return .white }
        return message.isError ? .orange : .primary
    }

    private var bubbleBackground: AnyShapeStyle {
        if isUser { return AnyShapeStyle(Theme.brandGradient) }
        if message.isError { return AnyShapeStyle(Color.orange.opacity(0.12)) }
        return AnyShapeStyle(Material.regular)
    }
}

private struct TypingIndicator: View {
    @State private var phase = 0.0
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .opacity(0.3 + 0.7 * abs(sin(phase + Double(i) * 0.6)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
