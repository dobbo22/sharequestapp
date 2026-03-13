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
    @State private var selectedPortfolioType: PortfolioType = .practice
    @State private var showTradeSheet = false
    @State private var selectedHolding: Holding?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.primaryGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Portfolio Type Selector
                        portfolioTypeSelector
                        
                        // Portfolio Summary Card
                        portfolioSummaryCard
                        
                        // Holdings Section
                        holdingsSection
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.fetchPortfolio(type: selectedPortfolioType)
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.fetchPortfolio(type: selectedPortfolioType)
        }
        .onChange(of: selectedPortfolioType) { _, newType in
            Task {
                await viewModel.fetchPortfolio(type: newType)
            }
        }
        .sheet(isPresented: $showTradeSheet) {
            if let holding = selectedHolding {
                TradeSheetView(holding: holding)
            }
        }
    }
    
    // MARK: - Portfolio Type Selector
    private var portfolioTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PortfolioType.allCases, id: \.self) { type in
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
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            
            // Change
            HStack(spacing: 8) {
                Image(systemName: viewModel.totalChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(viewModel.formattedChange)
            }
            .font(.headline)
            .foregroundColor(viewModel.totalChange >= 0 ? Theme.accentGreen : Theme.accentRed)
            
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
                        showTradeSheet = true
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
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? type.color.opacity(0.3) : Theme.glassBackground)
            .foregroundColor(isSelected ? type.color : Theme.textSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? type.color : Theme.glassBorder, lineWidth: 1)
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
                    Text(holding.symbol)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text(holding.companyName)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Value & Change
                VStack(alignment: .trailing, spacing: 4) {
                    Text(holding.formattedValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text(holding.formattedChange)
                        Image(systemName: holding.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    }
                    .font(.caption)
                    .foregroundColor(holding.changePercent >= 0 ? Theme.accentGreen : Theme.accentRed)
                }
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Trade Sheet View
struct TradeSheetView: View {
    let holding: Holding
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
                        Text(holding.symbol)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                        Text(holding.companyName)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        Text(holding.formattedPrice)
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
                    
                    Spacer()
                    
                    // Trade Button
                    Button(action: executeTrade) {
                        Text(tradeType == .buy ? "Buy" : "Sell")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(tradeType == .buy ? Theme.accentGreen : Theme.accentRed)
                            .cornerRadius(12)
                    }
                    .padding()
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
        // TODO: Implement trade execution
        dismiss()
    }
}

enum TradeType {
    case buy, sell
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
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    var totalValue: Double {
        cashBalance + holdings.reduce(0) { $0 + $1.value }
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
            }
            
            if let holdingsData = response.holdings {
                holdings = holdingsData.map { h in
                    Holding(
                        id: h.symbol,
                        symbol: h.symbol,
                        companyName: h.displayName,
                        quantity: h.quantity,
                        averagePrice: h.average_price / 100, // Convert pence to pounds
                        currentPrice: h.current_price / 100
                    )
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
