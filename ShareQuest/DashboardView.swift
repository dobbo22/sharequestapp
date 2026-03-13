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
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showXPToast = false
    @State private var xpGained = 0
    
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with greeting and market status
                        headerSection
                        
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
                
                // XP Toast
                if showXPToast {
                    XPToastView(amount: xpGained)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("ShareQuest")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "bell")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task {
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top) {
            // Greeting
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.greeting)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Text(authManager.currentUser?.displayName ?? viewModel.username)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Market Status Pill
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
        .padding(.top)
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
            
            // XP
            Text("\(viewModel.gamProfile?.xp ?? 0)/\(viewModel.gamProfile?.xpForNextLevel ?? 100) XP")
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.tickerStocks) { stock in
                        TickerStockView(stock: stock)
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
        HStack(spacing: 8) {
            Text(stock.symbol)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(stock.formattedPrice)
                .font(.caption)
                .foregroundColor(.white)
            
            HStack(spacing: 2) {
                Image(systemName: stock.changePercent >= 0 ? "arrow.up" : "arrow.down")
                Text(stock.formattedChange)
            }
            .font(.caption2)
            .foregroundColor(stock.changePercent >= 0 ? Theme.accentGreen : Theme.accentRed)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.glassBackground)
        .cornerRadius(8)
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
    let id = UUID()
    let symbol: String
    let price: Double
    let changePercent: Double
    
    var formattedPrice: String {
        "£\(String(format: "%.2f", price))"
    }
    
    var formattedChange: String {
        String(format: "%+.1f%%", changePercent)
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
            print("Dashboard data error: \(error)")
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
            print("Login record error: \(error)")
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
        } catch {
            print("Gamification profile error: \(error)")
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
            let stocks = try await apiService.fetchFTSE100(limit: 10)
            tickerStocks = stocks.map { stock in
                TickerStock(
                    symbol: stock.symbol,
                    price: stock.displayPrice,
                    changePercent: stock.displayChangePercent
                )
            }
        } catch {
            // Demo data
            tickerStocks = [
                TickerStock(symbol: "SHEL", price: 25.42, changePercent: 1.4),
                TickerStock(symbol: "AZN", price: 105.50, changePercent: -1.1),
                TickerStock(symbol: "HSBA", price: 6.45, changePercent: 0.8),
                TickerStock(symbol: "BP", price: 4.75, changePercent: 2.3)
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
