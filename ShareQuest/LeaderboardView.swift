//
//  LeaderboardView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

// MARK: - Leaderboard Type Enum

enum LeaderboardType: String, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case annual = "annual"

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        }
    }

    var emoji: String {
        switch self {
        case .weekly: return "⚡"
        case .monthly: return "📅"
        case .annual: return "🏆"
        }
    }

    var title: String {
        switch self {
        case .weekly: return "Weekly ShareQuest"
        case .monthly: return "Monthly ShareQuest"
        case .annual: return "Annual ShareQuest"
        }
    }

    var color: Color {
        switch self {
        case .weekly: return Theme.primaryBlue
        case .monthly: return Theme.accentPurple
        case .annual: return Theme.accentYellow
        }
    }

    var icon: String {
        switch self {
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .annual: return "trophy"
        }
    }
}

// MARK: - Leaderboard Entry Model

struct LeaderboardEntry: Identifiable {
    let id: String
    let userId: String
    let username: String
    let totalAssets: Double
    let profitLossPercent: Double
    let profitLoss: Double
    let playerLevel: Int?
    let rank: Int

    var formattedValue: String {
        let pounds = totalAssets / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: pounds)) ?? String(format: "%.2f", pounds)
        return "£\(formatted)"
    }

    var formattedReturn: String {
        String(format: "%+.2f%%", profitLossPercent)
    }
}

// MARK: - LeaderboardView

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedUser: LeaderboardEntry? = nil
    @State private var showUserModal = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient matching rest of app
                LinearGradient(
                    colors: [
                        Color(red: 0.059, green: 0.090, blue: 0.165),
                        Color(red: 0.118, green: 0.227, blue: 0.373),
                        Color(red: 0.345, green: 0.110, blue: 0.529)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                            .scaleEffect(1.4)
                        Text("Loading leaderboard...")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        // Type tabs
                        if !viewModel.availableTypes.isEmpty {
                            typeSelector
                        }

                        if let error = viewModel.errorMessage {
                            errorView(error: error)
                        } else if viewModel.entries.isEmpty {
                            emptyView
                        } else {
                            mainContent
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await viewModel.loadAll()
        }
        .sheet(isPresented: $showUserModal) {
            if let user = selectedUser {
                UserPortfolioSheet(
                    entry: user,
                    competitionType: viewModel.selectedType,
                    isPresented: $showUserModal
                )
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.availableTypes, id: \.self) { type in
                    Button {
                        Task { await viewModel.selectType(type) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.caption)
                            Text(type.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(viewModel.selectedType == type ? type.color : Color.white.opacity(0.05))
                        .foregroundColor(viewModel.selectedType == type ? .white : Theme.textSecondary)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(viewModel.selectedType == type ? type.color : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Competition info banner (orange card)
                if let info = viewModel.competitionInfo {
                    competitionBanner(info: info)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // Your position card
                if let userEntry = viewModel.currentUserEntry {
                    yourPositionCard(entry: userEntry)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }

                // Leaderboard entries
                let leaderValue = viewModel.entries.first?.totalAssets ?? 1.0
                VStack(spacing: 10) {
                    ForEach(viewModel.entries) { entry in
                        leaderboardCard(entry: entry, leaderValue: leaderValue)
                            .onTapGesture {
                                selectedUser = entry
                                showUserModal = true
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Competition Banner

    private func competitionBanner(info: LeaderboardViewModel.CompetitionInfo) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: viewModel.selectedType.icon)
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedType.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let status = info.status {
                    Text(status.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let timeLeft = info.timeRemaining {
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    Text(timeLeft)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                if let prize = info.prizePool {
                    Text("Prize: £\(Int(prize))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(red: 1.0, green: 0.60, blue: 0.0))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.9, green: 0.54, blue: 0), lineWidth: 1)
        )
    }

    // MARK: - Your Position Card

    private func yourPositionCard(entry: LeaderboardEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Position")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primaryBlue)
                Text("#\(entry.rank)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.formattedValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                ChangePill(percent: entry.profitLossPercent)
            }
        }
        .padding()
        .background(Theme.primaryBlue.opacity(0.12))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.primaryBlue.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Per-Rank Cards

    @ViewBuilder
    private func leaderboardCard(entry: LeaderboardEntry, leaderValue: Double) -> some View {
        let progress = leaderValue > 0 ? entry.totalAssets / leaderValue : 0
        let isCurrentUser = entry.userId == viewModel.currentUserId

        switch entry.rank {
        case 1:
            ChampionCard(entry: entry, isCurrentUser: isCurrentUser)
        case 2:
            ContenderCard(
                entry: entry,
                medal: "🥈",
                accentColor: Color(red: 0.75, green: 0.75, blue: 0.78),
                progress: progress,
                isCurrentUser: isCurrentUser
            )
        case 3:
            ContenderCard(
                entry: entry,
                medal: "🥉",
                accentColor: Color(red: 0.80, green: 0.50, blue: 0.20),
                progress: progress,
                isCurrentUser: isCurrentUser
            )
        default:
            OtherCard(entry: entry, progress: progress, isCurrentUser: isCurrentUser)
        }
    }

    // MARK: - Error & Empty

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(error)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task { await viewModel.selectType(viewModel.selectedType) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.15))
            .foregroundColor(.red)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.textMuted)
            Text("No participants yet")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Be the first to join this competition!")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Champion Card (Rank 1)

struct ChampionCard: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Gold crown + avatar
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Theme.accentYellow.opacity(0.25))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(entry.username.prefix(2).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.accentYellow)
                    )
                Text("👑")
                    .font(.caption)
                    .offset(x: 4, y: -4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.username)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isCurrentUser ? Theme.primaryBlue : .white)
                        .lineLimit(1)
                    if isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primaryBlue.opacity(0.2))
                            .foregroundColor(Theme.primaryBlue)
                            .cornerRadius(4)
                    }
                }
                if let level = entry.playerLevel {
                    Text("Level \(level)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.formattedValue)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                ChangePill(percent: entry.profitLossPercent)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Theme.accentYellow.opacity(0.15), Theme.accentYellow.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.accentYellow.opacity(0.4), lineWidth: 1.5)
        )
    }
}

// MARK: - Contender Card (Ranks 2-3)

struct ContenderCard: View {
    let entry: LeaderboardEntry
    let medal: String
    let accentColor: Color
    let progress: Double
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Medal + avatar
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(entry.username.prefix(2).uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(accentColor)
                    )
                Text(medal)
                    .font(.caption2)
                    .offset(x: 4, y: -4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentUser ? Theme.primaryBlue : .white)
                        .lineLimit(1)
                    if isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primaryBlue.opacity(0.2))
                            .foregroundColor(Theme.primaryBlue)
                            .cornerRadius(4)
                    }
                }
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor.opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(min(progress, 1.0)))
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.formattedValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                ChangePill(percent: entry.profitLossPercent)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Other Card (Ranks 4+)

struct OtherCard: View {
    let entry: LeaderboardEntry
    let progress: Double
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank number
            Text("\(entry.rank)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textMuted)
                .frame(width: 28, alignment: .center)

            // Avatar circle
            Circle()
                .fill(Theme.primaryBlue.opacity(isCurrentUser ? 0.3 : 0.15))
                .frame(width: 38, height: 38)
                .overlay(
                    Text(entry.username.prefix(2).uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentUser ? Theme.primaryBlue : Theme.textSecondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isCurrentUser ? Theme.primaryBlue : .white)
                        .lineLimit(1)
                    if isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primaryBlue.opacity(0.2))
                            .foregroundColor(Theme.primaryBlue)
                            .cornerRadius(4)
                    }
                }
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.primaryBlue.opacity(0.6))
                            .frame(width: geo.size.width * CGFloat(min(progress, 1.0)))
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.formattedValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                ChangePill(percent: entry.profitLossPercent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isCurrentUser ? Theme.primaryBlue.opacity(0.1) : Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? Theme.primaryBlue.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - User Portfolio Sheet

struct UserPortfolioSheet: View {
    let entry: LeaderboardEntry
    let competitionType: LeaderboardType
    @Binding var isPresented: Bool
    @State private var portfolio: LeaderboardUserPortfolio? = nil
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.118, green: 0.176, blue: 0.243), Color(red: 0.059, green: 0.090, blue: 0.165)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                        .scaleEffect(1.4)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Stats row
                            HStack(spacing: 10) {
                                statBox(label: "Rank", value: "#\(entry.rank)")
                                statBox(label: "Total Value", value: entry.formattedValue)
                                statBox(label: "Cash", value: portfolio.map { formatPounds($0.cashBalance / 100) } ?? "--")
                            }
                            .padding(.horizontal)

                            // Holdings
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Holdings")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)

                                if let holdings = portfolio?.holdings, !holdings.isEmpty {
                                    ForEach(holdings, id: \.symbol) { holding in
                                        holdingRow(holding: holding)
                                    }
                                    .padding(.horizontal)
                                } else {
                                    Text("No holdings in this portfolio")
                                        .foregroundColor(Theme.textSecondary)
                                        .padding()
                                }
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("\(entry.username)'s Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(Theme.primaryBlue)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await loadPortfolio()
        }
    }

    private func formatPounds(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        return "£\(formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))"
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    private func holdingRow(holding: LeaderboardUserPortfolio.Holding) -> some View {
        let value = holding.quantity * holding.currentPrice
        let cost = holding.quantity * holding.averagePrice
        let pl = value - cost
        let plPercent = cost > 0 ? (pl / cost) * 100 : 0

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("\(Int(holding.quantity)) @ \(String(format: "%.2f", holding.averagePrice))p")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPounds(value / 100))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                ChangePill(percent: plPercent)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func loadPortfolio() async {
        defer { isLoading = false }
        do {
            let result = try await APIService.shared.fetchLeaderboardUserPortfolio(
                type: competitionType.rawValue,
                userId: entry.userId
            )
            portfolio = result
        } catch {
            // If endpoint fails just show empty holdings
            portfolio = LeaderboardUserPortfolio(rank: entry.rank, cashBalance: 0, holdings: [])
        }
    }
}

// MARK: - Leaderboard ViewModel

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var competitionInfo: CompetitionInfo?
    @Published var currentUserEntry: LeaderboardEntry?
    @Published var availableTypes: [LeaderboardType] = []
    @Published var selectedType: LeaderboardType = .weekly
    var currentUserId: String = ""

    // Cache all fetched results so tab switches don't re-fetch
    private var cache: [LeaderboardType: LeaderboardResponse] = [:]

    struct CompetitionInfo {
        let status: String?
        let prizePool: Double?
        let startDate: String?
        let endDate: String?
        let timeRemaining: String?
    }

    /// Fetch all three types sequentially, pick the first with data.
    func loadAll() async {
        isLoading = true
        errorMessage = nil
        currentUserId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        cache.removeAll()

        let allTypes: [LeaderboardType] = [.weekly, .monthly, .annual]
        var active: [LeaderboardType] = []

        for type in allTypes {
            print("[Leaderboard] Fetching \(type.rawValue)...")
            do {
                let response = try await APIService.shared.fetchLeaderboard(type: type.rawValue)
                let count = response.leaderboard?.count ?? 0
                print("[Leaderboard] \(type.rawValue): \(count) entries, success=\(response.success ?? false)")
                cache[type] = response
                if count > 0 {
                    active.append(type)
                }
            } catch {
                print("[Leaderboard] \(type.rawValue) FAILED: \(error)")
            }
        }

        availableTypes = active
        print("[Leaderboard] Active tabs: \(active.map(\.rawValue))")

        if let first = active.first {
            selectedType = first
            applyCache(for: first)
        } else {
            entries = []
            competitionInfo = nil
            currentUserEntry = nil
        }

        isLoading = false
    }

    /// Switch to a tab - use cache if available, otherwise fetch.
    func selectType(_ type: LeaderboardType) async {
        selectedType = type
        if let cached = cache[type] {
            applyCache(for: type)
            _ = cached // already applied
        } else {
            await fetchAndCache(type: type)
        }
    }

    func refresh() async {
        cache.removeAll()
        await loadAll()
    }

    private func fetchAndCache(type: LeaderboardType) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.fetchLeaderboard(type: type.rawValue)
            cache[type] = response
            applyCache(for: type)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func applyCache(for type: LeaderboardType) {
        guard let response = cache[type] else { return }
        guard let leaderboardData = response.leaderboard, !leaderboardData.isEmpty else {
            entries = []
            currentUserEntry = nil
            competitionInfo = nil
            return
        }

        entries = leaderboardData.map { data in
            LeaderboardEntry(
                id: data.id,
                userId: data.user_id ?? "",
                username: data.username ?? "User \(data.rank)",
                totalAssets: data.displayValue,
                profitLossPercent: data.profit_loss_percent ?? 0,
                profitLoss: data.profit_loss ?? 0,
                playerLevel: nil,
                rank: data.rank
            )
        }

        currentUserId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        currentUserEntry = entries.first { $0.userId == currentUserId }

        if let comp = response.competition {
            competitionInfo = CompetitionInfo(
                status: comp.status,
                prizePool: comp.prize_pool,
                startDate: comp.start_date,
                endDate: comp.end_date,
                timeRemaining: comp.time_remaining.map { formatTimeLeft($0) }
            )
        } else {
            competitionInfo = nil
        }
    }

    private func formatTimeLeft(_ raw: String) -> String {
        print("[Leaderboard] formatTimeLeft raw='\(raw)'")
        // Try parsing as seconds (number); API may return milliseconds — detect by value > 1 year in seconds
        if var n = Double(raw), n > 0 {
            if n > 31_536_000 { n /= 1000 } // convert ms → seconds
            let days = Int(n) / 86400
            let hours = (Int(n) % 86400) / 3600
            let minutes = (Int(n) % 3600) / 60
            if days > 0 { return "\(days)d \(hours)h" }
            if hours > 0 { return "\(hours)h \(minutes)m" }
            if minutes > 0 { return "\(minutes)m" }
            return "<1m"
        }
        // If the API returned a pre-formatted string, use it as-is
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "--" : trimmed
    }
}

#Preview {
    LeaderboardView()
}
