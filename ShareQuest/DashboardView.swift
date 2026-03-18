//
//  DashboardView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

/// Dashboard/Home screen - matches React Native index.tsx
struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showXPToast = false
    @State private var xpGained = 0
    @State private var showNotifications = false
    // Auto-scroll state for ticker
    @State private var tickerScrollIndex: Int = 0
    private let tickerAutoscrollInterval: TimeInterval = 2.5
    // Computed safe display name: prefer firstName when present and non-empty
    private var displayFirstName: String {
        if let user = authManager.currentUser {
            if let first = user.firstName, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return first
            }
            if !user.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return user.displayName
            }
            if !user.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return user.username
            }
        }
        // Try persisted first name from UserDefaults (set during signIn/loadUserProfile)
        if let persisted = UserDefaults.standard.string(forKey: "user_first_name"), !persisted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return persisted
        }
        return viewModel.username
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
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
                
                VStack(spacing: 12) {
                    // Fixed header at the top so user name and bell are always visible
                    headerSection
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Gamification Bar
                            if viewModel.gamProfile != nil {
                                gamificationBar
                            }
                            
                            // Stock Ticker
                            stockTickerSection
                            
                            // Swipeable Portfolio Cards
                            portfolioCardsSection
                            
                            // Daily Challenges
                            if !viewModel.dailyChallenges.isEmpty {
                                challengesSection
                            }
                            
                            // Market Sentiment
                            if viewModel.marketSentiment != nil {
                                marketSentimentSection
                            }
                            
                            // XP Activity Feed
                            if !viewModel.recentXP.isEmpty {
                                xpActivitySection
                            }
                            
                            // Bottom padding for tab bar
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
                
                // XP Toast
                if showXPToast {
                    XPToastView(amount: xpGained)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            // Hide the navigation bar to reclaim vertical space; bell moved into the header
            .navigationBarHidden(true)
            .task {
                // Ensure we have the latest user profile (firstName) before loading dashboard data
                await authManager.loadUserProfile()
                await viewModel.loadData()
            }
            .onChange(of: viewModel.xpDelta) { _, newValue in
                if newValue > 0 {
                    xpGained = newValue
                    withAnimation {
                        showXPToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showXPToast = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top) {
            // Greeting
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.greeting)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Text(displayFirstName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minHeight: 22)
            }
            
            Spacer()
            
            // Top-line: market status pill, optional market sentiment pill, and bell
            HStack(spacing: 12) {
                marketPill
                if let sentiment = viewModel.marketSentiment {
                    marketSentimentPill(sentiment: sentiment)
                }
                Button(action: { showNotifications = true }) {
                    Image(systemName: "bell")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color(red: 0.067, green: 0.094, blue: 0.153))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.top)
        // Present notifications sheet when bell tapped
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }
    
    // Extracted market pill for reuse
    private var marketPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isMarketOpen ? Theme.accentGreen : Theme.accentRed)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isMarketOpen ? "Open" : "Closed")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(viewModel.ukTime)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(viewModel.isMarketOpen ? Theme.accentGreen.opacity(0.15) : Theme.accentRed.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(viewModel.isMarketOpen ? Theme.accentGreen.opacity(0.3) : Theme.accentRed.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // Small pill summarising market sentiment for the top banner
    private func marketSentimentPill(sentiment: MarketSentimentData) -> some View {
        HStack(spacing: 8) {
            Image(systemName: sentiment.overall?.sentiment == "bullish" ? "arrow.up.right" : (sentiment.overall?.sentiment == "bearish" ? "arrow.down.right" : "minus"))
                .font(.caption2)
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 0) {
                Text(sentiment.overall?.sentiment?.capitalized ?? "Neutral")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text("G:\(sentiment.metrics?.gainerCount ?? 0)")
                        .font(.caption2)
                        .foregroundColor(Theme.accentGreen)
                    Text("L:\(sentiment.metrics?.loserCount ?? 0)")
                        .font(.caption2)
                        .foregroundColor(Theme.accentRed)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.067, green: 0.094, blue: 0.153)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.glassBorder, lineWidth: 1))
    }
    
    // MARK: - Gamification Bar
    private var gamificationBar: some View {
        HStack(spacing: 16) {
            // Level and Name
            HStack(spacing: 6) {
                Image(systemName: levelIcon)
                    .foregroundColor(Theme.primaryBlue)
                Text("Lv.\(viewModel.gamProfile?.playerLevel ?? 1)")
                    .fontWeight(.bold)
                    .foregroundColor(Theme.primaryBlue)
                Text(viewModel.gamProfile?.playerLevelName ?? "Rookie")
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primaryBlue)
            }
            .font(.subheadline)
            
            Spacer()
            
            // XP (use displayedXP which accounts for local onboarding XP fallback)
            Text("\(viewModel.displayedXP)/\(viewModel.displayedXPForNext) XP")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 1, green: 0.84, blue: 0)) // Gold
            
            // Streak
            StreakBadge(streak: viewModel.streak)
        }
        .padding()
        .background(Theme.glassBackground)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
    }
    
    private var levelIcon: String {
        let level = viewModel.gamProfile?.playerLevel ?? 1
        let icons = [
            1: "graduationcap",
            2: "eye",
            3: "arrow.up.right",
            4: "arrow.left.arrow.right",
            5: "briefcase",
            6: "chart.bar",
            7: "banknote",
            8: "shield",
            9: "diamond",
            10: "trophy"
        ]
        return icons[level] ?? "star"
    }
    
    // MARK: - Stock Ticker
    private var stockTickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Auto-scrolling horizontal ticker. Uses ScrollViewReader and a Timer publisher to scroll between items.
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.tickerStocks.indices, id: \.self) { index in
                            let stock = viewModel.tickerStocks[index]
                            TickerStockView(stock: stock)
                                .id(stock.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onReceive(Timer.publish(every: tickerAutoscrollInterval, on: .main, in: .common).autoconnect()) { _ in
                    guard !viewModel.tickerStocks.isEmpty else { return }
                    tickerScrollIndex = (tickerScrollIndex + 1) % max(viewModel.tickerStocks.count, 1)
                    let target = viewModel.tickerStocks[tickerScrollIndex].id
                    withAnimation(.easeInOut(duration: 0.6)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Portfolio Cards Section
    private var portfolioCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Portfolios")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.portfolioCards) { card in
                        PortfolioCardView(portfolio: card)
                    }
                }
            }
        }
    }
    
    // MARK: - Challenges Section
    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Challenges")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                ForEach(viewModel.dailyChallenges.prefix(3)) { challenge in
                    ChallengeRowView(challenge: challenge)
                }
            }
            
            if viewModel.dailyChallenges.count > 3 {
                Button(action: {}) {
                    Text("View All Challenges →")
                        .font(.caption)
                        .foregroundColor(Theme.accentYellow)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Market Sentiment Section
    private var marketSentimentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Sentiment")
                .font(.headline)
                .foregroundColor(.white)
            
            if let sentiment = viewModel.marketSentiment {
                HStack {
                    // Sentiment Indicator
                    VStack(spacing: 4) {
                        Image(systemName: sentimentIcon(for: sentiment.overall?.sentiment))
                            .font(.title)
                            .foregroundColor(sentimentColor(for: sentiment.overall?.sentiment))
                        Text(sentiment.overall?.sentiment?.capitalized ?? "Neutral")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(sentimentColor(for: sentiment.overall?.sentiment))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Gainers/Losers
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "arrow.up")
                                .foregroundColor(Theme.accentGreen)
                            Text("\(sentiment.metrics?.gainerCount ?? 0)")
                                .foregroundColor(Theme.accentGreen)
                        }
                        Text("Gainers")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "arrow.down")
                                .foregroundColor(Theme.accentRed)
                            Text("\(sentiment.metrics?.loserCount ?? 0)")
                                .foregroundColor(Theme.accentRed)
                        }
                        Text("Losers")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .glassCard()
            }
        }
    }
    
    private func sentimentIcon(for sentiment: String?) -> String {
        switch sentiment?.lowercased() {
        case "bullish": return "arrow.up.right.circle.fill"
        case "bearish": return "arrow.down.right.circle.fill"
        default: return "minus.circle.fill"
        }
    }
    
    private func sentimentColor(for sentiment: String?) -> Color {
        switch sentiment?.lowercased() {
        case "bullish": return Theme.accentGreen
        case "bearish": return Theme.accentRed
        default: return Theme.textSecondary
        }
    }
    
    // MARK: - XP Activity Section
    private var xpActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent XP")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                ForEach(viewModel.recentXP.prefix(5)) { activity in
                    XPActivityRow(activity: activity)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StreakBadge: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text("\(streak)")
                .fontWeight(.bold)
                .foregroundColor(.orange)
        }
        .font(.subheadline)
    }
}

struct TickerStockView: View {
    let stock: TickerStock

    var body: some View {
        // Wrap the ticker card in a NavigationLink to the existing StockDetailView
        NavigationLink(destination: StockDetailView(stock: Stock(
            id: stock.symbol,
            symbol: stock.symbol,
            companyName: stock.companyName,
            price: stock.pencePrice / 100.0, // convert pence to pounds
            changeAmount: (stock.pencePrice / 100.0) * (stock.changePercent / 100.0),
            changePercent: stock.changePercent,
            sector: "", // unknown here
            marketCap: 0
        ))) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stock.shortName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(stock.symbol)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(stock.formattedPrice)
                        .font(.caption)
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Image(systemName: stock.changePercent >= 0 ? "arrow.up" : "arrow.down")
                        Text(stock.formattedChange)
                    }
                    .font(.caption2)
                    .foregroundColor(stock.changePercent >= 0 ? Theme.accentGreen : Theme.accentRed)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.glassBackground)
            .cornerRadius(8)
            .frame(minWidth: 120)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChallengeRowView: View {
    let challenge: ChallengeData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title ?? "Challenge")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                if let description = challenge.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Progress
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(challenge.reward) XP")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.accentYellow)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.glassBackground)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(challenge.isCompleted ? Theme.accentGreen : Theme.primaryBlue)
                            .frame(width: geometry.size.width * challenge.progressPercent)
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
        .padding()
        .glassCard()
    }
}

struct XPActivityRow: View {
    let activity: XPActivity
    
    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(Theme.accentYellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.source)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                if let description = activity.description {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Text("+\(activity.amount) XP")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Theme.accentYellow)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .glassCard()
    }
}

struct XPToastView: View {
    let amount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundColor(Theme.accentYellow)
            Text("+\(amount) XP")
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
        )
        .padding(.top, 60)
    }
}

// MARK: - Ticker Stock Model

struct TickerStock: Identifiable {
    // Use symbol as stable id
    var id: String { symbol }
    let symbol: String
    let companyName: String
    let pencePrice: Double // price in pence (e.g., 275.0 means 275p)
    let changePercent: Double

    // Format price in pence. If pence has no fractional component show as integer ("275p"), otherwise show one or two decimals ("275.5p" / "275.50p").
    var formattedPrice: String {
        // Determine if there is a fractional part
        let rounded = (pencePrice * 100).rounded() / 100.0
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))p"
        }
        // Show up to two decimals, but trim trailing zeros
        var s = String(format: "%.2f", rounded)
        // Trim unnecessary trailing zeros and dot
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
            s.removeLast()
        }
        return "\(s)p"
    }

    var formattedChange: String {
        String(format: "%+.1f%%", changePercent)
    }

    // Short name: first two words of companyName to save space in ticker
    var shortName: String {
        let parts = companyName.split(separator: " ")
        if parts.count <= 2 {
            return companyName
        }
        return parts.prefix(2).joined(separator: " ")
    }
}

// MARK: - Dashboard ViewModel

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var username = "Trader"
    @Published var isMarketOpen = false
    @Published var ukTime = ""
    @Published var streak = 0
    @Published var gamProfile: GamificationProfileResponse?
    // Displayed XP values (may include unsynced local onboarding XP)
    @Published var displayedXP: Int = 0
    @Published var displayedXPForNext: Int = 100
    @Published var marketSentiment: MarketSentimentData?
    @Published var dailyChallenges: [ChallengeData] = []
    @Published var portfolioCards: [PortfolioSummary] = []
    @Published var recentXP: [XPActivity] = []
    @Published var tickerStocks: [TickerStock] = []
    @Published var isLoading = false
    @Published var xpDelta = 0
    
    private var previousXP = 0
    private let apiService = APIService.shared
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning," }
        if hour < 17 { return "Good afternoon," }
        return "Good evening,"
    }
    
    func loadData() async {
        isLoading = true
        updateMarketStatus()
        
        // Load all data in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadDashboardData() }
            group.addTask { await self.recordLogin() }
            group.addTask { await self.loadGamificationProfile() }
            group.addTask { await self.loadPortfolios() }
            group.addTask { await self.loadTickerStocks() }
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
    
    private func updateMarketStatus() {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "HH:mm"
        
        let now = Date()
        ukTime = "\(formatter.string(from: now)) UK"
        
        let calendar = Calendar.current
        guard let londonTZ = TimeZone(identifier: "Europe/London") else { return }
        let components = calendar.dateComponents(in: londonTZ, from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let weekday = components.weekday ?? 1
        
        let isWeekend = weekday == 1 || weekday == 7
        let afterOpen = hour > 8 || (hour == 8 && minute >= 0)
        let beforeClose = hour < 16 || (hour == 16 && minute <= 30)
        
        isMarketOpen = !isWeekend && afterOpen && beforeClose
    }
    
    private func loadDashboardData() async {
        do {
            let response = try await apiService.fetchDashboard()
            marketSentiment = response.sentiment
        } catch {
            // Dashboard data error - suppressed in production
        }
    }
    
    private func recordLogin() async {
        do {
            let response = try await apiService.recordDailyLogin()
            streak = response.streak
            
            // Load challenges after login
            let challengesResponse = try await apiService.getDailyChallenges()
            dailyChallenges = challengesResponse.allChallenges
        } catch {
            // Login record error - suppressed in production
        }
    }
    
    private func loadGamificationProfile() async {
        do {
            let response = try await apiService.getGamificationProfile()
            
            // Check for XP change
            if previousXP > 0 && response.xp > previousXP {
                xpDelta = response.xp - previousXP
            }
            previousXP = response.xp
            
            gamProfile = response
            recentXP = response.xpActivities
            
            // Account for any local onboarding XP that might not yet be reflected on the server.
            let localOnboardingXP = UserDefaults.standard.integer(forKey: "onboarding_xp")
            // If the server XP is less than the locally-stored onboarding XP, add it as a fallback.
            if response.xp < localOnboardingXP {
                displayedXP = response.xp + localOnboardingXP
            } else {
                displayedXP = response.xp
            }
            displayedXPForNext = response.xpForNextLevel
        } catch {
            // Gamification profile error - suppressed in production
        }
    }
    
    private func loadPortfolios() async {
        // Create portfolio cards for subscribed types
        let configs: [(type: String, name: String, emoji: String, colors: [Color])] = [
            ("default", "Practice", "🎯", [Color(red: 0.231, green: 0.510, blue: 0.965), Color(red: 0.149, green: 0.388, blue: 0.918)]),
            ("weekly", "Weekly", "⚡", [Color(red: 0.388, green: 0.400, blue: 0.945), Color(red: 0.263, green: 0.224, blue: 0.792)]),
            ("monthly", "Monthly", "📅", [Color(red: 0.545, green: 0.361, blue: 0.965), Color(red: 0.486, green: 0.227, blue: 0.929)])
        ]
        
        var cards: [PortfolioSummary] = []
        
        for config in configs {
            do {
                let response = try await apiService.fetchPortfolio(type: config.type)
                if let portfolio = response.portfolio {
                    let totalValue = portfolio.totalPortfolioValue > 0 ? portfolio.totalPortfolioValue : portfolio.cashBalanceValue
                    let initialBalance = portfolio.initialBalanceValue
                    let changePercent = initialBalance > 0 ? ((totalValue - initialBalance) / initialBalance) * 100 : 0
                    
                    cards.append(PortfolioSummary(
                        id: config.type,
                        name: config.name,
                        emoji: config.emoji,
                        value: totalValue,
                        changePercent: changePercent,
                        gradientColors: config.colors
                    ))
                }
            } catch {
                // Add default card if fetch fails
                cards.append(PortfolioSummary(
                    id: config.type,
                    name: config.name,
                    emoji: config.emoji,
                    value: 100000,
                    changePercent: 0,
                    gradientColors: config.colors
                ))
            }
        }
        
        portfolioCards = cards
    }
    
    private func loadTickerStocks() async {
        do {
            let stocks = try await apiService.fetchFTSE100(limit: 345)
            tickerStocks = stocks.map { stock in
                TickerStock(
                    symbol: stock.symbol,
                    companyName: stock.displayName, // Use displayName which falls back
                    pencePrice: stock.rawPencePrice, // Use raw pence price
                    changePercent: stock.displayChangePercent
                )
            }
        } catch {
            // Demo data
            tickerStocks = [
                TickerStock(symbol: "SHEL", companyName: "Shell plc", pencePrice: 2545.0, changePercent: 1.4),
                TickerStock(symbol: "AZN", companyName: "AstraZeneca plc", pencePrice: 10550.0, changePercent: -1.1),
                TickerStock(symbol: "HSBA", companyName: "HSBC Holdings plc", pencePrice: 645.0, changePercent: 0.8),
                TickerStock(symbol: "BP", companyName: "BP plc", pencePrice: 475.0, changePercent: 2.3)
            ]
        }
    }
}

// MARK: - Portfolio Summary Model

struct PortfolioSummary: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let value: Double
    let changePercent: Double
    let gradientColors: [Color]
    
    var formattedValue: String {
        "£\(String(format: "%.2f", value))"
    }
    
    var formattedChange: String {
        String(format: "%+.2f%%", changePercent)
    }
}

// MARK: - Portfolio Card View

struct PortfolioCardView: View {
    let portfolio: PortfolioSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(portfolio.emoji)
                    .font(.title2)
                Text(portfolio.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Text(portfolio.formattedValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: portfolio.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(portfolio.formattedChange)
            }
            .font(.caption)
            .foregroundColor(portfolio.changePercent >= 0 ? Theme.accentGreen : Theme.accentRed)
        }
        .padding()
        .frame(width: 160)
        .background(
            LinearGradient(
                colors: portfolio.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager.shared)
}
