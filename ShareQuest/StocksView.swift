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

// MARK: - Stock Detail View
struct StockDetailView: View {
    let stock: Stock
    @State private var showTradeSheet = false
    
    var body: some View {
        ZStack {
            Theme.primaryGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(stock.symbol)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                        Text(stock.companyName)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top)
                    
                    // Price Card
                    VStack(spacing: 12) {
                        Text(stock.formattedPrice)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        
                        HStack(spacing: 8) {
                            Text(stock.formattedChangeAmount)
                            Text("(\(stock.formattedChange))")
                        }
                        .font(.headline)
                        .foregroundColor(stock.changePercent >= 0 ? Theme.accentGreen : Theme.accentRed)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    
                    // Trade Button
                    Button(action: { showTradeSheet = true }) {
                        Text("Trade")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primaryBlue)
                            .cornerRadius(12)
                    }
                    
                    // Stock Info
                    stockInfoSection
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTradeSheet) {
            StockTradeSheet(stock: stock)
        }
    }
    
    private var stockInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            VStack(spacing: 12) {
                InfoRow(label: "Sector", value: stock.sector)
                InfoRow(label: "Market Cap", value: stock.formattedMarketCap)
                InfoRow(label: "Day High", value: stock.formattedPrice)
                InfoRow(label: "Day Low", value: stock.formattedPrice)
            }
            .padding()
            .glassCard()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
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
