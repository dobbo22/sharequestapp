//
//  APIService.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import Foundation

/// API configuration
enum APIConfig {
    enum Environment: String {
        case local
        case remote
    }

    private static let selectedEnvironmentKey = "api_environment"
    private static let localHostKey = "api_local_host"

    static var remoteBaseURL: String {
        get {
            UserDefaults.standard.string(forKey: "api_remote_base_url") ?? "https://sharequest.co.uk/api"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "api_remote_base_url")
        }
    }

    static var selectedEnvironment: Environment {
        get {
            if let raw = UserDefaults.standard.string(forKey: selectedEnvironmentKey),
               let env = Environment(rawValue: raw) {
                return env
            }
#if targetEnvironment(simulator)
            return .local
#else
            return .remote
#endif
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: selectedEnvironmentKey)
        }
    }

    static var localHost: String {
        get { UserDefaults.standard.string(forKey: localHostKey) ?? defaultLocalHost }
        set { UserDefaults.standard.set(newValue, forKey: localHostKey) }
    }

    static var defaultLocalHost: String {
#if targetEnvironment(simulator)
        return "localhost:3000"
#else
        // Physical devices cannot reach localhost on Mac.
        return "192.168.1.100:3000"
#endif
    }

    static var localBaseURL: String { "http://\(localHost)/api" }

    static var mainAppURL: String {
        selectedEnvironment == .local ? localBaseURL : remoteBaseURL
    }

    // Legacy item endpoints remain pointed at remote API by default.
    static let baseURL = remoteBaseURL
}

/// API error types
enum APIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case serverErrorWithMessage(Int, String)
    case decodingError(String)
    case networkError(String)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .serverError(let code):
            return "Server error: \(code)"
        case .serverErrorWithMessage(let code, let message):
            return "Server error \(code): \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .noData:
            return "No data received"
        }
    }
}

/// API Response wrapper
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let error: String?
    let message: String?
}

/// Service to handle all API calls to the ShareQuest backend
final class APIService: @unchecked Sendable {
    static let shared = APIService()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private var authToken: String?
    private var userId: String?
    
    private init() {
        // Load saved auth token from UserDefaults (use Keychain in production)
        self.authToken = UserDefaults.standard.string(forKey: "auth_token")
        self.userId = UserDefaults.standard.string(forKey: "user_id")
    }
    
    // MARK: - Authentication
    
    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    func setUserId(_ id: String) {
        self.userId = id
        UserDefaults.standard.set(id, forKey: "user_id")
    }
    
    func clearAuth() {
        self.authToken = nil
        self.userId = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "user_id")
    }
    
    var isAuthenticated: Bool {
        return authToken?.isEmpty == false
    }

    var currentEnvironment: APIConfig.Environment {
        APIConfig.selectedEnvironment
    }

    func setAPIEnvironment(_ env: APIConfig.Environment) {
        APIConfig.selectedEnvironment = env
    }

    func setLocalAPIHost(_ host: String) {
        APIConfig.localHost = host
    }

    func setRemoteBaseURL(_ url: String) {
        APIConfig.remoteBaseURL = url
    }

    // MARK: - Items (sq.items table)
    
    /// Fetch all items
    func fetchItems() async throws -> [Item] {
        let url = try buildURL(path: "/items", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode([Item].self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Fetch a single item by ID
    func fetchItem(id: String) async throws -> Item {
        let url = try buildURL(path: "/items/\(id)", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(Item.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Create a new item
    func createItem(title: String, details: String?, priority: Int = 0) async throws -> Item {
        let url = try buildURL(path: "/items", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        
        let body = ItemRequest(title: title, details: details, isCompleted: false, priority: priority)
        request.httpBody = try encoder.encode(body)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(Item.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Update an existing item
    func updateItem(id: String, title: String?, details: String?, isCompleted: Bool?, priority: Int?) async throws -> Item {
        let url = try buildURL(path: "/items/\(id)", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        
        let body = ItemRequest(title: title ?? "", details: details, isCompleted: isCompleted, priority: priority)
        request.httpBody = try encoder.encode(body)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(Item.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Delete an item
    func deleteItem(id: String) async throws {
        let url = try buildURL(path: "/items/\(id)", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuthHeader(to: &request)
        
        _ = try await performRequest(request)
    }
    
    // MARK: - Stocks (from main ShareQuest API)
    
    /// Fetch FTSE 100 stocks
    func fetchFTSE100(limit: Int = 100) async throws -> [StockData] {
        let url = try buildURL(path: "/mobile/stocks/ftse100?limit=\(limit)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            let response = try decoder.decode(StocksResponse.self, from: data)
            return response.stocks ?? []
        } catch {
            // Try direct array decode
            do {
                return try decoder.decode([StockData].self, from: data)
            } catch {
                throw APIError.decodingError(error.localizedDescription)
            }
        }
    }
    
    /// Fetch FTSE 250 stocks
    func fetchFTSE250(limit: Int = 250) async throws -> [StockData] {
        let url = try buildURL(path: "/mobile/stocks/ftse250?limit=\(limit)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            let response = try decoder.decode(StocksResponse.self, from: data)
            return response.stocks ?? []
        } catch {
            do {
                return try decoder.decode([StockData].self, from: data)
            } catch {
                throw APIError.decodingError(error.localizedDescription)
            }
        }
    }
    
    /// Search stocks
    func searchStocks(query: String) async throws -> [StockData] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Call main app mobile search endpoint directly
        let url = try buildURL(path: "/mobile/stocks/search?q=\(encodedQuery)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        // Try multiple possible response shapes:
        // 1. APIResponse<[StockData]> with `.data` field
        // 2. StocksResponse with `.stocks` field
        // 3. raw array [StockData]
        do {
            // 1. APIResponse<[StockData]>
            if let apiWrapped = try? decoder.decode(APIResponse<[StockData]>.self, from: data), let wrapped = apiWrapped.data {
                return wrapped
            }
            // 2. StocksResponse
            if let stocksResp = try? decoder.decode(StocksResponse.self, from: data), let stocks = stocksResp.stocks {
                return stocks
            }
            // 3. Raw array
            if let arr = try? decoder.decode([StockData].self, from: data) {
                return arr
            }
            // Nothing matched
            throw APIError.decodingError("Unrecognized stocks response")
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Get stock quote
    func getStockQuote(symbol: String) async throws -> StockQuote {
        let url = try buildURL(path: "/mobile/stocks/\(symbol)/quote", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let data = try await performRequest(request)

        // Flexible parsing: try wrapped APIResponse, then direct StockQuote, then inner `data` object
        if let wrapped = try? decoder.decode(APIResponse<StockQuote>.self, from: data), let obj = wrapped.data {
            print("[APIService] getStockQuote(\(symbol)) - decoded as APIResponse<StockQuote>")
            // If description is missing, log the raw payload for debugging
            if (obj.profile?.description ?? "").isEmpty {
                if let s = String(data: data, encoding: .utf8) {
                    print("[APIService] getStockQuote(\(symbol)) - no description; raw response:\n\(s)")
                }
            }
            return obj
        }
        if let direct = try? decoder.decode(StockQuote.self, from: data) {
            print("[APIService] getStockQuote(\(symbol)) - decoded as direct StockQuote")
            if (direct.profile?.description ?? "").isEmpty {
                if let s = String(data: data, encoding: .utf8) {
                    print("[APIService] getStockQuote(\(symbol)) - no description; raw response:\n\(s)")
                }
            }
            return direct
        }
        // Try to find inner `data` key and decode that
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let inner = json["data"] as? [String: Any] {
            let innerData = try JSONSerialization.data(withJSONObject: inner)
            if let decoded = try? decoder.decode(StockQuote.self, from: innerData) {
                print("[APIService] getStockQuote(\(symbol)) - decoded StockQuote from inner data")
                if (decoded.profile?.description ?? "").isEmpty {
                    if let s = String(data: innerData, encoding: .utf8) {
                        print("[APIService] getStockQuote(\(symbol)) - no description in inner data; inner response:\n\(s)")
                    }
                }
                return decoded
            } else {
                // keep going to manual fallback but log that inner decode failed
                if let s = String(data: innerData, encoding: .utf8) {
                    print("[APIService] getStockQuote(\(symbol)) - inner data present but failed to decode StockQuote; inner: \n\(s)")
                }
            }
        }

        // Flexible manual fallback: inspect JSON and attempt to extract common keys and construct a StockQuote
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            func stringValue(_ dict: [String: Any]?, _ keys: [String]) -> String? {
                guard let dict = dict else { return nil }
                for k in keys {
                    if let v = dict[k] as? String, !v.isEmpty { return v }
                    if let v = dict[k] as? NSNumber { return v.stringValue }
                }
                return nil
            }
            func doubleFrom(_ any: Any?) -> Double? {
                if let d = any as? Double { return d }
                if let n = any as? NSNumber { return n.doubleValue }
                if let s = any as? String, let d = Double(s) { return d }
                return nil
            }

            // Helper to dig nested dictionaries by path
            func dig(_ root: [String: Any], _ path: [String]) -> Any? {
                var cur: Any? = root
                for p in path {
                    if let c = cur as? [String: Any] {
                        cur = c[p]
                    } else { return nil }
                }
                return cur
            }

            // Try several sensible locations for description and company name
            let topProfile = json["profile"] as? [String: Any]
            let topQuote = json["quote"] as? [String: Any]
            let dataObj = (json["data"] as? [String: Any]) ?? json
            let dataProfile = dataObj["profile"] as? [String: Any]
            let dataQuote = dataObj["quote"] as? [String: Any]

            let companyName = stringValue(json, ["companyName", "company_name", "companyname"]) ?? stringValue(topQuote, ["longName", "long_name"]) ?? stringValue(dataObj, ["companyName"]) ?? symbol

            // description search paths
            let descCandidates: [Any?] = [
                topProfile?["description"],
                dataProfile?["description"],
                dig(json, ["data","profile","description"]),
                dig(json, ["quote","profile","description"]),
                json["description"],
                json["companyDescription"],
                topQuote?["description"],
                dataQuote?["description"]
            ]
            var descriptionFound: String? = nil
            for c in descCandidates {
                if let s = c as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { descriptionFound = s; break }
            }

            // sector and industry (subsector)
            let sector = stringValue(topProfile, ["sector"]) ?? stringValue(dataProfile, ["sector"]) ?? nil
            let sectorDisp = stringValue(topProfile, ["sectorDisp", "sector_disp"]) ?? stringValue(dataProfile, ["sectorDisp", "sector_disp"]) ?? nil
            let industry = stringValue(topProfile, ["industry", "industry_disp"]) ?? stringValue(dataProfile, ["industry", "industry_disp"]) ?? nil
            
            // Market cap from profile
            let marketCapVal = doubleFrom(topProfile?["marketCap"] ?? dataProfile?["marketCap"] ?? json["marketCap"] ?? dataObj["marketCap"]) ?? nil

            // Build quote data if possible
            let price = doubleFrom(topQuote?["price"] ?? topQuote?["regularMarketPrice"] ?? dataQuote?["price"] ?? dataQuote?["regularMarketPrice"]) ?? doubleFrom(json["price"]) ?? doubleFrom(dataObj["price"]) ?? nil
            let dayHigh = doubleFrom(topQuote?["dayHigh"] ?? topQuote?["regularMarketDayHigh"] ?? dataQuote?["dayHigh"] ?? dataQuote?["regularMarketDayHigh"]) ?? nil
            let dayLow = doubleFrom(topQuote?["dayLow"] ?? topQuote?["regularMarketDayLow"] ?? dataQuote?["dayLow"] ?? dataQuote?["regularMarketDayLow"]) ?? nil
            let vol = (topQuote?["volume"] as? NSNumber)?.intValue ?? (dataQuote?["volume"] as? NSNumber)?.intValue ?? nil
            
            // 52-week high/low - check standard fields and Infront keyfigure fields
            let keyfigure = json["keyfigure"] as? [String: Any]
            let keyfigureCommon = keyfigure?["common"] as? [String: Any]
            
            // Also check fiftyTwoWeek nested object
            let fiftyTwoWeekObj = json["fiftyTwoWeek"] as? [String: Any] ?? dataObj["fiftyTwoWeek"] as? [String: Any]
            
            let fiftyHi = doubleFrom(topQuote?["fiftyTwoWeekHigh"] ?? topQuote?["52WeekHigh"] ?? dataQuote?["fiftyTwoWeekHigh"] ?? fiftyTwoWeekObj?["high"] ?? keyfigureCommon?["high_price_52_week"] ?? json["high_price_52_week"]) ?? nil
            let fiftyLo = doubleFrom(topQuote?["fiftyTwoWeekLow"] ?? topQuote?["52WeekLow"] ?? dataQuote?["fiftyTwoWeekLow"] ?? fiftyTwoWeekObj?["low"] ?? keyfigureCommon?["low_price_52_week"] ?? json["low_price_52_week"]) ?? nil
            
            // Debug logging for 52-week values
            print("[APIService] getStockQuote(\(symbol)) - 52wk parsing: fiftyHi=\(fiftyHi.map { String($0) } ?? "nil"), fiftyLo=\(fiftyLo.map { String($0) } ?? "nil")")
            print("[APIService] getStockQuote(\(symbol)) - fiftyTwoWeekObj=\(fiftyTwoWeekObj.map { String(describing: $0) } ?? "nil")")
            
            let bidVal = doubleFrom(topQuote?["bid"] ?? dataQuote?["bid"]) ?? nil
            let askVal = doubleFrom(topQuote?["ask"] ?? dataQuote?["ask"]) ?? nil

            let quote = StockQuote.QuoteData(
                regularMarketPrice: price,
                regularMarketChange: doubleFrom(topQuote?["change"] ?? dataQuote?["change"] ?? topQuote?["regularMarketChange"] ?? dataQuote?["regularMarketChange"]),
                regularMarketChangePercent: doubleFrom(topQuote?["changePercent"] ?? dataQuote?["changePercent"] ?? topQuote?["regularMarketChangePercent"] ?? dataQuote?["regularMarketChangePercent"]),
                regularMarketVolume: vol,
                regularMarketDayHigh: dayHigh,
                regularMarketDayLow: dayLow,
                fiftyTwoWeekHigh: fiftyHi,
                fiftyTwoWeekLow: fiftyLo,
                longName: stringValue(topQuote, ["longName"]) ?? stringValue(dataQuote, ["longName"]) ?? companyName,
                bid: bidVal,
                ask: askVal
            )

            let profile = StockQuote.ProfileData(
                longName: companyName,
                description: descriptionFound,
                sector: sector,
                sectorDisp: sectorDisp,
                industry: industry,
                country: nil,
                marketCap: marketCapVal
            )

            let fallback = StockQuote(symbol: stringValue(json, ["symbol"]) ?? symbol, companyName: companyName, quote: quote, profile: profile, fundamentals: nil)

            if (fallback.profile?.description ?? "").isEmpty {
                if let s = String(data: data, encoding: .utf8) {
                    print("[APIService] getStockQuote(\(symbol)) - manual fallback created but description still empty; raw response:\n\(s)")
                }
            } else {
                print("[APIService] getStockQuote(\(symbol)) - manual fallback extracted description (len \(fallback.profile?.description?.count ?? 0))")
            }

            // Log key fallback fields for debugging
            print("[APIService] getStockQuote(\(symbol)) - fallback.symbol=\(fallback.symbol) companyName=\(fallback.companyName ?? "<nil>") price=\(fallback.quote?.regularMarketPrice.map { String($0) } ?? "<nil>") sector=\(fallback.profile?.sector ?? "<nil>")")

            return fallback
        }

        // If nothing matched, attempt to decode to surface the decoding error
        do {
            return try decoder.decode(StockQuote.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Fetch trade ticks for a stock from main app endpoint (/api/tradeticks).
    /// Web app sends: symbol, feedNumber, date(YYYY-MM-DD).
    func fetchTradeTicks(symbol: String, feedNumber: Int = 19, date: String? = nil) async throws -> [TradeTick] {
        let day: String = {
            if let date { return date }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()

        let path = "/tradeticks?symbol=\(symbol)&feedNumber=\(feedNumber)&date=\(day)"
        let url = try buildURL(path: path, base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        // Log masked token for debugging (don't print full secret)
        if let token = authToken, !token.isEmpty {
            let prefix = token.prefix(6)
            let suffix = token.suffix(4)
            print("[APIService] fetchTradeTicks using token: \(prefix)....\(suffix) for \(symbol)")
        }

        var lastError: Error? = nil
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                let data = try await performRequest(request)

                // Preferred shape: { data: [...] }
                if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let arr = root["data"] as? [[String: Any]] {
                    let arrData = try JSONSerialization.data(withJSONObject: arr)
                    if let decoded = try? decoder.decode([TradeTick].self, from: arrData) {
                        return decoded
                    }
                }

                // Fallback: direct array
                if let decoded = try? decoder.decode([TradeTick].self, from: data) {
                    return decoded
                }

                throw APIError.decodingError("Unable to decode /api/tradeticks response")
            } catch {
                lastError = error
                // If unauthorized, perform Infront fallback (no retries)
                if let apiErr = error as? APIError, case .unauthorized = apiErr {
                    print("[APIService] /tradeticks returned 401 for \(symbol). Attempting Infront fallback via listing_id...")
                    do {
                        let listingId = try await getListingId(for: symbol)
                        // Try the infront tradeticks proxy (may or may not exist on server) with a small limit
                        let fallbackPath = "/stocks/\(symbol)/infront/tradeticks?listing_id=\(listingId)&limit=20"
                        let fallbackURL = try buildURL(path: fallbackPath, base: APIConfig.mainAppURL)
                        var fallbackRequest = URLRequest(url: fallbackURL)
                        fallbackRequest.httpMethod = "GET"
                        addHeaders(to: &fallbackRequest)

                        let fbData = try await performRequest(fallbackRequest)
                        // Try same decoding strategy
                        if let root = try? JSONSerialization.jsonObject(with: fbData) as? [String: Any],
                           let arr = root["data"] as? [[String: Any]] {
                            let arrData = try JSONSerialization.data(withJSONObject: arr)
                            if let decoded = try? decoder.decode([TradeTick].self, from: arrData) {
                                print("[APIService] Infront fallback succeeded for \(symbol) with listing_id=\(listingId)")
                                return decoded
                            }
                        }
                        if let decoded = try? decoder.decode([TradeTick].self, from: fbData) {
                            print("[APIService] Infront fallback raw array decode succeeded for \(symbol)")
                            return decoded
                        }
                        // If fallback didn't decode, fallthrough to original error
                        print("[APIService] Infront fallback did not return decodable trade ticks for \(symbol)")
                        throw APIError.decodingError("Unable to decode fallback /infront/tradeticks response")
                    } catch {
                        print("[APIService] Infront fallback failed for \(symbol): \(error)")
                        throw apiErr
                    }
                }

                // For transient network/server errors, retry with small backoff
                if let apiErr = error as? APIError {
                    switch apiErr {
                    case .networkError, .serverError:
                         if attempt < maxAttempts {
                             let waitNs = UInt64(200_000_000 * attempt) // 0.2s, 0.4s, ...
                             print("[APIService] transient error fetching tradeticks for \(symbol) (attempt \(attempt)), retrying after \(waitNs/1_000_000)ms: \(apiErr)")
                             try? await Task.sleep(nanoseconds: waitNs)
                             continue
                         }
                     default:
                         break
                     }
                 } else {
                    // Non-APIError (e.g., URLSession) treat as transient and retry
                    if attempt < maxAttempts {
                        let waitNs = UInt64(200_000_000 * attempt)
                        print("[APIService] transient (non-API) error fetching tradeticks for \(symbol) (attempt \(attempt)), retrying after \(waitNs/1_000_000)ms: \(error)")
                        try? await Task.sleep(nanoseconds: waitNs)
                        continue
                    }
                 }

                // No retry or retries exhausted - break and propagate
                break
            }
        }

        // If we reach here, retries exhausted or non-retryable error
        if let err = lastError as? APIError {
            throw err
        }
        throw lastError ?? APIError.noData
    }

    /// Lookup listing_id for a symbol from the database
    private func getListingId(for symbol: String) async throws -> String {
        // First try the dedicated listing-id endpoint (most efficient)
        let listingIdUrl = try buildURL(path: "/stocks/\(symbol)/listing-id", base: APIConfig.mainAppURL)
        var listingIdRequest = URLRequest(url: listingIdUrl)
        listingIdRequest.httpMethod = "GET"
        addHeaders(to: &listingIdRequest)
        
        print("[APIService] getListingId(\(symbol)) - trying dedicated endpoint: \(listingIdUrl)")
        
        do {
            let listingIdData = try await performRequest(listingIdRequest)
            if let json = try? JSONSerialization.jsonObject(with: listingIdData) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let listingId = json["listing_id"] as? String {
                print("[APIService] getListingId(\(symbol)) - found via dedicated endpoint: \(listingId)")
                return listingId
            }
        } catch {
            print("[APIService] getListingId(\(symbol)) - dedicated endpoint failed: \(error), trying fallbacks...")
        }
        
        // Fallback: Try the FTSE100 endpoint which includes listing_id
        let ftse100Url = try buildURL(path: "/mobile/stocks/ftse100?limit=200", base: APIConfig.mainAppURL)
        var ftse100Request = URLRequest(url: ftse100Url)
        ftse100Request.httpMethod = "GET"
        addHeaders(to: &ftse100Request)
        
        print("[APIService] getListingId(\(symbol)) - searching in FTSE100 list")
        
        let ftse100Data = try await performRequest(ftse100Request)
        
        if let json = try? JSONSerialization.jsonObject(with: ftse100Data) as? [String: Any],
           let stocks = json["stocks"] as? [[String: Any]] {
            for stock in stocks {
                if let stockSymbol = stock["symbol"] as? String, stockSymbol.uppercased() == symbol.uppercased() {
                    if let listingId = stock["listing_id"] as? String {
                        print("[APIService] getListingId(\(symbol)) - found listing_id from FTSE100: \(listingId)")
                        return listingId
                    }
                    if let listingId = stock["listing_id"] as? Int {
                        print("[APIService] getListingId(\(symbol)) - found listing_id (int) from FTSE100: \(listingId)")
                        return String(listingId)
                    }
                }
            }
        }
        
        // Also try FTSE250
        let ftse250Url = try buildURL(path: "/mobile/stocks/ftse250?limit=300", base: APIConfig.mainAppURL)
        var ftse250Request = URLRequest(url: ftse250Url)
        ftse250Request.httpMethod = "GET"
        addHeaders(to: &ftse250Request)
        
        print("[APIService] getListingId(\(symbol)) - searching in FTSE250 list")
        
        let ftse250Data = try await performRequest(ftse250Request)
        
        if let json = try? JSONSerialization.jsonObject(with: ftse250Data) as? [String: Any],
           let stocks = json["stocks"] as? [[String: Any]] {
            for stock in stocks {
                if let stockSymbol = stock["symbol"] as? String, stockSymbol.uppercased() == symbol.uppercased() {
                    if let listingId = stock["listing_id"] as? String {
                        print("[APIService] getListingId(\(symbol)) - found listing_id from FTSE250: \(listingId)")
                        return listingId
                    }
                    if let listingId = stock["listing_id"] as? Int {
                        print("[APIService] getListingId(\(symbol)) - found listing_id (int) from FTSE250: \(listingId)")
                        return String(listingId)
                    }
                }
            }
        }
        
        print("[APIService] getListingId(\(symbol)) - listing_id not found")
        throw APIError.noData
    }
    
    /// Fetch live Infront data directly (bypasses database cache)
    /// Returns raw keyfigure data including 52-week high/low
    func getInfrontLiveData(symbol: String) async throws -> InfrontLiveData {
        // Step 1: Lookup listing_id from database via stocks endpoint
        let listingId = try await getListingId(for: symbol)
        
        print("[APIService] getInfrontLiveData(\(symbol)) - got listing_id: \(listingId)")
        
        // Step 2: Call Infront live endpoint with listing_id and specific fields for 52-week data
        let fields = "keyfigure.common.high_price_52_week,keyfigure.common.low_price_52_week,keyfigure.common.performance_1_week,keyfigure.common.performance_1_month,keyfigure.common.performance_1_year,keyfigure.common.performance_current_year,keyfigure.equity.market_capitalization,keyfigure.equity.earnings_per_share,keyfigure.equity.price_earnings_ratio,snapquote,listing.common.name"
        let url = try buildURL(path: "/stocks/\(symbol)/infront/live?listing_id=\(listingId)&fields=\(fields)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        print("[APIService] getInfrontLiveData(\(symbol)) - fetching from \(url)")
        
        let data = try await performRequest(request)
        
        // Log raw response for debugging
        if let rawStr = String(data: data, encoding: .utf8) {
            print("[APIService] getInfrontLiveData(\(symbol)) - raw response length: \(rawStr.count)")
            print("[APIService] getInfrontLiveData(\(symbol)) - raw response: \(rawStr.prefix(1000))...")
        }
        
        // Parse the Infront response - it may be wrapped in _data array or data array
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("Invalid JSON from Infront live endpoint")
        }
        
        // Log top-level keys
        print("[APIService] getInfrontLiveData(\(symbol)) - top-level keys: \(json.keys.joined(separator: ", "))")
        
        // Extract the actual data object (may be nested)
        let dataArray = json["_data"] as? [[String: Any]] ?? json["data"] as? [[String: Any]]
        let rawData: [String: Any] = dataArray?.first ?? json
        
        // Log rawData keys
        print("[APIService] getInfrontLiveData(\(symbol)) - rawData keys: \(rawData.keys.joined(separator: ", "))")
        // Check if keyfigure exists
        if let keyfigure = rawData["keyfigure"] as? [String: Any] {
            print("[APIService] getInfrontLiveData(\(symbol)) - keyfigure keys: \(keyfigure.keys.joined(separator: ", "))")
            if let common = keyfigure["common"] as? [String: Any] {
                print("[APIService] getInfrontLiveData(\(symbol)) - keyfigure.common keys: \(common.keys.joined(separator: ", "))")
                print("[APIService] getInfrontLiveData(\(symbol)) - keyfigure.common.high_price_52_week = \(common["high_price_52_week"] ?? "nil")")
                print("[APIService] getInfrontLiveData(\(symbol)) - keyfigure.common.low_price_52_week = \(common["low_price_52_week"] ?? "nil")")
            }
        }
        
        // Helper to extract nested values using dot notation
        func getValue(_ keyPath: String) -> Any? {
            let keys = keyPath.split(separator: ".").map(String.init)
            var current: Any? = rawData
            for key in keys {
                if let dict = current as? [String: Any] {
                    current = dict[key]
                } else {
                    return nil
                }
            }
            return current
        }
        
        func getDouble(_ keyPath: String) -> Double? {
            if let val = getValue(keyPath) {
                if let d = val as? Double { return d }
                if let i = val as? Int { return Double(i) }
                if let s = val as? String, let d = Double(s) { return d }
            }
            return nil
        }
        
        func getString(_ keyPath: String) -> String? {
            if let val = getValue(keyPath) {
                if let s = val as? String { return s }
            }
            return nil
        }
        
        // Extract all the fields
        let result = InfrontLiveData(
            lastPrice: getDouble("snapquote.last_price"),
            bidPrice: getDouble("snapquote.bid_price"),
            askPrice: getDouble("snapquote.ask_price"),
            openPrice: getDouble("snapquote.open_price"),
            highPrice: getDouble("snapquote.high_price"),
            lowPrice: getDouble("snapquote.low_price"),
            closePrice: getDouble("snapquote.close_price"),
            previousClosePrice: getDouble("snapquote.previous_close_price"),
            volume: getDouble("snapquote.cumulative_volume").map { Int($0) },
            high52Week: getDouble("keyfigure.common.high_price_52_week"),
            low52Week: getDouble("keyfigure.common.low_price_52_week"),
            ytdPerformance: getDouble("keyfigure.common.performance_current_year"),
            weekPerformance: getDouble("keyfigure.common.performance_1_week"),
            monthPerformance: getDouble("keyfigure.common.performance_1_month"),
            yearPerformance: getDouble("keyfigure.common.performance_1_year"),
            marketCap: getDouble("keyfigure.equity.market_capitalization"),
            eps: getDouble("keyfigure.equity.earnings_per_share"),
            peRatio: getDouble("keyfigure.equity.price_earnings_ratio"),
            dividendYield: getDouble("issuer_keyfigure.equity.dividend_yield"),
            companyName: getString("listing.common.name"),
            description: getString("company_basic.description_en")
        )
        
        print("[APIService] getInfrontLiveData(\(symbol)) - parsed: high52Week=\(result.high52Week.map { String($0) } ?? "nil"), low52Week=\(result.low52Week.map { String($0) } ?? "nil")")
        
        return result
    }
    
    /// Fetch fundamentals for a stock symbol. Returns nil if decoding fails.
    func getStockFundamentals(symbol: String) async throws -> StockFundamentals {
        let url = try buildURL(path: "/mobile/stocks/\(symbol)/fundamentals", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let data = try await performRequest(request)

        // Try multiple shapes: APIResponse.data, direct object
        if let wrapped = try? decoder.decode(APIResponse<StockFundamentals>.self, from: data), let obj = wrapped.data {
            return obj
        }
        if let direct = try? decoder.decode(StockFundamentals.self, from: data) {
            return direct
        }
        // As a last resort, try to decode a flexible dict and map keys
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Map common keys
            func dbl(_ keys: [String]) -> Double? {
                for k in keys { if let v = json[k] as? Double { return v } ; if let s = json[k] as? String, let d = Double(s) { return d } }
                return nil
            }
            // Also check Infront keyfigure.common nested structure
            let keyfigure = json["keyfigure"] as? [String: Any]
            let keyfigureCommon = keyfigure?["common"] as? [String: Any]
            func dblWithKeyfigure(_ keys: [String], keyfigureKey: String? = nil) -> Double? {
                // First try top-level keys
                if let val = dbl(keys) { return val }
                // Then try keyfigure.common
                if let kfKey = keyfigureKey, let kfVal = keyfigureCommon?[kfKey] {
                    if let d = kfVal as? Double { return d }
                    if let s = kfVal as? String, let d = Double(s) { return d }
                }
                return nil
            }
            let pe = dbl(["peRatio","pe","pe_ratio"])
            let eps = dbl(["eps","earningsPerShare","earnings_per_share"])
            let div = dbl(["dividendYield","dividend_yield"])
            let mc = dbl(["marketCap","market_cap"])
            let hi = dblWithKeyfigure(["fiftyTwoWeekHigh","52WeekHigh","fiftyTwoWeekHighRaw","high_price_52_week"], keyfigureKey: "high_price_52_week")
            let lo = dblWithKeyfigure(["fiftyTwoWeekLow","52WeekLow","fiftyTwoWeekLowRaw","low_price_52_week"], keyfigureKey: "low_price_52_week")
            let fundamentals = StockFundamentals(peRatio: pe, eps: eps, dividendYield: div, marketCap: mc, fiftyTwoWeekHigh: hi, fiftyTwoWeekLow: lo, taxonomies: nil)
            return fundamentals
        }
        throw APIError.decodingError("Unable to decode fundamentals for \(symbol)")
    }
    
    // MARK: - Portfolio (from main ShareQuest API)
    
    /// Fetch portfolio by type
    func fetchPortfolio(type: String) async throws -> PortfolioResponse {
        let url = try buildURL(path: "/mobile/portfolio/\(type)?refresh=true", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(PortfolioResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Execute a trade
    func executeTrade(portfolioType: String, symbol: String, action: String, quantity: Int) async throws -> TradeResponse {
        let url = try buildURL(path: "/mobile/portfolio/\(portfolioType)/trade", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        
        let body: [String: Any] = [
            "symbol": symbol,
            "action": action,
            "quantity": quantity
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(TradeResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Leaderboard (from main ShareQuest API)
    
    /// Fetch leaderboard
    func fetchLeaderboard(type: String) async throws -> LeaderboardResponse {
        let url = try buildURL(path: "/mobile/leaderboards/\(type)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(LeaderboardResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - User Authentication (from main ShareQuest API)
    
    /// Login user
    func login(email: String, password: String) async throws -> AuthResponse {
        let url = try buildURL(path: "/mobile/auth/login", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let data = try await performRequest(request)

        do {
            // First try the normal shape
            let response = try decoder.decode(AuthResponse.self, from: data)
            if let token = response.token {
                setAuthToken(token)
            }
            if let user = response.user {
                setUserId(user.id ?? user.username ?? "")
            }
            // If token/user were present at top-level return as-is
            if response.token != nil || response.user != nil {
                return response
            }
            // If we got here, top-level token/user were nil — fall through to flexible parsing
        } catch {
            // ignore, we'll try flexible parsing below
        }

        // Flexible fallback: some responses wrap payload under { success: true, data: { token, user } }
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let dataObj = json["data"] as? [String: Any] {
            var token: String? = nil
            var user: AuthResponse.UserData? = nil
            if let t = dataObj["token"] as? String {
                token = t
                setAuthToken(t)
            }
            if let userObj = dataObj["user"] as? [String: Any] {
                if let userData = try? JSONSerialization.data(withJSONObject: userObj),
                   let parsedUser = try? decoder.decode(AuthResponse.UserData.self, from: userData) {
                    user = parsedUser
                    setUserId(user?.id ?? user?.username ?? "")
                } else {
                    // Try to map minimal fields manually
                    let id = userObj["id"] as? String
                    let username = userObj["username"] as? String
                    let email = userObj["email"] as? String
                    let first = userObj["first_name"] as? String
                    let last = userObj["last_name"] as? String
                    user = AuthResponse.UserData(id: id, username: username, email: email, first_name: first, last_name: last, isAdmin: nil)
                    setUserId(user?.id ?? user?.username ?? "")
                }
            }
            return AuthResponse(success: json["success"] as? Bool, token: token, user: user, error: json["error"] as? String, message: json["message"] as? String)
        }

        // If nothing matched, attempt to decode and return (to surface decoding error)
        do {
            return try decoder.decode(AuthResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Register new user
    func register(email: String, username: String, password: String, firstName: String? = nil, lastName: String? = nil, dateOfBirth: String? = nil) async throws -> AuthResponse {
        let url = try buildURL(path: "/mobile/auth/register", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: String] = [
            "email": email,
            "username": username,
            "password": password
        ]
        
        if let firstName = firstName, !firstName.isEmpty {
            body["first_name"] = firstName
        }
        if let lastName = lastName, !lastName.isEmpty {
            body["last_name"] = lastName
        }
        if let dateOfBirth = dateOfBirth, !dateOfBirth.isEmpty {
            body["date_of_birth"] = dateOfBirth
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let data = try await performRequest(request)
        
        do {
            let response = try decoder.decode(AuthResponse.self, from: data)
            if let token = response.token {
                setAuthToken(token)
            }
            if let user = response.user {
                setUserId(user.id ?? user.username ?? "")
            }
            return response
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Dashboard (Unified)
    struct DashboardResponse: Codable {
        let success: Bool?
        let marketSentiment: MarketSentimentData?
        let market_sentiment: MarketSentimentData?
        let userSubscriptions: UserSubscriptionsData?
        let user_subscriptions: UserSubscriptionsData?
        let subscriptions: UserSubscriptionsData?
        
        var sentiment: MarketSentimentData? {
            marketSentiment ?? market_sentiment
        }
        var subs: UserSubscriptionsData? {
            userSubscriptions ?? user_subscriptions ?? subscriptions
        }
    }

    struct UserSubscriptionsData: Codable {
        let weekly: Bool?
        let monthly: Bool?
        let annual: Bool?
        let `default`: Bool? // always true for practice
    }

    // Fetch dashboard/unified (market sentiment, subscriptions, etc)
    func fetchDashboard() async throws -> DashboardResponse {
        let url = try buildURL(path: "/mobile/dashboard/unified", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        do {
            return try decoder.decode(DashboardResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // Fetch user subscriptions (for portfolio types)
    func fetchUserSubscriptions() async throws -> UserSubscriptionsData? {
        let url = try buildURL(path: "/mobile/subscriptions", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        do {
            let resp = try decoder.decode(APIResponse<UserSubscriptionsData>.self, from: data)
            return resp.data
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // Fetch portfolio details for a given type (default, weekly, monthly, etc)
    struct PortfolioDetailsResponse: Codable {
        let portfolio: PortfolioData?
    }
    struct PortfolioData: Codable {
        let id: String?
        let user_id: String?
        let portfolio_type: String?
        let cash_balance: String?
        let total_value: String?
        let holdingsValue: String?
        let initial_balance: String?
        let created_at: String?
        
        // Helper computed values
        var cashBalanceValue: Double {
            Double(cash_balance ?? "0") ?? 0
        }
        var totalPortfolioValue: Double {
            Double(total_value ?? holdingsValue ?? "0") ?? 0
        }
        var initialBalanceValue: Double {
            Double(initial_balance ?? "10000000") ?? 10000000
        }
    }
    func fetchPortfolioDetails(type: String) async throws -> PortfolioData? {
        let url = try buildURL(path: "/mobile/portfolio/\(type)?refresh=true", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        do {
            let resp = try decoder.decode(APIResponse<PortfolioDetailsResponse>.self, from: data)
            return resp.data?.portfolio
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Authentication

    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    func setUserId(_ id: String) {
        self.userId = id
        UserDefaults.standard.set(id, forKey: "user_id")
    }
    
    func clearAuth() {
        self.authToken = nil
        self.userId = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "user_id")
    }
    
    var isAuthenticated: Bool {
        return authToken?.isEmpty == false
    }

    var currentEnvironment: APIConfig.Environment {
        APIConfig.selectedEnvironment
    }

    func setAPIEnvironment(_ env: APIConfig.Environment) {
        APIConfig.selectedEnvironment = env
    }

    func setLocalAPIHost(_ host: String) {
        APIConfig.localHost = host
    }

    func setRemoteBaseURL(_ url: String) {
        APIConfig.remoteBaseURL = url
    }

    // MARK: - Items (sq.items table)
    
    /// Fetch all items
    func fetchItems() async throws -> [Item] {
        let url = try buildURL(path: "/items", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode([Item].self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Fetch a single item by ID
    func fetchItem(id: String) async throws -> Item {
        let url = try buildURL(path: "/items/\(id)", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(Item.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Create a new item
    func createItem(title: String, details: String?, priority: Int = 0) async throws -> Item {
        let url = try buildURL(path: "/items", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        
        let body = ItemRequest(title: title, details: details, isCompleted: false, priority: priority)
        request.httpBody = try encoder.encode(body)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(Item.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Update an existing item
    func updateItem(id: String, title: String?, details: String?, isCompleted: Bool?, priority: Int?) async throws -> Item {
        let url = try buildURL(path: "/items/\(id)", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        
        let body = ItemRequest(title: title ?? "", details: details, isCompleted: isCompleted, priority: priority)
        request.httpBody = try encoder.encode(body)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(Item.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Delete an item
    func deleteItem(id: String) async throws {
        let url = try buildURL(path: "/items/\(id)", base: APIConfig.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuthHeader(to: &request)
        
        _ = try await performRequest(request)
    }
    
    // MARK: - Stocks (from main ShareQuest API)
    
    /// Fetch FTSE 100 stocks
    func fetchFTSE100(limit: Int = 100) async throws -> [StockData] {
        let url = try buildURL(path: "/mobile/stocks/ftse100?limit=\(limit)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            let response = try decoder.decode(StocksResponse.self, from: data)
            return response.stocks ?? []
        } catch {
            // Try direct array decode
            do {
                return try decoder.decode([StockData].self, from: data)
            } catch {
                throw APIError.decodingError(error.localizedDescription)
            }
        }
    }
    
    /// Fetch FTSE 250 stocks
    func fetchFTSE250(limit: Int = 250) async throws -> [StockData] {
        let url = try buildURL(path: "/mobile/stocks/ftse250?limit=\(limit)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            let response = try decoder.decode(StocksResponse.self, from: data)
            return response.stocks ?? []
        } catch {
            do {
                return try decoder.decode([StockData].self, from: data)
            } catch {
                throw APIError.decodingError(error.localizedDescription)
            }
        }
    }
    
    /// Search stocks
    func searchStocks(query: String) async throws -> [StockData] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Call main app mobile search endpoint directly
        let url = try buildURL(path: "/mobile/stocks/search?q=\(encodedQuery)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        // Try multiple possible response shapes:
        // 1. APIResponse<[StockData]> with `.data` field
        // 2. StocksResponse with `.stocks` field
        // 3. raw array [StockData]
        do {
            // 1. APIResponse<[StockData]>
            if let apiWrapped = try? decoder.decode(APIResponse<[StockData]>.self, from: data), let wrapped = apiWrapped.data {
                return wrapped
            }
            // 2. StocksResponse
            if let stocksResp = try? decoder.decode(StocksResponse.self, from: data), let stocks = stocksResp.stocks {
                return stocks
            }
            // 3. Raw array
            if let arr = try? decoder.decode([StockData].self, from: data) {
                return arr
            }
            // Nothing matched
            throw APIError.decodingError("Unrecognized stocks response")
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Get stock quote
    func getStockQuote(symbol: String) async throws -> StockQuote {
        let url = try buildURL(path: "/mobile/stocks/\(symbol)/quote", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let data = try await performRequest(request)

        // Flexible parsing: try wrapped APIResponse, then direct StockQuote, then inner `data` object
        if let wrapped = try? decoder.decode(APIResponse<StockQuote>.self, from: data), let obj = wrapped.data {
            print("[APIService] getStockQuote(\(symbol)) - decoded as APIResponse<StockQuote>")
            // If description is missing, log the raw payload for debugging
            if (obj.profile?.description ?? "").isEmpty {
                if let s = String(data: data, encoding: .utf8) {
                    print("[APIService] getStockQuote(\(symbol)) - no description; raw response:\n\(s)")
                }
            }
            return obj
        }
        if let direct = try? decoder.decode(StockQuote.self, from: data) {
            print("[APIService] getStockQuote(\(symbol)) - decoded as direct StockQuote")
            if (direct.profile?.description ?? "").isEmpty {
                if let s = String(data: data, encoding: .utf8) {
                    print("[APIService] getStockQuote(\(symbol)) - no description; raw response:\n\(s)")
                }
            }
            return direct
        }
        // Try to find inner `data` key and decode that
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let inner = json["data"] as? [String: Any] {
            let innerData = try JSONSerialization.data(withJSONObject: inner)
            if let decoded = try? decoder.decode(StockQuote.self, from: innerData) {
                print("[APIService] getStockQuote(\(symbol)) - decoded StockQuote from inner data")
                if (decoded.profile?.description ?? "").isEmpty {
                    if let s = String(data: innerData, encoding: .utf8) {
                        print("[APIService] getStockQuote(\(symbol)) - no description in inner data; inner response:\n\(s)")
                    }
                }
                return decoded
            } else {
                // keep going to manual fallback but log that inner decode failed
                if let s = String(data: innerData, encoding: .utf8) {
                    print("[APIService] getStockQuote(\(symbol)) - inner data present but failed to decode StockQuote; inner: \n\(s)")
                }
            }
        }

        // Flexible manual fallback: inspect JSON and attempt to extract common keys and construct a StockQuote
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            func stringValue(_ dict: [String: Any]?, _ keys: [String]) -> String? {
                guard let dict = dict else { return nil }
                for k in keys {
                    if let v = dict[k] as? String, !v.isEmpty { return v }
                    if let v = dict[k] as? NSNumber { return v.stringValue }
                }
                return nil
            }
            func doubleFrom(_ any: Any?) -> Double? {
                if let d = any as? Double { return d }
                if let n = any as? NSNumber { return n.doubleValue }
                if let s = any as? String, let d = Double(s) { return d }
                return nil
            }

            // Helper to dig nested dictionaries by path
            func dig(_ root: [String: Any], _ path: [String]) -> Any? {
                var cur: Any? = root
                for p in path {
                    if let c = cur as? [String: Any] {
                        cur = c[p]
                    } else { return nil }
                }
                return cur
            }

            // Try several sensible locations for description and company name
            let topProfile = json["profile"] as? [String: Any]
            let topQuote = json["quote"] as? [String: Any]
            let dataObj = (json["data"] as? [String: Any]) ?? json
            let dataProfile = dataObj["profile"] as? [String: Any]
            let dataQuote = dataObj["quote"] as? [String: Any]

            let companyName = stringValue(json, ["companyName", "company_name", "companyname"]) ?? stringValue(topQuote, ["longName", "long_name"]) ?? stringValue(dataObj, ["companyName"]) ?? symbol

            // description search paths
            let descCandidates: [Any?] = [
                topProfile?["description"],
                dataProfile?["description"],
                dig(json, ["data","profile","description"]),
                dig(json, ["quote","profile","description"]),
                json["description"],
                json["companyDescription"],
                topQuote?["description"],
                dataQuote?["description"]
            ]
            var descriptionFound: String? = nil
            for c in descCandidates {
                if let s = c as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { descriptionFound = s; break }
            }

            // sector and industry (subsector)
            let sector = stringValue(topProfile, ["sector"]) ?? stringValue(dataProfile, ["sector"]) ?? nil
            let sectorDisp = stringValue(topProfile, ["sectorDisp", "sector_disp"]) ?? stringValue(dataProfile, ["sectorDisp", "sector_disp"]) ?? nil
            let industry = stringValue(topProfile, ["industry", "industry_disp"]) ?? stringValue(dataProfile, ["industry", "industry_disp"]) ?? nil
            
            // Market cap from profile
            let marketCapVal = doubleFrom(topProfile?["marketCap"] ?? dataProfile?["marketCap"] ?? json["marketCap"] ?? dataObj["marketCap"]) ?? nil

            // Build quote data if possible
            let price = doubleFrom(topQuote?["price"] ?? topQuote?["regularMarketPrice"] ?? dataQuote?["price"] ?? dataQuote?["regularMarketPrice"]) ?? doubleFrom(json["price"]) ?? doubleFrom(dataObj["price"]) ?? nil
            let dayHigh = doubleFrom(topQuote?["dayHigh"] ?? topQuote?["regularMarketDayHigh"] ?? dataQuote?["dayHigh"] ?? dataQuote?["regularMarketDayHigh"]) ?? nil
            let dayLow = doubleFrom(topQuote?["dayLow"] ?? topQuote?["regularMarketDayLow"] ?? dataQuote?["dayLow"] ?? dataQuote?["regularMarketDayLow"]) ?? nil
            let vol = (topQuote?["volume"] as? NSNumber)?.intValue ?? (dataQuote?["volume"] as? NSNumber)?.intValue ?? nil
            
            // 52-week high/low - check standard fields and Infront keyfigure fields
            let keyfigure = json["keyfigure"] as? [String: Any]
            let keyfigureCommon = keyfigure?["common"] as? [String: Any]
            
            // Also check fiftyTwoWeek nested object
            let fiftyTwoWeekObj = json["fiftyTwoWeek"] as? [String: Any] ?? dataObj["fiftyTwoWeek"] as? [String: Any]
            
            let fiftyHi = doubleFrom(topQuote?["fiftyTwoWeekHigh"] ?? topQuote?["52WeekHigh"] ?? dataQuote?["fiftyTwoWeekHigh"] ?? fiftyTwoWeekObj?["high"] ?? keyfigureCommon?["high_price_52_week"] ?? json["high_price_52_week"]) ?? nil
            let fiftyLo = doubleFrom(topQuote?["fiftyTwoWeekLow"] ?? topQuote?["52WeekLow"] ?? dataQuote?["fiftyTwoWeekLow"] ?? fiftyTwoWeekObj?["low"] ?? keyfigureCommon?["low_price_52_week"] ?? json["low_price_52_week"]) ?? nil
            
            // Debug logging for 52-week values
            print("[APIService] getStockQuote(\(symbol)) - 52wk parsing: fiftyHi=\(fiftyHi.map { String($0) } ?? "nil"), fiftyLo=\(fiftyLo.map { String($0) } ?? "nil")")
            print("[APIService] getStockQuote(\(symbol)) - fiftyTwoWeekObj=\(fiftyTwoWeekObj.map { String(describing: $0) } ?? "nil")")
            
            let bidVal = doubleFrom(topQuote?["bid"] ?? dataQuote?["bid"]) ?? nil
            let askVal = doubleFrom(topQuote?["ask"] ?? dataQuote?["ask"]) ?? nil

            let quote = StockQuote.QuoteData(
                regularMarketPrice: price,
                regularMarketChange: doubleFrom(topQuote?["change"] ?? dataQuote?["change"] ?? topQuote?["regularMarketChange"] ?? dataQuote?["regularMarketChange"]),
                regularMarketChangePercent: doubleFrom(topQuote?["changePercent"] ?? dataQuote?["changePercent"] ?? topQuote?["regularMarketChangePercent"] ?? dataQuote?["regularMarketChangePercent"]),
                regularMarketVolume: vol,
                regularMarketDayHigh: dayHigh,
                regularMarketDayLow: dayLow,
                fiftyTwoWeekHigh: fiftyHi,
                fiftyTwoWeekLow: fiftyLo,
                longName: stringValue(topQuote, ["longName"]) ?? stringValue(dataQuote, ["longName"]) ?? companyName,
                bid: bidVal,
                ask: askVal
            )

            let profile = StockQuote.ProfileData(
                longName: companyName,
                description: descriptionFound,
                sector: sector,
                sectorDisp: sectorDisp,
                industry: industry,
                country: nil,
                marketCap: marketCapVal
            )

            let fallback = StockQuote(symbol: stringValue(json, ["symbol"]) ?? symbol, companyName: companyName, quote: quote, profile: profile, fundamentals: nil)

            if (fallback.profile?.description ?? "").isEmpty {
                if let s = String(data: data, encoding: .utf8) {
                    print("[APIService] getStockQuote(\(symbol)) - manual fallback created but description still empty; raw response:\n\(s)")
                }
            } else {
                print("[APIService] getStockQuote(\(symbol)) - manual fallback extracted description (len \(fallback.profile?.description?.count ?? 0))")
            }

            // Log key fallback fields for debugging
            print("[APIService] getStockQuote(\(symbol)) - fallback.symbol=\(fallback.symbol) companyName=\(fallback.companyName ?? "<nil>") price=\(fallback.quote?.regularMarketPrice.map { String($0) } ?? "<nil>") sector=\(fallback.profile?.sector ?? "<nil>")")

            return fallback
        }

        // If nothing matched, attempt to decode to surface the decoding error
        do {
            return try decoder.decode(StockQuote.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Fetch trade ticks for a stock from main app endpoint (/api/tradeticks).
    /// Web app sends: symbol, feedNumber, date(YYYY-MM-DD).
    func fetchTradeTicks(symbol: String, feedNumber: Int = 19, date: String? = nil) async throws -> [TradeTick] {
        let day: String = {
            if let date { return date }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()

        let path = "/tradeticks?symbol=\(symbol)&feedNumber=\(feedNumber)&date=\(day)"
        let url = try buildURL(path: path, base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        // Log masked token for debugging (don't print full secret)
        if let token = authToken, !token.isEmpty {
            let prefix = token.prefix(6)
            let suffix = token.suffix(4)
            print("[APIService] fetchTradeTicks using token: \(prefix)....\(suffix) for \(symbol)")
        }

        var lastError: Error? = nil
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                let data = try await performRequest(request)

                // Preferred shape: { data: [...] }
                if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let arr = root["data"] as? [[String: Any]] {
                    let arrData = try JSONSerialization.data(withJSONObject: arr)
                    if let decoded = try? decoder.decode([TradeTick].self, from: arrData) {
                        return decoded
                    }
                }

                // Fallback: direct array
                if let decoded = try? decoder.decode([TradeTick].self, from: data) {
                    return decoded
                }

                throw APIError.decodingError("Unable to decode /api/tradeticks response")
            } catch {
                lastError = error
                // If unauthorized, perform Infront fallback (no retries)
                if let apiErr = error as? APIError, case .unauthorized = apiErr {
                    print("[APIService] /tradeticks returned 401 for \(symbol). Attempting Infront fallback via listing_id...")
                    do {
                        let listingId = try await getListingId(for: symbol)
                        // Try the infront tradeticks proxy (may or may not exist on server) with a small limit
                        let fallbackPath = "/stocks/\(symbol)/infront/tradeticks?listing_id=\(listingId)&limit=20"
                        let fallbackURL = try buildURL(path: fallbackPath, base: APIConfig.mainAppURL)
                        var fallbackRequest = URLRequest(url: fallbackURL)
                        fallbackRequest.httpMethod = "GET"
                        addHeaders(to: &fallbackRequest)

                        let fbData = try await performRequest(fallbackRequest)
                        // Try same decoding strategy
                        if let root = try? JSONSerialization.jsonObject(with: fbData) as? [String: Any],
                           let arr = root["data"] as? [[String: Any]] {
                            let arrData = try JSONSerialization.data(withJSONObject: arr)
                            if let decoded = try? decoder.decode([TradeTick].self, from: arrData) {
                                print("[APIService] Infront fallback succeeded for \(symbol) with listing_id=\(listingId)")
                                return decoded
                            }
                        }
                        if let decoded = try? decoder.decode([TradeTick].self, from: fbData) {
                            print("[APIService] Infront fallback raw array decode succeeded for \(symbol)")
                            return decoded
                        }
                        // If fallback didn't decode, fallthrough to original error
                        print("[APIService] Infront fallback did not return decodable trade ticks for \(symbol)")
                        throw APIError.decodingError("Unable to decode fallback /infront/tradeticks response")
                    } catch {
                        print("[APIService] Infront fallback failed for \(symbol): \(error)")
                        throw apiErr
                    }
                }

                // For transient network/server errors, retry with small backoff
                if let apiErr = error as? APIError {
                    switch apiErr {
                    case .networkError, .serverError:
                         if attempt < maxAttempts {
                             let waitNs = UInt64(200_000_000 * attempt) // 0.2s, 0.4s, ...
                             print("[APIService] transient error fetching tradeticks for \(symbol) (attempt \(attempt)), retrying after \(waitNs/1_000_000)ms: \(apiErr)")
                             try? await Task.sleep(nanoseconds: waitNs)
                             continue
                         }
                     default:
                         break
                     }
                 } else {
                    // Non-APIError (e.g., URLSession) treat as transient and retry
                    if attempt < maxAttempts {
                        let waitNs = UInt64(200_000_000 * attempt)
                        print("[APIService] transient (non-API) error fetching tradeticks for \(symbol) (attempt \(attempt)), retrying after \(waitNs/1_000_000)ms: \(error)")
                        try? await Task.sleep(nanoseconds: waitNs)
                        continue
                    }
                 }

                // No retry or retries exhausted - break and propagate
                break
            }
        }

        // If we reach here, retries exhausted or non-retryable error
        if let err = lastError as? APIError {
            throw err
        }
        throw lastError ?? APIError.noData
    }

    /// Lookup listing_id for a symbol from the database
    private func getListingId(for symbol: String) async throws -> String {
        // First try the dedicated listing-id endpoint (most efficient)
        let listingIdUrl = try buildURL(path: "/stocks/\(symbol)/listing-id", base: APIConfig.mainAppURL)
        var listingIdRequest = URLRequest(url: listingIdUrl)
        listingIdRequest.httpMethod = "GET"
        addHeaders(to: &listingIdRequest)
        
        print("[APIService] getListingId(\(symbol)) - trying dedicated endpoint: \(listingIdUrl)")
        
        do {
            let listingIdData = try await performRequest(listingIdRequest)
            if let json = try? JSONSerialization.jsonObject(with: listingIdData) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let listingId = json["listing_id"] as? String {
                print("[APIService] getListingId(\(symbol)) - found via dedicated endpoint: \(listingId)")
                return listingId
            }
        } catch {
            print("[APIService] getListingId(\(symbol)) - dedicated endpoint failed: \(error), trying fallbacks...")
        }
        
        // Fallback: Try the FTSE100 endpoint which includes listing_id
        let ftse100Url = try buildURL(path: "/mobile/stocks/ftse100?limit=200", base: APIConfig.mainAppURL)
        var ftse100Request = URLRequest(url: ftse100Url)
        ftse100Request.httpMethod = "GET"
        addHeaders(to: &ftse100Request)
        
        print("[APIService] getListingId(\(symbol)) - searching in FTSE100 list")
        
        let ftse100Data = try await performRequest(ftse100Request)
        
        if let json = try? JSONSerialization.jsonObject(with: ftse100Data) as? [String: Any],
           let stocks = json["stocks"] as? [[String: Any]] {
            for stock in stocks {
                if let stockSymbol = stock["symbol"] as? String, stockSymbol.uppercased() == symbol.uppercased() {
                    if let listingId = stock["listing_id"] as? String {
                        print("[APIService] getListingId(\(symbol)) - found listing_id from FTSE100: \(listingId)")
                        return listingId
                    }
                    if let listingId = stock["listing_id"] as? Int {
                        print("[APIService] getListingId(\(symbol)) - found listing_id (int) from FTSE100: \(listingId)")
                        return String(listingId)
                    }
                }
            }
        }
        
        // Also try FTSE250
        let ftse250Url = try buildURL(path: "/mobile/stocks/ftse250?limit=300", base: APIConfig.mainAppURL)
        var ftse250Request = URLRequest(url: ftse250Url)
        ftse250Request.httpMethod = "GET"
        addHeaders(to: &ftse250Request)
        
        print("[APIService] getListingId(\(symbol)) - searching in FTSE250 list")
        
        let ftse250Data = try await performRequest(ftse250Request)
        
        if let json = try? JSONSerialization.jsonObject(with: ftse250Data) as? [String: Any],
           let stocks = json["stocks"] as? [[String: Any]] {
            for stock in stocks {
                if let stockSymbol = stock["symbol"] as? String, stockSymbol.uppercased() == symbol.uppercased() {
                    if let listingId = stock["listing_id"] as? String {
                        print("[APIService] getListingId(\(symbol)) - found listing_id from FTSE250: \(listingId)")
                        return listingId
                    }
                    if let listingId = stock["listing_id"] as? Int {
                        print("[APIService] getListingId(\(symbol)) - found listing_id (int) from FTSE250: \(listingId)")
                        return String(listingId)
                    }
                }
            }
        }
        
        print("[APIService] getListingId(\(symbol)) - listing_id not found")
        throw APIError.noData
    }
    
    /// Fetch live Infront data directly (bypasses database cache)
    /// Returns raw keyfigure data including 52-week high/low
    func getInfrontLiveData(symbol: String) async throws -> InfrontLiveData {
        // Step 1: Lookup listing_id from database via stocks endpoint
        let listingId = try await getListingId(for: symbol)
        
        print("[APIService] getInfrontLiveData(\(symbol)) - got listing_id: \(listingId)")
        
        // Step 2: Call Infront live endpoint with listing_id and specific fields for 52-week data
        let fields = "keyfigure.common.high_price_52_week,keyfigure.common.low_price_52_week,keyfigure.common.performance_1_week,keyfigure.common.performance_1_month,keyfigure.common.performance_1_year,keyfigure.common.performance_current_year,keyfigure.equity.market_capitalization,keyfigure.equity.earnings_per_share,keyfigure.equity.price_earnings_ratio,snapquote,listing.common.name"
        let url = try buildURL(path: "/stocks/\(symbol)/infront/live?listing_id=\(listingId)&fields=\(fields)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        print("[APIService] getInfrontLiveData(\(symbol)) - fetching from \(url)")
        
        let data = try await performRequest(request)
        
        // Log raw response for debugging
        if let rawStr = String(data: data, encoding: .utf8) {
            print("[APIService] getInfrontLiveData(\(symbol)) - raw response length: \(rawStr.count)")
            print("[APIService] getInfrontLiveData(\(symbol)) - raw response: \(rawStr.prefix(1000))...")
        }
        
        // Parse the Infront response - it may be wrapped in _data array or data array
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("Invalid JSON from Infront live endpoint")
        }
        
        // Log top-level keys
        print("[APIService] getInfrontLiveData(\(symbol)) - top-level keys: \(json.keys.joined(separator: ", "))")
        
        // Extract the actual data object (may be nested)
        let dataArray = json["_data"] as? [[String: Any]] ?? json["data"] as? [[String: Any]]
        let rawData: [String: Any] = dataArray?.first ?? json
        
        // Log rawData keys
        print("[APIService] getInfrontLiveData(\(symbol)) - rawData keys: \(rawData.keys.joined(separator: ", "))")
        // Check if keyfigure exists
        if let keyfigure = rawData["keyfigure"] as? [String: Any] {
            print("[APIService] getInfrontLiveData(\(symbol)) - keyfigure keys: \(keyfigure.keys.joined(separator: ", "))")
            if let common = keyfigure["common"] as? [String: Any] {
                print("[APIService] getInfrontLiveData(\(symbol)) - keyfigure.common keys: \(common.keys.joined(separator: ", "))")
                print("[APIService] getInfrontLiveData(\(symbol)) - keyfigure.common.high_price_52_week = \(common["high_price_52_week"] ?? "nil")")
                print("[APIService] getInfrontLiveData(\(symbol)) - keyfigure.common.low_price_52_week = \(common["low_price_52_week"] ?? "nil")")
            }
        }
        
        // Helper to extract nested values using dot notation
        func getValue(_ keyPath: String) -> Any? {
            let keys = keyPath.split(separator: ".").map(String.init)
            var current: Any? = rawData
            for key in keys {
                if let dict = current as? [String: Any] {
                    current = dict[key]
                } else {
                    return nil
                }
            }
            return current
        }
        
        func getDouble(_ keyPath: String) -> Double? {
            if let val = getValue(keyPath) {
                if let d = val as? Double { return d }
                if let i = val as? Int { return Double(i) }
                if let s = val as? String, let d = Double(s) { return d }
            }
            return nil
        }
        
        func getString(_ keyPath: String) -> String? {
            if let val = getValue(keyPath) {
                if let s = val as? String { return s }
            }
            return nil
        }
        
        // Extract all the fields
        let result = InfrontLiveData(
            lastPrice: getDouble("snapquote.last_price"),
            bidPrice: getDouble("snapquote.bid_price"),
            askPrice: getDouble("snapquote.ask_price"),
            openPrice: getDouble("snapquote.open_price"),
            highPrice: getDouble("snapquote.high_price"),
            lowPrice: getDouble("snapquote.low_price"),
            closePrice: getDouble("snapquote.close_price"),
            previousClosePrice: getDouble("snapquote.previous_close_price"),
            volume: getDouble("snapquote.cumulative_volume").map { Int($0) },
            high52Week: getDouble("keyfigure.common.high_price_52_week"),
            low52Week: getDouble("keyfigure.common.low_price_52_week"),
            ytdPerformance: getDouble("keyfigure.common.performance_current_year"),
            weekPerformance: getDouble("keyfigure.common.performance_1_week"),
            monthPerformance: getDouble("keyfigure.common.performance_1_month"),
            yearPerformance: getDouble("keyfigure.common.performance_1_year"),
            marketCap: getDouble("keyfigure.equity.market_capitalization"),
            eps: getDouble("keyfigure.equity.earnings_per_share"),
            peRatio: getDouble("keyfigure.equity.price_earnings_ratio"),
            dividendYield: getDouble("issuer_keyfigure.equity.dividend_yield"),
            companyName: getString("listing.common.name"),
            description: getString("company_basic.description_en")
        )
        
        print("[APIService] getInfrontLiveData(\(symbol)) - parsed: high52Week=\(result.high52Week.map { String($0) } ?? "nil"), low52Week=\(result.low52Week.map { String($0) } ?? "nil")")
        
        return result
    }
    
    /// Fetch fundamentals for a stock symbol. Returns nil if decoding fails.
    func getStockFundamentals(symbol: String) async throws -> StockFundamentals {
        let url = try buildURL(path: "/mobile/stocks/\(symbol)/fundamentals", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let data = try await performRequest(request)

        // Try multiple shapes: APIResponse.data, direct object
        if let wrapped = try? decoder.decode(APIResponse<StockFundamentals>.self, from: data), let obj = wrapped.data {
            return obj
        }
        if let direct = try? decoder.decode(StockFundamentals.self, from: data) {
            return direct
        }
        // As a last resort, try to decode a flexible dict and map keys
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Map common keys
            func dbl(_ keys: [String]) -> Double? {
                for k in keys { if let v = json[k] as? Double { return v } ; if let s = json[k] as? String, let d = Double(s) { return d } }
                return nil
            }
            // Also check Infront keyfigure.common nested structure
            let keyfigure = json["keyfigure"] as? [String: Any]
            let keyfigureCommon = keyfigure?["common"] as? [String: Any]
            func dblWithKeyfigure(_ keys: [String], keyfigureKey: String? = nil) -> Double? {
                // First try top-level keys
                if let val = dbl(keys) { return val }
                // Then try keyfigure.common
                if let kfKey = keyfigureKey, let kfVal = keyfigureCommon?[kfKey] {
                    if let d = kfVal as? Double { return d }
                    if let s = kfVal as? String, let d = Double(s) { return d }
                }
                return nil
            }
            let pe = dbl(["peRatio","pe","pe_ratio"])
            let eps = dbl(["eps","earningsPerShare","earnings_per_share"])
            let div = dbl(["dividendYield","dividend_yield"])
            let mc = dbl(["marketCap","market_cap"])
            let hi = dblWithKeyfigure(["fiftyTwoWeekHigh","52WeekHigh","fiftyTwoWeekHighRaw","high_price_52_week"], keyfigureKey: "high_price_52_week")
            let lo = dblWithKeyfigure(["fiftyTwoWeekLow","52WeekLow","fiftyTwoWeekLowRaw","low_price_52_week"], keyfigureKey: "low_price_52_week")
            let fundamentals = StockFundamentals(peRatio: pe, eps: eps, dividendYield: div, marketCap: mc, fiftyTwoWeekHigh: hi, fiftyTwoWeekLow: lo, taxonomies: nil)
            return fundamentals
        }
        throw APIError.decodingError("Unable to decode fundamentals for \(symbol)")
    }
    
    // MARK: - Portfolio (from main ShareQuest API)
    
    /// Fetch portfolio by type
    func fetchPortfolio(type: String) async throws -> PortfolioResponse {
        let url = try buildURL(path: "/mobile/portfolio/\(type)?refresh=true", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(PortfolioResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Execute a trade
    func executeTrade(portfolioType: String, symbol: String, action: String, quantity: Int) async throws -> TradeResponse {
        let url = try buildURL(path: "/mobile/portfolio/\(portfolioType)/trade", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        
        let body: [String: Any] = [
            "symbol": symbol,
            "action": action,
            "quantity": quantity
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(TradeResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Leaderboard (from main ShareQuest API)
    
    /// Fetch leaderboard
    func fetchLeaderboard(type: String) async throws -> LeaderboardResponse {
        let url = try buildURL(path: "/mobile/leaderboards/\(type)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(LeaderboardResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - User Authentication (from main ShareQuest API)
    
    /// Login user
    func login(email: String, password: String) async throws -> AuthResponse {
        let url = try buildURL(path: "/mobile/auth/login", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let data = try await performRequest(request)

        do {
            // First try the normal shape
            let response = try decoder.decode(AuthResponse.self, from: data)
            if let token = response.token {
                setAuthToken(token)
            }
            if let user = response.user {
                setUserId(user.id ?? user.username ?? "")
            }
            // If token/user were present at top-level return as-is
            if response.token != nil || response.user != nil {
                return response
            }
            // If we got here, top-level token/user were nil — fall through to flexible parsing
        } catch {
            // ignore, we'll try flexible parsing below
        }

        // Flexible fallback: some responses wrap payload under { success: true, data: { token, user } }
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let dataObj = json["data"] as? [String: Any] {
            var token: String? = nil
            var user: AuthResponse.UserData? = nil
            if let t = dataObj["token"] as? String {
                token = t
                setAuthToken(t)
            }
            if let userObj = dataObj["user"] as? [String: Any] {
                if let userData = try? JSONSerialization.data(withJSONObject: userObj),
                   let parsedUser = try? decoder.decode(AuthResponse.UserData.self, from: userData) {
                    user = parsedUser
                    setUserId(user?.id ?? user?.username ?? "")
                } else {
                    // Try to map minimal fields manually
                    let id = userObj["id"] as? String
                    let username = userObj["username"] as? String
                    let email = userObj["email"] as? String
                    let first = userObj["first_name"] as? String
                    let last = userObj["last_name"] as? String
                    user = AuthResponse.UserData(id: id, username: username, email: email, first_name: first, last_name: last, isAdmin: nil)
                    setUserId(user?.id ?? user?.username ?? "")
                }
            }
            return AuthResponse(success: json["success"] as? Bool, token: token, user: user, error: json["error"] as? String, message: json["message"] as? String)
        }

        // If nothing matched, attempt to decode and return (to surface decoding error)
        do {
            return try decoder.decode(AuthResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Register new user
    func register(email: String, username: String, password: String, firstName: String? = nil, lastName: String? = nil, dateOfBirth: String? = nil) async throws -> AuthResponse {
        let url = try buildURL(path: "/mobile/auth/register", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: String] = [
            "email": email,
            "username": username,
            "password": password
        ]
        
        if let firstName = firstName, !firstName.isEmpty {
            body["first_name"] = firstName
        }
        if let lastName = lastName, !lastName.isEmpty {
            body["last_name"] = lastName
        }
        if let dateOfBirth = dateOfBirth, !dateOfBirth.isEmpty {
            body["date_of_birth"] = dateOfBirth
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let data = try await performRequest(request)
        
        do {
            let response = try decoder.decode(AuthResponse.self, from: data)
            if let token = response.token {
                setAuthToken(token)
            }
            if let user = response.user {
                setUserId(user.id ?? user.username ?? "")
            }
            return response
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Portfolio API Response (patched)
    struct PortfolioAPIResponse: Codable {
        let success: Bool?
        let data: PortfolioDataWrapper?
        struct PortfolioDataWrapper: Codable {
            let portfolio: PortfolioResponse.PortfolioData?
            let holdings: [PortfolioResponse.HoldingData]?
        }
    }

    // MARK: - Gamification Profile API Response (patched)
    struct GamificationProfileAPIResponse: Codable {
        let success: Bool?
        let data: GamificationProfileData?
        struct GamificationProfileData: Codable {
            let totalXP: Int?
            let total_xp: Int?
            let level: Int?
            let player_level: Int?
            let levelName: String?
            let level_name: String?
            let nextLevelXP: Int?
            let next_level_xp: Int?
            let xpToNextLevel: Int?
            let xp_to_next_level: Int?
            let recentXP: [XPActivity]?
            let recent_xp: [XPActivity]?
        }
    }

    extension APIService {
        // MARK: - Patched Portfolio fetch
        func fetchPortfolioDetails(type: String) async throws -> PortfolioResponse.PortfolioData? {
            let url = try buildURL(path: "/mobile/portfolio/\(type)?refresh=true", base: APIConfig.mainAppURL)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            addHeaders(to: &request)
            let data = try await performRequest(request)
            let decoded = try decoder.decode(PortfolioAPIResponse.self, from: data)
            return decoded.data?.portfolio
        }

        // MARK: - Patched Gamification Profile fetch
        func getGamificationProfile() async throws -> GamificationProfileResponse {
            let url = try buildURL(path: "/mobile/gamification/profile", base: APIConfig.mainAppURL)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            addHeaders(to: &request)
            let data = try await performRequest(request)
            if let decoded = try? decoder.decode(GamificationProfileAPIResponse.self, from: data), let d = decoded.data {
                // Map to old GamificationProfileResponse for compatibility
                return GamificationProfileResponse(
                    success: decoded.success,
                    totalXP: d.totalXP,
                    total_xp: d.total_xp,
                    level: d.level,
                    player_level: d.player_level,
                    levelName: d.levelName,
                    level_name: d.level_name,
                    nextLevelXP: d.nextLevelXP,
                    next_level_xp: d.next_level_xp,
                    xpToNextLevel: d.xpToNextLevel,
                    xp_to_next_level: d.xp_to_next_level,
                    recentXP: d.recentXP,
                    recent_xp: d.recent_xp
                )
            }
            // fallback to old decoding for legacy/local
            return try decoder.decode(GamificationProfileResponse.self, from: data)
        }
    }
    
    // MARK: - Helpers

    func checkAPIHealth() async throws -> Bool {
        // Try multiple known-good endpoints because local and remote may expose different health routes.
        let candidates = [
            "/mobile/health",
            "/health",
            "/mobile/stocks/ftse100?limit=1"
        ]

        var lastError: Error?
        for path in candidates {
            do {
                let url = try buildURL(path: path, base: APIConfig.mainAppURL)
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                addHeaders(to: &request)

                _ = try await performRequest(request)
                return true
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        throw APIError.noData
    }

    // MARK: - Onboarding XP
    /// Record onboarding XP for the authenticated user
    func recordOnboardingXP(xp: Int) async throws -> Bool {
        let url = try buildURL(path: "/mobile/auth/onboarding-xp", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        let body: [String: Any] = ["xp": xp]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await performRequest(request)
        // Accept both { success: true } and { data: { success: true } }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let success = json["success"] as? Bool { return success }
            if let dataObj = json["data"] as? [String: Any], let success = dataObj["success"] as? Bool { return success }
        }
        return false
    }

    // MARK: - Daily Login
    /// Record daily login and return streak/xp/achievements
    func recordDailyLogin() async throws -> DailyLoginResponse {
        let url = try buildURL(path: "/mobile/auth/daily-login", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        return try decoder.decode(DailyLoginResponse.self, from: data)
    }

    // MARK: - Daily Challenges
    /// Fetch daily challenges for the user
    func getDailyChallenges() async throws -> ChallengesResponse {
        let url = try buildURL(path: "/mobile/challenges/daily", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        return try decoder.decode(ChallengesResponse.self, from: data)
    }

    // MARK: - Gamification Profile
    /// Fetch gamification profile (XP, level, activities)
    func getGamificationProfile() async throws -> GamificationProfileResponse {
        let url = try buildURL(path: "/mobile/gamification/profile", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        return try decoder.decode(GamificationProfileResponse.self, from: data)
    }

    private func buildURL(path: String, base: String) throws -> URL {
        guard var components = URLComponents(string: base) else {
            throw APIError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        let parts = normalizedPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let endpointPath = String(parts.first ?? "")
        components.path = "/" + [basePath, endpointPath].filter { !$0.isEmpty }.joined(separator: "/")

        if parts.count > 1 {
            let query = String(parts[1])
            components.percentEncodedQuery = query.isEmpty ? nil : query
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }
    
    private func addAuthHeader(to request: inout URLRequest) {
        guard let token = authToken, token.isEmpty == false else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func addHeaders(to request: inout URLRequest) {
        addAuthHeader(to: &request)
        if let userId = userId {
            request.setValue(userId, forHTTPHeaderField: "x-user-id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
#if DEBUG
        if let method = request.httpMethod, let url = request.url?.absoluteString {
            print("[APIService] \(method) \(url) env=\(APIConfig.selectedEnvironment.rawValue)")
        }
#endif

        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

#if DEBUG
        let responsePreview = String(data: data.prefix(300), encoding: .utf8) ?? "<binary>"
        print("[APIService] status=\(httpResponse.statusCode) body=\(responsePreview)")
#endif
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        default:
            let serverMessage = extractServerMessage(from: data)
            if let message = serverMessage, !message.isEmpty {
                throw APIError.serverErrorWithMessage(httpResponse.statusCode, message)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    private func extractServerMessage(from data: Data) -> String? {
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = dict["message"] as? String, !message.isEmpty { return message }
            if let error = dict["error"] as? String, !error.isEmpty { return error }
            if let detail = dict["details"] as? String, !detail.isEmpty { return detail }
        }
        if let text = String(data: data, encoding: .utf8), text.isEmpty == false {
            return text
        }
        return nil
    }
}

// MARK: - API Response Models

struct StocksResponse: Codable {
    let stocks: [StockData]?
    let success: Bool?
}

struct StockData: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let companyName: String?
    let companyname: String?
    let company_name: String?
    let sector: String?
    let price: Double?
    let current_price: Double?
    let change: Double?
    let change_amount: Double?
    let changePercent: Double?
    let change_percent: Double?
    let marketCap: Double?
    let market_cap: Double?
    let volume: Int?
    let currency: String?
    
    var displayName: String {
        companyName ?? companyname ?? company_name ?? symbol
    }
    
    // Raw pence price as returned by API (some endpoints return price in pence)
    var rawPencePrice: Double {
        return price ?? current_price ?? 0
    }

    var displayPrice: Double {
        // API returns prices in pence, convert to pounds
        let rawPrice = price ?? current_price ?? 0
        return rawPrice > 1000 ? rawPrice / 100 : rawPrice
    }
    
    var displayChange: Double {
        change ?? change_amount ?? 0
    }
    
    var displayChangePercent: Double {
        changePercent ?? change_percent ?? 0
    }
    
    var displayMarketCap: Double {
        marketCap ?? market_cap ?? 0
    }
}

/// Live data fetched directly from Infront API
struct InfrontLiveData {
    let lastPrice: Double?
    let bidPrice: Double?
    let askPrice: Double?
    let openPrice: Double?
    let highPrice: Double?
    let lowPrice: Double?
    let closePrice: Double?
    let previousClosePrice: Double?
    let volume: Int?
    let high52Week: Double?
    let low52Week: Double?
    let ytdPerformance: Double?
    let weekPerformance: Double?
    let monthPerformance: Double?
    let yearPerformance: Double?
    let marketCap: Double?
    let eps: Double?
    let peRatio: Double?
    let dividendYield: Double?
    let companyName: String?
    let description: String?
}

struct StockQuote: Decodable {
    let symbol: String
    let companyName: String?
    let quote: QuoteData?
    let profile: ProfileData?
    let fundamentals: Fundamentals?
    let performance: PerformanceData?

    // Manual initializer for fallback construction
    init(symbol: String, companyName: String?, quote: QuoteData?, profile: ProfileData?, fundamentals: Fundamentals?, performance: PerformanceData? = nil) {
        self.symbol = symbol
        self.companyName = companyName
        self.quote = quote
        self.profile = profile
        self.fundamentals = fundamentals
        self.performance = performance
    }

    // Performance data with YTD and other time periods
    struct PerformanceData: Decodable {
        let oneWeek: Double?
        let oneMonth: Double?
        let threeMonth: Double?
        let sixMonth: Double?
        let oneYear: Double?
        let ytd: Double?
        
        enum CodingKeys: String, CodingKey {
            case oneWeek, oneMonth, threeMonth, sixMonth, oneYear, ytd
            case performance_1_week, performance_1_month, performance_3_month
            case performance_6_month, performance_1_year, performance_current_year
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            oneWeek = (try? container.decodeIfPresent(Double.self, forKey: .oneWeek)) ?? (try? container.decodeIfPresent(Double.self, forKey: .performance_1_week))
            oneMonth = (try? container.decodeIfPresent(Double.self, forKey: .oneMonth)) ?? (try? container.decodeIfPresent(Double.self, forKey: .performance_1_month))
            threeMonth = (try? container.decodeIfPresent(Double.self, forKey: .threeMonth)) ?? (try? container.decodeIfPresent(Double.self, forKey: .performance_3_month))
            sixMonth = (try? container.decodeIfPresent(Double.self, forKey: .sixMonth)) ?? (try? container.decodeIfPresent(Double.self, forKey: .performance_6_month))
            oneYear = (try? container.decodeIfPresent(Double.self, forKey: .oneYear)) ?? (try? container.decodeIfPresent(Double.self, forKey: .performance_1_year))
            ytd = (try? container.decodeIfPresent(Double.self, forKey: .ytd)) ?? (try? container.decodeIfPresent(Double.self, forKey: .performance_current_year))
        }
        
        init(oneWeek: Double?, oneMonth: Double?, threeMonth: Double?, sixMonth: Double?, oneYear: Double?, ytd: Double?) {
            self.oneWeek = oneWeek
            self.oneMonth = oneMonth
            self.threeMonth = threeMonth
            self.sixMonth = sixMonth
            self.oneYear = oneYear
            self.ytd = ytd
        }
    }

    struct QuoteData: Decodable {
        let regularMarketPrice: Double?
        let regularMarketChange: Double?
        let regularMarketChangePercent: Double?
        let regularMarketVolume: Int?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?
        let longName: String?
        let bid: Double?
        let ask: Double?

        // Memberwise initializer (kept so manual construction in fallback works)
        init(regularMarketPrice: Double?, regularMarketChange: Double?, regularMarketChangePercent: Double?, regularMarketVolume: Int?, regularMarketDayHigh: Double?, regularMarketDayLow: Double?, fiftyTwoWeekHigh: Double?, fiftyTwoWeekLow: Double?, longName: String?, bid: Double? = nil, ask: Double? = nil) {
            self.regularMarketPrice = regularMarketPrice
            self.regularMarketChange = regularMarketChange
            self.regularMarketChangePercent = regularMarketChangePercent
            self.regularMarketVolume = regularMarketVolume
            self.regularMarketDayHigh = regularMarketDayHigh
            self.regularMarketDayLow = regularMarketDayLow
            self.fiftyTwoWeekHigh = fiftyTwoWeekHigh
            self.fiftyTwoWeekLow = fiftyTwoWeekLow
            self.longName = longName
            self.bid = bid
            self.ask = ask
        }

         enum CodingKeys: String, CodingKey {
             case regularMarketPrice
             case regularMarketChange
             case regularMarketChangePercent
             case regularMarketVolume
             case regularMarketDayHigh
             case regularMarketDayLow
             case fiftyTwoWeekHigh
             case fiftyTwoWeekLow
             case longName

             // Alternate keys used by mobile API
             case price
             case change
             case changePercent
             case volume
             case dayHigh
             case dayLow
             case previousClose
             case long_name
             case bid
             case ask
             
             // Infront keyfigure field names
             case high_price_52_week
             case low_price_52_week
         }

         init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            func decodeDouble(_ keys: [CodingKeys]) -> Double? {
                for k in keys {
                    if let d = try? container.decodeIfPresent(Double.self, forKey: k) { return d }
                    if let i = try? container.decodeIfPresent(Int.self, forKey: k) { return Double(i) }
                    if let s = try? container.decodeIfPresent(String.self, forKey: k), let d = Double(s) { return d }
                }
                return nil
            }
            func decodeInt(_ keys: [CodingKeys]) -> Int? {
                for k in keys {
                    if let i = try? container.decodeIfPresent(Int.self, forKey: k) { return i }
                    if let d = try? container.decodeIfPresent(Double.self, forKey: k) { return Int(d) }
                    if let s = try? container.decodeIfPresent(String.self, forKey: k), let i = Int(s) { return i }
                }
                return nil
            }

            regularMarketPrice = decodeDouble([.regularMarketPrice, .price, .previousClose])
            regularMarketChange = decodeDouble([.regularMarketChange, .change])
            regularMarketChangePercent = decodeDouble([.regularMarketChangePercent, .changePercent])
            regularMarketVolume = decodeInt([.regularMarketVolume, .volume])
            regularMarketDayHigh = decodeDouble([.regularMarketDayHigh, .dayHigh])
            regularMarketDayLow = decodeDouble([.regularMarketDayLow, .dayLow])
            fiftyTwoWeekHigh = decodeDouble([.fiftyTwoWeekHigh, .high_price_52_week])
            fiftyTwoWeekLow = decodeDouble([.fiftyTwoWeekLow, .low_price_52_week])
            longName = (try? container.decodeIfPresent(String.self, forKey: .longName)) ?? (try? container.decodeIfPresent(String.self, forKey: .long_name))
            bid = decodeDouble([.bid])
            ask = decodeDouble([.ask])
        }
    }
    
    struct ProfileData: Codable {
        let longName: String?
        let description: String?
        let sector: String?
        let sectorDisp: String?
        let industry: String?
        let country: String?
        let marketCap: Double?
    }

    // Optional fundamentals block — some API shapes include this under `fundamentals` or similar keys.
    struct Fundamentals: Codable {
        let peRatio: Double?
        let eps: Double?
        let dividendYield: Double?
        let marketCap: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Try common key names used across different API responses
            func decodeDouble(_ keys: [CodingKeys]) -> Double? {
                for k in keys {
                    if let v = try? container.decodeIfPresent(Double.self, forKey: k) { return v }
                    if let s = try? container.decodeIfPresent(String.self, forKey: k), let d = Double(s) { return d }
                }
                return nil
            }

            peRatio = decodeDouble([.peRatio, .pe_ratio, .pe])
            eps = decodeDouble([.eps, .earningsPerShare, .earnings_per_share])
            dividendYield = decodeDouble([.dividendYield, .dividend_yield])
            marketCap = decodeDouble([.marketCap, .market_cap])
        }

        // Provide Encodable implementation so this struct is Codable
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(peRatio, forKey: .peRatio)
            try container.encodeIfPresent(eps, forKey: .eps)
            try container.encodeIfPresent(dividendYield, forKey: .dividendYield)
            try container.encodeIfPresent(marketCap, forKey: .marketCap)
            try container.encodeIfPresent(fiftyTwoWeekHighRawOrAlias(), forKey: .fiftyTwoWeekHigh)
            try container.encodeIfPresent(fiftyTwoWeekLowRawOrAlias(), forKey: .fiftyTwoWeekLow)
        }

        // Helper accessors for optional 52-week fields if present under alternate keys
        private func fiftyTwoWeekHighRawOrAlias() -> Double? { return nil }
        private func fiftyTwoWeekLowRawOrAlias() -> Double? { return nil }

         enum CodingKeys: String, CodingKey {
             case peRatio = "peRatio"
             case pe_ratio = "pe_ratio"
             case pe = "pe"
             case eps = "eps"
             case earningsPerShare = "earningsPerShare"
             case earnings_per_share = "earnings_per_share"
             case dividendYield = "dividendYield"
             case dividend_yield = "dividend_yield"
             case marketCap = "marketCap"
             case market_cap = "market_cap"
             case fiftyTwoWeekHigh = "fiftyTwoWeekHigh"
             case fiftyTwoWeekHighRaw = "fiftyTwoWeekHighRaw"
             case fiftyTwoWeekLow = "fiftyTwoWeekLow"
             case fiftyTwoWeekLowRaw = "fiftyTwoWeekLowRaw"
         }
     }
}

struct PortfolioResponse: Codable {
    let portfolio: PortfolioData?
    let holdings: [HoldingData]?
    let success: Bool?
    
    struct PortfolioData: Codable {
        let id: String?
        let user_id: String?
        let portfolio_type: String?
        let cash_balance: String?
        let initial_balance: String?
        let total_value: String?
        let total_portfolio_value: String?
        let created_at: String?
        let updated_at: String?
        
        var cashBalanceValue: Double {
            // Balance is stored in pence as string
            let pence = Double(cash_balance ?? "0") ?? 0
            return pence / 100
        }
        
        var initialBalanceValue: Double {
            let pence = Double(initial_balance ?? "10000000") ?? 10000000
            return pence / 100
        }
        
        var totalPortfolioValue: Double {
            let pence = Double(total_portfolio_value ?? total_value ?? "0") ?? 0
            return pence / 100
        }
    }
    
    struct HoldingData: Codable, Identifiable {
        var id: String { symbol }
        let symbol: String
        let companyname: String?
        let company_name: String?
        let quantity: Int
        let average_price: Double
        let current_price: Double
        
        var displayName: String {
            companyname ?? company_name ?? symbol
        }
        
        var value: Double {
            Double(quantity) * current_price / 100 // Convert pence to pounds
        }
        
        var profitLoss: Double {
            Double(quantity) * (current_price - average_price) / 100
        }
        
        var profitLossPercent: Double {
            guard average_price > 0 else { return 0 }
            return ((current_price - average_price) / average_price) * 100
        }
    }
}

struct TradeResponse: Codable {
    let success: Bool
    let trade: TradeData?
    let message: String?
    let error: String?
    
    struct TradeData: Codable {
        let id: String
        let symbol: String
        let action: String
        let quantity: Int
        let price: Double
        let total_value: Double
        let timestamp: String?
    }
}

struct LeaderboardResponse: Codable {
    let leaderboard: [LeaderboardEntryData]?
    let totalParticipants: Int?
    let competition: CompetitionData?
    let success: Bool?
    
    struct LeaderboardEntryData: Codable, Identifiable {
        var id: String { user_id ?? username ?? UUID().uuidString }
        let rank: Int
        let user_id: String?
        let username: String?
        let total_portfolio_value: Double?
        let profit_loss: Double?
        let profit_loss_percent: Double?
        let cash_balance: Double?
        
        var displayValue: Double {
            // Values may be in pence
            let value = total_portfolio_value ?? 0
            return value > 100000 ? value / 100 : value
        }
        
        var displayProfitLoss: Double {
            let pl = profit_loss ?? 0
            return pl > 10000 ? pl / 100 : pl
        }
    }
    
    struct CompetitionData: Codable {
        let status: String?
        let start_date: String?
        let end_date: String?
        let prize_pool: Double?
        let time_remaining: String?
    }
}

struct AuthResponse: Codable {
    let success: Bool?
    let token: String?
    let user: UserData?
    let error: String?
    let message: String?
    
    struct UserData: Codable {
        let id: String?
        let username: String?
        let email: String?
        let first_name: String?
        let last_name: String?
        let isAdmin: Bool?
    }
}

struct UserProfile: Codable {
    let id: String?
    let username: String?
    let email: String?
    let first_name: String?
    let last_name: String?
    let isAdmin: Bool?
    let created_at: String?
}

// MARK: - Dashboard Response Models

struct DashboardResponse: Codable {
    let success: Bool?
    let marketSentiment: MarketSentimentData?
    let market_sentiment: MarketSentimentData?
    let userSubscriptions: UserSubscriptionsData?
    let user_subscriptions: UserSubscriptionsData?
    let subscriptions: UserSubscriptionsData?
    
    var sentiment: MarketSentimentData? {
        marketSentiment ?? market_sentiment
    }
    
    var subs: UserSubscriptionsData? {
        userSubscriptions ?? user_subscriptions ?? subscriptions
    }
}

struct MarketSentimentData: Codable {
    let overall: OverallSentiment?
    let metrics: SentimentMetrics?
    let topGainers: [SentimentStock]?
    let topLosers: [SentimentStock]?
    
    struct OverallSentiment: Codable {
        let score: Double?
        let sentiment: String? // bullish, neutral, bearish
        let direction: String? // up, down, sideways
    }
    
    struct SentimentMetrics: Codable {
        let gainerCount: Int?
        let loserCount: Int?
    }
    
    struct SentimentStock: Codable, Identifiable {
        var id: String { symbol }
        let symbol: String
        let name: String?
        let price: Double?
        let changePercent: Double?
    }
}

struct UserSubscriptionsData: Codable {
    let weekly: Bool?
    let monthly: Bool?
    let annual: Bool?
    let `default`: Bool? // always true for practice
}

// MARK: - Gamification Response Models

struct GamificationProfileResponse: Codable {
    let success: Bool?
    let totalXP: Int?
    let total_xp: Int?
    let level: Int?
    let player_level: Int?
    let levelName: String?
    let level_name: String?
    let nextLevelXP: Int?
    let next_level_xp: Int?
    let xpToNextLevel: Int?
    let xp_to_next_level: Int?
    let recentXP: [XPActivity]?
    let recent_xp: [XPActivity]?
    
    var xp: Int { totalXP ?? total_xp ?? 0 }
    var playerLevel: Int { level ?? player_level ?? 1 }
    var playerLevelName: String { levelName ?? level_name ?? "Rookie" }
    var xpForNextLevel: Int { nextLevelXP ?? next_level_xp ?? 100 }
    var xpNeeded: Int { xpToNextLevel ?? xp_to_next_level ?? 100 }
    var xpActivities: [XPActivity] { recentXP ?? recent_xp ?? [] }
}

struct XPActivity: Codable, Identifiable {
    var id: String { "\(source)_\(created_at ?? "")" }
    let source: String
    let amount: Int
    let description: String?
    let created_at: String?
}

struct DailyLoginResponse: Codable {
    let success: Bool?
    let currentStreak: Int?
    let current_streak: Int?
    let xpAwarded: Int?
    let xp_awarded: Int?
    let newAchievements: [AchievementData]?
    let new_achievements: [AchievementData]?
    
    var streak: Int { currentStreak ?? current_streak ?? 0 }
    var xp: Int { xpAwarded ?? xp_awarded ?? 0 }
    var achievements: [AchievementData] { newAchievements ?? new_achievements ?? [] }
}

struct ChallengesResponse: Codable {
    let success: Bool?
    let challenges: [ChallengeData]?
    let daily_challenges: [ChallengeData]?
    
    var allChallenges: [ChallengeData] { challenges ?? daily_challenges ?? [] }
}

struct ChallengeData: Codable, Identifiable {
    let id: String?
    let challenge_id: String?
    let title: String?
    let description: String?
    let xp_reward: Int?
    let xpReward: Int?
    let progress: Int?
    let target: Int?
    let completed: Bool?
    let type: String?
    let criteria_type: String?
    
    var challengeId: String { id ?? challenge_id ?? UUID().uuidString }
    var reward: Int { xp_reward ?? xpReward ?? 0 }
    var isCompleted: Bool { completed ?? false }
    var currentProgress: Int { progress ?? 0 }
    var targetProgress: Int { target ?? 1 }
    var progressPercent: Double {
        guard targetProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetProgress), 1.0)
    }
}

struct AchievementsResponse: Codable {
    let success: Bool?
    let achievements: [AchievementData]?
    let unlocked: [AchievementData]?
    let locked: [AchievementData]?
    
    var allAchievements: [AchievementData] { achievements ?? [] }
    var unlockedAchievements: [AchievementData] { unlocked ?? [] }
    var lockedAchievements: [AchievementData] { locked ?? [] }
}

struct AchievementData: Codable, Identifiable {
    let id: String?
    let achievement_id: String?
    let name: String?
    let title: String?
    let description: String?
    let icon: String?
    let emoji: String?
    let xp_reward: Int?
    let xpReward: Int?
    let unlocked: Bool?
    let unlocked_at: String?
    
    var achievementId: String { id ?? achievement_id ?? UUID().uuidString }
    var displayName: String { name ?? title ?? "Achievement" }
    var displayIcon: String { emoji ?? icon ?? "🏆" }
    var reward: Int { xp_reward ?? xpReward ?? 0 }
    var isUnlocked: Bool { unlocked ?? false }
}

/// Trade tick row returned by /api/tradeticks
struct TradeTick: Decodable, Identifiable {
    let timestamp: String
    let tradePrice: Double
    let tradeVolume: Double

    var id: String { "\(timestamp)-\(tradePrice)-\(tradeVolume)" }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case tradePrice = "trade_price"
        case tradeVolume = "trade_volume"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = (try? container.decode(String.self, forKey: .timestamp)) ?? ""

        func decodeNumber(_ key: CodingKeys) -> Double {
            if let d = try? container.decode(Double.self, forKey: key) { return d }
            if let i = try? container.decode(Int.self, forKey: key) { return Double(i) }
            if let s = try? container.decode(String.self, forKey: key), let d = Double(s) { return d }
            return 0
        }

        tradePrice = decodeNumber(.tradePrice)
        tradeVolume = decodeNumber(.tradeVolume)
    }
}

struct StockFundamentals: Decodable {
    let peRatio: Double?
    let eps: Double?
    let dividendYield: Double?
    let marketCap: Double?
    let fiftyTwoWeekHigh: Double?
    let fiftyTwoWeekLow: Double?
    let taxonomies: [String: AnyDecodable]?

    enum CodingKeys: String, CodingKey {
        case peRatio = "peRatio"
        case pe = "pe"
        case pe_ratio = "pe_ratio"
        case eps = "eps"
        case earningsPerShare = "earningsPerShare"
        case earnings_per_share = "earnings_per_share"
        case dividendYield = "dividendYield"
        case dividend_yield = "dividend_yield"
        case marketCap = "marketCap"
        case market_cap = "market_cap"
        case fiftyTwoWeekHigh = "fiftyTwoWeekHigh"
        case fiftyTwoWeekLow = "fiftyTwoWeekLow"
        case fiftyTwoWeekHighRaw = "fiftyTwoWeekHighRaw"
        case fiftyTwoWeekLowRaw = "fiftyTwoWeekLowRaw"
        case taxonomies = "taxonomies"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func decodeDouble(keys: [CodingKeys]) -> Double? {
            for k in keys {
                if let v = try? container.decodeIfPresent(Double.self, forKey: k) { return v }
                if let s = try? container.decodeIfPresent(String.self, forKey: k), let d = Double(s) { return d }
            }
            return nil
        }
        peRatio = decodeDouble(keys: [.peRatio, .pe, .pe_ratio])
        eps = decodeDouble(keys: [.eps, .earningsPerShare, .earnings_per_share])
        dividendYield = decodeDouble(keys: [.dividendYield, .dividend_yield])
        marketCap = decodeDouble(keys: [.marketCap, .market_cap])
        fiftyTwoWeekHigh = decodeDouble(keys: [.fiftyTwoWeekHigh, .fiftyTwoWeekHighRaw])
        fiftyTwoWeekLow = decodeDouble(keys: [.fiftyTwoWeekLow, .fiftyTwoWeekLowRaw])
        taxonomies = try? container.decodeIfPresent([String: AnyDecodable].self, forKey: .taxonomies)
    }

    init(peRatio: Double?, eps: Double?, dividendYield: Double?, marketCap: Double?, fiftyTwoWeekHigh: Double?, fiftyTwoWeekLow: Double?, taxonomies: [String: AnyDecodable]?) {
        self.peRatio = peRatio
        self.eps = eps
        self.dividendYield = dividendYield
        self.marketCap = marketCap
        self.fiftyTwoWeekHigh = fiftyTwoWeekHigh
        self.fiftyTwoWeekLow = fiftyTwoWeekLow
        self.taxonomies = taxonomies
    }
}

// Small helper to decode arbitrary JSON values into Swift types for flexible taxonomies
struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intV = try? container.decode(Int.self) { value = intV; return }
        if let dblV = try? container.decode(Double.self) { value = dblV; return }
        if let strV = try? container.decode(String.self) { value = strV; return }
        if let boolV = try? container.decode(Bool.self) { value = boolV; return }
        if let arr = try? container.decode([AnyDecodable].self) { value = arr.map { $0.value }; return }
        if let dict = try? container.decode([String: AnyDecodable].self) { value = dict.mapValues { $0.value }; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
    }
}
