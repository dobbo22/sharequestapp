//
//  StocksView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

/// Stocks screen - matches React Native stocks.tsx
struct StocksView: View {
    @StateObject private var viewModel = StocksViewModel()
    @State private var selectedTab: StockTab = .top100
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.primaryGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                    
                    // Tab Selector
                    tabSelector
                    
                    // Content
                    stocksList
                }
            }
            .navigationTitle("Stocks")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.fetchStocks(tab: selectedTab)
        }
        .onChange(of: selectedTab) { _, newTab in
            Task {
                await viewModel.fetchStocks(tab: newTab)
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textMuted)
            TextField("Search stocks...", text: $searchText)
                .foregroundColor(Theme.textPrimary)
                .autocorrectionDisabled()
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
                    StockTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
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
                } else {
                    let filteredStocks = searchText.isEmpty ? viewModel.stocks : viewModel.stocks.filter {
                        $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                        $0.companyName.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    ForEach(filteredStocks) { stock in
                        StockRowView(stock: stock)
                     }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.fetchStocks(tab: selectedTab)
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
    
    var body: some View {
        NavigationLink(destination: StockDetailView(stock: stock)) {
            HStack {
                // Stock Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text(stock.companyName)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Price & Change
                VStack(alignment: .trailing, spacing: 4) {
                    Text(stock.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text(stock.formattedChange)
                        Image(systemName: stock.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    }
                    .font(.caption)
                    .foregroundColor(stock.changePercent >= 0 ? Theme.accentGreen : Theme.accentRed)
                }
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    
                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                    Text(String(format: "%@%.2f%%", isPositive ? "+" : "", changePercent))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("today")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .foregroundColor(isPositive ? .green : .red)
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
        .sheet(isPresented: $showTradeSheet) {
            StockTradeSheet(stock: stock)
        }
    }
}

// MARK: - Stock Trade Sheet
struct StockTradeSheet: View {
    let stock: Stock
    @Environment(\.dismiss) private var dismiss
    @State private var quantity = ""
    @State private var tradeType: TradeType = .buy
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Stock Info
                    VStack(spacing: 8) {
                        Text(stock.symbol)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                        Text(stock.formattedPrice)
                            .font(.title2)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    // Trade Type Picker
                    Picker("Trade Type", selection: $tradeType) {
                        Text("Buy").tag(TradeType.buy)
                        Text("Sell").tag(TradeType.sell)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Quantity Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quantity")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        TextField("0", text: $quantity)
                            .keyboardType(.numberPad)
                            .font(.title2)
                            .padding()
                            .background(Theme.glassBackground)
                            .cornerRadius(12)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.horizontal)
                    
                    // Estimated Cost
                    if let qty = Int(quantity), qty > 0 {
                        let total = Double(qty) * stock.price
                        Text("Estimated: £\(String(format: "%.2f", total))")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Trade Button
                    Button(action: executeTrade) {
                        Text(tradeType == .buy ? "Buy \(stock.symbol)" : "Sell \(stock.symbol)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(tradeType == .buy ? Theme.accentGreen : Theme.accentRed)
                            .cornerRadius(12)
                    }
                    .padding()
                    .disabled(quantity.isEmpty)
                }
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.primaryBlue)
                }
            }
        }
    }
    
    private func executeTrade() {
        // TODO: Implement trade execution via API
        dismiss()
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
    
    var formattedPrice: String {
        "£\(String(format: "%.2f", price))"
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
    
    /// Create Stock from API StockData
    init(from stockData: StockData) {
        self.id = stockData.symbol
        self.symbol = stockData.symbol
        self.companyName = stockData.displayName
        self.price = stockData.displayPrice
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
                // For now, use Top 100 for these tabs
                stockData = try await apiService.fetchFTSE100()
            }
            
            stocks = stockData.map { Stock(from: $0) }
            
        } catch {
            // Keep last loaded values, just show error
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

#Preview {
    StocksView()
}
