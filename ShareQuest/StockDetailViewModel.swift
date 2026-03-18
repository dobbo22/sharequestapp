import Foundation
import Combine

@MainActor
final class StockDetailViewModel: ObservableObject {
    @Published var symbol: String
    @Published var quote: StockQuote? = nil
    @Published var fundamentalsData: StockFundamentals? = nil
    @Published var infrontLive: InfrontLiveData? = nil
    @Published var tradeTicks: [TradeTick] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var requiresSubscriptionForTrades: Bool = false

    private let api = APIService.shared

    init(symbol: String, initialQuote: StockQuote? = nil, initialFundamentals: StockFundamentals? = nil) {
        self.symbol = symbol
        self.quote = initialQuote
        self.fundamentalsData = initialFundamentals
        Task { await fetch() }
    }

    func fetch() async {
        isLoading = true
        errorMessage = nil
        do {
            async let q = api.getStockQuote(symbol: symbol)
            async let f = api.getStockFundamentals(symbol: symbol)

            let (quoteRes, fundRes) = try await (q, f)
            self.quote = quoteRes
            self.fundamentalsData = fundRes

            // Debug logging summarising returned data to help UI issues
            let descLen = quoteRes.profile?.description?.count ?? 0
            print("[StockDetailViewModel] fetched quote for \(symbol) - companyName=\(quoteRes.companyName ?? "<nil>"), profile.longName=\(quoteRes.profile?.longName ?? "<nil>"), descLen=\(descLen), price=\(quoteRes.quote?.regularMarketPrice.map { String($0) } ?? "<nil>")")

            // More detailed debug payloads
            if let qDebug = quoteDebugString() {
                print("[StockDetailViewModel] quote payload: \(qDebug)")
            }
            if let f = fundRes as StockFundamentals? {
                var fundParts: [String] = []
                if let pe = f.peRatio { fundParts.append("pe:\(pe)") }
                if let eps = f.eps { fundParts.append("eps:\(eps)") }
                if let mc = f.marketCap { fundParts.append("mc:\(mc)") }
                if let hi = f.fiftyTwoWeekHigh { fundParts.append("52hi:\(hi)") }
                if let lo = f.fiftyTwoWeekLow { fundParts.append("52lo:\(lo)") }
                print("[StockDetailViewModel] fundamentals: \(fundParts.joined(separator: " | "))")
            } else {
                print("[StockDetailViewModel] no fundamentals returned for \(symbol)")
            }
            
            // Debug 52-week values from both sources
            let q52Hi = quoteRes.quote?.fiftyTwoWeekHigh
            let q52Lo = quoteRes.quote?.fiftyTwoWeekLow
            let f52Hi = fundRes.fiftyTwoWeekHigh
            let f52Lo = fundRes.fiftyTwoWeekLow
            print("[StockDetailViewModel] 52-week from quote: hi=\(q52Hi.map { String($0) } ?? "nil") lo=\(q52Lo.map { String($0) } ?? "nil")")
            print("[StockDetailViewModel] 52-week from fund:  hi=\(f52Hi.map { String($0) } ?? "nil") lo=\(f52Lo.map { String($0) } ?? "nil")")
            
            // Always fetch from Infront live API to get 52-week data (it's more reliable than cached DB data)
            print("[StockDetailViewModel] Fetching from Infront live API for \(symbol)...")
            do {
                let liveData = try await api.getInfrontLiveData(symbol: symbol)
                self.infrontLive = liveData
                print("[StockDetailViewModel] Infront live SUCCESS: high52Week=\(liveData.high52Week.map { String($0) } ?? "nil"), low52Week=\(liveData.low52Week.map { String($0) } ?? "nil")")
            } catch {
                print("[StockDetailViewModel] Infront live fetch FAILED: \(error)")
            }

            // Fetch stock-specific trade ticks from /api/tradeticks (Infront-backed)
            do {
                let ticks = try await api.fetchTradeTicks(symbol: symbol, feedNumber: 19)
                self.tradeTicks = ticks
                self.requiresSubscriptionForTrades = false
                print("[StockDetailViewModel] trade ticks SUCCESS: \(ticks.count)")
            } catch {
                self.tradeTicks = []
                // If unauthorized, set subscription flag so UI can show gating
                if let apiErr = error as? APIError {
                    switch apiErr {
                    case .unauthorized:
                        self.requiresSubscriptionForTrades = true
                    default:
                        self.requiresSubscriptionForTrades = false
                    }
                } else {
                    let desc = (error as NSError).localizedDescription.lowercased()
                    self.requiresSubscriptionForTrades = desc.contains("unauthor")
                }
                print("[StockDetailViewModel] trade ticks FAILED: \(error)")
            }

        } catch {
            self.errorMessage = error.localizedDescription
            print("[StockDetailViewModel] fetch error for \(symbol): \(error)")
        }
        isLoading = false
    }

    // Basic fields
    var companyName: String {
        // Prefer explicit companyName, then profile.longName, then symbol
        quote?.companyName ?? quote?.profile?.longName ?? symbol
    }

    var displaySymbol: String {
        quote?.symbol ?? symbol
    }

    var pencePriceString: String {
        guard let price = quote?.quote?.regularMarketPrice else { return "--" }
        return formatPenceFromPounds(price)
    }

    // Raw values for calculations
    var currentPriceValue: Double {
        quote?.quote?.regularMarketPrice ?? 0
    }
    
    var dayHighValue: Double {
        quote?.quote?.regularMarketDayHigh ?? 0
    }
    
    var dayLowValue: Double {
        quote?.quote?.regularMarketDayLow ?? 0
    }
    
    var changeAmount: Double {
        quote?.quote?.regularMarketChange ?? 0
    }
    
    var changePercent: Double {
        quote?.quote?.regularMarketChangePercent ?? 0
    }

    // Bid/Ask values
    var bidValue: Double? {
        quote?.quote?.bid
    }
    
    var askValue: Double? {
        quote?.quote?.ask
    }
    
    var bidString: String {
        if let b = quote?.quote?.bid { return formatPenceFromPounds(b) }
        return "--"
    }
    
    var askString: String {
        if let a = quote?.quote?.ask { return formatPenceFromPounds(a) }
        return "--"
    }
    
    var spreadValue: Double? {
        guard let bid = bidValue, let ask = askValue else { return nil }
        return ask - bid
    }
    
    var spreadString: String {
        if let spread = spreadValue { return formatPenceFromPounds(spread) }
        return "--"
    }
    
    var spreadPercentString: String {
        guard let spread = spreadValue, let price = quote?.quote?.regularMarketPrice, price > 0 else { return "" }
        let pct = (spread / price) * 100
        return String(format: "(%.2f%%)", pct)
    }

    // Market status - UK market hours 8:00-16:30 Mon-Fri
    var isMarketOpen: Bool {
        let now = Date()
        let calendar = Calendar.current
        guard let londonTZ = TimeZone(identifier: "Europe/London") else { return false }
        let components = calendar.dateComponents(in: londonTZ, from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let weekday = components.weekday ?? 1
        
        let isWeekend = weekday == 1 || weekday == 7
        let afterOpen = hour > 8 || (hour == 8 && minute >= 0)
        let beforeClose = hour < 16 || (hour == 16 && minute <= 30)
        
        return !isWeekend && afterOpen && beforeClose
    }

    var dayHigh: String {
        if let h = quote?.quote?.regularMarketDayHigh { return formatPenceFromPounds(h) }
        return "--"
    }

    var dayLow: String {
        if let l = quote?.quote?.regularMarketDayLow { return formatPenceFromPounds(l) }
        return "--"
    }

    var previousClose: String {
        if let p = quote?.quote?.regularMarketPrice { return formatPenceFromPounds(p) }
        return "--"
    }

    var openPriceString: String {
        // Try to get open price, fall back to previous close if not available
        if quote?.quote?.regularMarketDayLow != nil {
            // Note: API doesn't always provide open, using dayLow as fallback indicator
            // In real implementation, this should come from quote.open or similar field
            return formatPenceFromPounds(quote?.quote?.regularMarketPrice ?? 0)
        }
        return "--"
    }

    var volumeString: String {
        if let v = quote?.quote?.regularMarketVolume { return NumberFormatter.localizedString(from: NSNumber(value: v), number: .decimal) }
        return "--"
    }

    // Value traded = current price (pence) × volume / 100 to get £
    var tradedValueString: String {
        guard let price = quote?.quote?.regularMarketPrice,
              let volume = quote?.quote?.regularMarketVolume else { return "--" }
        let valueInPounds = (price * Double(volume)) / 100.0
        return formatLargeValue(valueInPounds)
    }

    private func formatLargeValue(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "£%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "£%.2fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "£%.2fK", value / 1_000)
        } else {
            return String(format: "£%.2f", value)
        }
    }

    // Overview extras
    private func extractDescription() -> String? {
        // Try common locations for description in order of preference
        let candidates: [String?] = [
            quote?.profile?.description,
            quote?.companyName,
            quote?.profile?.longName,
            quote?.quote?.longName
        ]
        for c in candidates {
            if let s = c?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return s
            }
        }
        return nil
    }

    var descriptionShort: String {
        if let desc = extractDescription(), !desc.isEmpty {
            // Return first two paragraphs/lines or up to ~300 chars
            let lines = desc.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).map { String($0) }
            if lines.count <= 2 { return desc }
            return lines.prefix(2).joined(separator: " ")
        }

        // Fallback: show company name and sector if available so Overview isn't empty
        let name = quote?.companyName ?? quote?.profile?.longName ?? symbol
        if let sector = quote?.profile?.sector ?? fundamentalsData?.taxonomies?[("sector")]?.value as? String {
            let fallback = "\(name) — Sector: \(sector)"
            print("[StockDetailViewModel] using fallback description for \(symbol): \(fallback)")
            return fallback
        }

        // No description found - log for debugging (helps trace API payloads)
        if let s = quoteDebugString() {
            print("[StockDetailViewModel] No description for \(symbol). Quote payload: \(s)")
        } else {
            print("[StockDetailViewModel] No description for \(symbol) and no payload available")
        }
        return "No description available."
    }

    var descriptionFull: String {
        extractDescription() ?? "No description available."
    }

    var fiftyTwoWeekRange: String {
        // Prefer Infront live data (direct from Infront API), then fallback to other sources
        if let low = infrontLive?.low52Week ?? fundamentalsData?.fiftyTwoWeekLow ?? quote?.quote?.fiftyTwoWeekLow,
           let high = infrontLive?.high52Week ?? fundamentalsData?.fiftyTwoWeekHigh ?? quote?.quote?.fiftyTwoWeekHigh {
            let lowStr = formatPenceFromPounds(low)
            let highStr = formatPenceFromPounds(high)
            return "\(lowStr) – \(highStr)"
        }
        return "--"
    }

    // Year Low/High for the range slider - prefer Infront live data (direct from Infront API)
    var yearLowValue: Double {
        infrontLive?.low52Week ?? fundamentalsData?.fiftyTwoWeekLow ?? quote?.quote?.fiftyTwoWeekLow ?? 0
    }
    
    var yearHighValue: Double {
        infrontLive?.high52Week ?? fundamentalsData?.fiftyTwoWeekHigh ?? quote?.quote?.fiftyTwoWeekHigh ?? 0
    }
    
    var yearLowString: String {
        let low = yearLowValue
        if low > 0 { return formatPenceFromPounds(low) }
        return "--"
    }
    
    var yearHighString: String {
        let high = yearHighValue
        if high > 0 { return formatPenceFromPounds(high) }
        return "--"
    }

    var marketCapDisplay: String {
        // Check multiple sources for market cap: fundamentals, profile, quote.fundamentals, infrontLive
        if let cap = fundamentalsData?.marketCap, cap > 0 {
            return formatMarketCap(cap)
        }
        if let cap = quote?.profile?.marketCap, cap > 0 {
            return formatMarketCap(cap)
        }
        if let cap = quote?.fundamentals?.marketCap, cap > 0 {
            return formatMarketCap(cap)
        }
        if let cap = infrontLive?.marketCap, cap > 0 {
            return formatMarketCap(cap)
        }
        return "--"
    }

    var sectorDisplay: String {
        // Map to sector_disp: prefer sectorDisp, then sector
        if let s = quote?.profile?.sectorDisp, !s.isEmpty { return s }
        if let s = quote?.profile?.sector, !s.isEmpty { return s }
        if let s = fundamentalsData?.taxonomies?["sector"]?.value as? String, !s.isEmpty { return s }
        return "--"
    }

    var subsectorDisplay: String {
        // Map to industry_disp: use profile.industry
        if let s = quote?.profile?.industry, !s.isEmpty { return s }
        if let s = fundamentalsData?.taxonomies?["industry"]?.value as? String, !s.isEmpty { return s }
        return "--"
    }

    var peDisplay: String {
        if let pe = fundamentalsData?.peRatio ?? quote?.fundamentals?.peRatio { return String(format: "%.2f", pe) }
        return "--"
    }

    var epsDisplay: String {
        if let eps = fundamentalsData?.eps ?? quote?.fundamentals?.eps { return String(format: "%.2f", eps) }
        return "--"
    }

    // Performance figures - prefer StockQuote.performance then Infront live keyfigures
    var perfOneWeekValue: Double? {
        quote?.performance?.oneWeek ?? infrontLive?.weekPerformance
    }
    var perfOneMonthValue: Double? {
        quote?.performance?.oneMonth ?? infrontLive?.monthPerformance
    }
    var perfThreeMonthValue: Double? {
        quote?.performance?.threeMonth
    }
    var perfSixMonthValue: Double? {
        quote?.performance?.sixMonth
    }
    var perfOneYearValue: Double? {
        quote?.performance?.oneYear ?? infrontLive?.yearPerformance
    }
    var perfYTDValue: Double? {
        quote?.performance?.ytd ?? infrontLive?.ytdPerformance
    }

    // Helper to format a performance value as a percentage string
    func perfString(_ value: Double?) -> String {
        guard let v = value else { return "--" }
        return String(format: "%+.2f%%", v)
    }

    // Provide an ordered list of period labels and their values for the UI
    var performanceSeries: [(label: String, value: Double?)] {
        [
            ("1W", perfOneWeekValue),
            ("1M", perfOneMonthValue),
            ("3M", perfThreeMonthValue),
            ("6M", perfSixMonthValue),
            ("1Y", perfOneYearValue),
            ("YTD", perfYTDValue)
        ]
    }

    // Helper formatters
    private func formatMarketCap(_ cap: Double) -> String {
        // cap may be in raw units (e.g., GBP), attempt to format sensibly
        if cap >= 1_000_000_000 { return "£\(String(format: "%.1fB", cap / 1_000_000_000))" }
        if cap >= 1_000_000 { return "£\(String(format: "%.1fM", cap / 1_000_000))" }
        return "£\(String(format: "%.0f", cap))"
    }

    func quoteDebugString() -> String? {
        guard let q = quote else { return nil }
        // Build a conservative debug string from key fields to avoid depending on Encodable conformance
        var parts: [String] = []
        parts.append("symbol:\(q.symbol)")
        if let cn = q.companyName { parts.append("companyName:\(cn)") }
        if let pln = q.profile?.longName { parts.append("profile.longName:\(pln)") }
        if let desc = q.profile?.description { parts.append("descriptionLen:\(desc.count)") }
        if let price = q.quote?.regularMarketPrice { parts.append("price:\(price)") }
        return parts.joined(separator: " | ")
    }

    // Trades helpers
    var latest20TradeTicks: [TradeTick] {
        // Parse ISO8601 timestamps where possible, sort newest-first, then return top 20
        let iso = ISO8601DateFormatter()
        let sorted = tradeTicks.sorted { a, b in
            let da = iso.date(from: a.timestamp) ?? Date.distantPast
            let db = iso.date(from: b.timestamp) ?? Date.distantPast
            return da > db
        }
        return Array(sorted.prefix(20))
    }

    func tradeTimeString(_ timestamp: String) -> String {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: timestamp) {
            let out = DateFormatter()
            out.dateFormat = "HH:mm:ss"
            return out.string(from: d)
        }
        return timestamp
    }

    func tradePriceString(_ price: Double) -> String {
        formatPenceFromPounds(price)
    }

    func tradeVolumeString(_ volume: Double) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: Int(volume)), number: .decimal)
    }
}
