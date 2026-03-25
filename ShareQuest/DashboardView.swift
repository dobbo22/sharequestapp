//
//  DashboardView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

// MARK: - Level System (mirrors GamificationService.ts LEVEL_THRESHOLDS)

private struct SQLevel {
    let level: Int
    let minXP: Int
    let name: String
    let icon: String
}

// Gaps: L1→2=500, L2→3=1000 … L19→20=9500 (mirrors GamificationService.ts LEVEL_THRESHOLDS)
private let sqLevelTable: [SQLevel] = [
    .init(level: 1,  minXP: 0,      name: "Rookie",             icon: "graduationcap"),
    .init(level: 2,  minXP: 500,    name: "Market Watcher",     icon: "eye"),
    .init(level: 3,  minXP: 1500,   name: "Day Trader",         icon: "arrow.up.right"),
    .init(level: 4,  minXP: 3000,   name: "Swing Trader",       icon: "arrow.left.arrow.right"),
    .init(level: 5,  minXP: 5000,   name: "Portfolio Pro",      icon: "briefcase"),
    .init(level: 6,  minXP: 7500,   name: "Fund Manager",       icon: "chart.bar"),
    .init(level: 7,  minXP: 10500,  name: "Market Maker",       icon: "building.columns"),
    .init(level: 8,  minXP: 14000,  name: "Trading Elite",      icon: "banknote"),
    .init(level: 9,  minXP: 18000,  name: "Hedge Fund Boss",    icon: "shield"),
    .init(level: 10, minXP: 22500,  name: "Wall Street Wolf",   icon: "trophy"),
    .init(level: 11, minXP: 27500,  name: "Alpha Seeker",       icon: "sparkles"),
    .init(level: 12, minXP: 33000,  name: "Quant Master",       icon: "function"),
    .init(level: 13, minXP: 39000,  name: "Market Sage",        icon: "eyes"),
    .init(level: 14, minXP: 45500,  name: "Risk Architect",     icon: "puzzlepiece.fill"),
    .init(level: 15, minXP: 52500,  name: "Grand Trader",       icon: "crown"),
    .init(level: 16, minXP: 60000,  name: "Market Oracle",      icon: "globe"),
    .init(level: 17, minXP: 68000,  name: "Apex Investor",      icon: "bolt.fill"),
    .init(level: 18, minXP: 76500,  name: "Titan of Finance",   icon: "mountain.2"),
    .init(level: 19, minXP: 85500,  name: "Financial Elite",    icon: "diamond"),
    .init(level: 20, minXP: 95000,  name: "ShareQuest Legend",  icon: "star.fill"),
]

/// Returns (level, name, icon, progressXP within level, rangeXP of level) for any total XP.
func sqLevelInfo(totalXP: Int) -> (level: Int, name: String, icon: String, progressXP: Int, rangeXP: Int) {
    let current = sqLevelTable.last(where: { totalXP >= $0.minXP }) ?? sqLevelTable[0]
    let next = sqLevelTable.first(where: { $0.level == current.level + 1 })
    let progressXP = totalXP - current.minXP
    let rangeXP = (next?.minXP ?? current.minXP + 50000) - current.minXP
    return (current.level, current.name, current.icon, progressXP, rangeXP)
}

/// Accent colour that scales with prestige.
func sqLevelColor(_ level: Int) -> Color {
    switch level {
    case 1...3:   return Color(red: 0.23, green: 0.51, blue: 0.96)  // blue
    case 4...6:   return Color(red: 0.18, green: 0.78, blue: 0.45)  // green
    case 7...9:   return Color(red: 0.55, green: 0.36, blue: 0.96)  // purple
    case 10:      return Color(red: 1.0,  green: 0.84, blue: 0.0)   // gold
    case 11...14: return Color(red: 0.96, green: 0.62, blue: 0.04)  // orange
    case 15...17: return Color(red: 0.94, green: 0.27, blue: 0.27)  // red
    default:      return Color(red: 1.0,  green: 0.84, blue: 0.0)   // legendary gold
    }
}

/// Dashboard/Home screen - matches React Native index.tsx
struct DashboardView: View {
    @Binding var selectedTab: Int
    // Level up animation state
    @State private var showLevelUp = false
    @State private var levelUpInfo: (level: Int, name: String, icon: String)? = nil
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showXPToast = false
    @State private var xpGained = 0
    @State private var showNotifications = false
    @State private var unreadNotificationCount = 0
    @State private var showProfile = false
    @State private var selectedChallenge: ChallengeData? = nil
    @State private var showStockHuntHub = false
    @State private var taskSectionTab = 0
    @State private var isAnnualSubscriber: Bool? = nil
    @State private var showSubscriptions = false
    @State private var promoCardIndex = 0
    // Global challenge completion popup
    @State private var pendingCompletions: [ChallengeCompletion] = []
    @State private var showCompletionPopup = false
    // Auto-scroll state for ticker — timer stored as stable let so it doesn't recreate on re-renders
    @State private var tickerScrollIndex: Int = 0
    private let tickerTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()
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
                Theme.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: vscaled(8)) {

                    // Fixed header at the top so user name and bell are always visible
                    headerSection

                    ScrollView {
                        VStack(spacing: vscaled(10)) {
                            // Gamification Bar (always reserve space, show placeholder if nil)
                            Group {
                                if viewModel.gamProfile != nil {
                                    gamificationBar
                                } else {
                                    HStack(spacing: 16) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.primaryBlue.opacity(0.3))
                                            .frame(width: 80, height: 18)
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 1, green: 0.84, blue: 0).opacity(0.3))
                                            .frame(width: 60, height: 18)
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange.opacity(0.3))
                                            .frame(width: 40, height: 18)
                                    }
                                    .padding()
                                    .background(Theme.backgroundCard)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.glassBorder, lineWidth: 1))
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Stock Ticker
                            stockTickerSection
                            
                            // Swipeable Portfolio Cards
                            portfolioCardsSection
                            
                            // Daily Challenges (always show section so all-done state is visible)
                            challengesSection
                            
                            // Market Sentiment
                            if viewModel.marketSentiment != nil {
                                marketSentimentSection
                            }

                            // Bottom padding for tab bar
                            Spacer(minLength: vscaled(80))
                        }
                        .padding(.horizontal)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
                .padding(.top, vscaled(4))
                
                // XP Toast
                if showXPToast {
                    XPToastView(amount: xpGained)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }

                // Level Up Overlay
                if showLevelUp, let info = levelUpInfo {
                    LevelUpOverlay(level: info.level, levelName: info.name, icon: info.icon, onDismiss: { withAnimation { showLevelUp = false } })
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(200)
                }
            }
            // Hide the navigation bar to reclaim vertical space; bell moved into the header
            .navigationBarHidden(true)
            .task {
                // Ensure we have the latest user profile (firstName) before loading dashboard data
                await authManager.loadUserProfile()
                await viewModel.loadData()
                let subs = try? await APIService.shared.fetchUserSubscriptions()
                isAnnualSubscriber = subs?.annual ?? false
                await refreshUnreadCount()
            }
            .onAppear {
                // Refresh subscription status whenever dashboard becomes visible
                // (e.g. returning from ShareQuests tab after subscribing)
                Task {
                    let subs = try? await APIService.shared.fetchUserSubscriptions()
                    isAnnualSubscriber = subs?.annual ?? false
                }
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
            .onChange(of: viewModel.displayedXP) { _, newXP in
                let newLevelInfo = sqLevelInfo(totalXP: newXP)
                let userId = UserDefaults.standard.string(forKey: "user_id") ?? "unknown"
                let shownKey = "levelUpShownForLevel_\(userId)"
                let lastShownLevel = UserDefaults.standard.integer(forKey: shownKey)
                // Only show once per level — never re-show on login/reload
                if newLevelInfo.level > lastShownLevel {
                    UserDefaults.standard.set(newLevelInfo.level, forKey: shownKey)
                    levelUpInfo = (newLevelInfo.level, newLevelInfo.name, newLevelInfo.icon)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showLevelUp = true
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
                HStack(spacing: 8) {
                    Text(displayFirstName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(minHeight: 22)
                    Button { showProfile = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: scaled(16)))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Top-line: market status pill, optional market sentiment pill, and bell
            HStack(spacing: 12) {
                marketPill
                if let sentiment = viewModel.marketSentiment {
                    marketSentimentPill(sentiment: sentiment)
                }
                Button(action: {
                    showNotifications = true
                    unreadNotificationCount = 0
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color(red: 0.067, green: 0.094, blue: 0.153))
                            .clipShape(Circle())
                        if unreadNotificationCount > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 16, height: 16)
                                Text(unreadNotificationCount > 9 ? "9+" : "\(unreadNotificationCount)")
                                    .font(.system(size: scaled(9), weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }
            }
        }
        .padding(.top, vscaled(6))
        // Present notifications sheet when bell tapped
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(selectedTab: $selectedTab)
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChallenge) { challenge in
            DailyTaskDetailSheet(challenge: challenge) {
                Task { await viewModel.refreshChallenges() }
            }
            .onDisappear {
                Task { await viewModel.refreshChallenges() }
            }
        }
        .sheet(isPresented: $showStockHuntHub) {
            StockHuntHubSheet(allChallenges: viewModel.dailyChallenges)
                .onDisappear { Task { await viewModel.refreshChallenges() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stockHuntClaimed)) { _ in
            Task { await viewModel.refreshChallenges() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .challengeCompleted)) { note in
            // Always refresh — even if popup is suppressed, the list must update
            Task { await viewModel.refreshChallenges() }
            guard !showCompletionPopup,
                  let completions = note.userInfo?["completions"] as? [ChallengeCompletion],
                  !completions.isEmpty else { return }
            pendingCompletions = completions
            showCompletionPopup = true
        }
        .fullScreenCover(isPresented: $showCompletionPopup) {
            CompletionPopupView(completions: pendingCompletions) {
                showCompletionPopup = false
                pendingCompletions = []
            }
        }
    }
    
    // MARK: - Gamification Bar

    private func compactXP(_ xp: Int) -> String {
        xp >= 1000 ? "\(xp / 1000)K" : "\(xp)"
    }

    private var gamificationBar: some View {
        let info = sqLevelInfo(totalXP: viewModel.displayedXP)
        let progress = info.rangeXP > 0 ? min(Double(info.progressXP) / Double(info.rangeXP), 1.0) : 1.0
        let lvColor = sqLevelColor(info.level)

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                // Level badge — compact pill
                HStack(spacing: 3) {
                    Image(systemName: info.icon)
                        .font(.system(size: scaled(10), weight: .bold))
                        .foregroundColor(lvColor)
                    Text("Lv.\(info.level)")
                        .font(.system(size: scaled(11), weight: .black))
                        .foregroundColor(lvColor)
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(lvColor.opacity(0.18))
                .cornerRadius(8)

                // Level name — takes remaining space, shrinks before XP
                Text(info.name)
                    .font(.system(size: scaled(12), weight: .semibold))
                    .foregroundColor(lvColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(0)

                Spacer(minLength: 2)

                // XP — compact "261/1K XP" style
                Text("\(info.progressXP)/\(compactXP(info.rangeXP)) XP")
                    .font(.system(size: scaled(11), weight: .bold))
                    .foregroundColor(Color(red: 1, green: 0.84, blue: 0))
                    .lineLimit(1)
                    .layoutPriority(1)

                StreakBadge(streak: viewModel.streak)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [lvColor.opacity(0.8), lvColor],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.glassBackground)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.glassBorder, lineWidth: 1))
    }

    // Extracted market pill for reuse
    private func refreshUnreadCount() async {
        let readIds = Set(UserDefaults.standard.stringArray(forKey: "read_notification_ids") ?? [])
        let fetched = (try? await APIService.shared.fetchNotifications()) ?? []
        unreadNotificationCount = fetched.filter { !readIds.contains($0.id) }.count
    }

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
                .onReceive(tickerTimer) { _ in
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
    @State private var portfolioPageIndex = 0

    private var portfolioCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Your Portfolios")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if viewModel.portfolioCards.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.draw")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        Text("Swipe")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            if viewModel.portfolioCards.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.glassBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: vscaled(100))
                    .overlay(
                        Text("No portfolios available")
                            .foregroundColor(Theme.textSecondary)
                            .font(.subheadline)
                    )
            } else {
                TabView(selection: $portfolioPageIndex) {
                    ForEach(viewModel.portfolioCards.indices, id: \.self) { idx in
                        PortfolioCardView(portfolio: viewModel.portfolioCards[idx])
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: vscaled(120))

                // Page dots
                if viewModel.portfolioCards.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(viewModel.portfolioCards.indices, id: \.self) { idx in
                            Circle()
                                .fill(idx == portfolioPageIndex ? Color.white : Color.white.opacity(0.3))
                                .frame(width: idx == portfolioPageIndex ? 8 : 5, height: idx == portfolioPageIndex ? 8 : 5)
                                .animation(.easeInOut(duration: 0.2), value: portfolioPageIndex)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Tasks + Leagues Tabbed Section
    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: vscaled(10)) {
            // Tab picker
            HStack(spacing: 0) {
                ForEach(["Daily Tasks", "ShareQuests"], id: \.self) { label in
                    let idx = label == "Daily Tasks" ? 0 : 1
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { taskSectionTab = idx }
                    } label: {
                        Text(label)
                            .font(.system(size: scaled(13), weight: .semibold))
                            .foregroundColor(taskSectionTab == idx ? .white : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, vscaled(7))
                            .background(
                                taskSectionTab == idx
                                    ? AnyShapeStyle(LinearGradient(colors: [Theme.primaryBlue, Theme.accentPurple], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color.clear)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())

            if taskSectionTab == 0 {
                dailyTasksContent
            } else {
                leaguesPromotionContent
            }
        }
    }

    private var leaguesPromotionContent: some View {
        let subscribed = isAnnualSubscriber == true
        let cards: [Int] = subscribed ? [1] : [0, 1]  // 0 = annual, 1 = leagues

        return VStack(spacing: 8) {
            TabView(selection: $promoCardIndex) {
                ForEach(cards, id: \.self) { idx in
                    if idx == 0 {
                        annualShareQuestPromoCard
                            .tag(0)
                            .padding(.horizontal, 2)
                    } else {
                        leaguesPromoCard
                            .tag(1)
                            .padding(.horizontal, 2)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: vscaled(155))

            // Page dots — only when both cards visible
            if !subscribed {
                HStack(spacing: 6) {
                    ForEach(cards, id: \.self) { idx in
                        Circle()
                            .fill(promoCardIndex == idx ? Color.white : Color.white.opacity(0.3))
                            .frame(width: promoCardIndex == idx ? 7 : 5,
                                   height: promoCardIndex == idx ? 7 : 5)
                            .animation(.easeInOut(duration: 0.2), value: promoCardIndex)
                    }
                }
            }

            // Feature pills
            HStack(spacing: 8) {
                ForEach([
                    ("person.3.fill", "Private Leagues"),
                    ("chart.line.uptrend.xyaxis", "Live Rankings"),
                    ("banknote.fill", "Prize Pools"),
                ], id: \.1) { icon, label in
                    HStack(spacing: 5) {
                        Image(systemName: icon).font(.caption).foregroundColor(Theme.primaryBlue)
                        Text(label).font(.caption).foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                }
            }
        }
        .sheet(isPresented: $showSubscriptions, onDismiss: {
            Task {
                let subs = try? await APIService.shared.fetchUserSubscriptions()
                isAnnualSubscriber = subs?.annual ?? false
            }
        }) {
            SubscriptionsView(selectedTab: $selectedTab)
        }
    }

    private var annualShareQuestPromoCard: some View {
        let gold = Color(red: 0.95, green: 0.65, blue: 0.15)
        return Button { showSubscriptions = true } label: {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.18, green: 0.12, blue: 0.04), Color(red: 0.38, green: 0.25, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(LinearGradient(colors: [gold.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.4), lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.circle.fill").font(.title2).foregroundColor(gold)
                        Text("Annual ShareQuest").font(.title3).fontWeight(.bold).foregroundColor(.white)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("£50/yr").font(.caption).fontWeight(.bold).foregroundColor(gold)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(gold.opacity(0.15)).cornerRadius(6)
                            Text("+500 XP Bonus").font(.caption2).fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.purple.opacity(0.5)).cornerRadius(6)
                        }
                    }
                    Text("Compete in the year-long trading competition and win from the prize pool.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Subscribe to compete")
                            .font(.subheadline).fontWeight(.semibold).foregroundColor(gold)
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(gold)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(gold.opacity(0.12)).cornerRadius(10)
                }
                .padding(16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var leaguesPromoCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.27, green: 0.12, blue: 0.55), Color(red: 0.13, green: 0.38, blue: 0.72)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill").font(.title2).foregroundColor(.yellow)
                    Text("Compete & Win").font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                    Text("From £5").font(.caption).fontWeight(.bold).foregroundColor(.yellow)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.15)).cornerRadius(8)
                }
                Text("Join a private league, trade against friends or the community, and split the prize pool.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Button { selectedTab = 4 } label: {
                    HStack {
                        Text("View Leagues").fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline).foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.white.opacity(0.2)).cornerRadius(10)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Daily Tasks Content (extracted from challengesSection)
    private var dailyTasksContent: some View {
        let xpEarned = viewModel.xpEarnedToday
        let completed = viewModel.dailyCompletedCount
        let limit = viewModel.dailyLimit
        let progress = limit > 0 ? Double(completed) / Double(limit) : 0.0

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Daily Tasks")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Text("\(completed)/\(limit)")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(viewModel.allChallengesDone ? Theme.accentGreen : Theme.textSecondary)
            }

            // Daily progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                    Capsule()
                        .fill(viewModel.allChallengesDone
                              ? AnyShapeStyle(Theme.accentGreen)
                              : AnyShapeStyle(LinearGradient(colors: [Theme.primaryBlue, Theme.accentPurple],
                                               startPoint: .leading, endPoint: .trailing)))
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 6)

            // Stats row
            HStack(spacing: 10) {
                DailyTaskStatView(icon: "flame.fill", iconColor: .orange, value: "\(viewModel.streak)", label: "Streak")
                DailyTaskStatView(icon: "checkmark.circle.fill", iconColor: Theme.accentGreen, value: "\(completed)/\(limit)", label: "Done")
                DailyTaskStatView(icon: "star.fill", iconColor: Theme.accentYellow, value: "+\(xpEarned)", label: "XP Earned")
            }

            // All-done state
            if viewModel.allChallengesDone {
                HStack(spacing: 12) {
                    Text("🎉")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All done for today!")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("You've completed all \(limit) challenges. Come back tomorrow!")
                            .font(.caption).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accentGreen.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentGreen.opacity(0.3), lineWidth: 1))
            } else {
                // Active + completed task cards
                VStack(spacing: 8) {
                    ForEach(viewModel.dailyChallenges) { challenge in
                        let isHunt = (challenge.criteria_type ?? challenge.type ?? "") == "stock_hunt"
                        Button {
                            if isHunt { showStockHuntHub = true }
                            else { selectedChallenge = challenge }
                        } label: {
                            DailyTaskRowView(challenge: challenge)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
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

                VStack(alignment: .trailing, spacing: 4) {
                    // Price with same directional colour as the pill
                    Text(stock.formattedPrice)
                        .font(.system(size: scaled(11), weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            stock.changePercent > 0
                                ? Color(red: 0.18, green: 0.45, blue: 0.90)
                                : stock.changePercent < 0
                                    ? Color(red: 0.78, green: 0.15, blue: 0.15)
                                    : Color(red: 0.05, green: 0.55, blue: 0.37)
                        )
                        .cornerRadius(6)
                    ChangePill(percent: stock.changePercent,
                               label: stock.formattedChange,
                               compact: true)
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

// Stat chip for the Daily Tasks stats row
struct DailyTaskStatView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.glassBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.glassBorder, lineWidth: 1))
    }
}

// Richer daily task row
struct DailyTaskRowView: View {
    let challenge: ChallengeData

    private var taskIcon: String {
        switch challenge.criteria_type ?? challenge.type ?? "" {
        case "trade":             return "arrow.left.arrow.right.circle.fill"
        case "login":             return "person.fill.checkmark"
        case "watchlist":         return "star.circle.fill"
        case "portfolio_check":   return "chart.pie.fill"
        case "leaderboard":       return "list.number"
        case "sector":            return "building.2.fill"
        case "stock_hunt":        return "magnifyingglass.circle.fill"
        case "pnl_check":         return "chart.line.uptrend.xyaxis.circle.fill"
        default:                  return "checkmark.circle.fill"
        }
    }

    private var taskIconColor: Color {
        if challenge.isCompleted { return Theme.accentGreen }
        switch challenge.criteria_type ?? challenge.type ?? "" {
        case "trade":           return Color(red: 0.23, green: 0.51, blue: 0.96)
        case "stock_hunt":      return Color(red: 0.55, green: 0.36, blue: 0.96)
        case "watchlist":       return Theme.accentYellow
        default:                return Theme.primaryBlue
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(taskIconColor.opacity(0.15))
                    .frame(width: vscaled(36), height: vscaled(36))
                Image(systemName: taskIcon)
                    .font(.system(size: scaled(16)))
                    .foregroundColor(taskIconColor)
            }

            // Title + progress
            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if let desc = challenge.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        Capsule()
                            .fill(challenge.isCompleted ? Theme.accentGreen : taskIconColor)
                            .frame(width: geo.size.width * challenge.progressPercent, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            // XP badge / checkmark
            VStack(alignment: .trailing, spacing: 4) {
                if challenge.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(Theme.accentGreen)
                } else {
                    Text("+\(challenge.reward)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.accentYellow)
                    Text("XP")
                        .font(.caption2)
                        .foregroundColor(Theme.accentYellow.opacity(0.7))
                }
                // Progress fraction
                if !challenge.isCompleted && challenge.targetProgress > 1 {
                    Text("\(challenge.currentProgress)/\(challenge.targetProgress)")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, vscaled(10))
        .background(challenge.isCompleted ? Theme.accentGreen.opacity(0.08) : Theme.glassBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(challenge.isCompleted ? Theme.accentGreen.opacity(0.3) : Theme.glassBorder, lineWidth: 1)
        )
    }
}

// Keep for backward-compat (no longer used in main body)
struct ChallengeRowView: View {
    let challenge: ChallengeData
    var body: some View { DailyTaskRowView(challenge: challenge) }
}

/// MARK: - Stock Hunt Hub Sheet

struct StockHuntHubSheet: View {
    /// All daily challenges — filtered internally for stock_hunt type
    let allChallenges: [ChallengeData]
    @Environment(\.dismiss) private var dismiss
    @State private var stockHunt: StockHuntChallengeResponse.StockHuntData? = nil
    @State private var isLoading = true

    private let huntColor = Color(red: 0.55, green: 0.36, blue: 0.96)

    private var huntChallenges: [ChallengeData] {
        allChallenges.filter { ($0.criteria_type ?? $0.type ?? "") == "stock_hunt" }
    }
    private var completedCount: Int { huntChallenges.filter(\.isCompleted).count }
    private var total: Int { huntChallenges.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Header icon + progress
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(huntColor.opacity(0.15))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "scope")
                                    .font(.system(size: scaled(32), weight: .semibold))
                                    .foregroundColor(huntColor)
                            }

                            Text("Stock Hunt")
                                .font(.title2).fontWeight(.bold).foregroundColor(.white)

                            Text("\(completedCount) of \(total) completed today")
                                .font(.subheadline).foregroundColor(Theme.textSecondary)

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 8)
                                    Capsule()
                                        .fill(completedCount == total && total > 0
                                              ? AnyShapeStyle(Theme.accentGreen)
                                              : AnyShapeStyle(LinearGradient(
                                                    colors: [huntColor, Color(red: 0.23, green: 0.51, blue: 0.96)],
                                                    startPoint: .leading, endPoint: .trailing)))
                                        .frame(width: geo.size.width * (total > 0 ? Double(completedCount) / Double(total) : 0), height: 8)
                                        .animation(.easeOut(duration: 0.5), value: completedCount)
                                }
                            }
                            .frame(height: 8)
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)

                        // Today's criteria card (from API)
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: huntColor))
                                .padding()
                        } else if let hunt = stockHunt {
                            criteriaCard(hunt)
                        }

                        // Challenge list
                        VStack(spacing: 10) {
                            ForEach(huntChallenges) { challenge in
                                huntRow(challenge)
                            }
                        }
                        .padding(.horizontal)

                        // CTA
                        if huntChallenges.contains(where: { !$0.isCompleted }) {
                            Button { dismiss() } label: {
                                Label("Browse Stocks to Find a Match", systemImage: "chart.bar.fill")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(huntColor)
                                    .cornerRadius(14)
                            }
                            .padding(.horizontal)

                            Text("Open any stock's detail page and tap **Claim for Stock Hunt** when you find a match.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Stock Hunt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(huntColor)
                }
            }
            .task {
                stockHunt = (try? await APIService.shared.getStockHuntChallenge())?.data
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private func criteriaCard(_ hunt: StockHuntChallengeResponse.StockHuntData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target").foregroundColor(huntColor).font(.subheadline)
                Text("Today's Criteria")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                Spacer()
                if let diff = hunt.template?.difficulty {
                    Text(diff.capitalized)
                        .font(.caption).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(difficultyColor(diff).opacity(0.2))
                        .foregroundColor(difficultyColor(diff))
                        .cornerRadius(6)
                }
            }
            if let name = hunt.template?.name {
                Text(name).font(.headline).fontWeight(.bold).foregroundColor(.white)
            }
            if let desc = hunt.template?.description ?? hunt.template?.hint {
                Text(desc).font(.caption).foregroundColor(Theme.textSecondary)
            }
            if let hint = hunt.template?.hint, hunt.template?.description != nil {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill").foregroundColor(Theme.accentYellow).font(.caption)
                    Text(hint).font(.caption).foregroundColor(Theme.textSecondary)
                }
            }
            if let count = hunt.matchingStockCount {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill").foregroundColor(Theme.accentGreen).font(.caption)
                    Text("\(count) matching stock\(count == 1 ? "" : "s") available today")
                        .font(.caption).foregroundColor(Theme.accentGreen)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(huntColor.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(huntColor.opacity(0.3), lineWidth: 1))
    }

    @ViewBuilder
    private func huntRow(_ challenge: ChallengeData) -> some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(challenge.isCompleted ? Theme.accentGreen.opacity(0.15) : huntColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : "scope")
                    .foregroundColor(challenge.isCompleted ? Theme.accentGreen : huntColor)
                    .font(.system(size: scaled(16)))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.displayTitle)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(challenge.isCompleted ? Theme.accentGreen : .white)
                if let desc = challenge.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption).foregroundColor(Theme.textSecondary).lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(challenge.reward) XP")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(challenge.isCompleted ? Theme.accentGreen : Theme.accentYellow)
                if challenge.isCompleted {
                    Text("Earned").font(.caption2).foregroundColor(Theme.accentGreen)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(challenge.isCompleted ? Theme.accentGreen.opacity(0.06) : Theme.glassBackground))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(challenge.isCompleted ? Theme.accentGreen.opacity(0.25) : Theme.glassBorder, lineWidth: 1))
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d.lowercased() {
        case "easy":   return Theme.accentGreen
        case "medium": return Color(red: 0.96, green: 0.62, blue: 0.04)
        case "hard":   return Color(red: 0.94, green: 0.27, blue: 0.27)
        default:       return Theme.primaryBlue
        }
    }
}

// MARK: - Daily Task Detail Sheet

struct DailyTaskDetailSheet: View {
    let challenge: ChallengeData
    var onCompleted: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var stockHunt: StockHuntChallengeResponse.StockHuntData? = nil
    @State private var isLoadingHunt = false
    // Local mutable progress state (updates live without mutating the immutable `challenge`)
    @State private var localCompleted: Bool = false
    @State private var localProgress: Int = 0
    @State private var localXP: Int = 0

    private var criteriaKey: String { challenge.criteria_type ?? challenge.type ?? "" }
    private var target: Int { challenge.targetProgress }
    // Use local state so progress bar / status update live after claim
    private var isCompleted: Bool  { localCompleted }
    private var currentProgress: Int { localProgress }
    private var progressPercent: Double {
        guard target > 0 else { return isCompleted ? 1.0 : 0.0 }
        return min(Double(currentProgress) / Double(target), 1.0)
    }

    private var iconName: String {
        switch criteriaKey {
        case "trade":           return "arrow.left.arrow.right.circle.fill"
        case "login":           return "person.fill.checkmark"
        case "watchlist":       return "star.circle.fill"
        case "portfolio_check": return "chart.pie.fill"
        case "leaderboard":     return "list.number"
        case "sector":          return "building.2.fill"
        case "stock_hunt":      return "magnifyingglass.circle.fill"
        case "pnl_check":       return "chart.line.uptrend.xyaxis.circle.fill"
        default:                return "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        if isCompleted { return Theme.accentGreen }
        switch criteriaKey {
        case "trade":           return Color(red: 0.23, green: 0.51, blue: 0.96)
        case "stock_hunt":      return Color(red: 0.55, green: 0.36, blue: 0.96)
        case "watchlist":       return Theme.accentYellow
        case "portfolio_check": return Theme.accentGreen
        case "pnl_check":       return Theme.accentGreen
        case "leaderboard":     return Theme.accentPurple
        case "sector":          return Color(red: 0.96, green: 0.62, blue: 0.04)
        default:                return Theme.primaryBlue
        }
    }

    /// Always show a meaningful description — stock_hunt uses live template, others use DB or fallback.
    private var challengeDescription: String {
        if criteriaKey == "stock_hunt", let t = stockHunt?.template {
            return t.description ?? "Find and trade a stock matching today's criteria."
        }
        if let desc = challenge.description, !desc.isEmpty { return desc }
        let n = target
        switch criteriaKey {
        case "trade":
            return n > 1
                ? "Execute \(n) trades on any stock in your portfolio today."
                : "Execute a trade on any stock in your portfolio today."
        case "login":           return "Log in to ShareQuest today to keep your streak alive."
        case "watchlist":
            return n > 1
                ? "Add \(n) stocks to your watchlist today."
                : "Add a stock to your watchlist today."
        case "portfolio_check": return "Open and review your portfolio to track your performance."
        case "leaderboard":     return "Check the leaderboard to see how you rank against other traders."
        case "sector":
            return n > 1
                ? "Explore \(n) sectors in the market browser today."
                : "Explore a sector in the market browser today."
        case "stock_hunt":      return "Search for a stock that matches today's specific criteria."
        case "pnl_check":       return "Review your profit & loss to see how your positions are performing."
        default:                return "Complete this challenge to earn XP and grow your trading skills."
        }
    }

    /// Short action label shown in the "How to complete" card.
    private var howToComplete: String {
        switch criteriaKey {
        case "trade":           return "Go to any stock and tap Trade"
        case "login":           return "Already done — you're in the app!"
        case "watchlist":       return "Find a stock and tap the ★ star icon to add it"
        case "portfolio_check": return "Open your Portfolio tab to review your positions"
        case "leaderboard":     return "Open the Leaderboard tab to see your rank"
        case "sector":          return "Go to Stocks → Sectors and explore a sector"
        case "stock_hunt":      return "Browse Stocks, open a stock detail, tap Claim for Stock Hunt"
        case "pnl_check":       return "Open your Portfolio tab and review your P&L"
        default:                return "Complete the required action in the app"
        }
    }

    /// (Button label, SF symbol) for the action button — nil if no direct navigation available.
    private var actionButton: (String, String)? {
        switch criteriaKey {
        case "trade":           return ("Go to Stocks", "arrow.left.arrow.right")
        case "watchlist":       return ("Browse Stocks", "star.circle")
        case "portfolio_check": return ("Open Portfolio", "chart.pie.fill")
        case "pnl_check":       return ("Open Portfolio", "chart.line.uptrend.xyaxis")
        case "leaderboard":     return ("Open Leaderboard", "list.number")
        case "sector":          return ("Explore Sectors", "building.2.fill")
        case "stock_hunt":      return ("Browse Stocks", "chart.bar.fill")
        default:                return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Icon + title + status
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(iconColor.opacity(0.15))
                                    .frame(width: 76, height: 76)
                                    .overlay(Circle().stroke(iconColor.opacity(0.3), lineWidth: 1.5))
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : iconName)
                                    .font(.system(size: scaled(36)))
                                    .foregroundColor(iconColor)
                            }
                            .padding(.top, 8)

                            Text(challenge.displayTitle)
                                .font(.title3).fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            if isCompleted {
                                Label("Challenge Complete!", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(Theme.accentGreen)
                            } else {
                                Text("In Progress")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }

                        // Description
                        Text(challengeDescription)
                            .font(.body)
                            .foregroundColor(Color(red: 0.75, green: 0.78, blue: 0.84))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Action card: instructions + Go button (only when not done, not stock_hunt)
                        if !isCompleted && criteriaKey != "stock_hunt" {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(Color(red: 0.96, green: 0.85, blue: 0.3))
                                        .font(.subheadline)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("How to complete")
                                            .font(.caption).foregroundColor(Theme.textSecondary)
                                        Text(howToComplete)
                                            .font(.subheadline).fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                }

                                if let (label, icon) = actionButton {
                                    Button { dismiss() } label: {
                                        Label(label, systemImage: icon)
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 11)
                                            .background(iconColor)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)
                        }

                        // Stock Hunt — criteria header + live search/claim
                        if criteriaKey == "stock_hunt" {
                            if isLoadingHunt {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: iconColor))
                                    .padding()
                            } else if let hunt = stockHunt {
                                VStack(alignment: .leading, spacing: 14) {

                                    // Criteria header
                                    HStack(spacing: 8) {
                                        Image(systemName: "target")
                                            .foregroundColor(iconColor).font(.subheadline)
                                        Text("Today's Criteria")
                                            .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                                        Spacer()
                                        if let diff = hunt.template?.difficulty {
                                            Text(diff.capitalized)
                                                .font(.caption).fontWeight(.bold)
                                                .padding(.horizontal, 8).padding(.vertical, 3)
                                                .background(difficultyColor(diff).opacity(0.2))
                                                .foregroundColor(difficultyColor(diff))
                                                .cornerRadius(6)
                                        }
                                    }
                                    if let name = hunt.template?.name {
                                        Text(name)
                                            .font(.headline).fontWeight(.bold).foregroundColor(.white)
                                    }
                                    if let hint = hunt.template?.hint {
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "info.circle")
                                                .foregroundColor(Theme.primaryBlue).font(.caption)
                                            Text(hint).font(.caption).foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    if let count = hunt.matchingStockCount {
                                        HStack(spacing: 6) {
                                            Image(systemName: "chart.bar.fill")
                                                .foregroundColor(Theme.accentGreen).font(.caption)
                                            Text("\(count) matching stock\(count == 1 ? "" : "s") available today")
                                                .font(.caption).foregroundColor(Theme.accentGreen)
                                        }
                                    }

                                    // How to find the stock (hidden once completed)
                                    if !isCompleted {
                                        Divider().background(Color.white.opacity(0.1))

                                        VStack(spacing: 10) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "arrow.right.circle.fill")
                                                    .foregroundColor(iconColor)
                                                Text("How to complete")
                                                    .font(.caption).fontWeight(.semibold)
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                            Text("Browse the Stocks tab to research and find a matching stock. Open the stock's detail page, then tap **Claim for Stock Hunt** to earn your XP.")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                                .multilineTextAlignment(.leading)

                                            Button {
                                                dismiss()
                                            } label: {
                                                Label("Go to Stocks", systemImage: "chart.bar.fill")
                                                    .font(.subheadline).fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 11)
                                                    .background(iconColor)
                                                    .cornerRadius(12)
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 14).fill(iconColor.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(iconColor.opacity(0.3), lineWidth: 1))
                                .padding(.horizontal)
                            }
                        }

                        // Progress card
                        VStack(spacing: 14) {
                            HStack {
                                Text("Today's Progress")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(currentProgress) / \(target)")
                                    .font(.subheadline).fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 10)
                                    Capsule()
                                        .fill(isCompleted ? Theme.accentGreen : iconColor)
                                        .frame(width: geo.size.width * progressPercent, height: 10)
                                        .animation(.easeOut(duration: 0.5), value: progressPercent)
                                }
                            }
                            .frame(height: 10)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                        .padding(.horizontal)

                        // XP reward
                        HStack(spacing: 14) {
                            Image(systemName: "star.fill")
                                .foregroundColor(Theme.accentYellow).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("XP Reward")
                                    .font(.caption).foregroundColor(Theme.textSecondary)
                                Text("+\(challenge.reward) XP")
                                    .font(.headline).fontWeight(.bold)
                                    .foregroundColor(Theme.accentYellow)
                            }
                            Spacer()
                            if isCompleted {
                                Label("Earned", systemImage: "checkmark.seal.fill")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(Theme.accentGreen)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accentYellow.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentYellow.opacity(0.25), lineWidth: 1))
                        .padding(.horizontal)

                        Spacer(minLength: 30)
                    }
                }

            }
            .navigationTitle(challenge.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(isCompleted ? Theme.accentGreen : Theme.primaryBlue)
                }
            }
            .task {
                // Initialise local mutable state from the immutable challenge
                localCompleted = challenge.isCompleted
                localProgress  = challenge.currentProgress
                localXP        = challenge.reward

                if criteriaKey == "stock_hunt" {
                    isLoadingHunt = true
                    stockHunt = (try? await APIService.shared.getStockHuntChallenge())?.data
                    isLoadingHunt = false
                }
                // Pre-completed challenges open in completed state without re-showing the popup
            }
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy":   return Theme.accentGreen
        case "medium": return Color(red: 0.96, green: 0.62, blue: 0.04)
        case "hard":   return Color(red: 0.94, green: 0.27, blue: 0.27)
        default:       return Theme.primaryBlue
        }
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
                    .font(.caption).fontWeight(.medium).foregroundColor(.white)
                if let description = activity.description {
                    Text(description).font(.caption2).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            Text("+\(activity.amount) XP")
                .font(.caption).fontWeight(.bold).foregroundColor(Theme.accentYellow)
        }
        .padding(.horizontal).padding(.vertical, 8)
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
    @Published var dailyCompletedCount: Int = 0
    @Published var dailyLimit: Int = 10
    @Published var allChallengesDone: Bool = false
    @Published var xpEarnedToday: Int = 0
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
        // Record login (updates streak) — don't let a failure block challenge loading
        if let response = try? await apiService.recordDailyLogin() {
            streak = response.streak
        }
        // Always attempt to load today's challenges independently
        do {
            let challengesResponse = try await apiService.getDailyChallenges()
            dailyChallenges = challengesResponse.allChallenges
            dailyCompletedCount = challengesResponse.dailyCompletedCount
            dailyLimit = challengesResponse.dailyLimit
            allChallengesDone = challengesResponse.allDone
            xpEarnedToday = challengesResponse.xpEarnedToday
            print("[Dashboard] Loaded \(dailyChallenges.count) challenges, \(dailyCompletedCount)/\(dailyLimit) done, \(xpEarnedToday) XP earned today")
        } catch {
            print("[Dashboard] Failed to load challenges: \(error)")
        }
    }
    
    func refreshChallenges() async {
        do {
            let resp = try await apiService.getDailyChallenges()
            dailyChallenges = resp.allChallenges
            dailyCompletedCount = resp.dailyCompletedCount
            dailyLimit = resp.dailyLimit
            allChallengesDone = resp.allDone
            xpEarnedToday = resp.xpEarnedToday
        } catch {}
    }

    private func loadGamificationProfile() async {
        print("[DashboardViewModel] Loading gamification profile...")
        do {
            let response = try await apiService.getGamificationProfile()
            print("[DashboardViewModel] Raw gamification profile response: \(response)")
            // Check for XP change
            if previousXP > 0 && response.xp > previousXP {
                xpDelta = response.xp - previousXP
            }
            previousXP = response.xp
            await MainActor.run {
                gamProfile = response
                recentXP = response.xpActivities
                // Account for any local onboarding XP that might not yet be reflected on the server.
                let localOnboardingXP = UserDefaults.standard.integer(forKey: "onboarding_xp")
                if response.xp < localOnboardingXP {
                    displayedXP = response.xp + localOnboardingXP
                } else {
                    displayedXP = response.xp
                }
                displayedXPForNext = response.xpForNextLevel
                print("[DashboardViewModel] Gamification profile set: \(gamProfile?.playerLevelName ?? "nil") XP=\(gamProfile?.xp ?? -1) displayedXP=\(displayedXP)/\(displayedXPForNext)")
            }
        } catch {
            print("[DashboardViewModel] Failed to load gamification profile: \(error)")
        }
    }
    
    private func loadPortfolios() async {
        print("[DashboardViewModel] Loading portfolios...")
        var cards: [PortfolioSummary] = []
        do {
            // Fetch dashboard to get portfolio configs
            let dashboardResponse = try await apiService.fetchDashboard()
            // Try to get portfolios array from dashboard response
            let portfolios: [PortfolioConfig]? = dashboardResponse.data?.portfolios // <-- update here
            let configs = portfolios?.filter { $0.isSubscribed } ?? []
            for config in configs {
                do {
                    if let portfolio = try await apiService.fetchPortfolioDetails(type: config.type) {
                        let totalValue = portfolio.totalPortfolioValue > 0 ? portfolio.totalPortfolioValue : portfolio.cashBalanceValue
                        let initialBalance = portfolio.initialBalanceValue
                        let changePercent = initialBalance > 0 ? ((totalValue - initialBalance) / initialBalance) * 100 : 0
                        cards.append(PortfolioSummary(
                            id: config.type,
                            name: config.label,
                            emoji: config.emoji,
                            value: totalValue,
                            changePercent: changePercent,
                            gradientColors: portfolioGradient(for: config.type)
                        ))
                    } else {
                        print("[DashboardViewModel] No portfolio found for type \(config.type)")
                    }
                } catch {
                    print("[DashboardViewModel] Error loading portfolio for type \(config.type): \(error)")
                }
            }
        } catch {
            print("[DashboardViewModel] Error loading dashboard portfolios: \(error)")
            // Fallback: show Practice portfolio only
            cards.append(PortfolioSummary(
                id: "default",
                name: "Practice",
                emoji: "🎯",
                value: 100000,
                changePercent: 0,
                gradientColors: portfolioGradient(for: "default")
            ))
        }
        await MainActor.run {
            portfolioCards = cards
            print("[DashboardViewModel] Portfolios set: \(portfolioCards.map { $0.name })")
        }
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

// MARK: - Portfolio Colour Helpers (shared across Dashboard + Trade modal)

func portfolioColor(for type: String) -> Color {
    switch type {
    case "default":  return Color(red: 0.23, green: 0.51, blue: 0.96)   // Vivid blue
    case "weekly":   return Color(red: 0.06, green: 0.73, blue: 0.51)   // Vivid green
    case "monthly":  return Color(red: 0.55, green: 0.36, blue: 0.96)   // Vivid purple
    case "annual":   return Color(red: 0.96, green: 0.62, blue: 0.04)   // Vivid amber/gold
    default:         return Color(red: 0.39, green: 0.40, blue: 0.95)
    }
}

func portfolioGradient(for type: String) -> [Color] {
    let base = portfolioColor(for: type)
    switch type {
    case "default":  return [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.15, green: 0.39, blue: 0.92)]
    case "weekly":   return [Color(red: 0.06, green: 0.73, blue: 0.51), Color(red: 0.02, green: 0.55, blue: 0.37)]
    case "monthly":  return [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.38, green: 0.20, blue: 0.82)]
    case "annual":   return [Color(red: 0.96, green: 0.62, blue: 0.04), Color(red: 0.78, green: 0.46, blue: 0.02)]
    default:         return [base, base.opacity(0.75)]
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
        NavigationLink(destination: PortfolioView(
            initialType: PortfolioType(rawValue: portfolio.id) ?? .practice,
            isEmbedded: true
        )) {
            VStack(alignment: .leading, spacing: vscaled(8)) {
                HStack {
                    Text(portfolio.emoji)
                        .font(.title3)
                    Text(portfolio.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: scaled(11), weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }

                Text(portfolio.formattedValue)
                    .font(.system(size: scaled(26), weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                ChangePill(percent: portfolio.changePercent)
            }
            .padding(.horizontal, 16).padding(.vertical, vscaled(12))
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: portfolio.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0))
        .environmentObject(AuthManager.shared)
}

struct PortfolioConfig: Codable, Hashable, Identifiable {
    let type: String
    let label: String
    let emoji: String
    let color: String
    let isSubscribed: Bool
    var id: String { type }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
