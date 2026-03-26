//
//  LeagueChatView.swift
//  ShareQuest
//
//  WhatsApp-style league chat. Polls for new messages every 10 seconds.
//

import SwiftUI

// MARK: - Model

struct LeagueMessage: Identifiable, Codable {
    let id: Int
    let user_id: String
    let author: String
    let content: String
    let created_at: String
    let is_mine: Bool
}

// MARK: - ViewModel

@MainActor
class LeagueChatViewModel: ObservableObject {
    @Published var messages: [LeagueMessage] = []
    @Published var isLoading = true
    @Published var isSending = false
    @Published var errorMessage: String? = nil
    @Published var blockedMessage: String? = nil
    @Published var draft = ""

    let leagueId: String
    private var pollTask: Task<Void, Never>?
    private var lastTimestamp: String? = nil

    init(leagueId: String) {
        self.leagueId = leagueId
    }

    func start() {
        Task { await loadInitial() }
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
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
            let fetched = try await APIService.shared.fetchLeagueMessages(leagueId: leagueId, since: nil)
            messages = fetched
            lastTimestamp = fetched.last?.created_at
        } catch {
            errorMessage = "Could not load messages"
        }
    }

    private func poll() async {
        guard let since = lastTimestamp else { return }
        do {
            let newMessages = try await APIService.shared.fetchLeagueMessages(leagueId: leagueId, since: since)
            if !newMessages.isEmpty {
                messages.append(contentsOf: newMessages)
                lastTimestamp = newMessages.last?.created_at
            }
        } catch {}
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        defer { isSending = false }
        do {
            let sent = try await APIService.shared.sendLeagueMessage(leagueId: leagueId, content: text)
            messages.append(sent)
            lastTimestamp = sent.created_at
        } catch APIError.networkError(let reason) {
            // Could be a moderation block — surface the exact reason
            blockedMessage = reason
            draft = text
        } catch {
            errorMessage = "Failed to send message"
            draft = text
        }
    }
}

// MARK: - View

struct LeagueChatView: View {
    let leagueId: String
    @StateObject private var vm: LeagueChatViewModel

    init(leagueId: String) {
        self.leagueId = leagueId
        _vm = StateObject(wrappedValue: LeagueChatViewModel(leagueId: leagueId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if vm.messages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary)
                    Text("No messages yet")
                        .font(.headline).foregroundColor(.white)
                    Text("Be the first to say something!")
                        .font(.subheadline).foregroundColor(Theme.textSecondary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(vm.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
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
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            // Input bar
            HStack(spacing: 10) {
                TextField("Message...", text: $vm.draft, axis: .vertical)
                    .lineLimit(1...5)
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
                        .foregroundColor(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textSecondary : Theme.primaryBlue)
                }
                .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.08, green: 0.1, blue: 0.16))
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .alert("Message Blocked", isPresented: Binding(
            get: { vm.blockedMessage != nil },
            set: { if !$0 { vm.blockedMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.blockedMessage = nil }
        } message: {
            Text(vm.blockedMessage ?? "")
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: LeagueMessage

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
                if !message.is_mine {
                    Text(message.author)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.primaryBlue)
                        .padding(.leading, 4)
                }

                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.is_mine ? .white : .white)
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

                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 4)
            }

            if !message.is_mine { Spacer(minLength: 50) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Rounded Corner Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
