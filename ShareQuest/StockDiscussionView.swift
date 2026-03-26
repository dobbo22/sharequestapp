//
//  StockDiscussionView.swift
//  ShareQuest
//
//  Chat-style stock discussion feed powered by community_posts.
//

import SwiftUI
import Combine

// MARK: - Model

struct StockPost: Identifiable, Codable {
    let id: Int
    let user_id: String
    let author: String
    let content: String
    let created_at: String
    let likes_count: Int
    let replies_count: Int
    let is_mine: Bool
}

// MARK: - ViewModel

@MainActor
class StockDiscussionViewModel: ObservableObject {
    @Published var posts: [StockPost] = []
    @Published var isLoading = true
    @Published var isSending = false
    @Published var draft = ""
    @Published var blockedMessage: String? = nil
    @Published var errorMessage: String? = nil
    @Published var hasMore = true

    let symbol: String
    private var offset = 0
    private let limit = 30

    init(symbol: String) {
        self.symbol = symbol
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await APIService.shared.fetchStockDiscussion(symbol: symbol, offset: 0)
            posts = fetched
            offset = fetched.count
            hasMore = fetched.count == limit
        } catch {
            errorMessage = "Could not load discussion"
        }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        do {
            let fetched = try await APIService.shared.fetchStockDiscussion(symbol: symbol, offset: offset)
            posts.append(contentsOf: fetched)
            offset += fetched.count
            hasMore = fetched.count == limit
        } catch {}
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        defer { isSending = false }
        do {
            let post = try await APIService.shared.postStockDiscussion(symbol: symbol, content: text)
            posts.insert(post, at: 0)
        } catch APIError.networkError(let reason) {
            blockedMessage = reason
            draft = text
        } catch {
            errorMessage = "Failed to post"
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
            if vm.isLoading && vm.posts.isEmpty {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if vm.posts.isEmpty {
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
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(vm.posts) { post in
                            StockPostRow(post: post)
                            Divider().background(Color.white.opacity(0.07))
                        }
                        if vm.hasMore {
                            Button("Load more") { Task { await vm.loadMore() } }
                                .font(.subheadline)
                                .foregroundColor(Theme.primaryBlue)
                                .padding(.vertical, 12)
                        }
                    }
                }
            }

            if let error = vm.errorMessage {
                Text(error).font(.caption).foregroundColor(.red).padding(8)
            }

            // Input bar
            HStack(spacing: 10) {
                TextField("Share your thoughts on \(symbol)…", text: $vm.draft, axis: .vertical)
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
        .task { await vm.load() }
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

// MARK: - Post Row

private struct StockPostRow: View {
    let post: StockPost

    private var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: post.created_at)
            ?? ISO8601DateFormatter().date(from: post.created_at)
            ?? Date()
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60 { return "just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(post.is_mine ? Theme.primaryBlue : Color(red: 0.2, green: 0.25, blue: 0.35))
                    .frame(width: 36, height: 36)
                Text(String(post.author.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(post.is_mine ? "You" : post.author)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(post.is_mine ? Theme.primaryBlue : .white)
                    Text("·")
                        .foregroundColor(Theme.textSecondary)
                    Text(timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }

                Text(post.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                if post.replies_count > 0 || post.likes_count > 0 {
                    HStack(spacing: 14) {
                        if post.likes_count > 0 {
                            Label("\(post.likes_count)", systemImage: "heart")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        if post.replies_count > 0 {
                            Label("\(post.replies_count)", systemImage: "bubble.right")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
