import SwiftUI
import Charts

// MARK: - Main Stock Detail View

struct StockDetailTabsView: View {
    @StateObject var vm: StockDetailViewModel
    @State private var activeTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview, chart, price, financials, balanceSheet, trades
        var displayName: String {
            switch self {
            case .overview:     return "Overview"
            case .chart:        return "Chart"
            case .price:        return "Price"
            case .financials:   return "Financials"
            case .balanceSheet: return "Balance Sheet"
            case .trades:       return "Trades"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TabSelector(activeTab: $activeTab)
                    .padding(.top, 4)

                Group {
                    switch activeTab {
                    case .overview:     OverviewContent(vm: vm)
                    case .chart:        ChartContent(vm: vm)
                    case .price:        PriceContent(vm: vm)
                    case .financials:   FinancialsContent(vm: vm)
                    case .balanceSheet: BalanceSheetContent(vm: vm)
                    case .trades:       TradeContent(vm: vm)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .task {
            if vm.quote == nil { await vm.fetch() }
        }
    }
}

// MARK: - Tab Selector

struct TabSelector: View {
    @Binding var activeTab: StockDetailTabsView.Tab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(StockDetailTabsView.Tab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { activeTab = tab }
                    } label: {
                        Text(tab.displayName)
                            .font(.subheadline)
                            .fontWeight(activeTab == tab ? .semibold : .regular)
                            .foregroundColor(activeTab == tab ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(activeTab == tab ? Theme.primaryBlue : Color.clear)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 4)
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

// MARK: - Overview

struct OverviewContent: View {
    @ObservedObject var vm: StockDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Performance chips
            if vm.performanceSeries.contains(where: { $0.value != nil }) {
                InfoCard(title: "PERFORMANCE", icon: "speedometer") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.performanceSeries.indices, id: \.self) { i in
                                let item = vm.performanceSeries[i]
                                PerfChip(label: item.label, value: item.value)
                            }
                        }
                    }
                }
            }

            // About
            InfoCard(title: "ABOUT", icon: "building.2") {
                Text(vm.descriptionFull)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            }
        }
    }
}

struct SectorChip: View {
    let label: String
    let icon: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2).foregroundColor(Theme.primaryBlue)
            Text(label).font(.caption).foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Chart Tab

struct ChartContent: View {
    @ObservedObject var vm: StockDetailViewModel

    private let periods: [(label: String, days: Int)] = [
        ("1W", 7), ("1M", 30), ("3M", 90), ("6M", 180), ("1Y", 365)
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Period selector + price change header
            VStack(spacing: 10) {
                HStack {
                    if let chg = vm.chartPriceChange {
                        HStack(spacing: 4) {
                            Image(systemName: chg >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)
                            Text(String(format: "%+.2f%%", chg))
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        .foregroundColor(chg >= 0 ? Color(red: 0.2, green: 0.8, blue: 0.5) : Color(red: 0.9, green: 0.3, blue: 0.3))
                        Text("over period")
                            .font(.caption).foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    // Period pills
                    HStack(spacing: 6) {
                        ForEach(periods, id: \.days) { p in
                            Button {
                                Task { await vm.loadHistory(period: p.days) }
                            } label: {
                                Text(p.label)
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(vm.selectedHistoryPeriod == p.days ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(vm.selectedHistoryPeriod == p.days ? Theme.primaryBlue : Color.white.opacity(0.08))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)

                // Chart
                if vm.isLoadingHistory {
                    ProgressView().frame(height: 200).tint(.white)
                } else if vm.priceHistory.isEmpty {
                    Text("No price data available")
                        .font(.subheadline).foregroundColor(.white.opacity(0.4))
                        .frame(height: 180)
                } else {
                    priceLineChart
                        .frame(height: 200)
                        .padding(.horizontal, 8)

                    volumeBarChart
                        .frame(height: 50)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                }
            }
            .background(Color(red: 0.118, green: 0.161, blue: 0.216))
            .cornerRadius(12)

            // Latest OHLC
            if let last = vm.priceHistory.last {
                InfoCard(title: "LAST SESSION", icon: "clock") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        OHLCCell(label: "Open",  value: last.open)
                        OHLCCell(label: "High",  value: last.high)
                        OHLCCell(label: "Low",   value: last.low)
                        OHLCCell(label: "Close", value: last.close)
                    }
                    if let vol = last.volume {
                        Divider().background(Color.white.opacity(0.1))
                        PriceRowWhite(label: "Volume", value: NumberFormatter.localizedString(from: NSNumber(value: Int(vol)), number: .decimal))
                    }
                }
            }
        }
    }

    private var lineColor: Color {
        guard let chg = vm.chartPriceChange else { return Theme.primaryBlue }
        return chg >= 0 ? Color(red: 0.2, green: 0.8, blue: 0.5) : Color(red: 0.9, green: 0.3, blue: 0.3)
    }

    @ViewBuilder private var priceLineChart: some View {
        let pts = vm.priceHistory.compactMap { p -> (String, Double)? in
            guard let c = p.close else { return nil }
            return (p.date, c)
        }
        Chart {
            ForEach(pts.indices, id: \.self) { i in
                LineMark(
                    x: .value("Date", i),
                    y: .value("Price", pts[i].1)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Date", i),
                    yStart: .value("Min", vm.chartMin),
                    yEnd: .value("Price", pts[i].1)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.3), lineColor.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) {
                AxisValueLabel().foregroundStyle(Color.white.opacity(0.5))
                    .font(.caption2)
            }
        }
        .chartYScale(domain: vm.chartMin...vm.chartMax)
    }

    @ViewBuilder private var volumeBarChart: some View {
        let vols = vm.priceHistory.compactMap { p -> (Int, Double)? in
            guard let v = p.volume else { return nil }
            return (vm.priceHistory.firstIndex(where: { $0.date == p.date }) ?? 0, v)
        }
        Chart {
            ForEach(vols, id: \.0) { (i, vol) in
                BarMark(x: .value("Date", i), y: .value("Volume", vol))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct OHLCCell: View {
    let label: String
    let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.5))
            Text(value.map { formatPenceFromPounds($0) } ?? "--")
                .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Price Tab

struct PriceContent: View {
    @ObservedObject var vm: StockDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            BidAskCard(bid: vm.bidString, ask: vm.askString,
                       closePrice: vm.previousClose, isMarketOpen: vm.isMarketOpen)

            RangeSlider(label: "Day",  lowValue: vm.dayLow,     highValue: vm.dayHigh,
                        low: vm.dayLowValue,  high: vm.dayHighValue,  current: vm.currentPriceValue)
            RangeSlider(label: "Year", lowValue: vm.yearLowString, highValue: vm.yearHighString,
                        low: vm.yearLowValue, high: vm.yearHighValue, current: vm.currentPriceValue)

            InfoCard(title: "TRADING DETAILS", icon: "chart.line.uptrend.xyaxis") {
                VStack(spacing: 14) {
                    PriceRowWhite(label: "Previous Close",    value: vm.previousClose)
                    PriceRowWhite(label: "Open Price",        value: vm.openPriceString)
                    Divider().background(Color.white.opacity(0.2))
                    PriceRowWhite(label: "Shares Traded",     value: vm.volumeString)
                    PriceRowWhite(label: "Value Traded",      value: vm.tradedValueString)
                    Divider().background(Color.white.opacity(0.2))
                    PriceRowWhite(label: "Market Cap",        value: vm.marketCapDisplay)
                }
            }
        }
    }
}

// MARK: - Financials Tab

struct FinancialsContent: View {
    @ObservedObject var vm: StockDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Valuation
            InfoCard(title: "VALUATION", icon: "scalemass") {
                VStack(spacing: 0) {
                    FinRow(label: "Market Cap",     value: vm.marketCapDisplay,
                           tooltip: "Total market value of all shares outstanding.")
                    FinDivider()
                    FinRow(label: "P/E Ratio",      value: vm.peDisplay,
                           tooltip: "Price-to-Earnings: how much investors pay per £1 of profit. Lower may mean better value.")
                    FinDivider()
                    FinRow(label: "P/B Ratio",      value: vm.priceToBookDisplay,
                           tooltip: "Price-to-Book: share price vs book value per share. Under 1 can signal undervaluation.")
                    FinDivider()
                    FinRow(label: "EPS",            value: vm.epsDisplay,
                           tooltip: "Earnings Per Share — profit attributable to each share.")
                    FinDivider()
                    FinRow(label: "Dividend Yield", value: vm.dividendYieldDisplay,
                           tooltip: "Annual dividend as % of current price. Higher = more income return.")
                }
            }

            // Revenue snapshot
            InfoCard(title: "REVENUE & INCOME", icon: "banknote") {
                VStack(spacing: 0) {
                    FinRow(label: "Revenue",    value: vm.revenueDisplay,
                           tooltip: "Total sales / turnover for the latest reported year.")
                    FinDivider()
                    FinRow(label: "Net Income", value: vm.netIncomeDisplay,
                           tooltip: "Profit after all costs and taxes.")
                    FinDivider()
                    FinRow(label: "Net Margin", value: vm.profitMarginDisplay,
                           tooltip: "Net income as % of revenue — how much of each £ of sales becomes profit.")
                }
            }

            // Profitability
            InfoCard(title: "PROFITABILITY", icon: "chart.bar.fill") {
                VStack(spacing: 0) {
                    FinRow(label: "Return on Equity", value: vm.roeDisplay,
                           tooltip: "Net income ÷ shareholders' equity. Shows how efficiently equity generates profit.")
                    FinDivider()
                    FinRow(label: "Return on Assets", value: vm.roaDisplay,
                           tooltip: "Net income ÷ total assets. Measures how well assets are used to generate profit.")
                }
            }

            // Leverage
            InfoCard(title: "LEVERAGE & LIQUIDITY", icon: "lock.shield") {
                VStack(spacing: 0) {
                    FinRow(label: "Debt / Equity",  value: vm.debtToEquityDisplay,
                           tooltip: "Total debt ÷ equity. Higher ratios mean more leverage and financial risk.")
                    FinDivider()
                    FinRow(label: "Current Ratio",  value: vm.currentRatioDisplay,
                           tooltip: "Current assets ÷ current liabilities. Above 1 means the company can cover short-term debts.")
                }
            }

            // 52-week / key stats
            InfoCard(title: "KEY STATS", icon: "chart.line.uptrend.xyaxis") {
                VStack(spacing: 0) {
                    FinRow(label: "52-Week Range", value: vm.fiftyTwoWeekRange,
                           tooltip: "Lowest and highest traded prices over the past 52 weeks.")
                }
            }
        }
    }
}

struct FinRow: View {
    let label: String
    let value: String
    let tooltip: String
    @State private var showTip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Text(label).font(.subheadline).foregroundColor(.white.opacity(0.85))
                    Button { withAnimation(.easeInOut(duration: 0.15)) { showTip.toggle() } } label: {
                        Image(systemName: "info.circle").font(.caption).foregroundColor(Theme.primaryBlue.opacity(0.7))
                    }
                }
                Spacer()
                Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
            }
            .padding(.vertical, 12)

            if showTip {
                Text(tooltip)
                    .font(.caption).foregroundColor(.white.opacity(0.75))
                    .padding(10)
                    .background(Theme.primaryBlue.opacity(0.18))
                    .cornerRadius(8)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct FinDivider: View {
    var body: some View {
        Divider().background(Color.white.opacity(0.1))
    }
}

// MARK: - Balance Sheet Tab

struct BalanceSheetContent: View {
    @ObservedObject var vm: StockDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Year selector
            if !vm.balanceSheetYears.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.balanceSheetYears, id: \.self) { yr in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { vm.selectedBSYear = yr }
                            } label: {
                                Text(yr)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(vm.selectedBSYear == yr || (vm.selectedBSYear == nil && yr == vm.balanceSheetYears.first) ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(vm.selectedBSYear == yr || (vm.selectedBSYear == nil && yr == vm.balanceSheetYears.first) ? Theme.primaryBlue : Color.white.opacity(0.07))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if let row = vm.selectedBalanceSheetRow {
                // Visual breakdown bar
                if let assets = row.totalAssets, let liab = row.totalLiabilities,
                   let equity = row.totalEquity, assets > 0 {
                    InfoCard(title: "STRUCTURE", icon: "chart.pie") {
                        VStack(spacing: 10) {
                            StructureBar(assets: assets, liabilities: liab, equity: equity)
                            HStack(spacing: 16) {
                                LegendDot(color: Color(red: 0.27, green: 0.52, blue: 0.96), label: "Assets")
                                LegendDot(color: Color(red: 0.9, green: 0.35, blue: 0.3), label: "Liabilities")
                                LegendDot(color: Color(red: 0.2, green: 0.75, blue: 0.5), label: "Equity")
                                Spacer()
                            }
                        }
                    }
                }

                // Assets
                InfoCard(title: "ASSETS", icon: "plus.circle") {
                    VStack(spacing: 0) {
                        BSRow(label: "Total Assets",        value: row.totalAssets,       bold: true)
                        FinDivider()
                        BSRow(label: "Current Assets",      value: row.currentAssets,     indent: true)
                        BSRow(label: "Non-Current Assets",  value: row.nonCurrentAssets,  indent: true)
                        BSRow(label: "Cash & Equivalents",  value: row.cash,              indent: true)
                    }
                }

                // Liabilities
                InfoCard(title: "LIABILITIES", icon: "minus.circle") {
                    VStack(spacing: 0) {
                        BSRow(label: "Total Liabilities",    value: row.totalLiabilities,   bold: true)
                        FinDivider()
                        BSRow(label: "Current Liabilities",  value: row.currentLiabilities, indent: true)
                        BSRow(label: "Long-Term Debt",       value: row.longTermDebt,        indent: true)
                    }
                }

                // Equity
                InfoCard(title: "EQUITY", icon: "checkmark.circle") {
                    VStack(spacing: 0) {
                        BSRow(label: "Total Equity",      value: row.totalEquity,      bold: true)
                        FinDivider()
                        BSRow(label: "Retained Earnings", value: row.retainedEarnings, indent: true)
                    }
                }

                // Quick ratios from balance sheet
                if let curA = row.currentAssets, let curL = row.currentLiabilities, curL > 0,
                   let totD = row.totalLiabilities, let eq = row.totalEquity, eq > 0 {
                    InfoCard(title: "DERIVED RATIOS", icon: "function") {
                        VStack(spacing: 0) {
                            BSRow(label: "Current Ratio", rawValue: String(format: "%.2f", curA / curL))
                            FinDivider()
                            BSRow(label: "Debt / Equity", rawValue: String(format: "%.2f", totD / eq))
                        }
                    }
                }
            } else if vm.balanceSheetYears.isEmpty {
                // Income statement fallback when no balance sheet
                if !vm.incomeStatementRows.isEmpty {
                    incomeStatementSection
                } else {
                    noDataCard
                }
            }

            // Income statement always shown below balance sheet
            if !vm.incomeStatementRows.isEmpty && vm.selectedBalanceSheetRow != nil {
                incomeStatementSection
            }
        }
    }

    private var incomeStatementSection: some View {
        InfoCard(title: "INCOME STATEMENT", icon: "doc.text") {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Year").font(.caption).foregroundColor(.white.opacity(0.5)).frame(width: 44, alignment: .leading)
                    Spacer()
                    Text("Revenue").font(.caption).foregroundColor(.white.opacity(0.5)).frame(width: 72, alignment: .trailing)
                    Text("Net Income").font(.caption).foregroundColor(.white.opacity(0.5)).frame(width: 80, alignment: .trailing)
                    Text("Margin").font(.caption).foregroundColor(.white.opacity(0.5)).frame(width: 54, alignment: .trailing)
                }
                .padding(.bottom, 8)

                ForEach(vm.incomeStatementRows.prefix(5), id: \.year) { row in
                    Divider().background(Color.white.opacity(0.08))
                    HStack {
                        Text(row.year).font(.subheadline).foregroundColor(.white.opacity(0.6)).frame(width: 44, alignment: .leading)
                        Spacer()
                        Text(row.revenue.map { vm.formatLargeValuePublic($0) } ?? "--")
                            .font(.subheadline).fontWeight(.semibold).foregroundColor(.white).frame(width: 72, alignment: .trailing)
                        Text(row.netIncome.map { vm.formatLargeValuePublic($0) } ?? "--")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(row.netIncome.map { $0 >= 0 } == true ? Color(red: 0.2, green: 0.8, blue: 0.5) : Color(red: 0.9, green: 0.35, blue: 0.3))
                            .frame(width: 80, alignment: .trailing)
                        Group {
                            if let m = row.netMarginPct {
                                Text(String(format: "%.1f%%", m))
                                    .foregroundColor(m >= 0 ? Color(red: 0.2, green: 0.8, blue: 0.5) : Color(red: 0.9, green: 0.35, blue: 0.3))
                            } else {
                                Text("--").foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .font(.caption).fontWeight(.semibold).frame(width: 54, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private var noDataCard: some View {
        InfoCard(title: "BALANCE SHEET", icon: "doc.plaintext") {
            Text("Balance sheet data not yet available for this stock.")
                .font(.subheadline).foregroundColor(.white.opacity(0.5))
        }
    }
}

struct StructureBar: View {
    let assets: Double
    let liabilities: Double
    let equity: Double

    var body: some View {
        GeometryReader { geo in
            let total = assets
            let liabW = total > 0 ? CGFloat(liabilities / total) * geo.size.width : 0
            let eqW   = total > 0 ? CGFloat(equity   / total) * geo.size.width : 0
            let assetW = geo.size.width

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.27, green: 0.52, blue: 0.96)).frame(width: assetW, height: 20)
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.9, green: 0.35, blue: 0.3)).frame(width: max(0, liabW - 2), height: 20)
                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.2, green: 0.75, blue: 0.5)).frame(width: max(0, eqW - 2),   height: 20)
                }
            }
        }
        .frame(height: 20)
    }
}

struct LegendDot: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.7))
        }
    }
}

struct BSRow: View {
    let label: String
    var value: Double? = nil
    var rawValue: String? = nil
    var bold: Bool = false
    var indent: Bool = false

    var displayValue: String {
        if let r = rawValue { return r }
        guard let v = value else { return "--" }
        let abs = Swift.abs(v)
        let sign = v < 0 ? "-" : ""
        if abs >= 1_000_000_000 { return "\(sign)£\(String(format: "%.2fB", abs / 1_000_000_000))" }
        if abs >= 1_000_000    { return "\(sign)£\(String(format: "%.1fM", abs / 1_000_000))" }
        if abs >= 1_000        { return "\(sign)£\(String(format: "%.1fK", abs / 1_000))" }
        return "\(sign)£\(String(format: "%.0f", abs))"
    }

    var body: some View {
        HStack {
            if indent { Color.clear.frame(width: 12) }
            Text(label)
                .font(bold ? .subheadline : .subheadline)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundColor(bold ? .white : .white.opacity(0.8))
            Spacer()
            Text(displayValue)
                .font(.subheadline)
                .fontWeight(bold ? .bold : .semibold)
                .foregroundColor(bold ? .white : .white.opacity(0.9))
        }
        .padding(.vertical, 11)
    }
}

// MARK: - Trade Content

struct TradeContent: View {
    @ObservedObject var vm: StockDetailViewModel
    var body: some View {
        InfoCard(title: "RECENT TRADES", icon: "list.bullet.rectangle") {
            TradesContent(vm: vm)
        }
    }
}

// MARK: - Reused Components

struct ChangeIndicator: View {
    let change: Double
    let changePercent: Double
    var showLabel: Bool = false
    var isPositive: Bool { changePercent >= 0 }
    var color: Color { isPositive ? .green : .red }
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right").font(.caption)
            Text(String(format: "%@%.2f%%", isPositive ? "+" : "", changePercent))
                .font(.subheadline).fontWeight(.semibold)
            if showLabel { Text("today").font(.caption).foregroundColor(.white.opacity(0.5)) }
        }
        .foregroundColor(color)
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline).fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(isActive ? .white : .white.opacity(0.5))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(isActive ? Theme.primaryBlue : Color.clear)
                .cornerRadius(20)
        }
    }
}

struct RangeSlider: View {
    let label: String
    let lowValue: String; let highValue: String
    let low: Double; let high: Double; let current: Double
    var progress: Double { guard high > low else { return 0.5 }; return (current - low) / (high - low) }
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(lowValue).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Text(label).font(.caption).fontWeight(.medium).foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(highValue).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(height: 6)
                    Circle().fill(Theme.primaryBlue).frame(width: 14, height: 14)
                        .offset(x: max(0, min(geo.size.width - 14, (geo.size.width - 14) * progress)))
                }
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(red: 0.118, green: 0.161, blue: 0.216))
        .cornerRadius(12)
    }
}

struct PriceRowWhite: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.white)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
        }
    }
}

struct BidAskCard: View {
    let bid: String; let ask: String; let closePrice: String; let isMarketOpen: Bool
    var body: some View {
        HStack {
            if isMarketOpen {
                VStack(spacing: 4) {
                    Text("SELLING PRICE").font(.caption2).fontWeight(.heavy).foregroundColor(.black.opacity(0.7))
                    Text(bid).font(.subheadline).fontWeight(.black).lineLimit(1).minimumScaleFactor(0.8).foregroundColor(.black)
                }.frame(maxWidth: .infinity)
                Rectangle().fill(Color.black.opacity(0.2)).frame(width: 1, height: 40)
                VStack(spacing: 4) {
                    Text("BUYING PRICE").font(.caption2).fontWeight(.heavy).foregroundColor(.black.opacity(0.7))
                    Text(ask).font(.subheadline).fontWeight(.black).lineLimit(1).minimumScaleFactor(0.8).foregroundColor(.black)
                }.frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 4) {
                    Text("CLOSE PRICE").font(.caption2).fontWeight(.heavy).foregroundColor(.black.opacity(0.7))
                    Text(closePrice).font(.subheadline).fontWeight(.black).lineLimit(1).minimumScaleFactor(0.8).foregroundColor(.black)
                }.frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(red: 1.0, green: 0.84, blue: 0.0))
        .cornerRadius(12)
    }
}

struct PriceRow: View {
    let label: String; let value: String; var explanation: String? = nil
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 4) {
                Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                if let e = explanation {
                    Text("(\(e))").font(.caption2).foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }
}

struct PerfChip: View {
    let label: String; let value: Double?
    var bgColor: Color {
        guard let v = value else { return Color(white: 0.25) }
        return v >= 0 ? Color(red: 0.0, green: 0.55, blue: 0.3) : Color(red: 0.75, green: 0.15, blue: 0.15)
    }
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption).fontWeight(.bold).foregroundColor(.white)
            Text(value.map { String(format: "%+.1f%%", $0) } ?? "--").font(.caption).fontWeight(.semibold).foregroundColor(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(bgColor))
    }
}

struct ActionButton: View {
    let title: String; let subtitle: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) { Image(systemName: icon); Text(title).fontWeight(.semibold) }.font(.subheadline)
                Text(subtitle).font(.caption2).opacity(0.8)
            }
            .foregroundColor(.white).padding(.vertical, 14).frame(maxWidth: .infinity).background(color).cornerRadius(10)
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
