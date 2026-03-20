import SwiftUI

// MARK: - TradeType Enum
public enum TradeType {
    case buy, sell
}

// MARK: - Stock Model
public struct Stock: Identifiable {
    public let id: String
    public let symbol: String
    public let companyName: String
    public let price: Double
    public let changeAmount: Double
    public let changePercent: Double
    public let sector: String
    public let marketCap: Double
    
    public var formattedPrice: String {
        "£\(String(format: "%.2f", price))"
    }
    
    public var formattedChange: String {
        String(format: "%+.2f%%", changePercent)
    }
    
    public var formattedChangeAmount: String {
        String(format: "%+.2f", changeAmount)
    }
    
    public var formattedMarketCap: String {
        if marketCap >= 1_000_000_000 {
            return "£\(String(format: "%.1fB", marketCap / 1_000_000_000))"
        } else if marketCap >= 1_000_000 {
            return "£\(String(format: "%.1fM", marketCap / 1_000_000))"
        }
        return "£\(String(format: "%.0f", marketCap))"
    }
    
    public init(id: String, symbol: String, companyName: String, price: Double, changeAmount: Double, changePercent: Double, sector: String, marketCap: Double) {
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

// MARK: - StockTradeSheet
public struct StockTradeSheet: View {
    public let stock: Stock
    public let portfolioType: PortfolioType
    public let initialTradeType: TradeType
    public let initialQuantity: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: TradeSheetViewModel

    public init(stock: Stock, portfolioType: PortfolioType, initialTradeType: TradeType = .buy, initialQuantity: String = "") {
        self.stock = stock
        self.portfolioType = portfolioType
        self.initialTradeType = initialTradeType
        self.initialQuantity = initialQuantity
        _vm = StateObject(wrappedValue: TradeSheetViewModel(stock: stock, portfolioType: portfolioType, initialTradeType: initialTradeType, initialQuantity: initialQuantity))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(stock.symbol)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(stock.formattedPrice)
                            .font(.title2)
                    }
                    Picker("Trade Type", selection: $vm.tradeType) {
                        Text("Buy").tag(TradeType.buy)
                        Text("Sell").tag(TradeType.sell)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quantity")
                            .font(.subheadline)
                        TextField("0", text: $vm.quantity)
                            .keyboardType(.numberPad)
                            .font(.title2)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    if let qty = Int(vm.quantity), qty > 0 {
                        let total = Double(qty) * stock.price
                        Text("Estimated: £\(String(format: "%.2f", total))")
                            .font(.headline)
                    }
                    Spacer()
                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task { await vm.executeTrade() }
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text(vm.tradeType == .buy ? "Buy \(stock.symbol)" : "Sell \(stock.symbol)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(vm.tradeType == .buy ? Color.green : Color.red)
                    .cornerRadius(12)
                    .padding()
                    .disabled(vm.quantity.isEmpty || vm.isLoading)
                }
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: vm.tradeSuccess) { _, success in
                if success { dismiss() }
            }
        }
    }
}

// MARK: - TradeSheetViewModel
@MainActor
public class TradeSheetViewModel: ObservableObject {
    @Published public var tradeType: TradeType
    @Published public var quantity: String
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var tradeSuccess = false
    public let portfolioType: PortfolioType
    public let stock: Stock

    public init(stock: Stock, portfolioType: PortfolioType, initialTradeType: TradeType = .buy, initialQuantity: String = "") {
        self.stock = stock
        self.portfolioType = portfolioType
        self.tradeType = initialTradeType
        self.quantity = initialQuantity
    }

    public func executeTrade() async {
        guard let qty = Int(quantity), qty > 0 else { return }
        isLoading = true
        errorMessage = nil
        do {
            let action = tradeType == .buy ? "buy" : "sell"
            _ = try await APIService.shared.executeTrade(
                portfolioType: portfolioType.rawValue,
                symbol: stock.symbol,
                action: action,
                quantity: qty
            )
            tradeSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
