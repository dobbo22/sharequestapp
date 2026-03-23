import SwiftUI
import Combine

// MARK: - Stock Model
struct Stock: Identifiable {
    let id: String
    let symbol: String
    let companyName: String
    let price: Double        // in pounds
    let changeAmount: Double
    let changePercent: Double
    let sector: String
    let marketCap: Double

    var formattedPrice: String {
        // Show price in pence with decimals (e.g., 30.9p)
        let pence = price * 100
        // Show up to 2 decimals, but trim trailing zeros
        var s = String(format: "%.2f", pence)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
            s.removeLast()
        }
        return "\(s)p"
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

// MARK: - Portfolio Concentration Logic

private let portfolioConcentrationLimits: [String: Double] = [
    "weekly": 20, "monthly": 10, "annual": 10, "default": 100
]

private struct ConcentrationResult {
    let isValid: Bool
    let errorMessage: String?
    let warningMessage: String?
    let maxSharesAllowed: Int?
}

private func concentrationValidate(portfolioType: String, symbol: String, action: String, quantity: Int, pricePounds: Double, cashPounds: Double, holdings: [PortfolioResponse.HoldingData]) -> ConcentrationResult {
    if action == "sell" {
        return ConcentrationResult(isValid: true, errorMessage: nil, warningMessage: nil, maxSharesAllowed: nil)
    }
    guard pricePounds > 0, quantity > 0 else {
        return ConcentrationResult(isValid: true, errorMessage: nil, warningMessage: nil, maxSharesAllowed: nil)
    }
    let holdingsValuePounds = holdings.reduce(0.0) { $0 + Double($1.quantity) * ($1.mid ?? $1.mid_price ?? $1.current_price) / 100.0 }
    let total = cashPounds + holdingsValuePounds
    let maxPct = portfolioConcentrationLimits[portfolioType] ?? 100
    let maxAllowed = total * maxPct / 100
    let existing = holdings.first(where: { $0.symbol == symbol })
    let existingQty = existing.map { $0.quantity } ?? 0
    let existingValue = Double(existingQty) * pricePounds
    let newValue = Double(quantity) * pricePounds
    let combinedValue = Double(existingQty + quantity) * pricePounds
    let remaining = maxAllowed - existingValue
    let combinedPct = total > 0 ? (combinedValue / total) * 100 : 0
    let isValid = newValue <= remaining || total <= 0
    var errorMsg: String? = nil
    var warnMsg: String? = nil
    if !isValid {
        errorMsg = "Exceeds \(Int(maxPct))% concentration limit. Max: £\(String(format: "%.2f", maxAllowed))"
    } else if combinedPct > maxPct * 0.9 {
        warnMsg = String(format: "Warning: This brings your holding to %.1f%% of portfolio.", combinedPct)
    }
    let maxAffordable = cashPounds > 0 && pricePounds > 0 ? Int(cashPounds / pricePounds) : 0
    let maxFromConc = remaining > 0 && pricePounds > 0 ? Int(remaining / pricePounds) : 0
    let maxShares = min(maxAffordable, maxFromConc)
    return ConcentrationResult(isValid: isValid, errorMessage: errorMsg, warningMessage: warnMsg, maxSharesAllowed: maxShares > 0 ? maxShares : nil)
}

// MARK: - Trade Sheet ViewModel

@MainActor
class TradeSheetViewModel: ObservableObject {
    let stock: Stock

    @Published var tradeAction: String
    @Published var selectedPortfolio: String
    @Published var quantity: String
    @Published var isLoading: Bool = false
    @Published var isLoadingData: Bool = false
    @Published var error: String? = nil
    @Published var concentrationWarning: String? = nil
    @Published var maxSharesAllowed: Int? = nil
    @Published var holdings: [PortfolioResponse.HoldingData] = []
    @Published var cashPounds: Double = 100_000
    @Published var tradingWindow: TradingWindowData? = nil
    @Published var tradeSuccess: TradeSuccessInfo? = nil

    /// When set, the portfolio selector is hidden and this portfolio is always used
    let lockedPortfolio: String?

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
        return Double(qty) * stock.price
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

    init(stock: Stock, initialAction: String = "buy", initialQuantity: String = "", lockedPortfolio: String? = nil) {
        self.stock = stock
        self.tradeAction = initialAction
        self.quantity = initialQuantity
        self.lockedPortfolio = lockedPortfolio
        self.selectedPortfolio = lockedPortfolio ?? "default"
    }

    func loadData() async {
        isLoadingData = true
        async let portfolioTask: () = loadPortfolio()
        async let windowTask: () = loadTradingWindow()
        if lockedPortfolio == nil {
            async let subsTask: () = loadAvailablePortfolios()
            await portfolioTask; await windowTask; await subsTask
        } else {
            await portfolioTask; await windowTask
        }
        isLoadingData = false
        revalidate()
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
            // cash_balance comes as string pence — convert to pounds
            let rawPence = Double(resp.portfolio?.cash_balance ?? "10000000") ?? 10_000_000
            cashPounds = rawPence / 100.0
        } catch {
            holdings = []
            cashPounds = 100_000
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
            concentrationWarning = nil; error = nil; maxSharesAllowed = nil; return
        }
        if tradeAction == "buy" {
            let maxAffordable = cashPounds > 0 && stock.price > 0 ? Int(cashPounds / stock.price) : 0
            if qty > maxAffordable {
                error = "Insufficient funds. Max: \(maxAffordable) shares"
                maxSharesAllowed = maxAffordable
                concentrationWarning = nil
                return
            }
        }
        if tradeAction == "sell" {
            let owned = holdings.first(where: { $0.symbol == stock.symbol })?.quantity ?? 0
            if qty > owned {
                error = "You can only sell up to \(owned) shares"
                concentrationWarning = nil; maxSharesAllowed = nil
                return
            }
        }
        let result = concentrationValidate(
            portfolioType: selectedPortfolio,
            symbol: stock.symbol,
            action: tradeAction,
            quantity: qty,
            pricePounds: stock.price,
            cashPounds: cashPounds,
            holdings: holdings
        )
        error = result.errorMessage
        concentrationWarning = result.errorMessage == nil ? result.warningMessage : nil
        maxSharesAllowed = result.maxSharesAllowed
    }

    func executeTrade() async {
        guard let qty = Int(quantity), qty > 0 else { error = "Please enter a valid quantity"; return }
        guard error == nil else { return }
        isLoading = true
        error = nil
        tradeSuccess = nil
        do {
            // Ensure price is rounded and cast to Int (pence)
            let pricePence = Int(round(stock.price * 100))
            let resp = try await APIService.shared.executeMobileTrade(
                portfolioType: selectedPortfolio,
                symbol: stock.symbol,
                companyName: stock.companyName,
                action: tradeAction,
                quantity: qty,
                price: Double(pricePence)
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
    @State private var showNumpad = false

    /// From stock detail page — defaults to buy, no pre-fill
    init(stock: Stock) {
        self.stock = stock
        _vm = StateObject(wrappedValue: TradeSheetViewModel(stock: stock))
    }

    /// From portfolio page — pre-fills action/quantity and locks the portfolio
    private var onTradeSuccess: (() -> Void)? = nil
    init(stock: Stock, portfolioType: PortfolioType, initialTradeType: String, initialQuantity: String, onTradeSuccess: (() -> Void)? = nil) {
        self.stock = stock
        self.onTradeSuccess = onTradeSuccess
        _vm = StateObject(wrappedValue: TradeSheetViewModel(
            stock: stock,
            initialAction: initialTradeType,
            initialQuantity: initialQuantity,
            lockedPortfolio: portfolioType.rawValue
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.094, green: 0.094, blue: 0.110)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if let window = vm.tradingWindow, !window.isMarketOpen {
                            tradingWindowBanner(window)
                        }

                        if let success = vm.tradeSuccess {
                            successBanner(success)
                        }

                        actionToggle

                        // Portfolio selector — hidden when locked to a specific portfolio
                        if vm.lockedPortfolio == nil {
                            portfolioSelector
                        } else {
                            lockedPortfolioLabel
                        }

                        quantitySection

                        summaryCard

                        if let warn = vm.concentrationWarning, vm.error == nil {
                            alertRow(text: warn, color: Color(red: 0.96, green: 0.62, blue: 0.26), icon: "exclamationmark.triangle.fill")
                        }
                        if let err = vm.error {
                            alertRow(text: err, color: Color(red: 0.94, green: 0.27, blue: 0.27), icon: "exclamationmark.circle.fill")
                        }

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

                        executeButton

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
            // Call the onTradeSuccess callback immediately after a successful trade
            onTradeSuccess?()
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
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(window.isAfterHours ? Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.12) : Theme.primaryBlue.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(window.isAfterHours ? Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.35) : Theme.primaryBlue.opacity(0.35), lineWidth: 1))
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
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(info.isPendingOrder ? Theme.primaryBlue.opacity(0.12) : Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(info.isPendingOrder ? Theme.primaryBlue.opacity(0.35) : Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.35), lineWidth: 1))
    }

    // MARK: - Action Toggle

    private var actionToggle: some View {
        let buyColor = Color(red: 0.06, green: 0.73, blue: 0.51)
        let sellColor = Color(red: 0.94, green: 0.27, blue: 0.27)
        return HStack(spacing: 4) {
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

            // Show Sell button always when locked to a portfolio (portfolio context),
            // or when the user holds the stock in the selected portfolio
            if vm.lockedPortfolio != nil || vm.hasHolding {
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
                    Button { vm.selectedPortfolio = option.id } label: {
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
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? color : color.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    /// Shown instead of the selector when portfolio is locked (called from portfolio page)
    private var lockedPortfolioLabel: some View {
        let portfolio = PortfolioType(rawValue: vm.lockedPortfolio ?? "default") ?? .practice
        return HStack(spacing: 8) {
            Text(portfolio.emoji)
            Text(portfolio.displayName)
                .fontWeight(.semibold)
                .foregroundColor(portfolio.color)
            Text("Portfolio")
                .foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))
            Spacer()
        }
        .font(.subheadline)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(portfolio.color.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(portfolio.color.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Quantity Input

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUANTITY (SHARES)")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))

            // Display — tap to open numpad
            Button { showNumpad = true } label: {
                HStack {
                    Text(vm.quantity.isEmpty ? "0" : vm.quantity)
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(vm.quantity.isEmpty ? Color(red: 0.42, green: 0.45, blue: 0.52) : .white)
                    Spacer()
                    Text("shares")
                        .font(.subheadline)
                        .foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))
                    Image(systemName: showNumpad ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(showNumpad ? Theme.primaryBlue.opacity(0.6) : Color(red: 0.29, green: 0.34, blue: 0.39).opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())

            if showNumpad { numpad }
        }
    }

    private var numpad: some View {
        VStack(spacing: 8) {
            ForEach([["1","2","3"], ["4","5","6"], ["7","8","9"], ["done","0","⌫"]], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        numpadButton(key)
                    }
                }
            }
        }
    }

    private func numpadButton(_ key: String) -> some View {
        let isDone = key == "done"
        let isDelete = key == "⌫"
        return Button { handleNumpadKey(key) } label: {
            Group {
                if isDone {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.primaryBlue)
                } else if isDelete {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                } else {
                    Text(key)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isDone
                    ? Theme.primaryBlue.opacity(0.15)
                    : Color(red: 0.18, green: 0.22, blue: 0.28)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isDone ? Theme.primaryBlue.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func handleNumpadKey(_ key: String) {
        switch key {
        case "done":
            vm.revalidate()
            showNumpad = false
        case "⌫":
            if !vm.quantity.isEmpty { vm.quantity.removeLast() }
        default:
            if vm.quantity == "0" { return }
            if vm.quantity.count < 7 { vm.quantity += key }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow(label: "Price per Share", value: stock.formattedPrice)
            Divider().background(Color(red: 0.29, green: 0.34, blue: 0.39).opacity(0.35)).padding(.vertical, 8)
            summaryRow(label: "Quantity", value: "\(vm.quantity.isEmpty ? "0" : vm.quantity) shares")
            Divider().background(Color(red: 0.29, green: 0.34, blue: 0.39).opacity(0.35)).padding(.vertical, 8)
            HStack {
                Text("Estimated Total")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                // Show estimated total in pounds, rounded to 2 decimals
                Text("£\(String(format: "%.2f", vm.estimatedTotalPounds))")
                    .font(.title3).fontWeight(.bold)
                    .foregroundColor(Theme.primaryBlue)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(red: 0.29, green: 0.34, blue: 0.39).opacity(0.4), lineWidth: 1))
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(Color(red: 0.61, green: 0.65, blue: 0.73))
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium).foregroundColor(.white)
        }
    }

    // MARK: - Alert Row

    private func alertRow(text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 16))
            Text(text).font(.caption).foregroundColor(color).multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Execute Button

    private var executeButton: some View {
        Button { Task { await vm.executeTrade() } } label: {
            HStack(spacing: 8) {
                if vm.isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: vm.executeButtonIcon).font(.system(size: 20))
                    Text(vm.executeButtonLabel).font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(
                colors: vm.isExecuteDisabled ? [Color.gray.opacity(0.4), Color.gray.opacity(0.3)] : vm.executeButtonColors,
                startPoint: .leading, endPoint: .trailing))
            .cornerRadius(14)
        }
        .disabled(vm.isExecuteDisabled)
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private func portfolioColor(for id: String) -> Color {
        switch id {
        case "weekly":  return Theme.primaryBlue
        case "monthly": return Theme.accentPurple
        case "annual":  return Theme.accentYellow
        default:        return Theme.accentGreen
        }
    }
}
