import SwiftUI

// MARK: - Main Stock Detail View (Card-Based Novice-Friendly Design)

struct StockDetailTabsView: View {
    @StateObject var vm: StockDetailViewModel
    @State private var activeTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview, price, stats, trade
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Tab Selector at top of cards area
                TabSelector(activeTab: $activeTab)
                    .padding(.top, 4)
                
                // Tab Content
                Group {
                    switch activeTab {
                    case .overview:
                        OverviewContent(vm: vm)
                    case .price:
                        PriceContent(vm: vm)
                    case .stats:
                        StatsContent(vm: vm)
                    case .trade:
                        TradeContent(vm: vm)
                    }
                }
                
                // Action Buttons removed — trade button moved to header
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .task {
            if vm.quote == nil {
                await vm.fetch()
            }
        }
    }
}

// MARK: - Change Indicator

struct ChangeIndicator: View {
    let change: Double
    let changePercent: Double
    var showLabel: Bool = false
    
    var isPositive: Bool { changePercent >= 0 }
    var color: Color { isPositive ? .green : .red }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)
            
            Text(String(format: "%@%.2f%%", isPositive ? "+" : "", changePercent))
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if showLabel {
                Text("today")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .foregroundColor(color)
    }
}

// MARK: - Tab Selector

struct TabSelector: View {
    @Binding var activeTab: StockDetailTabsView.Tab
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StockDetailTabsView.Tab.allCases, id: \.rawValue) { tab in
                    TabButton(
                        title: tab.displayName,
                        isActive: activeTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(isActive ? .white : .white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isActive ? Theme.primaryBlue : Color.clear)
                .cornerRadius(20)
        }
    }
}

private extension StockDetailTabsView.Tab {
    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .price: return "Price"
        case .stats: return "Stats"
        case .trade: return "Trades"
        }
    }
}

// MARK: - Overview Content (Card-Based)

struct OverviewContent: View {
    @ObservedObject var vm: StockDetailViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // About the Company Card - description only
            InfoCard(title: "ABOUT THE COMPANY", icon: "building.2") {
                Text(vm.descriptionFull)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            }
        }
    }
}

// MARK: - Info Card Container

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Theme.primaryBlue)
                    .font(.subheadline)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(0.5)
            }
            
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.118, green: 0.161, blue: 0.216))
        .cornerRadius(12)
    }
}

// MARK: - Price Content (All price and trading data)

struct PriceContent: View {
    @ObservedObject var vm: StockDetailViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Bid / Ask or Close Price - Yellow card
            BidAskCard(
                bid: vm.bidString,
                ask: vm.askString,
                closePrice: vm.previousClose,
                isMarketOpen: vm.isMarketOpen
            )
            
            // Day Range - simple slider without card title
            RangeSlider(
                label: "Day",
                lowValue: vm.dayLow,
                highValue: vm.dayHigh,
                low: vm.dayLowValue,
                high: vm.dayHighValue,
                current: vm.currentPriceValue
            )
            
            // Year Range - always show (will display -- if no data)
            RangeSlider(
                label: "Year",
                lowValue: vm.yearLowString,
                highValue: vm.yearHighString,
                low: vm.yearLowValue,
                high: vm.yearHighValue,
                current: vm.currentPriceValue
            )
            
            // Price & Trading Details Card - Compact single tile
            InfoCard(title: "TRADING DETAILS", icon: "chart.line.uptrend.xyaxis") {
                VStack(spacing: 14) {
                    PriceRowWhite(label: "Previous Close", value: vm.previousClose)
                    PriceRowWhite(label: "Open Price", value: vm.openPriceString)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    PriceRowWhite(label: "Shares Traded Today", value: vm.volumeString)
                    PriceRowWhite(label: "Value Traded", value: vm.tradedValueString)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    PriceRowWhite(label: "Company Value", value: vm.marketCapDisplay)
                }
            }
        }
    }
}

// MARK: - Range Slider (Simple without card wrapper)
struct RangeSlider: View {
    let label: String
    let lowValue: String
    let highValue: String
    let low: Double
    let high: Double
    let current: Double
    
    var progress: Double {
        guard high > low else { return 0.5 }
        return (current - low) / (high - low)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(lowValue)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.85))
                
                Spacer()
                
                Text(highValue)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Range bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                    
                    // Current position indicator
                    Circle()
                        .fill(Theme.primaryBlue)
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, min(geo.size.width - 14, (geo.size.width - 14) * progress)))
                }
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.118, green: 0.161, blue: 0.216))
        .cornerRadius(12)
    }
}

// Price row with white labels and bold values
struct PriceRowWhite: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Bid/Ask Card (Yellow with bold black text)
struct BidAskCard: View {
    let bid: String
    let ask: String
    let closePrice: String
    let isMarketOpen: Bool
    
    var body: some View {
        HStack {
            if isMarketOpen {
                // Market Open - Show Selling Price (Bid) and Buying Price (Ask)
                VStack(spacing: 4) {
                    Text("SELLING PRICE")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundColor(.black.opacity(0.7))
                    Text(bid)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                
                // Divider
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 1, height: 40)
                
                VStack(spacing: 4) {
                    Text("BUYING PRICE")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundColor(.black.opacity(0.7))
                    Text(ask)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
            } else {
                // Market Closed - Show Close Price
                VStack(spacing: 4) {
                    Text("CLOSE PRICE")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundColor(.black.opacity(0.7))
                    Text(closePrice)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(red: 1.0, green: 0.84, blue: 0.0)) // Yellow #FFD600
        .cornerRadius(12)
    }
}

// Simple price row
struct PriceRow: View {
    let label: String
    let value: String
    var explanation: String? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                if let explanation = explanation {
                    Text("(\(explanation))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }
}

// MARK: - Stats Content

struct StatsContent: View {
    @ObservedObject var vm: StockDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Performance summary row (new)
            InfoCard(title: "PERFORMANCE", icon: "speedometer") {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.performanceSeries.indices, id: \.self) { idx in
                                let item = vm.performanceSeries[idx]
                                PerfChip(label: item.label, value: item.value)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // Optional explanatory line
                    Text("Performance figures use available sources (quote or Infront). Tap chips later for history.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }

            // Key Statistics Card
            InfoCard(title: "KEY STATISTICS", icon: "chart.bar.fill") {
                VStack(spacing: 16) {
                    StatRowWithTooltip(
                        label: "Market Cap",
                        value: vm.marketCapDisplay,
                        tooltip: "The total value of all shares. Think of it as the company's price tag."
                    )

                    StatRowWithTooltip(
                        label: "P/E Ratio",
                        value: vm.peDisplay,
                        tooltip: "Price-to-Earnings ratio. Lower = potentially better value. Compares share price to profits."
                    )

                    StatRowWithTooltip(
                        label: "EPS",
                        value: vm.epsDisplay,
                        tooltip: "Earnings Per Share. How much profit the company makes for each share you own."
                    )

                    StatRowWithTooltip(
                        label: "52-Week Range",
                        value: vm.fiftyTwoWeekRange,
                        tooltip: "The lowest and highest prices over the past year. Helps you see if current price is high or low."
                    )
                }
            }
        }
    }
}

// Small performance chip used in the Stats header
struct PerfChip: View {
    let label: String
    let value: Double?

    var bgColor: Color {
        guard let v = value else { return Color(white: 0.25) }
        return v >= 0
            ? Color(red: 0.0, green: 0.55, blue: 0.3)   // Dark green
            : Color(red: 0.75, green: 0.15, blue: 0.15)  // Dark red
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(value != nil ? String(format: "%+.1f%%", value!) : "--")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(bgColor))
    }
}

struct StatRowWithTooltip: View {
    let label: String
    let value: String
    let tooltip: String
    @State private var showTooltip = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Text(label)
                        .foregroundColor(.white.opacity(0.85))
                    
                    Button(action: { showTooltip.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(Theme.primaryBlue)
                    }
                }
                
                Spacer()
                
                Text(value)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .font(.subheadline)
            
            if showTooltip {
                Text(tooltip)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(10)
                    .background(Theme.primaryBlue.opacity(0.3))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showTooltip)
    }
}

// MARK: - Trade Content

struct TradeContent: View {
    @ObservedObject var vm: StockDetailViewModel
    
    var body: some View {
        InfoCard(title: "RECENT TRADES", icon: "list.bullet.rectangle") {
            // Use the new TradesContent view implemented in TradesContent.swift
            TradesContent(vm: vm)
        }
    }
}

// MARK: - Action Buttons Card

// Removed ActionButtonsCard — trade buttons moved to header

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                    Text(title)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                
                Text(subtitle)
                    .font(.caption2)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(10)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.primaryGradient.ignoresSafeArea()
        StockDetailTabsView(vm: StockDetailViewModel(symbol: "AZN.L"))
    }
}
