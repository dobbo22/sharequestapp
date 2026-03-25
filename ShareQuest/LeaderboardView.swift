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

    var title: String {
        switch self {
        case .weekly: return "Weekly Quest"
        case .monthly: return "Monthly Quest"
        case .annual: return "Annual Quest"
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
        case .weekly: return "bolt.fill"
        case .monthly: return "calendar"
        case .annual: return "trophy.fill"
        }
    }
}

// MARK: - Leaderboard Entry Model

struct LeaderboardEntry: Identifiable, Equatable {
    let id: String
    let userId: String
    let username: String
    let totalAssets: Double
    let profitLossPercent: Double
    let profitLoss: Double
    let playerLevel: Int?
    let rank: Int

    // Compact — used on podium steps where space is tight
    var formattedValue: String {
        let pounds = totalAssets / 100.0
        if pounds >= 1_000_000 { return String(format: "£%.2fM", pounds / 1_000_000) }
        if pounds >= 1_000    { return String(format: "£%.1fK", pounds / 1_000) }
        return String(format: "£%.0f", pounds)
    }

    // Full — used on rank tiles where full precision is shown
    var formattedValueFull: String {
        let pounds = totalAssets / 100.0
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        let s = fmt.string(from: NSNumber(value: pounds)) ?? String(format: "%.2f", pounds)
        return "£\(s)"
    }

    var formattedReturn: String {
        String(format: "%+.2f%%", profitLossPercent)
    }

    var initials: String {
        String(username.prefix(2)).uppercased()
    }
}

// MARK: - LeaderboardView

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedUser: LeaderboardEntry? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else {
                    VStack(spacing: 0) {
                        if !viewModel.availableTypes.isEmpty {
                            typeSelector
                                .padding(.top, 4)
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
            let done = await APIService.shared.postChallengeProgress(criteriaType: "leaderboard")
            postCompletionNotification(done)
            await viewModel.loadAll()
        }
        .sheet(item: $selectedUser) { user in
            UserPortfolioSheet(
                entry: user,
                competitionType: viewModel.selectedType
            )
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.availableTypes, id: \.self) { type in
                Button {
                    Task { await viewModel.selectType(type) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: type.icon)
                            .font(.system(size: scaled(11), weight: .bold))
                        Text(type.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        viewModel.selectedType == type
                            ? type.color
                            : Color.white.opacity(0.08)
                    )
                    .foregroundColor(viewModel.selectedType == type ? .white : .white.opacity(0.55))
                    .cornerRadius(22)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Competition info strip
                if let info = viewModel.competitionInfo {
                    competitionStrip(info: info)
                }

                // Your position banner (if not rank 1)
                if let userEntry = viewModel.currentUserEntry, userEntry.rank > 1 {
                    yourPositionBanner(entry: userEntry)
                }

                // All entries as tiles
                rankList(entries: viewModel.entries)
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Competition Strip

    private func competitionStrip(info: LeaderboardViewModel.CompetitionInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.selectedType.icon)
                .font(.system(size: scaled(13), weight: .bold))
                .foregroundColor(viewModel.selectedType.color)

            Text(viewModel.selectedType.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            if let status = info.status {
                Text(status.capitalized)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(viewModel.selectedType.color.opacity(0.25))
                    .foregroundColor(viewModel.selectedType.color)
                    .cornerRadius(6)
            }

            Spacer()

            if let timeLeft = info.timeRemaining {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.55))
                    Text(timeLeft)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.07))
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Your Position Banner

    private func yourPositionBanner(entry: LeaderboardEntry) -> some View {
        leaderboardTile(entry: entry, isUser: true)
    }

    // MARK: - Rank List (4+)

    private func rankList(entries: [LeaderboardEntry]) -> some View {
        VStack(spacing: 6) {
            ForEach(entries) { entry in
                let isUser = entry.userId == viewModel.currentUserId
                leaderboardTile(entry: entry, isUser: isUser)
                    .onTapGesture {
                        selectedUser = entry
                    }
            }
        }
    }

    // Medal colours for top 3
    private func medalGradient(rank: Int) -> LinearGradient? {
        switch rank {
        case 1: return LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.85, green: 0.65, blue: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2: return LinearGradient(colors: [Color(red: 0.85, green: 0.85, blue: 0.92), Color(red: 0.60, green: 0.60, blue: 0.70)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3: return LinearGradient(colors: [Color(red: 0.80, green: 0.50, blue: 0.20), Color(red: 0.55, green: 0.27, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return nil
        }
    }

    private func medalGlow(rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.85)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return .clear
        }
    }

    // Shared tile used for both "Your Position" banner and all rank rows
    private func leaderboardTile(entry: LeaderboardEntry, isUser: Bool) -> some View {
        let isMedal = entry.rank <= 3
        return HStack(spacing: 10) {
            // Rank badge
            ZStack {
                if isMedal, let grad = medalGradient(rank: entry.rank) {
                    Circle()
                        .fill(grad)
                        .frame(width: 40, height: 40)
                        .shadow(color: medalGlow(rank: entry.rank).opacity(0.8), radius: 8, x: 0, y: 0)
                } else {
                    Circle()
                        .fill(isUser ? Theme.primaryBlue.opacity(0.2) : Color.white.opacity(0.07))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(isUser ? Theme.primaryBlue.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1.5))
                }
                Text("\(entry.rank)")
                    .font(.system(size: scaled(isMedal ? 14 : 11), weight: .black))
                    .foregroundColor(isMedal ? .black.opacity(0.75) : (isUser ? Theme.primaryBlue : .white.opacity(0.6)))
            }

            // Name + label
            VStack(alignment: .leading, spacing: 1) {
                if isUser {
                    Text("Your Position")
                        .font(.system(size: scaled(9)))
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(entry.username)
                    .font(.system(size: scaled(13), weight: isUser ? .semibold : .medium))
                    .foregroundColor(isUser ? Theme.primaryBlue : .white)
                    .lineLimit(1)
            }

            Spacer()

            // Full value + movement
            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.formattedValueFull)
                    .font(.system(size: scaled(12), weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ChangePill(percent: entry.profitLossPercent, compact: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            isMedal
                ? LinearGradient(colors: [medalGlow(rank: entry.rank).opacity(0.15), medalGlow(rank: entry.rank).opacity(0.04)], startPoint: .leading, endPoint: .trailing)
                : isUser
                    ? LinearGradient(colors: [Theme.primaryBlue.opacity(0.18), Theme.primaryBlue.opacity(0.06)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)], startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            isMedal ? medalGlow(rank: entry.rank).opacity(0.35) : (isUser ? Theme.primaryBlue.opacity(0.4) : Color.white.opacity(0.08)),
            lineWidth: isMedal ? 1.5 : 1
        ))
    }

    // MARK: - Loading / Empty / Error

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentYellow))
                .scaleEffect(1.3)
            Text("Loading leaderboard…")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: scaled(40)))
                .foregroundColor(Theme.accentYellow)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task { await viewModel.selectType(viewModel.selectedType) }
            }
            .padding(.horizontal, 24).padding(.vertical, 10)
            .background(Theme.primaryBlue.opacity(0.2))
            .foregroundColor(Theme.primaryBlue)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: scaled(52)))
                .foregroundColor(Theme.accentYellow.opacity(0.4))
            Text("No participants yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Be the first to join this competition!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - User Portfolio Sheet

struct UserPortfolioSheet: View {
    let entry: LeaderboardEntry
    let competitionType: LeaderboardType
    @Environment(\.dismiss) private var dismiss
    @State private var portfolio: LeaderboardUserPortfolio? = nil
    @State private var isLoading = true
    @State private var selectedHolding: LeaderboardUserPortfolio.Holding? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Stats available immediately from entry — no waiting
                        HStack(spacing: 10) {
                            statBox(label: "Rank", value: "\(entry.rank)")
                            statBox(label: "Total Value", value: entry.formattedValue)
                            statBox(label: "Return", value: entry.formattedReturn)
                        }
                        .padding(.horizontal)

                        // Cash only available after load — show inline
                        if let p = portfolio {
                            HStack(spacing: 10) {
                                statBox(label: "Cash", value: formatPounds(p.cashBalance / 100))
                                statBox(label: "Holdings", value: "\(p.holdings.count)")
                                Spacer().frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)
                        }

                        // Holdings section — spinner only here, not full screen
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Holdings")
                                .font(.headline).foregroundColor(.white)
                                .padding(.horizontal)

                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                                    Spacer()
                                }
                                .padding()
                            } else if let holdings = portfolio?.holdings, !holdings.isEmpty {
                                ForEach(holdings) { holding in
                                    Button { selectedHolding = holding } label: {
                                        holdingRow(holding: holding)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal)
                                }
                            } else {
                                Text("No holdings")
                                    .foregroundColor(Theme.textSecondary).padding()
                            }
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("\(entry.username)'s Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Theme.primaryBlue)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedHolding) { holding in
                StockDetailView(stock: Stock(
                    id: holding.symbol,
                    symbol: holding.symbol,
                    companyName: holding.companyName ?? holding.symbol,
                    price: holding.currentPrice / 100.0,
                    changeAmount: 0,
                    changePercent: 0,
                    sector: "Portfolio",
                    marketCap: 0
                ))
            }
        }
        .task { await loadPortfolio() }
    }

    private func formatPounds(_ value: Double) -> String {
        if value >= 1_000 { return String(format: "£%.1fK", value / 1_000) }
        return String(format: "£%.0f", value)
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundColor(Theme.textSecondary)
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.8)
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
                Text(holding.companyName ?? holding.symbol)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.white).lineLimit(1)
                Text("\(holding.symbol) · \(Int(holding.quantity)) shares")
                    .font(.caption).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPounds(value / 100)).font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                ChangePill(percent: plPercent, compact: true)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func loadPortfolio() async {
        defer { isLoading = false }
        do {
            portfolio = try await APIService.shared.fetchLeaderboardUserPortfolio(
                type: competitionType.rawValue, userId: entry.userId)
        } catch {
            portfolio = LeaderboardUserPortfolio(rank: entry.rank, cashBalance: 0, holdings: [])
        }
    }
}

// MARK: - ViewModel

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

    private var cache: [LeaderboardType: LeaderboardResponse] = [:]

    struct CompetitionInfo {
        let status: String?
        let prizePool: Double?
        let startDate: String?
        let endDate: String?
        let timeRemaining: String?
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        currentUserId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        cache.removeAll()

        var active: [LeaderboardType] = []
        for type in LeaderboardType.allCases {
            do {
                let response = try await APIService.shared.fetchLeaderboard(type: type.rawValue)
                cache[type] = response
                if (response.leaderboard?.count ?? 0) > 0 { active.append(type) }
            } catch {}
        }

        availableTypes = active
        if let first = active.first {
            selectedType = first
            applyCache(for: first)
        } else {
            entries = []; competitionInfo = nil; currentUserEntry = nil
        }
        isLoading = false
    }

    func selectType(_ type: LeaderboardType) async {
        selectedType = type
        if cache[type] != nil {
            applyCache(for: type)
        } else {
            await fetchAndCache(type: type)
        }
    }

    func refresh() async { cache.removeAll(); await loadAll() }

    private func fetchAndCache(type: LeaderboardType) async {
        isLoading = true; errorMessage = nil
        do {
            let response = try await APIService.shared.fetchLeaderboard(type: type.rawValue)
            cache[type] = response; applyCache(for: type)
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func applyCache(for type: LeaderboardType) {
        guard let response = cache[type], let data = response.leaderboard, !data.isEmpty else {
            entries = []; currentUserEntry = nil; competitionInfo = nil; return
        }
        entries = data.map { d in
            LeaderboardEntry(id: d.id, userId: d.user_id ?? "",
                             username: d.username ?? "User \(d.rank)",
                             totalAssets: d.displayValue,
                             profitLossPercent: d.profit_loss_percent ?? 0,
                             profitLoss: d.profit_loss ?? 0,
                             playerLevel: nil, rank: d.rank)
        }
        currentUserId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        currentUserEntry = entries.first { $0.userId == currentUserId }
        if let comp = response.competition {
            competitionInfo = CompetitionInfo(
                status: comp.status, prizePool: comp.prize_pool,
                startDate: comp.start_date, endDate: comp.end_date,
                timeRemaining: comp.time_remaining.map { formatTimeLeft($0) }
            )
        } else { competitionInfo = nil }
    }

    private func formatTimeLeft(_ raw: String) -> String {
        if var n = Double(raw), n > 0 {
            if n > 31_536_000 { n /= 1000 }
            let days = Int(n) / 86400
            let hours = (Int(n) % 86400) / 3600
            let minutes = (Int(n) % 3600) / 60
            if days > 0 { return "\(days)d \(hours)h" }
            if hours > 0 { return "\(hours)h \(minutes)m" }
            if minutes > 0 { return "\(minutes)m" }
            return "<1m"
        }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "--" : trimmed
    }
}

#Preview {
    LeaderboardView()
}
