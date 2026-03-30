//
//  PortfolioView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

// MARK: - Portfolio Mode

enum PortfolioMode {
    case shareQuests
    case leagues
}

// MARK: - League Portfolio State

struct LeaguePortfolioState: Identifiable {
    let league: League
    var isExpanded: Bool = false
    var isLoading: Bool = false
    var holdings: [LeaderboardUserPortfolio.Holding] = []
    var cashBalance: Double = 0
    var totalValue: Double = 0
    var returnPercent: Double = 0
    var id: String { league.id }
}

// MARK: - PortfolioView

struct PortfolioView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @State private var selectedPortfolioType: PortfolioType
    @State private var selectedHolding: Holding?
    @State private var availablePortfolios: [PortfolioConfig] = []
    @State private var mode: PortfolioMode = .shareQuests
    @State private var leagueStates: [LeaguePortfolioState] = []
    @State private var leaguesLoading = false
    @State private var selectedLeague: League? = nil

    var isEmbedded: Bool = false

    init(initialType: PortfolioType = .practice, isEmbedded: Bool = false) {
        _selectedPortfolioType = State(initialValue: initialType)
        self.isEmbedded = isEmbedded
    }

    var body: some View {
        Group {
            if isEmbedded {
                portfolioContent
            } else {
                NavigationStack {
                    portfolioContent
                }
            }
        }
        .onDisappear {
            Task {
                // Small delay so user has clearly visited before awarding XP
                try? await Task.sleep(nanoseconds: 500_000_000)
                let done = await APIService.shared.postChallengeProgress(criteriaType: "portfolio_check")
                postCompletionNotification(done)
                let pnlDone = await APIService.shared.postChallengeProgress(criteriaType: "pnl_check")
                postCompletionNotification(pnlDone)
            }
        }
        .task(id: selectedPortfolioType) {
            await reloadPortfolios()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectPortfolioType)) { note in
            if let type = note.object as? PortfolioType {
                selectedPortfolioType = type
                mode = .shareQuests
            }
        }
        .onChange(of: selectedPortfolioType) { _, newType in
            Task { await viewModel.fetchPortfolio(type: newType) }
        }
        .sheet(item: $selectedHolding) { holding in
            StockTradeSheet(
                stock: holding.toStock(),
                portfolioType: selectedPortfolioType,
                initialTradeType: "sell",
                initialQuantity: String(holding.quantity),
                onTradeSuccess: {
                    Task { await viewModel.fetchPortfolio(type: selectedPortfolioType) }
                }
            )
        }
        .sheet(item: $selectedLeague) { league in
            LeaguePortfolioView(league: league)
        }
    }

    // MARK: - Main Content

    private var portfolioContent: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    modeToggle
                    if mode == .shareQuests {
                        shareQuestsContent
                    } else {
                        leaguesContent
                    }
                }
                .padding()
            }
            .refreshable {
                if mode == .shareQuests {
                    await reloadPortfolios()
                } else {
                    await reloadLeagues()
                }
            }
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            toggleButton(label: "ShareQuests", icon: "chart.line.uptrend.xyaxis", mode: .shareQuests)
            toggleButton(label: "Leagues", icon: "trophy.fill", mode: .leagues)
        }
        .background(Theme.glassBackground)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.glassBorder, lineWidth: 1))
    }

    private func toggleButton(label: String, icon: String, mode targetMode: PortfolioMode) -> some View {
        let isActive = mode == targetMode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { mode = targetMode }
            if targetMode == .leagues && leagueStates.isEmpty {
                Task { await reloadLeagues() }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: scaled(13), weight: .semibold))
                Text(label)
                    .font(.system(size: scaled(15), weight: .semibold))
            }
            .foregroundColor(isActive ? .white : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isActive
                    ? LinearGradient(
                        colors: targetMode == .leagues
                            ? [Color(red: 0.95, green: 0.65, blue: 0.15), Color(red: 0.85, green: 0.50, blue: 0.10)]
                            : [Theme.primaryBlue, Color(red: 0.20, green: 0.50, blue: 0.95)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.clear, Color.clear],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - ShareQuests Content

    private var shareQuestsContent: some View {
        VStack(spacing: 20) {
            portfolioTypeSelector
            portfolioSummaryCard
            holdingsSection
        }
    }

    private var portfolioTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availablePortfolios, id: \.type) { config in
                    let type = PortfolioType(rawValue: config.type) ?? .practice
                    PortfolioTypeButton(type: type, isSelected: selectedPortfolioType == type) {
                        selectedPortfolioType = type
                    }
                }
            }
        }
    }

    private var portfolioSummaryCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Total Value")
                    .font(.system(size: scaled(15)))
                    .foregroundColor(Theme.textSecondary)
                Text(viewModel.formattedTotalValue)
                    .font(.system(size: scaled(28), weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundColor(Theme.textPrimary)
            }
            ChangePill(percent: viewModel.totalChange)
            Divider().background(Theme.glassBorder)
            HStack {
                VStack(spacing: 4) {
                    Text("Cash").font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
                    Text(viewModel.formattedCash)
                        .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(Theme.textPrimary)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text("Holdings").font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
                    Text(viewModel.formattedHoldingsValue)
                        .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding()
        .glassCard()
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings").font(.system(size: scaled(17), weight: .semibold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(viewModel.holdings.count) stocks").font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
            }
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if viewModel.holdings.isEmpty {
                emptyHoldingsView
            } else {
                ForEach(viewModel.holdings) { holding in
                    HoldingRowView(holding: holding) { selectedHolding = holding }
                }
            }
        }
    }

    private var emptyHoldingsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase").font(.system(size: scaled(40))).foregroundColor(Theme.textMuted)
            Text("No holdings yet").font(.system(size: scaled(15))).foregroundColor(Theme.textSecondary)
            Text("Start trading to build your portfolio").font(.system(size: scaled(12))).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }

    // MARK: - Leagues Content

    private var leaguesContent: some View {
        VStack(spacing: 14) {
            if leaguesLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentYellow))
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if leagueStates.isEmpty {
                emptyLeaguesView
            } else {
                ForEach(leagueStates) { state in
                    LeaguePortfolioCard(state: state) {
                        selectedLeague = state.league
                    }
                }
            }
        }
    }

    private var emptyLeaguesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy").font(.system(size: scaled(40))).foregroundColor(Theme.textMuted)
            Text("No leagues yet").font(.system(size: scaled(15))).foregroundColor(Theme.textSecondary)
            Text("Create or join a league to compete with friends")
                .font(.system(size: scaled(12))).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }

    // MARK: - Reload

    private func reloadPortfolios() async {
        do {
            let dashboardResponse = try await APIService.shared.fetchDashboard()
            let portfolios: [PortfolioConfig] = dashboardResponse.data?.portfolios?.filter { $0.isSubscribed } ?? []
            await MainActor.run {
                availablePortfolios = portfolios
                if !portfolios.contains(where: { $0.type == selectedPortfolioType.rawValue }) {
                    if let first = portfolios.first {
                        selectedPortfolioType = PortfolioType(rawValue: first.type) ?? .practice
                    }
                }
            }
            await viewModel.fetchPortfolio(type: selectedPortfolioType)
        } catch {
            await MainActor.run {
                availablePortfolios = [PortfolioConfig(type: "default", label: "Practice", emoji: "🎯", color: "#3B82F6", isSubscribed: true)]
                selectedPortfolioType = .practice
            }
            await viewModel.fetchPortfolio(type: .practice)
        }
    }

    private func reloadLeagues() async {
        leaguesLoading = true
        if let leagues = try? await APIService.shared.fetchUserLeagues() {
            let userId = KeychainHelper.read("user_id") ?? ""
            var states = leagues.map { LeaguePortfolioState(league: $0) }
            // Load summary values for each league concurrently
            await withTaskGroup(of: (Int, LeaderboardUserPortfolio?).self) { group in
                for (i, state) in states.enumerated() {
                    group.addTask {
                        let p = try? await APIService.shared.fetchLeagueMemberPortfolio(
                            leagueId: state.league.id, memberId: userId)
                        return (i, p)
                    }
                }
                for await (i, p) in group {
                    guard let p else { continue }
                    let totalPence = p.cashBalance + p.holdings.reduce(0) { $0 + $1.quantity * $1.currentPrice }
                    let startPence = 10_000_000.0
                    states[i].cashBalance = p.cashBalance
                    states[i].totalValue = totalPence
                    states[i].returnPercent = ((totalPence - startPence) / startPence) * 100
                }
            }
            await MainActor.run { leagueStates = states }
        }
        leaguesLoading = false
    }
}

// MARK: - League Portfolio Card (summary tap-to-open)

struct LeaguePortfolioCard: View {
    let state: LeaguePortfolioState
    let onTap: () -> Void

    private var accentColor: Color { portfolioColor(for: state.league.competition_type ?? "annual") }

    private var statusInfo: (String, Color) {
        switch state.league.status {
        case "active":    return ("Active", Theme.accentGreen)
        case "pending":   return ("Pending", Theme.accentYellow)
        case "completed": return ("Ended", Theme.textMuted)
        default:          return (state.league.status?.capitalized ?? "", Theme.textSecondary)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accentColor)
                    .frame(width: 4, height: 56)

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: state.league.competition_type == "monthly"
                          ? "calendar.badge.clock" : "star.circle.fill")
                        .font(.system(size: scaled(18)))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.league.name)
                        .font(.system(size: scaled(15), weight: .semibold))
                        .foregroundColor(Theme.textPrimary).lineLimit(1)
                    HStack(spacing: 6) {
                        let typeLabel = (state.league.competition_type ?? "annual").capitalized
                        Text(typeLabel)
                            .font(.system(size: scaled(10), weight: .semibold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(accentColor.opacity(0.15)).cornerRadius(6)
                        let (sLabel, sColor) = statusInfo
                        Text(sLabel)
                            .font(.system(size: scaled(10), weight: .semibold))
                            .foregroundColor(sColor)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(sColor.opacity(0.15)).cornerRadius(6)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "£%.2f", state.totalValue / 100))
                        .font(.system(size: scaled(15), weight: .bold)).foregroundColor(Theme.textPrimary)
                    ChangePill(percent: state.returnPercent, compact: true)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: scaled(12), weight: .semibold))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Theme.glassBackground)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.glassBorder, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - League Portfolio Full View

struct LeaguePortfolioView: View {
    let league: League
    @Environment(\.dismiss) private var dismiss
    @State private var holdings: [LeaderboardUserPortfolio.Holding] = []
    @State private var cashBalance: Double = 0
    @State private var totalValue: Double = 0
    @State private var returnPercent: Double = 0
    @State private var isLoading = true
    @State private var tradingHolding: LeaderboardUserPortfolio.Holding? = nil

    private let startingBalance = 10_000_000.0 // £100,000 in pence
    private var accentColor: Color { portfolioColor(for: league.competition_type ?? "annual") }
    private var isActive: Bool { league.status == "active" }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        summaryCard
                        holdingsSection
                    }
                    .padding()
                }
                .refreshable { await loadPortfolio() }
            }
            .navigationTitle(league.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundColor(Theme.primaryBlue)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $tradingHolding) { holding in
                StockTradeSheet(
                    stock: Stock(
                        id: holding.symbol,
                        symbol: holding.symbol,
                        companyName: holding.companyName ?? holding.symbol,
                        price: holding.currentPrice / 100.0,
                        changeAmount: 0,
                        changePercent: 0,
                        sector: "League",
                        marketCap: 0
                    ),
                    leagueId: league.id,
                    leagueName: league.name,
                    initialTradeType: "sell",
                    initialQuantity: String(Int(holding.quantity)),
                    onTradeSuccess: { Task { await loadPortfolio() } }
                )
            }
        }
        .task { await loadPortfolio() }
    }

    // MARK: Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            // League type badge
            HStack(spacing: 8) {
                Image(systemName: league.competition_type == "monthly" ? "calendar.badge.clock" : "star.circle.fill")
                    .foregroundColor(accentColor)
                Text((league.competition_type ?? "annual").capitalized + " League")
                    .font(.system(size: scaled(12), weight: .semibold)).foregroundColor(accentColor)
                Spacer()
                let (sLabel, sColor) = statusInfo
                Text(sLabel)
                    .font(.system(size: scaled(10), weight: .semibold)).foregroundColor(sColor)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(sColor.opacity(0.15)).cornerRadius(8)
            }

            Divider().background(Theme.glassBorder)

            VStack(spacing: 4) {
                Text("Total Value").font(.system(size: scaled(15))).foregroundColor(Theme.textSecondary)
                Text(String(format: "£%.2f", totalValue / 100))
                    .font(.system(size: scaled(28), weight: .bold)).foregroundColor(Theme.textPrimary)
                    .minimumScaleFactor(0.7).lineLimit(1)
            }

            ChangePill(percent: returnPercent)

            Divider().background(Theme.glassBorder)

            HStack {
                VStack(spacing: 4) {
                    Text("Cash").font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
                    Text(String(format: "£%.2f", cashBalance / 100))
                        .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(Theme.textPrimary)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text("Holdings").font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
                    Text(String(format: "£%.2f", (totalValue - cashBalance) / 100))
                        .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(Theme.textPrimary)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text("Members").font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
                    Text("\(league.member_count ?? 0)")
                        .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding()
        .glassCard()
    }

    // MARK: Holdings Section

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings").font(.system(size: scaled(17), weight: .semibold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(holdings.count) stocks").font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
            }

            if isLoading {
                ProgressView().tint(accentColor).frame(maxWidth: .infinity, minHeight: 80)
            } else if holdings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "briefcase").font(.system(size: scaled(36))).foregroundColor(Theme.textMuted)
                    Text("No holdings yet").font(.system(size: scaled(15))).foregroundColor(Theme.textSecondary)
                    if isActive {
                        Text("Go to Stocks to make your first league trade")
                            .font(.system(size: scaled(12))).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
                    } else {
                        Text("Trading opens once the league is active")
                            .font(.system(size: scaled(12))).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40).glassCard()
            } else {
                ForEach(holdings, id: \.symbol) { holding in
                    leagueHoldingRow(holding: holding)
                }
            }
        }
    }

    private func leagueHoldingRow(holding: LeaderboardUserPortfolio.Holding) -> some View {
        let value = holding.quantity * holding.currentPrice
        let cost = holding.quantity * holding.averagePrice
        let plPct = cost > 0 ? ((value - cost) / cost) * 100 : 0
        return Button {
            if isActive { tradingHolding = holding }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.companyName ?? holding.symbol)
                        .font(.system(size: scaled(15), weight: .semibold))
                        .foregroundColor(Theme.textPrimary).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(holding.symbol).font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
                        Text("\(Int(holding.quantity)) shares").font(.system(size: scaled(12), weight: .bold)).foregroundColor(.white)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "£%.2f", value / 100))
                        .font(.system(size: scaled(12), weight: .semibold)).foregroundColor(Theme.textPrimary)
                    ChangePill(percent: plPct)
                }
            }
            .padding().glassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusInfo: (String, Color) {
        switch league.status {
        case "active":    return ("Active", Theme.accentGreen)
        case "pending":   return ("Pending", Theme.accentYellow)
        case "completed": return ("Ended", Theme.textMuted)
        default:          return (league.status?.capitalized ?? "", Theme.textSecondary)
        }
    }

    private func loadPortfolio() async {
        isLoading = true
        let userId = KeychainHelper.read("user_id") ?? ""
        if let p = try? await APIService.shared.fetchLeagueMemberPortfolio(
            leagueId: league.id, memberId: userId) {
            holdings = p.holdings
            cashBalance = p.cashBalance
            let holdingsValue = p.holdings.reduce(0.0) { $0 + $1.quantity * $1.currentPrice }
            totalValue = cashBalance + holdingsValue
            returnPercent = ((totalValue - startingBalance) / startingBalance) * 100
        }
        isLoading = false
    }
}

// MARK: - Portfolio Type Button

struct PortfolioTypeButton: View {
    let type: PortfolioType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(type.emoji)
                Text(type.displayName)
                    .font(.system(size: scaled(15), weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                isSelected
                    ? LinearGradient(colors: portfolioGradient(for: type.rawValue),
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Theme.glassBackground, Theme.glassBackground],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .foregroundColor(isSelected ? .white : Theme.textSecondary)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Color.clear : Theme.glassBorder, lineWidth: 1)
            )
            .shadow(color: isSelected ? portfolioColor(for: type.rawValue).opacity(0.45) : .clear,
                    radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Holding Row View

struct HoldingRowView: View {
    let holding: Holding
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.companyName)
                        .font(.system(size: scaled(15), weight: .semibold)).lineLimit(1)
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 8) {
                        Text(holding.symbol).font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary).lineLimit(1)
                        Text("\(holding.quantity) shares").font(.system(size: scaled(12), weight: .bold)).foregroundColor(.white)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(holding.formattedValue)
                        .font(.system(size: scaled(12), weight: .semibold)).lineLimit(1).foregroundColor(Theme.textPrimary)
                    ChangePill(percent: holding.changePercent)
                }
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Holding → Stock conversion

extension Holding {
    func toStock() -> Stock {
        Stock(
            id: self.id,
            symbol: self.symbol,
            companyName: self.companyName,
            price: self.currentPrice,
            changeAmount: 0,
            changePercent: self.changePercent,
            sector: "Portfolio",
            marketCap: 0
        )
    }
}

// MARK: - Portfolio Type Enum

enum PortfolioType: String, CaseIterable {
    case practice = "default"
    case weekly   = "weekly"
    case monthly  = "monthly"
    case annual   = "annual"

    var displayName: String {
        switch self {
        case .practice: return "Practice"
        case .weekly:   return "Weekly"
        case .monthly:  return "Monthly"
        case .annual:   return "Annual"
        }
    }

    var emoji: String {
        switch self {
        case .practice: return "🎯"
        case .weekly:   return "⚡"
        case .monthly:  return "📅"
        case .annual:   return "🏆"
        }
    }

    var color: Color {
        switch self {
        case .practice: return Theme.accentGreen
        case .weekly:   return Theme.primaryBlue
        case .monthly:  return Theme.accentPurple
        case .annual:   return Theme.accentYellow
        }
    }
}

// MARK: - Holding Model

struct Holding: Identifiable {
    let id: String
    let symbol: String
    let companyName: String
    let quantity: Int
    let averagePrice: Double
    let currentPrice: Double

    var value: Double { Double(quantity) * currentPrice }

    var changePercent: Double {
        guard averagePrice > 0 else { return 0 }
        return ((currentPrice - averagePrice) / averagePrice) * 100
    }

    var formattedValue: String  { "£\(String(format: "%.2f", value))" }
    var formattedChange: String { String(format: "%+.2f%%", changePercent) }
    var formattedPrice: String  { "£\(String(format: "%.2f", currentPrice))" }
}

// MARK: - Portfolio ViewModel

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var holdings: [Holding] = []
    @Published var cashBalance: Double = 0
    @Published var initialBalance: Double = 100000
    @Published var totalPortfolioValue: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    var totalValue: Double   { totalPortfolioValue }
    var holdingsValue: Double { holdings.reduce(0) { $0 + $1.value } }

    var totalChange: Double {
        guard initialBalance > 0 else { return 0 }
        return ((totalValue - initialBalance) / initialBalance) * 100
    }

    var formattedTotalValue:    String { "£\(String(format: "%.2f", totalValue))" }
    var formattedCash:          String { "£\(String(format: "%.2f", cashBalance))" }
    var formattedHoldingsValue: String { "£\(String(format: "%.2f", holdingsValue))" }
    var formattedChange:        String { String(format: "%+.2f%%", totalChange) }

    func fetchPortfolio(type: PortfolioType) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.fetchPortfolio(type: type.rawValue)
            if let portfolio = response.portfolio {
                cashBalance = portfolio.cashBalanceValue
                initialBalance = portfolio.initialBalanceValue
                totalPortfolioValue = portfolio.totalPortfolioValue
            }
            if let holdingsData = response.holdings, !holdingsData.isEmpty {
                let symbols = holdingsData.map { $0.symbol }
                let livePrices = (try? await apiService.fetchBatchPrices(symbols: symbols)) ?? [:]
                holdings = holdingsData.map { h in
                    let livePricePence = livePrices[h.symbol]?.price
                    let pricePence = livePricePence ?? h.mid ?? h.mid_price ?? h.current_price
                    return Holding(
                        id: h.symbol, symbol: h.symbol, companyName: h.displayName,
                        quantity: h.quantity,
                        averagePrice: h.average_price / 100,
                        currentPrice: pricePence / 100
                    )
                }
            } else {
                holdings = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func executeTrade(portfolioType: PortfolioType, symbol: String, companyName: String,
                      price: Double, action: String, quantity: Int) async throws {
        let pricePence = Int(round(price * 100))
        let _ = try await apiService.executeMobileTrade(
            portfolioType: portfolioType.rawValue, symbol: symbol, companyName: companyName,
            action: action, quantity: quantity, price: Double(pricePence))
        await fetchPortfolio(type: portfolioType)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let selectPortfolioType = Notification.Name("selectPortfolioType")
}

#Preview {
    PortfolioView()
}
