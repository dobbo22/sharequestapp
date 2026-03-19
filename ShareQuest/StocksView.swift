//
//  StocksView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

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
        }
        save()
    }
}

/// Stocks screen - matches React Native stocks.tsx
struct StocksView: View {
    @StateObject private var viewModel = StocksViewModel()
    @ObservedObject private var watchlist = WatchlistManager.shared
    @State private var selectedTab: StockTab? = nil
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.primaryGradient
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
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await viewModel.searchStocks(query: newValue)
                }
            }
        }
        .onChange(of: watchlist.items) { _, _ in
            // Refresh watchlist tab live when stars are toggled
            if selectedTab == .watchlist {
                searchTask?.cancel()
                searchTask = Task { await viewModel.fetchWatchlistStocks(items: WatchlistManager.shared.items) }
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
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
        .padding()
        .background(Theme.glassBackground)
        .cornerRadius(12)
        .padding()
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StockTab.allCases, id: \.self) { tab in
                    StockTabButton(tab: tab, isSelected: selectedTab == tab) {
                        searchText = ""
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
                                .font(.system(size: 48))
                                .foregroundColor(Theme.textMuted)
                            Text("No stocks in watchlist")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                            Text("Tap the ★ on any stock row or detail page to add it here")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Image(systemName: searchText.isEmpty ? "chart.bar.xaxis" : "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.textMuted)
                            Text(searchText.isEmpty ? "Browse or search stocks" : "No results for \"\(searchText)\"")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                            if searchText.isEmpty {
                                Text("Tap a category above or type to search the full database")
                                    .font(.caption)
                                    .foregroundColor(Theme.textMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(viewModel.stocks) { stock in
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

    var body: some View {
        NavigationLink(destination: StockDetailView(stock: stock)) {
            HStack {
                // Stock Info
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

                // Price & Change
                VStack(alignment: .trailing, spacing: 6) {
                    Text(stock.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                    ChangePill(percent: stock.changePercent)
                }

                // Star button — BorderlessButtonStyle prevents nav link from firing
                Button {
                    watchlist.toggle(stock: stock)
                } label: {
                    Image(systemName: watchlist.isWatched(stock.symbol) ? "star.fill" : "star")
                        .font(.system(size: 16))
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

// MARK: - Stock Detail Header (Contains all stock info)
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
            // Top row: company name + trade button
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
            
            // Symbol
            Text(symbol)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Price and Change
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
            
            // Sector and Industry pills
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
    
    // Color coding for sectors
    private func sectorColor(for sector: String) -> Color {
        let sectorLower = sector.lowercased()
        if sectorLower.contains("health") { return Color(red: 0.2, green: 0.8, blue: 0.6) } // Teal
        if sectorLower.contains("tech") { return Color(red: 0.4, green: 0.6, blue: 1.0) } // Blue
        if sectorLower.contains("financ") { return Color(red: 0.3, green: 0.7, blue: 0.4) } // Green
        if sectorLower.contains("consumer") && sectorLower.contains("defen") { return Color(red: 0.9, green: 0.6, blue: 0.2) } // Orange
        if sectorLower.contains("consumer") { return Color(red: 1.0, green: 0.5, blue: 0.5) } // Coral
        if sectorLower.contains("energy") { return Color(red: 1.0, green: 0.8, blue: 0.2) } // Yellow
        if sectorLower.contains("industrial") { return Color(red: 0.6, green: 0.6, blue: 0.7) } // Gray-blue
        if sectorLower.contains("material") { return Color(red: 0.8, green: 0.5, blue: 0.3) } // Brown
        if sectorLower.contains("utilit") { return Color(red: 0.5, green: 0.8, blue: 0.9) } // Light blue
        if sectorLower.contains("real estate") { return Color(red: 0.7, green: 0.5, blue: 0.8) } // Purple
        if sectorLower.contains("communication") { return Color(red: 0.9, green: 0.4, blue: 0.6) } // Pink
        if sectorLower.contains("basic") { return Color(red: 0.6, green: 0.8, blue: 0.4) } // Lime
        return Theme.primaryBlue // Default
    }
    
    // Color coding for industries (slightly different shade)
    private func industryColor(for industry: String) -> Color {
        let industryLower = industry.lowercased()
        if industryLower.contains("drug") || industryLower.contains("pharm") { return Color(red: 0.3, green: 0.7, blue: 0.9) } // Light blue
        if industryLower.contains("bank") { return Color(red: 0.2, green: 0.6, blue: 0.4) } // Dark green
        if industryLower.contains("insurance") { return Color(red: 0.4, green: 0.7, blue: 0.5) } // Sea green
        if industryLower.contains("oil") || industryLower.contains("gas") { return Color(red: 0.9, green: 0.7, blue: 0.3) } // Gold
        if industryLower.contains("retail") { return Color(red: 1.0, green: 0.6, blue: 0.4) } // Peach
        if industryLower.contains("beverage") || industryLower.contains("drink") { return Color(red: 0.8, green: 0.4, blue: 0.6) } // Rose
        if industryLower.contains("food") { return Color(red: 0.9, green: 0.5, blue: 0.3) } // Tangerine
        if industryLower.contains("aerospace") || industryLower.contains("defense") { return Color(red: 0.5, green: 0.5, blue: 0.7) } // Slate
        if industryLower.contains("auto") { return Color(red: 0.6, green: 0.6, blue: 0.6) } // Gray
        if industryLower.contains("telecom") { return Color(red: 0.8, green: 0.3, blue: 0.5) } // Magenta
        if industryLower.contains("software") || industryLower.contains("internet") { return Color(red: 0.5, green: 0.5, blue: 1.0) } // Indigo
        if industryLower.contains("mining") { return Color(red: 0.7, green: 0.6, blue: 0.4) } // Tan
        return Theme.accentPurple // Default
    }
}

// MARK: - Sector/Industry Pill Button
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
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stock Detail View
struct StockDetailView: View {
    let stock: Stock
    @StateObject private var vm: StockDetailViewModel
    @ObservedObject private var watchlist = WatchlistManager.shared
    @State private var showTradeSheet = false

    init(stock: Stock) {
        self.stock = stock
        _vm = StateObject(wrappedValue: StockDetailViewModel(symbol: stock.symbol))
    }

    var body: some View {
        ZStack {
            Theme.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header - contains all stock info
                StockDetailHeader(
                    companyName: (vm.quote == nil || vm.companyName == vm.displaySymbol) ? stock.companyName : vm.companyName,
                    symbol: vm.displaySymbol,
                    price: vm.pencePriceString,
                    changePercent: vm.changePercent,
                    sector: vm.sectorDisplay,
                    industry: vm.subsectorDisplay,
                    onTrade: { showTradeSheet.toggle() }
                )

                // Buffer space
                Spacer().frame(height: 12)

                // Tabs and content in cards area
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
        .sheet(isPresented: $showTradeSheet) {
            StockTradeSheet(stock: stock)
        }
    }
}

// MARK: - Portfolio Concentration Logic (ported from portfolio-limits.ts)

private let portfolioConcentrationLimits: [String: Double] = [
    "weekly": 20, "monthly": 10, "annual": 10, "default": 100
]

private struct ConcentrationResult {
    let isValid: Bool
    let errorMessage: String?
    let warningMessage: String?
    let maxSharesAllowed: Int?
}

private func concentrationTotalValue(cashPence: Double, holdings: [PortfolioResponse.HoldingData]) -> Double {
    let holdingsValue = holdings.reduce(into: 0.0) { $0 += Double($1.quantity) * ($1.mid ?? $1.mid_price ?? $1.current_price) }
    return cashPence + holdingsValue
}

private func concentrationMaxShares(portfolioType: String, symbol: String, pricePence: Double, cashPence: Double, holdings: [PortfolioResponse.HoldingData]) -> Int {
    guard pricePence > 0 else { return 0 }
    let total = concentrationTotalValue(cashPence: cashPence, holdings: holdings)
    let maxPct = portfolioConcentrationLimits[portfolioType] ?? 100
    let maxAllowed = total * maxPct / 100
    let existing = holdings.first(where: { $0.symbol == symbol })
    let existingValue = existing.map { Double($0.quantity) * ($0.mid ?? $0.mid_price ?? $0.current_price) } ?? 0
    let remaining = maxAllowed - existingValue
    if remaining <= 0 { return 0 }
    return min(Int(remaining / pricePence), Int(cashPence / pricePence))
}

private func concentrationValidate(portfolioType: String, symbol: String, action: String, quantity: Int, pricePence: Double, cashPence: Double, holdings: [PortfolioResponse.HoldingData]) -> ConcentrationResult {
    if action == "sell" {
        return ConcentrationResult(isValid: true, errorMessage: nil, warningMessage: nil, maxSharesAllowed: nil)
    }
    guard pricePence > 0, quantity > 0 else {
        return ConcentrationResult(isValid: true, errorMessage: nil, warningMessage: nil, maxSharesAllowed: nil)
    }
    let total = concentrationTotalValue(cashPence: cashPence, holdings: holdings)
    let maxPct = portfolioConcentrationLimits[portfolioType] ?? 100
    let maxAllowed = total * maxPct / 100
    let existing = holdings.first(where: { $0.symbol == symbol })
    let existingQty = existing.map { $0.quantity } ?? 0
    let combinedValue = Double(existingQty + quantity) * pricePence
    let existingValue = Double(existingQty) * pricePence
    let newValue = Double(quantity) * pricePence
    let remaining = maxAllowed - existingValue
    let isValid = newValue <= remaining && total > 0
    let combinedPct = total > 0 ? (combinedValue / total) * 100 : 0
    var errorMsg: String? = nil
    var warnMsg: String? = nil
    if !isValid {
        errorMsg = "This trade would exceed the \(Int(maxPct))% concentration limit. Max allowed: £\(String(format: "%.2f", maxAllowed / 100))"
    } else if combinedPct > maxPct * 0.9 {
        warnMsg = String(format: "Warning: This trade brings your holding to %.1f%% of portfolio.", combinedPct)
    }
    let maxShares = concentrationMaxShares(portfolioType: portfolioType, symbol: symbol, pricePence: pricePence, cashPence: cashPence, holdings: holdings)
    return ConcentrationResult(isValid: isValid, errorMessage: errorMsg, warningMessage: warnMsg, maxSharesAllowed: maxShares)
}

// MARK: - Trade Sheet ViewModel

@MainActor
class TradeSheetViewModel: ObservableObject {
    let stock: Stock

    @Published var tradeAction: String = "buy"
    @Published var selectedPortfolio: String = "default"
    @Published var quantity: String = ""
    @Published var isLoading: Bool = false
    @Published var isLoadingData: Bool = false
    @Published var error: String? = nil
    @Published var concentrationWarning: String? = nil
    @Published var maxSharesAllowed: Int? = nil
    @Published var holdings: [PortfolioResponse.HoldingData] = []
    @Published var cashPence: Double = 10_000_000
    @Published var tradingWindow: TradingWindowData? = nil
    @Published var tradeSuccess: TradeSuccessInfo? = nil

    struct TradeSuccessInfo: Equatable {
        let message: String
        let isPendingOrder: Bool
    }

    @Published var availablePortfolios: [(id: String, label: String, icon: String)] = [
        ("default", "Practice", "graduationcap")
    ]

    var hasHolding: Bool {
        holdings.contains(where: { $0.symbol == stock.symbol })
    }

    var estimatedTotalPounds: Double {
        guard let qty = Int(quantity), qty > 0 else { return 0 }
        return Double(qty) * stock.price / 100.0
    }

    var executeButtonColors: [Color] {
        if let window = tradingWindow {
            if window.isAfterHours { return [Color(red: 0.96, green: 0.62, blue: 0.04), Color(red: 0.85, green: 0.59, blue: 0.02)] }
            if window.isPreMarket { return [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.15, green: 0.39, blue: 0.92)] }
        }
        return tradeAction == "buy"
            ? [Color(red: 0.06, green: 0.73, blue: 0.51), Color(red: 0.02, green: 0.59, blue: 0.40)]
            : [Color(red: 0.94, green: 0.27, blue: 0.27), Color(red: 0.86, green: 0.15, blue: 0.15)]
    }

    var executeButtonLabel: String {
        if let window = tradingWindow {
            if window.isPreMarket { return "Schedule \(tradeAction == "buy" ? "Buy" : "Sell")" }
            if window.isAfterHours { return "\(tradeAction == "buy" ? "Buy" : "Sell") at Close" }
        }
        return "\(tradeAction == "buy" ? "Buy" : "Sell") \(stock.symbol)"
    }

    var executeButtonIcon: String {
        if let window = tradingWindow, window.isPreMarket { return "clock" }
        return tradeAction == "buy" ? "plus.circle.fill" : "minus.circle.fill"
    }

    var isExecuteDisabled: Bool {
        isLoading || quantity.isEmpty || (error != nil) || tradeSuccess != nil
    }

    init(stock: Stock) {
        self.stock = stock
    }

    func loadData() async {
        isLoadingData = true
        async let portfolioTask: () = loadPortfolio()
        async let windowTask: () = loadTradingWindow()
        async let subsTask: () = loadAvailablePortfolios()
        await portfolioTask
        await windowTask
        await subsTask
        isLoadingData = false
    }

    private func loadAvailablePortfolios() async {
        var list: [(id: String, label: String, icon: String)] = [("default", "Practice", "graduationcap")]
        do {
            if let subs = try await APIService.shared.fetchUserSubscriptions() {
                if subs.weekly == true  { list.append(("weekly",  "Weekly",  "calendar")) }
                if subs.monthly == true { list.append(("monthly", "Monthly", "calendar.badge.clock")) }
                if subs.annual == true  { list.append(("annual",  "Annual",  "trophy")) }
            }
        } catch { /* keep practice-only list */ }
        availablePortfolios = list
        if !list.contains(where: { $0.id == selectedPortfolio }) {
            selectedPortfolio = "default"
        }
    }

    private func loadPortfolio() async {
        do {
            let resp = try await APIService.shared.fetchPortfolio(type: selectedPortfolio)
            holdings = resp.holdings ?? []
            let raw = Double(resp.portfolio?.cash_balance ?? "10000000") ?? 10_000_000
            cashPence = raw
        } catch {
            holdings = []
            cashPence = 10_000_000
        }
    }

    private func loadTradingWindow() async {
        do {
            tradingWindow = try await APIService.shared.fetchTradingWindow()
        } catch {
            tradingWindow = TradingWindowData(type: "market_open", canTradeImmediately: true, canCreatePendingOrder: false, executionPrice: "live", message: "Market is open.")
        }
    }

    func onPortfolioChanged() async {
        await loadPortfolio()
        if tradeAction == "sell" && !hasHolding {
            tradeAction = "buy"
        }
        revalidate()
    }

    func revalidate() {
        guard let qty = Int(quantity), qty > 0 else {
            concentrationWarning = nil
            error = nil
            maxSharesAllowed = nil
            return
        }
        // Cash balance check for buys
        if tradeAction == "buy" {
            let maxAffordable = cashPence > 0 && stock.price > 0 ? Int(cashPence / stock.price) : 0
            if qty > maxAffordable {
                error = "Insufficient funds. Max: \(maxAffordable) shares"
                maxSharesAllowed = maxAffordable
                concentrationWarning = nil
                return
            }
        }
        // Sell check
        if tradeAction == "sell" {
            let holding = holdings.first(where: { $0.symbol == stock.symbol })
            let owned = holding?.quantity ?? 0
            if qty > owned {
                error = "You can only sell up to \(owned) shares"
                concentrationWarning = nil
                maxSharesAllowed = nil
                return
            }
        }
        let result = concentrationValidate(
            portfolioType: selectedPortfolio,
            symbol: stock.symbol,
            action: tradeAction,
            quantity: qty,
            pricePence: stock.price,
            cashPence: cashPence,
            holdings: holdings
        )
        error = result.errorMessage
        concentrationWarning = result.errorMessage == nil ? result.warningMessage : nil
        maxSharesAllowed = result.maxSharesAllowed
    }

    func executeTrade() async {
        guard let qty = Int(quantity), qty > 0 else {
            error = "Please enter a valid quantity"
            return
        }
        guard error == nil else { return }
        isLoading = true
        error = nil
        tradeSuccess = nil
        do {
            let resp = try await APIService.shared.executeMobileTrade(
                portfolioType: selectedPortfolio,
                symbol: stock.symbol,
                companyName: stock.companyName,
                action: tradeAction,
                quantity: qty,
                price: stock.price
            )
            if resp.success {
                let isPending = resp.data?.isPendingOrder ?? false
                let msg: String
                if isPending {
                    msg = resp.data?.message ?? "Order scheduled for market open"
                } else if resp.data?.isAfterHours == true {
                    msg = "\(tradeAction == "buy" ? "Bought" : "Sold") at closing price"
                } else {
                    msg = resp.data?.message ?? "\(tradeAction == "buy" ? "Bought" : "Sold") successfully"
                }
                tradeSuccess = TradeSuccessInfo(message: msg, isPendingOrder: isPending)
                quantity = ""
            } else {
                error = resp.error ?? resp.message ?? "Trade failed"
            }
        } catch {
            self.error = "An error occurred while processing your trade"
        }
        isLoading = false
    }
}

// MARK: - Stock Trade Sheet

struct StockTradeSheet: View {
    let stock: Stock
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: TradeSheetViewModel

    init(stock: Stock) {
        self.stock = stock
        _vm = StateObject(wrappedValue: TradeSheetViewModel(stock: stock))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.094, green: 0.094, blue: 0.110)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Trading window banner
                        if let window = vm.tradingWindow, !window.isMarketOpen {
                            tradingWindowBanner(window)
                        }

                        // Success message
                        if let success = vm.tradeSuccess {
                            successBanner(success)
                        }

                        // Buy / Sell toggle
                        actionToggle

                        // Portfolio selector
                        portfolioSelector

                        // Quantity
                        quantitySection

                        // Summary card
                        summaryCard

                        // Concentration warning / error
                        if let warn = vm.concentrationWarning, vm.error == nil {
                            alertRow(text: warn, color: Color(red: 0.96, green: 0.62, blue: 0.26), icon: "exclamationmark.triangle.fill")
                        }
                        if let err = vm.error {
                            alertRow(text: err, color: Color(red: 0.94, green: 0.27, blue: 0.27), icon: "exclamationmark.circle.fill")
                        }

                        // Max shares info
                        if let max = vm.maxSharesAllowed, vm.tradeAction == "buy" {
                            HStack {
                                Text("Max allowed:")
                                    .foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))
                                Text("\(max) shares")
                                    .foregroundColor(Theme.primaryBlue)
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                        }

                        // Execute button
                        executeButton

                        // Disclaimer
                        Text("This is a simulated trading platform for educational purposes only. No real money is involved.")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.52))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("\(stock.companyName) (\(stock.symbol))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.094, green: 0.094, blue: 0.110), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.primaryBlue)
                }
            }
        }
        .task { await vm.loadData() }
        .onChange(of: vm.quantity) { _, _ in vm.revalidate() }
        .onChange(of: vm.tradeAction) { _, _ in vm.revalidate() }
        .onChange(of: vm.selectedPortfolio) { _, _ in
            Task { await vm.onPortfolioChanged() }
        }
        .onChange(of: vm.tradeSuccess) { _, newSuccess in
            guard let success = newSuccess else { return }
            let delay: UInt64 = success.isPendingOrder ? 2_500_000_000 : 1_500_000_000
            Task {
                try? await Task.sleep(nanoseconds: delay)
                dismiss()
            }
        }
    }

    // MARK: - Trading Window Banner

    private func tradingWindowBanner(_ window: TradingWindowData) -> some View {
        HStack(spacing: 10) {
            Image(systemName: window.isAfterHours ? "moon.fill" : "clock")
                .foregroundColor(window.isAfterHours ? Color(red: 0.96, green: 0.62, blue: 0.04) : Theme.primaryBlue)
            Text(window.message ?? "")
                .font(.caption)
                .foregroundColor(window.isAfterHours ? Color(red: 0.96, green: 0.62, blue: 0.04) : Theme.primaryBlue)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(window.isAfterHours
                    ? Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.12)
                    : Theme.primaryBlue.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(window.isAfterHours ? Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.35) : Theme.primaryBlue.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Success Banner

    private func successBanner(_ info: TradeSheetViewModel.TradeSuccessInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: info.isPendingOrder ? "clock.fill" : "checkmark.circle.fill")
                .foregroundColor(info.isPendingOrder ? Theme.primaryBlue : Color(red: 0.06, green: 0.73, blue: 0.51))
            Text(info.message)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(info.isPendingOrder ? Theme.primaryBlue : Color(red: 0.06, green: 0.73, blue: 0.51))
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(info.isPendingOrder ? Theme.primaryBlue.opacity(0.12) : Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(info.isPendingOrder ? Theme.primaryBlue.opacity(0.35) : Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Action Toggle (Buy / Sell)

    private var actionToggle: some View {
        let buyColor = Color(red: 0.06, green: 0.73, blue: 0.51)
        let sellColor = Color(red: 0.94, green: 0.27, blue: 0.27)
        return HStack(spacing: 4) {
            // Buy — always shown
            Button { vm.tradeAction = "buy" } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Buy").fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(vm.tradeAction == "buy" ? buyColor : Color.clear)
                .foregroundColor(vm.tradeAction == "buy" ? .white : buyColor)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())

            // Sell — only shown if user holds this stock in selected portfolio
            if vm.hasHolding {
                Button { vm.tradeAction = "sell" } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle")
                        Text("Sell").fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(vm.tradeAction == "sell" ? sellColor : Color.clear)
                    .foregroundColor(vm.tradeAction == "sell" ? .white : sellColor)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.5))
        .cornerRadius(14)
    }

    // MARK: - Portfolio Selector

    private var portfolioSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SELECT PORTFOLIO")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(vm.availablePortfolios, id: \.id) { option in
                    let color = portfolioColor(for: option.id)
                    let isSelected = vm.selectedPortfolio == option.id
                    Button {
                        vm.selectedPortfolio = option.id
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: option.icon)
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? .white : color)
                            Text(option.label)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(isSelected ? .white : color)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? color : color.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Quantity Input

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUANTITY (SHARES)")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))

            TextField("Enter number of shares", text: $vm.quantity)
                .keyboardType(.numberPad)
                .font(.title3)
                .foregroundColor(.white)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.29, green: 0.34, blue: 0.39).opacity(0.4), lineWidth: 1)
                )

        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow(label: "Price per Share", value: stock.formattedPrice)
            Divider().background(Color(red: 0.29, green: 0.34, blue: 0.39).opacity(0.35)).padding(.vertical, 8)
            summaryRow(label: "Quantity", value: "\(vm.quantity.isEmpty ? "0" : vm.quantity) shares")
            Divider().background(Color(red: 0.29, green: 0.34, blue: 0.39).opacity(0.35)).padding(.vertical, 8)

            // Total row
            HStack {
                Text("Estimated Total")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text("£\(String(format: "%.2f", vm.estimatedTotalPounds))")
                    .font(.title3).fontWeight(.bold)
                    .foregroundColor(Theme.primaryBlue)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.29, green: 0.34, blue: 0.39).opacity(0.4), lineWidth: 1)
        )
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))
            Spacer()
            Text(value)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(.white)
        }
    }

    // MARK: - Alert Row (warning / error)

    private func alertRow(text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(text)
                .font(.caption)
                .foregroundColor(color)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Execute Button

    private var executeButton: some View {
        Button {
            Task { await vm.executeTrade() }
        } label: {
            HStack(spacing: 8) {
                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: vm.executeButtonIcon)
                        .font(.system(size: 20))
                    Text(vm.executeButtonLabel)
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: vm.isExecuteDisabled ? [Color.gray.opacity(0.4), Color.gray.opacity(0.3)] : vm.executeButtonColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
        .disabled(vm.isExecuteDisabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stock Tab Enum
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

// MARK: - Stock Model
struct Stock: Identifiable {
    let id: String
    let symbol: String
    let companyName: String
    let price: Double
    let changeAmount: Double
    let changePercent: Double
    let sector: String
    let marketCap: Double
    
    /// Price in pence, formatted with smart decimal places
    var formattedPrice: String {
        if price <= 0 { return "—" }
        if price >= 1 {
            // 1p and above: comma-separated thousands, 2dp (e.g. "14,104.00p")
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.groupingSeparator = ","
            formatter.decimalSeparator = "."
            let formatted = formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
            return "\(formatted)p"
        } else {
            // Sub-penny: find the first significant digit and show 2 more after it
            var decimals = 2
            var check = price
            while check < 1 && decimals < 8 {
                check *= 10
                decimals += 1
            }
            return String(format: "%.\(decimals)fp", price)
        }
    }
    
    var formattedChange: String {
        String(format: "%+.2f%%", changePercent)
    }
    
    var formattedChangeAmount: String {
        String(format: "%+.2f", changeAmount)
    }
    
    var formattedMarketCap: String {
        if marketCap >= 1_000_000_000 {
            return "£\(String(format: "%.1fB", marketCap / 1_000_000_000))"
        } else if marketCap >= 1_000_000 {
            return "£\(String(format: "%.1fM", marketCap / 1_000_000))"
        }
        return "£\(String(format: "%.0f", marketCap))"
    }
    
    /// Create Stock from API StockData — price stored in pence
    init(from stockData: StockData) {
        self.id = stockData.symbol
        self.symbol = stockData.symbol
        self.companyName = stockData.displayName
        self.price = stockData.rawPencePrice  // keep in pence for display
        self.changeAmount = stockData.displayChange
        self.changePercent = stockData.displayChangePercent
        self.sector = stockData.sector ?? "Unknown"
        self.marketCap = stockData.displayMarketCap
    }
    
    init(id: String, symbol: String, companyName: String, price: Double, changeAmount: Double, changePercent: Double, sector: String, marketCap: Double) {
        self.id = id
        self.symbol = symbol
        self.companyName = companyName
        self.price = price
        self.changeAmount = changeAmount
        self.changePercent = changePercent
        self.sector = sector
        self.marketCap = marketCap
    }
}

// MARK: - Stocks ViewModel
@MainActor
class StocksViewModel: ObservableObject {
    @Published var stocks: [Stock] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func clearStocks() {
        stocks = []
        errorMessage = nil
    }
    
    private let apiService = APIService.shared
    
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

            stocks = stockData.map { Stock(from: $0) }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func fetchWatchlistStocks(items: [WatchlistItem]) async {
        guard !items.isEmpty else {
            stocks = []
            return
        }
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
                let data = allQuotes[sym]
                return Stock(
                    id: sym,
                    symbol: sym,
                    companyName: nameMap[sym] ?? sym,
                    price: data?.price ?? 0,
                    changeAmount: data?.change ?? 0,
                    changePercent: data?.changePercent ?? 0,
                    sector: "",
                    marketCap: 0
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
            stocks = stockData.map { Stock(from: $0) }
        } catch {
            // Keep last loaded values, just show error
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Sector Colors

private let sectorColorPalette: [Color] = [
    Color(red: 0.23, green: 0.51, blue: 0.96),
    Color(red: 0.55, green: 0.36, blue: 0.96),
    Color(red: 0.93, green: 0.29, blue: 0.60),
    Color(red: 0.06, green: 0.72, blue: 0.51),
    Color(red: 0.96, green: 0.62, blue: 0.04),
    Color(red: 0.94, green: 0.27, blue: 0.27),
    Color(red: 0.02, green: 0.71, blue: 0.83),
    Color(red: 0.39, green: 0.40, blue: 0.95),
    Color(red: 0.08, green: 0.72, blue: 0.64),
    Color(red: 0.97, green: 0.45, blue: 0.09),
    Color(red: 0.52, green: 0.80, blue: 0.09),
    Color(red: 0.66, green: 0.33, blue: 0.97),
    Color(red: 0.96, green: 0.62, blue: 0.26),
    Color(red: 0.29, green: 0.85, blue: 0.87),
    Color(red: 0.30, green: 0.68, blue: 0.27),
]

private func sectorColor(at index: Int) -> Color {
    sectorColorPalette[index % sectorColorPalette.count]
}

// MARK: - Sectors ViewModel

@MainActor
class SectorsViewModel: ObservableObject {
    @Published var sectors: [SectorItem] = []
    @Published var subsectors: [SubsectorItem] = []
    @Published var stockQuotes: [String: BatchPriceData] = [:]
    @Published var selectedSector: String? = nil
    @Published var selectedSubsector: SubsectorItem? = nil
    @Published var isLoading = false

    /// Stocks in the selected subsector with their price data merged in
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
        }.sorted { ($0.companyName) < ($1.companyName) }
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

        var formattedChange: String {
            guard let pct = changePercent else { return "" }
            return String(format: "%+.2f%%", pct)
        }

        var isPositive: Bool { (changePercent ?? 0) >= 0 }
    }

    func loadSectors() async {
        guard sectors.isEmpty else { return }
        isLoading = true
        do {
            sectors = try await APIService.shared.fetchSectors()
        } catch {
            print("[Sectors] load failed: \(error)")
        }
        isLoading = false
    }

    func selectSector(_ name: String) async {
        selectedSector = name
        selectedSubsector = nil
        stockQuotes = [:]
        subsectors = []
        isLoading = true
        do {
            subsectors = try await APIService.shared.fetchSubsectors(sector: name)
        } catch {
            print("[Sectors] subsector load failed: \(error)")
        }
        isLoading = false
    }

    func selectSubsector(_ sub: SubsectorItem) async {
        selectedSubsector = sub
        stockQuotes = [:]
        let symbols = (sub.stocks ?? []).map { $0.symbol }
        guard !symbols.isEmpty else { return }
        isLoading = true
        // Batch in chunks of 50
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
                        // Breadcrumb / back bar
                        if vm.selectedSector != nil {
                            backBar
                        }

                        if vm.selectedSubsector != nil {
                            // Level 3: stocks grid
                            stocksGrid
                        } else if vm.selectedSector != nil {
                            // Level 2: subsector tiles
                            subsectorGrid
                        } else {
                            // Level 1: sector tiles
                            sectorGrid
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }

            // Loading overlay for drill-down fetches
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

    // MARK: Back bar

    private var backBar: some View {
        Button {
            vm.goBack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                if vm.selectedSubsector != nil {
                    Text(vm.selectedSector ?? "")
                        .fontWeight(.semibold)
                } else {
                    Text("All Sectors")
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)
            .foregroundColor(Theme.primaryBlue)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.bottom, 12)
    }

    // MARK: Level 1 — Sector list

    private var sectorGrid: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(vm.sectors.enumerated()), id: \.element.id) { idx, sector in
                Button {
                    Task { await vm.selectSector(sector.sector) }
                } label: {
                    SectorTile(
                        title: sector.sector,
                        subtitle: "\(sector.stockCount) stocks",
                        color: sectorColor(at: idx),
                        icon: sectorIcon(for: sector.sector)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: Level 2 — Subsector list

    private var subsectorGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.selectedSector ?? "")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 4)

            if vm.subsectors.isEmpty && !vm.isLoading {
                Text("No subsectors found")
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(vm.subsectors.enumerated()), id: \.element.id) { idx, sub in
                        Button {
                            Task { await vm.selectSubsector(sub) }
                        } label: {
                            SectorTile(
                                title: sub.subsector,
                                subtitle: "\(sub.stockCount) stocks",
                                color: sectorColor(at: idx + 3),
                                icon: "building.2"
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: Level 3 — Stocks list (same row style as search results)

    private var stocksGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.selectedSector ?? "")
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
                Text(vm.selectedSubsector?.subsector ?? "")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)

            if vm.subsectorStocks.isEmpty && !vm.isLoading {
                Text("No stocks found")
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.subsectorStocks) { stock in
                        StockRowView(stock: Stock(
                            id: stock.symbol,
                            symbol: stock.symbol,
                            companyName: stock.companyName,
                            price: stock.price ?? 0,
                            changeAmount: stock.change ?? 0,
                            changePercent: stock.changePercent ?? 0,
                            sector: vm.selectedSector ?? "",
                            marketCap: 0
                        ))
                    }
                }
            }
        }
    }
}

// MARK: - Sector Tile (compact single-column row)

struct SectorTile: View {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            // Coloured icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.glassBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Sector icon helper

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
