//
//  PortfolioView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

/// Portfolio screen - matches React Native portfolio.tsx
struct PortfolioView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @State private var selectedPortfolioType: PortfolioType
    @State private var selectedHolding: Holding?
    @State private var availablePortfolios: [PortfolioConfig] = []

    /// When pushed via NavigationLink from Dashboard, skip the inner NavigationStack
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
        .task {
            let done = await APIService.shared.postChallengeProgress(criteriaType: "portfolio_check")
            postCompletionNotification(done)
            // pnl_check fires here too — viewing portfolio counts as reviewing P&L
            let pnlDone = await APIService.shared.postChallengeProgress(criteriaType: "pnl_check")
            postCompletionNotification(pnlDone)
        }
        .task(id: selectedPortfolioType) {
            // Only reload when selectedPortfolioType changes
            await reloadPortfolios()
        }
        .onChange(of: selectedPortfolioType) { _, newType in
            Task { await viewModel.fetchPortfolio(type: newType) }
        }
        .sheet(item: $selectedHolding) { holding in
            StockTradeSheet(
                stock: holding.toStock(),
                portfolioType: selectedPortfolioType,
                initialTradeType: "sell",
                initialQuantity: String(holding.quantity)
            )
        }
    }

    private var portfolioContent: some View {
        ZStack {
            Theme.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    portfolioTypeSelector
                    portfolioSummaryCard
                    holdingsSection
                }
                .padding()
            }
            .refreshable { await reloadPortfolios() }
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Portfolio Type Selector
    private var portfolioTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availablePortfolios, id: \.type) { config in
                    let type = PortfolioType(rawValue: config.type) ?? .practice
                    PortfolioTypeButton(
                        type: type,
                        isSelected: selectedPortfolioType == type
                    ) {
                        selectedPortfolioType = type
                    }
                }
            }
        }
    }
    
    // MARK: - Portfolio Summary Card
    private var portfolioSummaryCard: some View {
        VStack(spacing: 16) {
            // Total Value
            VStack(spacing: 4) {
                Text("Total Value")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Text(viewModel.formattedTotalValue)
                    .font(.system(size: 28, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundColor(Theme.textPrimary)
            }
            
            // Change
            ChangePill(percent: viewModel.totalChange)
            
            Divider()
                .background(Theme.glassBorder)
            
            // Cash & Holdings
            HStack {
                VStack(spacing: 4) {
                    Text("Cash")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(viewModel.formattedCash)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Holdings")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(viewModel.formattedHoldingsValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding()
        .glassCard()
    }
    
    // MARK: - Holdings Section
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.holdings.count) stocks")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if viewModel.holdings.isEmpty {
                emptyHoldingsView
            } else {
                ForEach(viewModel.holdings) { holding in
                    HoldingRowView(holding: holding) {
                        selectedHolding = holding
                    }
                }
            }
        }
    }
    
    private var emptyHoldingsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase")
                .font(.system(size: 40))
                .foregroundColor(Theme.textMuted)
            Text("No holdings yet")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Text("Start trading to build your portfolio")
                .font(.caption)
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }
    
    // MARK: - Reload Portfolios
    private func reloadPortfolios() async {
        do {
            let dashboardResponse = try await APIService.shared.fetchDashboard()
            let portfolios: [PortfolioConfig] = dashboardResponse.data?.portfolios?.filter { $0.isSubscribed } ?? []
            await MainActor.run {
                availablePortfolios = portfolios
                // Default to first available portfolio if current is not available
                if !portfolios.contains(where: { $0.type == selectedPortfolioType.rawValue }) {
                    if let first = portfolios.first {
                        selectedPortfolioType = PortfolioType(rawValue: first.type) ?? .practice
                    }
                }
            }
            await viewModel.fetchPortfolio(type: selectedPortfolioType)
        } catch {
            // fallback: show only practice
            await MainActor.run {
                availablePortfolios = [PortfolioConfig(type: "default", label: "Practice", emoji: "🎯", color: "#3B82F6", isSubscribed: true)]
                selectedPortfolioType = .practice
            }
            await viewModel.fetchPortfolio(type: .practice)
        }
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
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                isSelected
                    ? LinearGradient(
                        colors: portfolioGradient(for: type.rawValue),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    : LinearGradient(
                        colors: [Theme.glassBackground, Theme.glassBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
            )
            .foregroundColor(isSelected ? .white : Theme.textSecondary)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        isSelected
                            ? Color.clear
                            : Theme.glassBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? portfolioColor(for: type.rawValue).opacity(0.45) : .clear,
                radius: 8, x: 0, y: 4
            )
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
                // Stock Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.companyName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 8) {
                        Text(holding.symbol)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                        Text("\(holding.quantity) shares")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Value & Change
                VStack(alignment: .trailing, spacing: 4) {
                    Text(holding.formattedValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(Theme.textPrimary)
                    
                    ChangePill(percent: holding.changePercent)
                }
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Helper to convert Holding to Stock
extension Holding {
    func toStock() -> Stock {
        Stock(
            id: self.id,
            symbol: self.symbol,
            companyName: self.companyName,
            price: self.currentPrice,
            changeAmount: 0, // Placeholder, update if available
            changePercent: self.changePercent,
            sector: "Portfolio", // Placeholder
            marketCap: 0 // Placeholder
        )
    }
}

// MARK: - Portfolio Type Enum
enum PortfolioType: String, CaseIterable {
    case practice = "default"
    case weekly = "weekly"
    case monthly = "monthly"
    case annual = "annual"
    
    var displayName: String {
        switch self {
        case .practice: return "Practice"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        }
    }
    
    var emoji: String {
        switch self {
        case .practice: return "🎯"
        case .weekly: return "⚡"
        case .monthly: return "📅"
        case .annual: return "🏆"
        }
    }
    
    var color: Color {
        switch self {
        case .practice: return Theme.accentGreen
        case .weekly: return Theme.primaryBlue
        case .monthly: return Theme.accentPurple
        case .annual: return Theme.accentYellow
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
    
    var value: Double {
        Double(quantity) * currentPrice
    }
    
    var changePercent: Double {
        guard averagePrice > 0 else { return 0 }
        return ((currentPrice - averagePrice) / averagePrice) * 100
    }
    
    var formattedValue: String {
        "£\(String(format: "%.2f", value))"
    }
    
    var formattedChange: String {
        String(format: "%+.2f%%", changePercent)
    }
    
    var formattedPrice: String {
        "£\(String(format: "%.2f", currentPrice))"
    }
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
    
    var totalValue: Double {
        totalPortfolioValue
    }
    
    var holdingsValue: Double {
        holdings.reduce(0) { $0 + $1.value }
    }
    
    var totalChange: Double {
        guard initialBalance > 0 else { return 0 }
        return ((totalValue - initialBalance) / initialBalance) * 100
    }
    
    var formattedTotalValue: String {
        "£\(String(format: "%.2f", totalValue))"
    }
    
    var formattedCash: String {
        "£\(String(format: "%.2f", cashBalance))"
    }
    
    var formattedHoldingsValue: String {
        "£\(String(format: "%.2f", holdingsValue))"
    }
    
    var formattedChange: String {
        String(format: "%+.2f%%", totalChange)
    }
    
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
            
            if let holdingsData = response.holdings {
                holdings = holdingsData.map { h in
                    let pricePence = h.mid ?? h.mid_price ?? h.current_price
                    return Holding(
                        id: h.symbol,
                        symbol: h.symbol,
                        companyName: h.displayName,
                        quantity: h.quantity,
                        averagePrice: h.average_price / 100, // Convert pence to pounds
                        currentPrice: pricePence / 100
                    )
                }
                // Debug logging: print holdings data
                print("[PortfolioViewModel] Holdings loaded:")
                for h in holdingsData {
                    let pricePence = h.mid ?? h.mid_price ?? h.current_price
                    print("\(h.symbol): qty=\(h.quantity), avg=\(h.average_price), price=\(pricePence), value=\(Double(h.quantity) * pricePence / 100)")
                }
            }
            
        } catch {
            // Keep last loaded values, just show error
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func executeTrade(portfolioType: PortfolioType, symbol: String, action: String, quantity: Int) async throws {
        let _ = try await apiService.executeTrade(
            portfolioType: portfolioType.rawValue,
            symbol: symbol,
            action: action,
            quantity: quantity
        )
        
        // Refresh portfolio after trade
        await fetchPortfolio(type: portfolioType)
    }
}

#Preview {
    PortfolioView()
}
