//
//  StockDiscussionView.swift
//  ShareQuest
//
//  WhatsApp-style stock discussion chat using the stock_discussions table.
//  System AI messages are shown as centred prompts. User messages use bubbles.
//

import SwiftUI
import Combine

// MARK: - Model

struct DiscussionReaction: Codable {
    let emoji: String
    let count: Int
}

struct StockDiscussionMessage: Identifiable, Codable {
    let id: Int
    let user_id: String?
    let author: String
    let content: String
    let is_system: Bool
    let system_urgency: String?   // "high" or "normal"
    let system_direction: String? // "up" or "down"
    let created_at: String
    let is_mine: Bool
    var reactions: [DiscussionReaction] = []
    var my_reactions: [String] = []
}

// MARK: - ViewModel

@MainActor
class StockDiscussionViewModel: ObservableObject {
    @Published var messages: [StockDiscussionMessage] = []
    @Published var isLoading = true
    @Published var isSending = false
    @Published var draft = ""
    @Published var blockedMessage: String? = nil
    @Published var errorMessage: String? = nil
    @Published var hasOlder = true

    let symbol: String
    private var lastTimestamp: String? = nil
    private var oldestId: Int? = nil
    private var pollTask: Task<Void, Never>?

    init(symbol: String) {
        self.symbol = symbol
    }

    func start() {
        Task { await loadInitial() }
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else { break }
                await poll()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await APIService.shared.fetchStockDiscussion(symbol: symbol, before: nil, since: nil)
            messages = fetched
            lastTimestamp = fetched.last?.created_at
            oldestId = fetched.first?.id
            hasOlder = fetched.count >= 40
        } catch {
            errorMessage = "Could not load discussion"
        }
    }

    func loadOlder() async {
        guard hasOlder, let oldest = oldestId else { return }
        do {
            let fetched = try await APIService.shared.fetchStockDiscussion(symbol: symbol, before: oldest, since: nil)
            messages.insert(contentsOf: fetched, at: 0)
            oldestId = fetched.first?.id
            hasOlder = fetched.count >= 40
        } catch {}
    }

    private func poll() async {
        guard let since = lastTimestamp else { return }
        do {
            let newMessages = try await APIService.shared.fetchStockDiscussion(symbol: symbol, before: nil, since: since)
            if !newMessages.isEmpty {
                messages.append(contentsOf: newMessages)
                lastTimestamp = newMessages.last?.created_at
            }
        } catch {}
    }

    func react(messageId: Int, emoji: String) async {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        do {
            let (reactions, myReactions) = try await APIService.shared.reactToDiscussionMessage(messageId: messageId, emoji: emoji)
            messages[idx].reactions = reactions
            messages[idx].my_reactions = myReactions
        } catch {}
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        defer { isSending = false }
        do {
            let sent = try await APIService.shared.postStockDiscussion(symbol: symbol, content: text)
            messages.append(sent)
            lastTimestamp = sent.created_at
        } catch APIError.networkError(let reason) {
            blockedMessage = reason
            draft = text
        } catch {
            errorMessage = "Failed to send"
            draft = text
        }
    }
}

// MARK: - View

struct StockDiscussionView: View {
    let symbol: String
    @StateObject private var vm: StockDiscussionViewModel

    init(symbol: String) {
        self.symbol = symbol
        _vm = StateObject(wrappedValue: StockDiscussionViewModel(symbol: symbol))
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.isLoading && vm.messages.isEmpty {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if vm.messages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary)
                    Text("No discussion yet")
                        .font(.headline).foregroundColor(.white)
                    Text("Be the first to comment on \(symbol)!")
                        .font(.subheadline).foregroundColor(Theme.textSecondary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            // Load older button
                            if vm.hasOlder {
                                Button {
                                    Task { await vm.loadOlder() }
                                } label: {
                                    Text("Load earlier messages")
                                        .font(.caption)
                                        .foregroundColor(Theme.primaryBlue)
                                        .padding(.vertical, 8)
                                }
                            }

                            ForEach(vm.messages) { message in
                                if message.is_system {
                                    SystemMessageBubble(message: message)
                                        .id(message.id)
                                } else {
                                    DiscussionBubble(message: message) { emoji in
                                        Task { await vm.react(messageId: message.id, emoji: emoji) }
                                    }
                                    .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = vm.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = vm.errorMessage {
                Text(error).font(.caption).foregroundColor(.red).padding(8)
            }

            // Input bar
            HStack(spacing: 10) {
                TextField("Comment on \(symbol)…", text: $vm.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                    .tint(Theme.primaryBlue)

                Button {
                    Task { await vm.send() }
                } label: {
                    Image(systemName: vm.isSending ? "clock" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Theme.textSecondary : Theme.primaryBlue)
                }
                .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.08, green: 0.1, blue: 0.16))
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .alert("Post Blocked", isPresented: Binding(
            get: { vm.blockedMessage != nil },
            set: { if !$0 { vm.blockedMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.blockedMessage = nil }
        } message: {
            Text(vm.blockedMessage ?? "")
        }
    }
}

// MARK: - System message (centred prompt card)

private struct SystemMessageBubble: View {
    let message: StockDiscussionMessage

    private var isUrgent: Bool { message.system_urgency == "high" }
    private var isUp: Bool { message.system_direction == "up" }

    // Pill colour: up=blue, down urgent=red, down normal=gold
    private var pillBg: Color {
        if isUp { return Color(red: 0.18, green: 0.42, blue: 0.78) }
        return isUrgent
            ? Color(red: 0.85, green: 0.12, blue: 0.12)
            : Color(red: 1.0,  green: 0.75, blue: 0.0)
    }
    private var pillText: Color { isUp ? .white : (isUrgent ? .white : .black) }
    private var bgColor: Color {
        if isUp { return Color(red: 0.06, green: 0.10, blue: 0.22) }
        return isUrgent
            ? Color(red: 0.14, green: 0.05, blue: 0.05)
            : Color(red: 0.11, green: 0.10, blue: 0.04)
    }
    private var borderColor: Color {
        if isUp { return Color.blue.opacity(0.4) }
        return isUrgent ? Color.red.opacity(0.45) : Color.yellow.opacity(0.3)
    }
    private var iconColor: Color {
        if isUp { return Color(red: 0.4, green: 0.7, blue: 1.0) }
        return isUrgent ? Color(red: 1.0, green: 0.4, blue: 0.4) : Color(red: 1.0, green: 0.84, blue: 0.0)
    }
    private var icon: String {
        isUp ? "arrow.up.circle.fill" : (isUrgent ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill")
    }

    var body: some View {
        HStack {
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 8) {
                // Header: icon + direction pill
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(iconColor)
                    Text(isUp ? "Moving Up" : "Moving Down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(pillText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(pillBg)
                        .clipShape(Capsule())
                }
                Text(message.content)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bgColor)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
            .shadow(color: isUp ? Color.blue.opacity(0.2) : (isUrgent ? Color.red.opacity(0.2) : .clear), radius: 6)
            Spacer(minLength: 12)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - User message bubble (WhatsApp style, with reactions)

private struct DiscussionBubble: View {
    let message: StockDiscussionMessage
    let onReact: (String) -> Void

    private let availableEmojis = ["👍", "🔥", "📈", "📉", "🤔", "😂"]
    @State private var showEmojiPicker = false

    private var timeString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: message.created_at)
            ?? ISO8601DateFormatter().date(from: message.created_at)
            ?? Date()
        let display = DateFormatter()
        display.timeStyle = .short
        return display.string(from: date)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.is_mine { Spacer(minLength: 50) }

            VStack(alignment: message.is_mine ? .trailing : .leading, spacing: 3) {
                // Author name (others only)
                if !message.is_mine {
                    Text(message.author)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.primaryBlue)
                        .padding(.leading, 4)
                }

                // Message bubble
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.is_mine
                            ? Theme.primaryBlue
                            : Color(red: 0.15, green: 0.19, blue: 0.28)
                    )
                    .cornerRadius(18, corners: message.is_mine
                        ? [.topLeft, .topRight, .bottomLeft]
                        : [.topLeft, .topRight, .bottomRight]
                    )
                    .onLongPressGesture { showEmojiPicker = true }

                // Emoji picker popover
                if showEmojiPicker {
                    HStack(spacing: 8) {
                        ForEach(availableEmojis, id: \.self) { emoji in
                            Button {
                                onReact(emoji)
                                showEmojiPicker = false
                            } label: {
                                Text(emoji).font(.title3)
                            }
                        }
                        Button {
                            showEmojiPicker = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.12, green: 0.15, blue: 0.22))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.glassBorder, lineWidth: 1))
                    .transition(.scale.combined(with: .opacity))
                }

                // Reaction counts
                if !message.reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(message.reactions, id: \.emoji) { reaction in
                            Button { onReact(reaction.emoji) } label: {
                                HStack(spacing: 3) {
                                    Text(reaction.emoji).font(.system(size: 13))
                                    Text("\(reaction.count)")
                                        .font(.caption2)
                                        .foregroundColor(message.my_reactions.contains(reaction.emoji)
                                            ? Theme.primaryBlue : Theme.textSecondary)
                                }
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(message.my_reactions.contains(reaction.emoji)
                                    ? Theme.primaryBlue.opacity(0.15) : Color.white.opacity(0.07))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(message.my_reactions.contains(reaction.emoji)
                                        ? Theme.primaryBlue.opacity(0.4) : Color.clear, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 4)
            }

            if !message.is_mine { Spacer(minLength: 50) }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: showEmojiPicker)
    }
}
