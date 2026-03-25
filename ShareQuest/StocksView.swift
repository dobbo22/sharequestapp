//
//  StocksView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

// MARK: - Challenge Completion Helper

/// Posts a notification so any listening view can show the 🎉 completion popup.
func postCompletionNotification(_ completions: [ChallengeCompletion]) {
    guard !completions.isEmpty else { return }
    NotificationCenter.default.post(
        name: .challengeCompleted,
        object: nil,
        userInfo: ["completions": completions]
    )
}

// MARK: - Watchlist Manager

struct WatchlistItem: Codable, Equatable {
    let symbol: String
    let companyName: String
}

final class WatchlistManager: ObservableObject {
    static let shared = WatchlistManager()
    @Published var items: [WatchlistItem] = []
    private let key = "stock_watchlist"

    private init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WatchlistItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func isWatched(_ symbol: String) -> Bool {
        items.contains { $0.symbol == symbol }
    }

    func toggle(stock: Stock) {
        if let idx = items.firstIndex(where: { $0.symbol == stock.symbol }) {
            items.remove(at: idx)
        } else {
            items.append(WatchlistItem(symbol: stock.symbol, companyName: stock.companyName))
            Task {
                let done = await APIService.shared.postChallengeProgress(criteriaType: "watchlist")
                postCompletionNotification(done)
            }
        }
        save()
    }
}

// MARK: - StockTab Enum

enum StockTab: String, CaseIterable {
    case top100 = "top100"
    case top250 = "top250"
    case sectors = "sectors"
    case watchlist = "watchlist"

    var displayName: String {
        switch self {
        case .top100: return "Top 100"
        case .top250: return "Top 250"
        case .sectors: return "Sectors"
        case .watchlist: return "Watchlist"
        }
    }
}

// MARK: - StocksViewModel

@MainActor
class StocksViewModel: ObservableObject {
    @Published var stocks: [Stock] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let apiService = APIService.shared

    func clearStocks() {
        stocks = []
        errorMessage = nil
    }

    func fetchStocks(tab: StockTab) async {
        isLoading = true
        errorMessage = nil
        do {
            let stockData: [StockData]
            switch tab {
            case .top100:
                stockData = try await apiService.fetchFTSE100()
            case .top250:
                stockData = try await apiService.fetchFTSE250()
            case .sectors, .watchlist:
                stockData = []
            }
            stocks = stockData.map { sd in
                Stock(
                    id: sd.symbol,
                    symbol: sd.symbol,
                    companyName: sd.displayName,
                    price: sd.rawPencePrice / 100.0,
                    changeAmount: sd.displayChange,
                    changePercent: sd.displayChangePercent,
                    sector: sd.sector ?? "Unknown",
                    marketCap: sd.displayMarketCap
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func searchStocks(query: String) async {
        guard !query.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let stockData = try await apiService.searchStocks(query: query)
            stocks = stockData.map { sd in
                Stock(
                    id: sd.symbol,
                    symbol: sd.symbol,
                    companyName: sd.displayName,
                    price: sd.rawPencePrice / 100.0,
                    changeAmount: sd.displayChange,
                    changePercent: sd.displayChangePercent,
                    sector: sd.sector ?? "Unknown",
                    marketCap: sd.displayMarketCap
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchWatchlistStocks(items: [WatchlistItem]) async {
        guard !items.isEmpty else { stocks = []; return }
        isLoading = true
        errorMessage = nil
        let symbols = items.map { $0.symbol }
        let nameMap = Dictionary(uniqueKeysWithValues: items.map { ($0.symbol, $0.companyName) })
        do {
            var allQuotes: [String: BatchPriceData] = [:]
            for chunk in stride(from: 0, to: symbols.count, by: 50).map({ Array(symbols[$0..<min($0 + 50, symbols.count)]) }) {
                let batch = try await apiService.fetchBatchPrices(symbols: chunk)
                allQuotes.merge(batch) { _, new in new }
            }
            stocks = symbols.map { sym in
                let q = allQuotes[sym]
                return Stock(
                    id: sym,
                    symbol: sym,
                    companyName: nameMap[sym] ?? sym,
                    price: (q?.price ?? 0) / 100.0,
                    changeAmount: q?.change ?? 0,
                    changePercent: q?.changePercent ?? 0,
                    sector: "Watchlist",
                    marketCap: 0
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Stock Sort Order

enum StockSortOrder: String, CaseIterable {
    case defaultOrder = "Default"
    case topGainers   = "Top Gainers"
    case topLosers    = "Top Losers"

    var icon: String {
        switch self {
        case .defaultOrder: return "line.3.horizontal.decrease"
        case .topGainers:   return "arrow.up.right"
        case .topLosers:    return "arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .defaultOrder: return Theme.textSecondary
        case .topGainers:   return Theme.accentGreen
        case .topLosers:    return Color(red: 0.94, green: 0.27, blue: 0.27)
        }
    }
}

// MARK: - StocksView

struct StocksView: View {
    @StateObject private var viewModel = StocksViewModel()
    @ObservedObject private var watchlist = WatchlistManager.shared
    @State private var selectedTab: StockTab? = nil
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var sortOrder: StockSortOrder = .defaultOrder

    private var displayedStocks: [Stock] {
        switch sortOrder {
        case .defaultOrder: return viewModel.stocks
        case .topGainers:   return viewModel.stocks.sorted { $0.changePercent > $1.changePercent }
        case .topLosers:    return viewModel.stocks.sorted { $0.changePercent < $1.changePercent }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if selectedTab != .sectors {
                        searchBar
                    }
                    tabSelector
                    if selectedTab == .sectors {
                        SectorsView()
                    } else {
                        stocksList
                    }
                }
            }
            .navigationTitle("Stocks")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            if newValue.isEmpty {
                if let tab = selectedTab {
                    searchTask = Task { await viewModel.fetchStocks(tab: tab) }
                } else {
                    viewModel.clearStocks()
                }
            } else {
                selectedTab = nil
                sortOrder = .defaultOrder
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await viewModel.searchStocks(query: newValue)
                }
            }
        }
        .onChange(of: watchlist.items) { _, _ in
            if selectedTab == .watchlist {
                searchTask?.cancel()
                searchTask = Task { await viewModel.fetchWatchlistStocks(items: WatchlistManager.shared.items) }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textMuted)
                TextField("Search all stocks...", text: $searchText)
                    .foregroundColor(Theme.textPrimary)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.glassBackground)
            .cornerRadius(12)

            // Sort / filter button — only shown when stock tiles are visible
            if !viewModel.stocks.isEmpty || selectedTab != nil {
                Menu {
                    ForEach(StockSortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            Label(order.rawValue, systemImage: order.icon)
                        }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(sortOrder == .defaultOrder ? Theme.glassBackground : sortOrder.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(sortOrder == .defaultOrder ? Theme.glassBorder : sortOrder.color.opacity(0.6), lineWidth: 1)
                            )
                        Image(systemName: sortOrder.icon)
                            .font(.system(size: scaled(15), weight: .semibold))
                            .foregroundColor(sortOrder.color)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StockTab.allCases, id: \.self) { tab in
                    StockTabButton(tab: tab, isSelected: selectedTab == tab) {
                        searchText = ""
                        sortOrder = .defaultOrder
                        searchTask?.cancel()
                        selectedTab = tab
                        if tab == .watchlist {
                            searchTask = Task { await viewModel.fetchWatchlistStocks(items: WatchlistManager.shared.items) }
                        } else if tab != .sectors {
                            searchTask = Task { await viewModel.fetchStocks(tab: tab) }
                        } else {
                            viewModel.clearStocks()
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }

    // MARK: - Stocks List

    private var stocksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                        .padding(.top, 40)
                } else if viewModel.stocks.isEmpty {
                    VStack(spacing: 16) {
                        if selectedTab == .watchlist {
                            Image(systemName: "star")
                                .font(.system(size: scaled(48)))
                                .foregroundColor(Theme.textMuted)
                            Text("No stocks in watchlist")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                            Text("Tap the ★ on any stock to add it here")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Image(systemName: searchText.isEmpty ? "magnifyingglass" : "magnifyingglass")
                                .font(.system(size: scaled(48)))
                                .foregroundColor(Theme.textMuted)
                            Text(searchText.isEmpty ? "Search for a stock" : "No results for \"\(searchText)\"")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                            if searchText.isEmpty {
                                Text("Type a company name or ticker, or tap a category above")
                                    .font(.caption)
                                    .foregroundColor(Theme.textMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(displayedStocks) { stock in
                        StockRowView(stock: stock)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            if let tab = selectedTab {
                await viewModel.fetchStocks(tab: tab)
            } else if !searchText.isEmpty {
                await viewModel.searchStocks(query: searchText)
            }
        }
    }
}

// MARK: - Stock Tab Button

struct StockTabButton: View {
    let tab: StockTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Theme.primaryBlue.opacity(0.3) : Theme.glassBackground)
                .foregroundColor(isSelected ? Theme.primaryBlue : Theme.textSecondary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Theme.primaryBlue : Theme.glassBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - Stock Row View

struct StockRowView: View {
    let stock: Stock
    @ObservedObject private var watchlist = WatchlistManager.shared

    /// Price in pence formatted as "1,234.56p"
    private var pencePriceDisplay: String {
        let pence = stock.price * 100
        if pence >= 1 {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            f.groupingSeparator = ","
            let s = f.string(from: NSNumber(value: pence)) ?? String(format: "%.2f", pence)
            return "\(s)p"
        }
        return String(format: "%.4fp", pence)
    }

    var body: some View {
        NavigationLink(destination: StockDetailView(stock: stock)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.companyName)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(stock.symbol)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(pencePriceDisplay)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                    ChangePill(percent: stock.changePercent)
                }

                Button {
                    watchlist.toggle(stock: stock)
                } label: {
                    Image(systemName: watchlist.isWatched(stock.symbol) ? "star.fill" : "star")
                        .font(.system(size: scaled(16)))
                        .foregroundColor(watchlist.isWatched(stock.symbol) ? Theme.accentYellow : Theme.textMuted)
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading, 8)
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stock Detail View

// MARK: - Stock Hunt Claim State

private enum HuntClaimState: Equatable {
    case idle
    case claiming
    case matched(xp: Int)
    case noMatch
}

// MARK: - Notification Names

extension Notification.Name {
    static let stockHuntClaimed    = Notification.Name("com.sharequest.stockHuntClaimed")
    static let challengeCompleted  = Notification.Name("com.sharequest.challengeCompleted")
}

// MARK: - Stock Detail View

struct StockDetailView: View {
    let stock: Stock
    @StateObject private var vm: StockDetailViewModel
    @ObservedObject private var watchlist = WatchlistManager.shared
    @State private var showTradeSheet = false
    // Stock Hunt
    @State private var activeHunts: [ChallengeData] = []
    @State private var huntClaimState: HuntClaimState = .idle

    init(stock: Stock) {
        self.stock = stock
        _vm = StateObject(wrappedValue: StockDetailViewModel(symbol: stock.symbol))
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                StockDetailHeader(
                    companyName: (vm.quote == nil || vm.companyName == vm.displaySymbol) ? stock.companyName : vm.companyName,
                    symbol: vm.displaySymbol,
                    price: vm.pencePriceString,
                    changePercent: vm.changePercent,
                    sector: vm.sectorDisplay,
                    industry: vm.subsectorDisplay,
                    onTrade: { showTradeSheet.toggle() }
                )

                // Stock Hunt claim banner — shown when active hunts exist
                if !activeHunts.isEmpty {
                    stockHuntClaimCard
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                Spacer().frame(height: 8)
                StockDetailTabsView(vm: vm)
                    .background(Theme.backgroundPrimary)
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    watchlist.toggle(stock: stock)
                } label: {
                    Image(systemName: watchlist.isWatched(stock.symbol) ? "star.fill" : "star")
                        .foregroundColor(watchlist.isWatched(stock.symbol) ? Theme.accentYellow : .white)
                }
            }
        }
        .task {
            let done = await APIService.shared.postChallengeProgress(criteriaType: "stock_view")
            postCompletionNotification(done)
            // Load active stock hunt challenges
            if let response = try? await APIService.shared.getDailyChallenges() {
                activeHunts = response.allChallenges.filter {
                    ($0.criteria_type ?? $0.type ?? "") == "stock_hunt" && !$0.isCompleted
                }
            }
        }
        .sheet(isPresented: $showTradeSheet) {
            StockTradeSheet(stock: stock)
        }
    }

    @ViewBuilder
    private var stockHuntClaimCard: some View {
        let huntColor = Color(red: 0.55, green: 0.36, blue: 0.96)
        VStack(spacing: 0) {
            switch huntClaimState {
            case .idle:
                HStack(spacing: 12) {
                    Image(systemName: "scope")
                        .font(.title3)
                        .foregroundColor(huntColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stock Hunt Active")
                            .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                        Text("\(activeHunts.count) challenge\(activeHunts.count == 1 ? "" : "s") — does this stock match?")
                            .font(.caption).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        Task { await claimHunt() }
                    } label: {
                        Text("Claim")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(huntColor)
                            .cornerRadius(10)
                    }
                }

            case .claiming:
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: huntColor))
                        .scaleEffect(0.85)
                    Text("Checking…")
                        .font(.subheadline).foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)

            case .matched(let xp):
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.accentGreen).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Challenge Complete!")
                            .font(.subheadline).fontWeight(.bold).foregroundColor(Theme.accentGreen)
                        Text("+\(xp) XP earned")
                            .font(.caption).foregroundColor(Theme.accentYellow)
                    }
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundColor(Theme.accentYellow)
                }

            case .noMatch:
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(red: 0.94, green: 0.27, blue: 0.27)).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Doesn't match today's criteria")
                            .font(.subheadline).fontWeight(.medium).foregroundColor(.white)
                        Text("Keep researching — try another stock")
                            .font(.caption).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        huntClaimState = .idle
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(huntColor.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(huntColor.opacity(0.3), lineWidth: 1))
        .animation(.easeInOut(duration: 0.2), value: huntClaimState)
    }

    private func claimHunt() async {
        huntClaimState = .claiming
        do {
            let result = try await APIService.shared.claimStockHunt(symbol: stock.symbol)
            if result.matched {
                let xp = result.xpReward ?? activeHunts.first?.reward ?? 0
                let huntName = activeHunts.first?.displayTitle ?? "Stock Hunt"
                huntClaimState = .matched(xp: xp)
                // Remove the claimed hunt from active list
                activeHunts = activeHunts.dropFirst().map { $0 }
                // stockHuntClaimed → dashboard refreshes challenge queue
                NotificationCenter.default.post(name: .stockHuntClaimed, object: nil)
                // challengeCompleted → shows global popup + second refresh ensures card disappears
                let completion = ChallengeCompletion(name: huntName, xp_reward: xp)
                postCompletionNotification([completion])
            } else {
                huntClaimState = .noMatch
            }
        } catch {
            huntClaimState = .noMatch
        }
    }
}

// MARK: - Stock Detail Header

struct StockDetailHeader: View {
    let companyName: String
    let symbol: String
    let price: String
    let changePercent: Double
    let sector: String
    let industry: String
    var onTrade: (() -> Void)? = nil

    var isPositive: Bool { changePercent >= 0 }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                Text(companyName.uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
                if let onTrade = onTrade {
                    Button(action: onTrade) {
                        Text("Trade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.primaryBlue)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Text(symbol)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 10) {
                Text(price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                ChangePill(percent: changePercent)
                Text("today")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            if sector != "--" || industry != "--" {
                HStack(spacing: 8) {
                    if sector != "--" {
                        SectorPill(text: sector, color: sectorColor(for: sector))
                    }
                    if industry != "--" {
                        SectorPill(text: industry, color: industryColor(for: industry))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sectorColor(for sector: String) -> Color {
        let s = sector.lowercased()
        if s.contains("health") { return Color(red: 0.2, green: 0.8, blue: 0.6) }
        if s.contains("tech") { return Color(red: 0.4, green: 0.6, blue: 1.0) }
        if s.contains("financ") { return Color(red: 0.3, green: 0.7, blue: 0.4) }
        if s.contains("consumer") && s.contains("defen") { return Color(red: 0.9, green: 0.6, blue: 0.2) }
        if s.contains("consumer") { return Color(red: 1.0, green: 0.5, blue: 0.5) }
        if s.contains("energy") { return Color(red: 1.0, green: 0.8, blue: 0.2) }
        if s.contains("industrial") { return Color(red: 0.6, green: 0.6, blue: 0.7) }
        if s.contains("material") { return Color(red: 0.8, green: 0.5, blue: 0.3) }
        if s.contains("utilit") { return Color(red: 0.5, green: 0.8, blue: 0.9) }
        if s.contains("real estate") { return Color(red: 0.7, green: 0.5, blue: 0.8) }
        if s.contains("communication") { return Color(red: 0.9, green: 0.4, blue: 0.6) }
        if s.contains("basic") { return Color(red: 0.6, green: 0.8, blue: 0.4) }
        return Theme.primaryBlue
    }

    private func industryColor(for industry: String) -> Color {
        let i = industry.lowercased()
        if i.contains("drug") || i.contains("pharm") { return Color(red: 0.3, green: 0.7, blue: 0.9) }
        if i.contains("bank") { return Color(red: 0.2, green: 0.6, blue: 0.4) }
        if i.contains("insurance") { return Color(red: 0.4, green: 0.7, blue: 0.5) }
        if i.contains("oil") || i.contains("gas") { return Color(red: 0.9, green: 0.7, blue: 0.3) }
        if i.contains("retail") { return Color(red: 1.0, green: 0.6, blue: 0.4) }
        if i.contains("beverage") || i.contains("drink") { return Color(red: 0.8, green: 0.4, blue: 0.6) }
        if i.contains("food") { return Color(red: 0.9, green: 0.5, blue: 0.3) }
        if i.contains("aerospace") || i.contains("defense") { return Color(red: 0.5, green: 0.5, blue: 0.7) }
        if i.contains("auto") { return Color(red: 0.6, green: 0.6, blue: 0.6) }
        if i.contains("telecom") { return Color(red: 0.8, green: 0.3, blue: 0.5) }
        if i.contains("software") || i.contains("internet") { return Color(red: 0.5, green: 0.5, blue: 1.0) }
        if i.contains("mining") { return Color(red: 0.7, green: 0.6, blue: 0.4) }
        return Theme.accentPurple
    }
}

// MARK: - Sector/Industry Pill

struct SectorPill: View {
    let text: String
    let color: Color
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.15), lineWidth: 1))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sectors ViewModel

class SectorsViewModel: ObservableObject {
    @Published var sectors: [SectorItem] = []
    @Published var subsectors: [SubsectorItem] = []
    @Published var stockQuotes: [String: BatchPriceData] = [:]
    @Published var selectedSector: String? = nil
    @Published var selectedSubsector: SubsectorItem? = nil
    @Published var isLoading = false

    var subsectorStocks: [SubsectorStockDisplay] {
        guard let sub = selectedSubsector else { return [] }
        return (sub.stocks ?? []).map { s in
            let q = stockQuotes[s.symbol]
            return SubsectorStockDisplay(
                symbol: s.symbol,
                companyName: s.companyname ?? s.symbol,
                price: q?.price,
                change: q?.change,
                changePercent: q?.changePercent
            )
        }.sorted { $0.companyName < $1.companyName }
    }

    struct SubsectorStockDisplay: Identifiable {
        var id: String { symbol }
        let symbol: String
        let companyName: String
        let price: Double?
        let change: Double?
        let changePercent: Double?

        var formattedPrice: String {
            guard let p = price, p > 0 else { return "—" }
            if p >= 1 {
                let f = NumberFormatter()
                f.numberStyle = .decimal
                f.minimumFractionDigits = 2
                f.maximumFractionDigits = 2
                f.groupingSeparator = ","
                return "\(f.string(from: NSNumber(value: p)) ?? String(format: "%.2f", p))p"
            }
            return String(format: "%.4fp", p)
        }

        var isPositive: Bool { (changePercent ?? 0) >= 0 }
    }

    func loadSectors() async {
        guard sectors.isEmpty else { return }
        isLoading = true
        do { sectors = try await APIService.shared.fetchSectors() } catch {}
        isLoading = false
    }

    func selectSector(_ name: String) async {
        selectedSector = name
        selectedSubsector = nil
        stockQuotes = [:]
        subsectors = []
        isLoading = true
        let done = await APIService.shared.postChallengeProgress(criteriaType: "sector")
        postCompletionNotification(done)
        do { subsectors = try await APIService.shared.fetchSubsectors(sector: name) } catch {}
        isLoading = false
    }

    func selectSubsector(_ sub: SubsectorItem) async {
        selectedSubsector = sub
        stockQuotes = [:]
        let symbols = (sub.stocks ?? []).map { $0.symbol }
        guard !symbols.isEmpty else { return }
        isLoading = true
        var allQuotes: [String: BatchPriceData] = [:]
        for chunk in stride(from: 0, to: symbols.count, by: 50).map({ Array(symbols[$0..<min($0+50, symbols.count)]) }) {
            if let batch = try? await APIService.shared.fetchBatchPrices(symbols: chunk) {
                allQuotes.merge(batch) { _, new in new }
            }
        }
        stockQuotes = allQuotes
        isLoading = false
    }

    func goBack() {
        if selectedSubsector != nil {
            selectedSubsector = nil
            stockQuotes = [:]
        } else if selectedSector != nil {
            selectedSector = nil
            subsectors = []
        }
    }
}

// MARK: - Sectors View

struct SectorsView: View {
    @StateObject private var vm = SectorsViewModel()

    var body: some View {
        ZStack {
            if vm.isLoading && vm.sectors.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if vm.selectedSector != nil {
                            backBar
                        }
                        if vm.selectedSubsector != nil {
                            stocksGrid
                        } else if vm.selectedSector != nil {
                            subsectorGrid
                        } else {
                            sectorGrid
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }

            if vm.isLoading && !vm.sectors.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                    .padding(20)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(12)
            }
        }
        .task { await vm.loadSectors() }
    }

    private var backBar: some View {
        Button { vm.goBack() } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: scaled(14), weight: .semibold))
                Text(vm.selectedSubsector != nil ? (vm.selectedSector ?? "") : "All Sectors")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(Theme.primaryBlue)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.bottom, 12)
    }

    private var sectorGrid: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(vm.sectors.enumerated()), id: \.element.id) { idx, sector in
                Button { Task { await vm.selectSector(sector.sector) } } label: {
                    SectorTile(title: sector.sector, subtitle: "\(sector.stockCount) stocks",
                               color: sectorColor(at: idx), icon: sectorIcon(for: sector.sector))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var subsectorGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.selectedSector ?? "")
                .font(.title2).fontWeight(.bold).foregroundColor(.white).padding(.bottom, 4)
            if vm.subsectors.isEmpty && !vm.isLoading {
                Text("No subsectors found").foregroundColor(Theme.textMuted)
                    .padding(.top, 20).frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(vm.subsectors.enumerated()), id: \.element.id) { idx, sub in
                        Button { Task { await vm.selectSubsector(sub) } } label: {
                            SectorTile(title: sub.subsector, subtitle: "\(sub.stockCount) stocks",
                                       color: sectorColor(at: idx + 3), icon: "building.2")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private var stocksGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.selectedSector ?? "").font(.caption).foregroundColor(Theme.textMuted)
                Text(vm.selectedSubsector?.subsector ?? "")
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
            }
            .padding(.bottom, 4)
            if vm.subsectorStocks.isEmpty && !vm.isLoading {
                Text("No stocks found").foregroundColor(Theme.textMuted)
                    .padding(.top, 20).frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.subsectorStocks) { s in
                        StockRowView(stock: Stock(
                            id: s.symbol, symbol: s.symbol, companyName: s.companyName,
                            price: (s.price ?? 0) / 100.0, changeAmount: s.change ?? 0,
                            changePercent: s.changePercent ?? 0, sector: vm.selectedSector ?? "", marketCap: 0
                        ))
                    }
                }
            }
        }
    }
}

// MARK: - Sector Tile

struct SectorTile: View {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color).frame(width: 42, height: 42)
                Image(systemName: icon).font(.system(size: scaled(18))).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold).foregroundColor(.white).lineLimit(1)
                Text(subtitle).font(.caption).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: scaled(13), weight: .semibold)).foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.glassBackground)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Sector helpers

private func sectorColor(at index: Int) -> Color {
    let palette: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.2, green: 0.8, blue: 0.6),
        Color(red: 0.96, green: 0.62, blue: 0.04),
        Color(red: 0.94, green: 0.27, blue: 0.27),
        Color(red: 0.6, green: 0.4, blue: 0.9),
        Color(red: 0.3, green: 0.7, blue: 0.4),
        Color(red: 1.0, green: 0.5, blue: 0.3),
        Color(red: 0.5, green: 0.8, blue: 0.9),
        Color(red: 0.8, green: 0.4, blue: 0.6),
        Color(red: 0.7, green: 0.6, blue: 0.4),
    ]
    return palette[index % palette.count]
}

private func sectorIcon(for sector: String) -> String {
    let s = sector.lowercased()
    if s.contains("health") || s.contains("pharma") { return "cross.case" }
    if s.contains("tech") || s.contains("software") { return "cpu" }
    if s.contains("financ") || s.contains("bank") { return "building.columns" }
    if s.contains("energy") || s.contains("oil") { return "bolt" }
    if s.contains("consumer") && s.contains("discret") { return "cart" }
    if s.contains("consumer") { return "basket" }
    if s.contains("industrial") { return "gearshape.2" }
    if s.contains("material") || s.contains("mining") { return "cube" }
    if s.contains("real estate") || s.contains("reit") { return "house" }
    if s.contains("util") { return "light.max" }
    if s.contains("telecom") || s.contains("communication") { return "antenna.radiowaves.left.and.right" }
    if s.contains("transport") { return "airplane" }
    if s.contains("media") { return "play.rectangle" }
    return "chart.bar"
}

#Preview {
    StocksView()
}
