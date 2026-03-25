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
            UserDefaults.standard.string(forKey: "api_remote_base_url") ?? "https://www.sharequest.co.uk/api"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "api_remote_base_url")
        }
    }

    static var selectedEnvironment: Environment {
        get {
#if targetEnvironment(simulator)
            // Simulator: respect any stored preference, default to local
            if let raw = UserDefaults.standard.string(forKey: selectedEnvironmentKey),
               let env = Environment(rawValue: raw) {
                return env
            }
            return .local
#else
            // Physical device: always remote — stored value is ignored
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
    
    /// Public alias used by AuthManager OAuth flow
    func saveToken(_ token: String) { setAuthToken(token) }

    struct OAuthTokenResult {
        let token: String
        let userId: String
        let username: String
        let email: String
        let firstName: String?
        let lastName: String?
    }

    func signInWithApple(identityToken: String, email: String?, firstName: String?, lastName: String?, appleUserId: String) async throws -> OAuthTokenResult {
        let url = try buildURL(path: "/mobile/auth/apple", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["identityToken": identityToken, "appleUserId": appleUserId]
        if let email    { body["email"]     = email }
        if let firstName { body["firstName"] = firstName }
        if let lastName  { body["lastName"]  = lastName }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = json["data"] as? [String: Any],
              let token = d["token"] as? String,
              let user = d["user"] as? [String: Any] else {
            throw APIError.decodingError("Invalid Apple sign-in response")
        }
        setAuthToken(token)
        let uid = user["id"] as? String ?? ""
        setUserId(uid)
        return OAuthTokenResult(
            token: token, userId: uid,
            username: user["username"] as? String ?? "",
            email: user["email"] as? String ?? "",
            firstName: user["first_name"] as? String,
            lastName: user["last_name"] as? String
        )
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
    
    /// Fetch trade ticks via the mobile JWT-authenticated endpoint.
    /// Falls back to the legacy /tradeticks path if the mobile path returns 404.
    func fetchMobileTradeTicks(symbol: String, date: String? = nil) async throws -> [TradeTick] {
        let day: String = {
            if let date { return date }
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        let mobilePath = "/mobile/stocks/\(symbol)/tradeticks?date=\(day)"
        let url = try buildURL(path: mobilePath, base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        do {
            let data = try await performRequest(request)
            if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = root["data"] as? [[String: Any]] {
                let arrData = try JSONSerialization.data(withJSONObject: arr)
                if let decoded = try? decoder.decode([TradeTick].self, from: arrData) { return decoded }
            }
            if let decoded = try? decoder.decode([TradeTick].self, from: data) { return decoded }
            throw APIError.decodingError("Unable to decode mobile tradeticks response")
        } catch let apiErr as APIError {
            // If mobile endpoint doesn't exist yet, fall back to legacy path
            if case .serverError(let code) = apiErr, code == 404 {
                return try await fetchTradeTicks(symbol: symbol, date: day)
            }
            throw apiErr
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
        
        // Try to decode from "data" key if present
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let dataObj = json["data"] {
            let dataData = try JSONSerialization.data(withJSONObject: dataObj)
            return try decoder.decode(PortfolioResponse.self, from: dataData)
        } else {
            return try decoder.decode(PortfolioResponse.self, from: data)
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
    
    /// Fetch all top-level sectors  GET /stocks/sectors
    func fetchSectors() async throws -> [SectorItem] {
        let url = try buildURL(path: "/stocks/sectors", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.decodingError("Bad JSON") }
        let payload = (json["data"] as? [String: Any]) ?? json
        let raw = payload["sectors"] as? [[String: Any]] ?? []
        return raw.compactMap { d -> SectorItem? in
            guard let s = d["sector"] as? String else { return nil }
            let count = (d["stock_count"] as? Int) ?? (d["count"] as? Int) ?? 0
            return SectorItem(sector: s, count: count, stock_count: count)
        }
    }

    /// Fetch subsectors for a sector  GET /stocks/sectors?sector=...
    func fetchSubsectors(sector: String) async throws -> [SubsectorItem] {
        let encoded = sector.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sector
        let url = try buildURL(path: "/stocks/sectors?sector=\(encoded)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.decodingError("Bad JSON") }
        let payload = (json["data"] as? [String: Any]) ?? json
        let raw = payload["subsectors"] as? [[String: Any]] ?? []
        return raw.compactMap { d -> SubsectorItem? in
            guard let name = d["subsector"] as? String else { return nil }
            let count = (d["stock_count"] as? Int) ?? (d["count"] as? Int) ?? 0
            let stocksRaw = d["stocks"] as? [[String: Any]] ?? []
            let stocks = stocksRaw.compactMap { s -> SubsectorStock? in
                guard let sym = s["symbol"] as? String else { return nil }
                return SubsectorStock(symbol: sym, companyname: s["companyname"] as? String, listing_id: s["listing_id"] as? String)
            }
            return SubsectorItem(subsector: name, count: count, stock_count: count, stocks: stocks)
        }
    }

    /// Batch stock prices  POST /mobile/stocks/batch-prices
    func fetchBatchPrices(symbols: [String]) async throws -> [String: BatchPriceData] {
        let url = try buildURL(path: "/mobile/stocks/batch-prices", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["symbols": symbols])
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        let payload = (json["data"] as? [String: Any]) ?? json
        var result: [String: BatchPriceData] = [:]
        for (symbol, value) in payload {
            guard let d = value as? [String: Any] else { continue }
            let price = (d["price"] as? Double) ?? (d["current_price"] as? Double)
            let change = (d["change"] as? Double) ?? (d["change_amount"] as? Double)
            let changePct = (d["changePercent"] as? Double) ?? (d["change_percent"] as? Double)
            result[symbol] = BatchPriceData(price: price, change: change, changePercent: changePct)
        }
        return result
    }

    /// Fetch trading window status (market open / after-hours / pre-market / weekend)
    func fetchTradingWindow() async throws -> TradingWindowData {
        let url = try buildURL(path: "/mobile/trading-window", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        let resp = try decoder.decode(TradingWindowResponse.self, from: data)
        guard let window = resp.data?.tradingWindow else {
            // Default to market open if response shape is unexpected
            return TradingWindowData(type: "market_open", canTradeImmediately: true, canCreatePendingOrder: false, executionPrice: "live", message: "Market is open.")
        }
        return window
    }

    /// Execute a trade via the mobile trade endpoint (POST /mobile/trade)
    func executeMobileTrade(portfolioType: String, symbol: String, companyName: String, action: String, quantity: Int, price: Double) async throws -> MobileTradeResponse {
        let url = try buildURL(path: "/mobile/trade", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        let body: [String: Any] = [
            "symbol": symbol,
            "quantity": quantity,
            "price": price,
            "action": action,
            "portfolioType": portfolioType,
            "companyName": companyName
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await performRequest(request)
        do {
            return try decoder.decode(MobileTradeResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Leaderboard (from main ShareQuest API)
    
    /// Fetch leaderboard
    func fetchLeaderboard(type: String) async throws -> LeaderboardResponse {
        // Use correct endpoint: /api/leaderboards/{type}
        let url = try buildURL(path: "/leaderboards/\(type)", base: APIConfig.mainAppURL)
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

    /// Fetch a specific user's portfolio for a leaderboard competition
    func fetchLeaderboardUserPortfolio(type: String, userId: String) async throws -> LeaderboardUserPortfolio {
        let encodedId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        let url = try buildURL(path: "/mobile/leaderboard/\(type)/user/\(encodedId)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let data = try await performRequest(request)

        // Parse flexible shape
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("Invalid JSON")
        }
        let payload = (json["data"] as? [String: Any]) ?? json
        let cashBalance = (payload["cash_balance"] as? Double) ?? 0
        let rank = payload["rank"] as? Int

        var holdings: [LeaderboardUserPortfolio.Holding] = []
        if let raw = payload["holdings"] as? [[String: Any]] {
            holdings = raw.compactMap { h in
                guard let symbol = h["symbol"] as? String else { return nil }
                let qty = (h["quantity"] as? Double) ?? (h["quantity"] as? Int).map(Double.init) ?? 0
                let avgPrice = (h["average_price"] as? Double) ?? (h["avg_price"] as? Double) ?? 0
                let curPrice = (h["current_price"] as? Double) ?? (h["mid_price"] as? Double) ?? (h["mid"] as? Double) ?? 0
                let name = (h["company_name"] as? String) ?? (h["name"] as? String)
                return LeaderboardUserPortfolio.Holding(
                    symbol: symbol,
                    companyName: name,
                    quantity: qty,
                    averagePrice: avgPrice,
                    currentPrice: curPrice
                )
            }
        }
        return LeaderboardUserPortfolio(rank: rank, cashBalance: cashBalance, holdings: holdings)
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
    func register(email: String, username: String, password: String, firstName: String? = nil, lastName: String? = nil, dateOfBirth: String? = nil, ageConfirmed: Bool = false) async throws -> AuthResponse {
        let url = try buildURL(path: "/mobile/auth/register", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "email": email,
            "username": username,
            "password": password,
            "age_confirmed": ageConfirmed
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
    
    // MARK: - User Profile
    /// Fetch the current user's profile ("me")
    func getProfile() async throws -> UserProfile {
        let url = try buildURL(path: "/mobile/auth/me", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        // Try to decode as UserProfile directly, or wrapped in { data: UserProfile }
        if let wrapped = try? decoder.decode(APIResponse<UserProfile>.self, from: data), let user = wrapped.data {
            return user
        }
        return try decoder.decode(UserProfile.self, from: data)
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
            let currentStreak: Int?
            let current_streak: Int?
            let longestStreak: Int?
            let longest_streak: Int?
            // Each element may be a bare AchievementData or wrapped as { achievement: {...}, unlocked, unlocked_at }
            let achievements: [AchievementWrapper]?

            var flatAchievements: [AchievementData] {
                achievements?.map { $0.resolved } ?? []
            }
        }
        // Wrapper handles both { achievement: { id, name, ... }, unlocked, unlocked_at } and direct AchievementData
        struct AchievementWrapper: Codable {
            let achievement: AchievementData?
            // direct fields present when not wrapped
            let id: Int?
            let name: String?
            let unlocked: Bool?
            let unlocked_at: String?

            var resolved: AchievementData {
                if let a = achievement {
                    // Merge unlocked status from the outer wrapper if the inner object didn't have it
                    if a.unlocked == nil, let u = unlocked {
                        return AchievementData(copying: a, unlocked: u, unlocked_at: unlocked_at)
                    }
                    return a
                }
                // Already a flat AchievementData shape — re-encode and decode
                if let encoded = try? JSONEncoder().encode(self),
                   let decoded = try? JSONDecoder().decode(AchievementData.self, from: encoded) {
                    return decoded
                }
                return AchievementData(id: id, name: name, unlocked: unlocked, unlocked_at: unlocked_at)
            }
        }
    }

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

    // MARK: - Patched Gamification Profile API fetch
    func getGamificationProfile() async throws -> GamificationProfileResponse {
        let url = try buildURL(path: "/mobile/gamification/profile", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let decoded = try? decoder.decode(GamificationProfileAPIResponse.self, from: data), let d = decoded.data {
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
                recent_xp: d.recent_xp,
                currentStreak: d.currentStreak ?? d.current_streak,
                longestStreak: d.longestStreak ?? d.longest_streak,
                achievements: d.flatAchievements
            )
        }
        // fallback to old decoding for legacy/local
        return try decoder.decode(GamificationProfileResponse.self, from: data)
    }
    
    // MARK: - Dashboard Data
    /// Fetch dashboard data (market sentiment, etc.)
    func fetchDashboard() async throws -> DashboardResponse {
        let url = try buildURL(path: "/mobile/dashboard", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        // Decode as APIResponse<DashboardData> for new API shape
        if let decoded = try? decoder.decode(APIResponse<DashboardData>.self, from: data) {
            return DashboardResponse(
                success: decoded.success,
                data: decoded.data,
                marketSentiment: nil,
                market_sentiment: nil,
                userSubscriptions: nil,
                user_subscriptions: nil,
                subscriptions: decoded.data?.subscriptions
            )
        }
        // fallback to old decoding for legacy/local
        return try decoder.decode(DashboardResponse.self, from: data)
    }

    // MARK: - User Subscriptions
    /// Fetch user subscriptions (weekly, monthly, etc.)
    func fetchUserSubscriptions() async throws -> UserSubscriptionsResponse? {
        let url = try buildURL(path: "/mobile/subscriptions", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        // Always unwrap envelope — direct decode would succeed with all-nil since fields are optional
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // API returns { success, subscriptions: { weekly, monthly, annual } }
            // Fall back to data or top-level for other shapes
            let payload = (json["subscriptions"] as? [String: Any])
                       ?? (json["data"] as? [String: Any])
                       ?? json
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            if let decoded = try? decoder.decode(UserSubscriptionsResponse.self, from: payloadData),
               decoded.weekly != nil || decoded.monthly != nil || decoded.annual != nil {
                return decoded
            }
        }
        return nil
    }

    /// Fetch competition options for a subscription plan
    func fetchSubscriptionOptions(plan: String) async throws -> SubscriptionOptionsResponse {
        let url = try buildURL(path: "/subscriptions/options?plan=\(plan)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let decoded = try? decoder.decode(SubscriptionOptionsResponse.self, from: data) { return decoded }
        return SubscriptionOptionsResponse(current: nil, next: nil, plan: plan)
    }

    /// Fetch all active subscription details (for manage screen)
    func fetchActiveSubscriptions() async throws -> [ActiveSubscription] {
        let url = try buildURL(path: "/subscriptions", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let payload = (json["data"] as? [String: Any]) ?? json
            if let arr = payload["subscriptions"] as? [[String: Any]] {
                let arrData = try JSONSerialization.data(withJSONObject: arr)
                return (try? decoder.decode([ActiveSubscription].self, from: arrData)) ?? []
            }
        }
        return (try? decoder.decode([ActiveSubscription].self, from: data)) ?? []
    }

    /// Create a Revolut payment order
    func createRevolutOrder(plan: String, amount: Int, competitionChoice: String) async throws -> RevolutOrderResponse {
        let url = try buildURL(path: "/payments/create-revolut-order", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        let body: [String: Any] = ["plan": plan, "amount": amount, "competitionChoice": competitionChoice]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await performRequest(request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let payload = (json["data"] as? [String: Any]) ?? json
            let publicId = payload["publicId"] as? String ?? payload["public_id"] as? String ?? ""
            let checkoutUrl = payload["checkoutUrl"] as? String ?? payload["checkout_url"] as? String ?? ""
            let orderId = payload["orderId"] as? String ?? payload["order_id"] as? String ?? ""
            return RevolutOrderResponse(publicId: publicId, checkoutUrl: checkoutUrl, orderId: orderId)
        }
        throw APIError.decodingError("Invalid Revolut order response")
    }

    /// Verify payment status for a plan
    func verifyPaymentStatus(plan: String) async throws -> PaymentVerifyResponse {
        let url = try buildURL(path: "/payments/verify-status?plan=\(plan)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let payload = (json["data"] as? [String: Any]) ?? json
            let paid = payload["paid"] as? Bool ?? payload["success"] as? Bool ?? false
            let status = payload["status"] as? String ?? (paid ? "paid" : "pending")
            return PaymentVerifyResponse(paid: paid, status: status)
        }
        return PaymentVerifyResponse(paid: false, status: "unknown")
    }

    /// Activate a subscription after successful payment
    func activateSubscription(plan: String, choice: String) async throws {
        let url = try buildURL(path: "/subscriptions/activate", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        let body: [String: Any] = ["plan": plan, "choice": choice]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performRequest(request)
    }

    /// Cancel a subscription
    func cancelSubscription(plan: String) async throws {
        let url = try buildURL(path: "/subscriptions/cancel", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        let body: [String: Any] = ["plan": plan]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performRequest(request)
    }

    /// Fetch auto-renew settings
    func fetchAutoRenewSettings() async throws -> AutoRenewSettings {
        let url = try buildURL(path: "/subscriptions/auto-renew", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let decoded = try? decoder.decode(AutoRenewSettings.self, from: data) { return decoded }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let payload = (json["data"] as? [String: Any]) ?? json
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            if let decoded = try? decoder.decode(AutoRenewSettings.self, from: payloadData) { return decoded }
        }
        return AutoRenewSettings(weekly: false, monthly: false, annual: false)
    }

    /// Update auto-renew for a plan
    func updateAutoRenew(plan: String, enabled: Bool) async throws {
        let url = try buildURL(path: "/subscriptions/auto-renew", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        let body: [String: Any] = ["plan": plan, "autoRenew": enabled]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performRequest(request)
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
        let url = try buildURL(path: "/mobile/gamification/login", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        return try decoder.decode(DailyLoginResponse.self, from: data)
    }

    /// Fetch user's leagues count
    func fetchLeaguesCount() async -> Int {
        guard let url = try? buildURL(path: "/mobile/leagues", base: APIConfig.mainAppURL) else { return 0 }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        guard let data = try? await performRequest(request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return 0 }
        let payload = (json["data"] as? [String: Any]) ?? json
        let leagues = payload["myLeagues"] as? [Any] ?? payload["leagues"] as? [Any] ?? []
        return leagues.count
    }

    /// Fetch public leagues (discover tab / subscriptions page)
    func fetchPublicLeagues() async throws -> [League] {
        // Public/discover leagues are returned from the same /mobile/leagues endpoint
        // under the "discoverLeagues" key
        let url = try buildURL(path: "/mobile/leagues", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let payload = (json["data"] as? [String: Any]) ?? json
            let arr = payload["discoverLeagues"] as? [[String: Any]]
                   ?? payload["publicLeagues"] as? [[String: Any]]
                   ?? []
            if arr.isEmpty { return [] }
            let arrData = try JSONSerialization.data(withJSONObject: arr)
            return (try? decoder.decode([League].self, from: arrData)) ?? []
        }
        return []
    }

    /// Fetch user's leagues list
    func fetchUserLeagues() async throws -> [League] {
        let url = try buildURL(path: "/mobile/leagues", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        // Response may be array directly or wrapped in data.myLeagues
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let payload = (json["data"] as? [String: Any]) ?? json
            // Try to extract array from myLeagues or leagues key
            if let arr = payload["myLeagues"] as? [[String: Any]] ?? payload["leagues"] as? [[String: Any]] {
                let arrData = try JSONSerialization.data(withJSONObject: arr)
                return try decoder.decode([League].self, from: arrData)
            }
            // Maybe data itself is the array
            if let arr = json["data"] as? [[String: Any]] {
                let arrData = try JSONSerialization.data(withJSONObject: arr)
                return try decoder.decode([League].self, from: arrData)
            }
        }
        // Try decoding as array directly
        return (try? decoder.decode([League].self, from: data)) ?? []
    }

    /// Fetch league members/leaderboard
    func fetchNotifications() async throws -> [AppNotification] {
        let url = try buildURL(path: "/mobile/notifications", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = (json["data"] as? [String: Any])?["notifications"] as? [[String: Any]] {
            let arrData = try JSONSerialization.data(withJSONObject: arr)
            return (try? decoder.decode([AppNotification].self, from: arrData)) ?? []
        }
        return []
    }

    func markNotificationsRead() async throws {
        let url = try buildURL(path: "/mobile/notifications/read", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        _ = try? await performRequest(request)
    }

    func sendFeedback(category: String, subject: String, message: String) async throws {
        let url = try buildURL(path: "/mobile/feedback", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        let body: [String: Any] = ["category": category, "subject": subject, "message": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performRequest(request)
    }

    func fetchLeagueMembers(leagueId: String) async throws -> [LeagueMember] {
        let url = try buildURL(path: "/mobile/leagues/\(leagueId)/members", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let payload = (json["data"] as? [String: Any]) ?? json
            if let arr = payload["members"] as? [[String: Any]] {
                let arrData = try JSONSerialization.data(withJSONObject: arr)
                return try decoder.decode([LeagueMember].self, from: arrData)
            }
            if let arr = json["data"] as? [[String: Any]] {
                let arrData = try JSONSerialization.data(withJSONObject: arr)
                return try decoder.decode([LeagueMember].self, from: arrData)
            }
        }
        return (try? decoder.decode([LeagueMember].self, from: data)) ?? []
    }

    /// Fetch a league member's portfolio (league-specific, not their main annual/monthly)
    func fetchLeagueMemberPortfolio(leagueId: String, memberId: String) async throws -> LeaderboardUserPortfolio {
        let path = "/mobile/leagues/\(leagueId)/portfolio?memberId=\(memberId)"
        let url = try buildURL(path: path, base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("Invalid JSON")
        }
        let cashBalance = (json["portfolio"] as? [String: Any]).flatMap { $0["cash_balance"] as? Double } ?? 0
        var holdings: [LeaderboardUserPortfolio.Holding] = []
        if let raw = json["holdings"] as? [[String: Any]] {
            holdings = raw.compactMap { h in
                guard let symbol = h["symbol"] as? String else { return nil }
                let qty = (h["quantity"] as? Double) ?? (h["quantity"] as? Int).map(Double.init) ?? 0
                let avgPrice = (h["average_price"] as? Double) ?? 0
                let curPrice = (h["mid"] as? Double) ?? (h["mid_price"] as? Double) ?? (h["current_price"] as? Double) ?? 0
                let name = (h["companyname"] as? String) ?? (h["company_name"] as? String)
                return LeaderboardUserPortfolio.Holding(
                    symbol: symbol, companyName: name,
                    quantity: qty, averagePrice: avgPrice, currentPrice: curPrice
                )
            }
        }
        return LeaderboardUserPortfolio(rank: nil, cashBalance: cashBalance, holdings: holdings)
    }

    /// Create a new league
    struct CreateLeagueResult {
        let id: String
        let name: String
        let code: String
        let entryFeePence: Int
        let requiresPayment: Bool
    }

    func createLeague(name: String, description: String, isPrivate: Bool, competitionType: String, endDate: Date? = nil) async throws -> CreateLeagueResult {
        let url = try buildURL(path: "/mobile/leagues", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "name": name,
            "description": description,
            "is_private": isPrivate,
            "competitionType": competitionType
        ]
        if let endDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            body["endDate"] = formatter.string(from: endDate)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let id = dataObj["id"] as? String else {
            throw APIError.decodingError("Failed to decode create league response")
        }
        return CreateLeagueResult(
            id: id,
            name: dataObj["name"] as? String ?? name,
            code: dataObj["code"] as? String ?? "",
            entryFeePence: dataObj["entryFeePence"] as? Int ?? 0,
            requiresPayment: dataObj["requiresPayment"] as? Bool ?? false
        )
    }

    struct LeaguePaymentResult {
        let checkoutUrl: String
        let amountFormatted: String
        let leagueName: String
    }

    func createLeaguePayment(leagueId: String) async throws -> LeaguePaymentResult {
        let url = try buildURL(path: "/mobile/leagues/\(leagueId)/payment", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let checkoutUrl = dataObj["checkoutUrl"] as? String else {
            throw APIError.decodingError("Failed to decode payment response")
        }
        return LeaguePaymentResult(
            checkoutUrl: checkoutUrl,
            amountFormatted: dataObj["amountFormatted"] as? String ?? "",
            leagueName: dataObj["leagueName"] as? String ?? ""
        )
    }

    func checkSubscriptionStatus(plan: String) async throws -> Bool {
        let url = try buildURL(path: "/mobile/subscriptions/status?plan=\(plan)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else { return false }
        return dataObj["isPaid"] as? Bool ?? false
    }

    func createSubscriptionOrder(plan: String) async throws -> RevolutOrderResponse {
        let url = try buildURL(path: "/mobile/subscriptions/create-order", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["plan": plan])
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else {
            throw APIError.decodingError("Failed to decode subscription order response")
        }
        let publicId = dataObj["publicId"] as? String ?? dataObj["public_id"] as? String ?? ""
        let checkoutUrl = dataObj["checkoutUrl"] as? String ?? dataObj["checkout_url"] as? String ?? ""
        let orderId = dataObj["orderId"] as? String ?? dataObj["order_id"] as? String ?? ""
        return RevolutOrderResponse(publicId: publicId, checkoutUrl: checkoutUrl, orderId: orderId)
    }

    func confirmApplePayment(orderId: String, plan: String, applePayTokenData: Data) async throws -> Bool {
        let url = try buildURL(path: "/mobile/subscriptions/confirm-apple-pay", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        // Decode Apple Pay token from JSON data to pass as object
        guard let tokenJSON = try? JSONSerialization.jsonObject(with: applePayTokenData) else {
            throw APIError.decodingError("Invalid Apple Pay token data")
        }
        let body: [String: Any] = ["orderId": orderId, "plan": plan, "applePayToken": tokenJSON]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else { return false }
        return dataObj["paid"] as? Bool ?? false
    }

    func getStockHistory(symbol: String, period: Int = 30) async throws -> [PricePoint] {
        let url = try buildURL(path: "/mobile/stocks/\(symbol)/history?period=\(period)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = json["data"] as? [String: Any],
           let quotes = dataObj["quotes"] as? [[String: Any]] {
            let quotesData = try JSONSerialization.data(withJSONObject: quotes)
            return (try? JSONDecoder().decode([PricePoint].self, from: quotesData)) ?? []
        }
        return []
    }

    func checkLeaguePaymentStatus(leagueId: String) async throws -> Bool {
        let url = try buildURL(path: "/mobile/leagues/\(leagueId)/status", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else { return false }
        return dataObj["isPaid"] as? Bool ?? false
    }

    /// Join a league by code
    func joinLeagueByCode(code: String) async throws {
        let url = try buildURL(path: "/mobile/leagues/join/\(code)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        _ = try await performRequest(request)
    }

    // MARK: - Daily Challenges
    /// Fetch daily challenges for the user
    func getDailyChallenges() async throws -> ChallengesResponse {
        let url = try buildURL(path: "/mobile/gamification/challenges", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        return try decoder.decode(ChallengesResponse.self, from: data)
    }

    /// Fetch today's stock hunt challenge detail (name, description, hint, difficulty, matching count)
    func getStockHuntChallenge() async throws -> StockHuntChallengeResponse {
        let url = try buildURL(path: "/mobile/gamification/challenges/stock-hunt", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        return try decoder.decode(StockHuntChallengeResponse.self, from: data)
    }

    /// Search stocks filtered by today's stock hunt criteria
    func searchStockHunt(query: String) async throws -> [StockHuntSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = try buildURL(path: "/mobile/gamification/challenges/stock-hunt/search?q=\(encoded)", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let data = try await performRequest(request)
        struct Wrapper: Decodable { let success: Bool?; let data: [StockHuntSearchResult]? }
        return (try decoder.decode(Wrapper.self, from: data)).data ?? []
    }

    /// Claim a stock for today's stock hunt — awards XP if it matches criteria
    @discardableResult
    func claimStockHunt(symbol: String) async throws -> StockHuntClaimResult {
        let url = try buildURL(path: "/mobile/gamification/challenges/stock-hunt/claim", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["symbol": symbol])
        let data = try await performRequest(request)
        struct Wrapper: Decodable { let success: Bool?; let data: StockHuntClaimResult? }
        return (try decoder.decode(Wrapper.self, from: data)).data ?? StockHuntClaimResult(matched: false, challengeName: nil, xpReward: nil)
    }

    /// Report progress for a daily challenge action. Returns any newly completed challenges (name + XP).
    @discardableResult
    func postChallengeProgress(criteriaType: String, increment: Int = 1) async -> [ChallengeCompletion] {
        guard !criteriaType.isEmpty else { return [] }
        do {
            let url = try buildURL(path: "/mobile/gamification/challenges/progress", base: APIConfig.mainAppURL)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            addHeaders(to: &request)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["criteria_type": criteriaType, "increment": increment])
            let data = try await performRequest(request)
            struct Resp: Decodable {
                struct Inner: Decodable {
                    let completed: [ChallengeCompletion]?
                }
                let data: Inner?
            }
            let resp = try? decoder.decode(Resp.self, from: data)
            return resp?.data?.completed ?? []
        } catch {
            return []
        }
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

        // Computed properties for value conversion
        var cashBalanceValue: Double {
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

        enum CodingKeys: String, CodingKey {
            case id
            case user_id
            case portfolio_type
            case cash_balance
            case initial_balance
            case total_value
            case total_portfolio_value
            case created_at
            case updated_at
        }

        // Custom decoding to handle both String and Int/Double
        private static func decodeStringOrNumber(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
            if let str = try? container.decodeIfPresent(String.self, forKey: key) {
                return str
            }
            if let int = try? container.decodeIfPresent(Int.self, forKey: key) {
                return String(int)
            }
            if let double = try? container.decodeIfPresent(Double.self, forKey: key) {
                return String(Int(double))
            }
            return nil
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try? container.decodeIfPresent(String.self, forKey: .id)
            user_id = try? container.decodeIfPresent(String.self, forKey: .user_id)
            portfolio_type = try? container.decodeIfPresent(String.self, forKey: .portfolio_type)
            cash_balance = Self.decodeStringOrNumber(container, key: .cash_balance)
            initial_balance = Self.decodeStringOrNumber(container, key: .initial_balance)
            total_value = Self.decodeStringOrNumber(container, key: .total_value)
            total_portfolio_value = Self.decodeStringOrNumber(container, key: .total_portfolio_value)
            created_at = try? container.decodeIfPresent(String.self, forKey: .created_at)
            updated_at = try? container.decodeIfPresent(String.self, forKey: .updated_at)
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
        let mid: Double? // Add this
        let mid_price: Double? // Add this
        
        var displayName: String {
            companyname ?? company_name ?? symbol
        }
        
        var value: Double {
            Double(quantity) * (mid ?? mid_price ?? current_price) / 100 // Use mid if available
        }
        
        var profitLoss: Double {
            Double(quantity) * ((mid ?? mid_price ?? current_price) - average_price) / 100
        }
        
        var profitLossPercent: Double {
            guard average_price > 0 else { return 0 }
            return (((mid ?? mid_price ?? current_price) - average_price) / average_price) * 100
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

// MARK: - Sectors

struct SectorItem: Codable, Identifiable {
    var id: String { sector }
    let sector: String
    let count: Int?
    let stock_count: Int?
    var stockCount: Int { stock_count ?? count ?? 0 }
}

struct SubsectorItem: Codable, Identifiable {
    var id: String { subsector }
    let subsector: String
    let count: Int?
    let stock_count: Int?
    let stocks: [SubsectorStock]?
    var stockCount: Int { stock_count ?? count ?? stocks?.count ?? 0 }
}

struct SubsectorStock: Codable {
    let symbol: String
    let companyname: String?
    let listing_id: String?
}

struct BatchPriceData {
    let price: Double?
    let change: Double?
    let changePercent: Double?
}

// MARK: - Mobile Trade (POST /mobile/trade)
struct MobileTradeResponse: Codable {
    let success: Bool
    let data: MobileTradeData?
    let error: String?
    let message: String?
}

struct MobileTradeData: Codable {
    let isPendingOrder: Bool?
    let message: String?
    let isAfterHours: Bool?
    let error: String?
}

// MARK: - Trading Window
struct TradingWindowResponse: Codable {
    let success: Bool?
    let data: Wrapper?
    struct Wrapper: Codable {
        let tradingWindow: TradingWindowData?
    }
}

struct TradingWindowData: Codable {
    let type: String          // "market_open" | "after_hours" | "pre_market" | "weekend_holiday"
    let canTradeImmediately: Bool?
    let canCreatePendingOrder: Bool?
    let executionPrice: String?
    let message: String?

    var isMarketOpen: Bool { type == "market_open" }
    var isAfterHours: Bool { type == "after_hours" }
    var isPreMarket: Bool { type == "pre_market" || type == "weekend_holiday" }
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
        let total_assets: Double? // <-- Add this
        let profit_loss: Double?
        let profit_loss_percent: Double?
        let cash_balance: Double?
        
        // Raw value in pence — callers divide by 100 to get pounds
        var displayValue: Double {
            total_assets ?? total_portfolio_value ?? 0
        }
    }
    
    struct CompetitionData: Codable {
        let status: String?
        let start_date: String?
        let end_date: String?
        let prize_pool: Double?
        // time_remaining comes as a number (seconds) or string from the API
        let time_remaining: String?

        enum CodingKeys: String, CodingKey {
            case status, start_date, end_date, prize_pool, time_remaining
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            status    = try c.decodeIfPresent(String.self, forKey: .status)
            start_date = try c.decodeIfPresent(String.self, forKey: .start_date)
            end_date   = try c.decodeIfPresent(String.self, forKey: .end_date)
            // prize_pool may arrive as Int or Double
            if let d = try? c.decodeIfPresent(Double.self, forKey: .prize_pool) {
                prize_pool = d
            } else if let i = try? c.decodeIfPresent(Int.self, forKey: .prize_pool) {
                prize_pool = Double(i)
            } else {
                prize_pool = nil
            }
            // time_remaining may arrive as a number (seconds) or string
            if let s = try? c.decodeIfPresent(String.self, forKey: .time_remaining) {
                time_remaining = s
            } else if let n = try? c.decodeIfPresent(Double.self, forKey: .time_remaining) {
                time_remaining = String(n)
            } else if let n = try? c.decodeIfPresent(Int.self, forKey: .time_remaining) {
                time_remaining = String(n)
            } else {
                time_remaining = nil
            }
        }
    }
}

// MARK: - Leaderboard User Portfolio

struct LeaderboardUserPortfolio {
    let rank: Int?
    let cashBalance: Double
    struct Holding {
        let symbol: String
        let companyName: String?
        let quantity: Double
        let averagePrice: Double
        let currentPrice: Double
    }
    let holdings: [Holding]
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
    let data: DashboardData?
    // Keep legacy fields for compatibility
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

struct DashboardData: Codable {
    let userId: String?
    let username: String?
    let subscriptions: UserSubscriptionsData?
    let portfolios: [PortfolioConfig]?
    // Add other dashboard fields as needed
}

// MARK: - Minimal Dashboard & Subscriptions Models for fetchDashboard/fetchUserSubscriptions

struct UserSubscriptionsResponse: Codable {
    let weekly: Bool?
    let monthly: Bool?
    let annual: Bool?
    let `default`: Bool? // always true for practice
}

struct MinimalDashboardResponse: Codable {
    let sentiment: MarketSentimentData?
    // Add other dashboard fields as needed
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
    let currentStreak: Int?
    let longestStreak: Int?
    let achievements: [AchievementData]?

    var xp: Int { totalXP ?? total_xp ?? 0 }
    var playerLevel: Int { level ?? player_level ?? 1 }
    var playerLevelName: String { levelName ?? level_name ?? "Rookie" }
    var xpForNextLevel: Int { nextLevelXP ?? next_level_xp ?? 100 }
    var xpNeeded: Int { xpToNextLevel ?? xp_to_next_level ?? 100 }
    var xpActivities: [XPActivity] { recentXP ?? recent_xp ?? [] }
    var streak: Int { currentStreak ?? 0 }
    var bestStreak: Int { longestStreak ?? 0 }
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
    let data: DailyLoginData?

    var streak: Int { data?.currentStreak ?? currentStreak ?? current_streak ?? 0 }
    var xp: Int { data?.streakXP ?? xpAwarded ?? xp_awarded ?? 0 }
    var achievements: [AchievementData] { newAchievements ?? new_achievements ?? [] }
}

struct DailyLoginData: Codable {
    let currentStreak: Int?
    let longestStreak: Int?
    let streakXP: Int?
}

struct StockHuntSearchResult: Codable, Identifiable {
    let symbol: String
    let companyname: String
    let matches: Bool
    var id: String { symbol }
}

struct StockHuntClaimResult: Codable {
    let matched: Bool
    let challengeName: String?
    let xpReward: Int?
}

struct StockHuntChallengeResponse: Codable {
    let success: Bool?
    let data: StockHuntData?

    struct StockHuntData: Codable {
        let template: StockHuntTemplate?
        let completed: Bool?
        let matchingStockCount: Int?
    }

    struct StockHuntTemplate: Codable {
        let name: String?
        let description: String?
        let hint: String?
        let xp_reward: Int?
        let difficulty: String?
    }
}

/// A challenge that was just completed by a progress-update call.
struct ChallengeCompletion: Codable, Identifiable {
    let name: String?
    let xp_reward: Int?
    var id: String { name ?? UUID().uuidString }
    var displayName: String { name ?? "Daily Challenge" }
    var xp: Int { xp_reward ?? 0 }
}

struct ChallengesResponse: Codable {
    let success: Bool?
    let challenges: [ChallengeData]?
    let daily_challenges: [ChallengeData]?
    let data: ChallengesData?

    var allChallenges: [ChallengeData] { data?.challenges ?? challenges ?? daily_challenges ?? [] }
    var dailyCompletedCount: Int { data?.daily_completed_count ?? 0 }
    var dailyLimit: Int { data?.daily_limit ?? 10 }
    var allDone: Bool { data?.all_done ?? false }
    var xpEarnedToday: Int { data?.xp_earned_today ?? 0 }
}

struct ChallengesData: Codable {
    let challenges: [ChallengeData]?
    let daily_completed_count: Int?
    let daily_limit: Int?
    let all_done: Bool?
    let xp_earned_today: Int?
}

struct ChallengeData: Identifiable {
    // Server returns id as Int; stored as String for Identifiable
    let id: String
    let title: String?
    let name: String?
    let description: String?
    let xp_reward: Int?
    let xpReward: Int?
    let progress: Int?
    let user_progress: Int?
    let target: Int?
    let criteria_value: Int?
    let completed: Bool?
    let user_completed: Bool?
    let type: String?
    let criteria_type: String?

    var displayTitle: String { title ?? name ?? "Daily Task" }
    var reward: Int { xp_reward ?? xpReward ?? 0 }
    var isCompleted: Bool { user_completed ?? completed ?? false }
    var currentProgress: Int { user_progress ?? progress ?? 0 }
    var targetProgress: Int { criteria_value ?? target ?? 1 }
    var progressPercent: Double {
        guard targetProgress > 0 else { return isCompleted ? 1.0 : 0.0 }
        return min(Double(currentProgress) / Double(targetProgress), 1.0)
    }
}

extension ChallengeData: Codable {
    enum CodingKeys: String, CodingKey {
        case id, challenge_id, title, name, description
        case xp_reward, xpReward, progress, user_progress
        case target, criteria_value, completed, user_completed, type, criteria_type
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id can be Int or String from different endpoints
        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = (try? c.decode(String.self, forKey: .id))
                ?? (try? c.decode(String.self, forKey: .challenge_id))
                ?? UUID().uuidString
        }
        title        = try? c.decode(String.self, forKey: .title)
        name         = try? c.decode(String.self, forKey: .name)
        description  = try? c.decode(String.self, forKey: .description)
        xp_reward    = try? c.decode(Int.self, forKey: .xp_reward)
        xpReward     = try? c.decode(Int.self, forKey: .xpReward)
        progress     = try? c.decode(Int.self, forKey: .progress)
        user_progress = try? c.decode(Int.self, forKey: .user_progress)
        target       = try? c.decode(Int.self, forKey: .target)
        criteria_value = try? c.decode(Int.self, forKey: .criteria_value)
        completed    = try? c.decode(Bool.self, forKey: .completed)
        user_completed = try? c.decode(Bool.self, forKey: .user_completed)
        type         = try? c.decode(String.self, forKey: .type)
        criteria_type = try? c.decode(String.self, forKey: .criteria_type)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(xp_reward, forKey: .xp_reward)
        try c.encodeIfPresent(progress, forKey: .progress)
        try c.encodeIfPresent(user_progress, forKey: .user_progress)
        try c.encodeIfPresent(criteria_value, forKey: .criteria_value)
        try c.encodeIfPresent(completed, forKey: .completed)
        try c.encodeIfPresent(user_completed, forKey: .user_completed)
        try c.encodeIfPresent(type, forKey: .type)
        try c.encodeIfPresent(criteria_type, forKey: .criteria_type)
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
    let _id: String?
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

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case achievement_id, name, title, description, icon, emoji
        case xp_reward, xpReward, unlocked, unlocked_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // "id" may be a string or an integer — handle both
        if let s = try? c.decodeIfPresent(String.self, forKey: ._id) {
            _id = s
        } else if let n = try? c.decodeIfPresent(Int.self, forKey: ._id) {
            _id = String(n)
        } else {
            _id = nil
        }
        achievement_id = try? c.decodeIfPresent(String.self, forKey: .achievement_id)
        name        = try? c.decodeIfPresent(String.self, forKey: .name)
        title       = try? c.decodeIfPresent(String.self, forKey: .title)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        icon        = try? c.decodeIfPresent(String.self, forKey: .icon)
        emoji       = try? c.decodeIfPresent(String.self, forKey: .emoji)
        xp_reward   = try? c.decodeIfPresent(Int.self, forKey: .xp_reward)
        xpReward    = try? c.decodeIfPresent(Int.self, forKey: .xpReward)
        unlocked    = try? c.decodeIfPresent(Bool.self, forKey: .unlocked)
        unlocked_at = try? c.decodeIfPresent(String.self, forKey: .unlocked_at)
    }

    /// Stable non-nil id — uses numeric id from JSON (even if stored as string), then achievement_id, then name
    var id: String { _id ?? achievement_id ?? (name ?? title ?? "unknown") }

    /// Convenience init for programmatic construction (e.g. from AchievementWrapper)
    init(id: Int? = nil, name: String? = nil, unlocked: Bool? = nil, unlocked_at: String? = nil) {
        _id = id.map(String.init)
        achievement_id = nil
        self.name = name; title = nil; description = nil; icon = nil; emoji = nil
        xp_reward = nil; xpReward = nil
        self.unlocked = unlocked; self.unlocked_at = unlocked_at
    }

    /// Copy with unlocked override
    init(copying other: AchievementData, unlocked: Bool, unlocked_at: String?) {
        _id = other._id; achievement_id = other.achievement_id
        name = other.name; title = other.title; description = other.description
        icon = other.icon; emoji = other.emoji
        xp_reward = other.xp_reward; xpReward = other.xpReward
        self.unlocked = unlocked; self.unlocked_at = unlocked_at ?? other.unlocked_at
    }
    var achievementId: String { id }
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

struct BalanceSheetYear: Decodable {
    let year: String
    let totalAssets: Double?
    let currentAssets: Double?
    let nonCurrentAssets: Double?
    let cash: Double?
    let totalLiabilities: Double?
    let currentLiabilities: Double?
    let longTermDebt: Double?
    let totalEquity: Double?
    let retainedEarnings: Double?
}

struct IncomeStatementYear: Decodable {
    let year: String
    let revenue: Double?
    let grossProfit: Double?
    let ebit: Double?
    let pretaxProfit: Double?
    let netIncome: Double?

    var grossMarginPct: Double? {
        guard let r = revenue, let g = grossProfit, r != 0 else { return nil }
        return (g / r) * 100
    }
    var netMarginPct: Double? {
        guard let r = revenue, let n = netIncome, r != 0 else { return nil }
        return (n / r) * 100
    }
}

struct PricePoint: Decodable {
    let date: String
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double?
    let volume: Double?
}

struct StockFundamentals: Decodable {
    let peRatio: Double?
    let eps: Double?
    let dividendYield: Double?
    let marketCap: Double?
    let fiftyTwoWeekHigh: Double?
    let fiftyTwoWeekLow: Double?
    // Extended financial metrics
    let priceToBook: Double?
    let returnOnEquity: Double?
    let returnOnAssets: Double?
    let profitMargin: Double?
    let debtToEquity: Double?
    let currentRatio: Double?
    let revenue: Double?
    let netIncome: Double?
    // Structured historical data
    let balanceSheet: [BalanceSheetYear]?
    let incomeStatement: [IncomeStatementYear]?
    let taxonomies: [String: AnyDecodable]?

    enum CodingKeys: String, CodingKey {
        case peRatio, pe, pe_ratio
        case eps, earningsPerShare, earnings_per_share
        case dividendYield, dividend_yield
        case marketCap, market_cap
        case fiftyTwoWeekHigh, fiftyTwoWeekLow, fiftyTwoWeekHighRaw, fiftyTwoWeekLowRaw
        case priceToBook, price_to_book
        case returnOnEquity, roe
        case returnOnAssets, roa
        case profitMargin, profit_margin
        case debtToEquity, debt_to_equity
        case currentRatio, current_ratio
        case revenue, netIncome, net_income
        case balanceSheet, incomeStatement
        case taxonomies
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func dbl(_ keys: CodingKeys...) -> Double? {
            for k in keys {
                if let v = try? c.decodeIfPresent(Double.self, forKey: k) { return v }
                if let s = try? c.decodeIfPresent(String.self, forKey: k), let d = Double(s) { return d }
            }
            return nil
        }
        peRatio = dbl(.peRatio, .pe, .pe_ratio)
        eps = dbl(.eps, .earningsPerShare, .earnings_per_share)
        dividendYield = dbl(.dividendYield, .dividend_yield)
        marketCap = dbl(.marketCap, .market_cap)
        fiftyTwoWeekHigh = dbl(.fiftyTwoWeekHigh, .fiftyTwoWeekHighRaw)
        fiftyTwoWeekLow = dbl(.fiftyTwoWeekLow, .fiftyTwoWeekLowRaw)
        priceToBook = dbl(.priceToBook, .price_to_book)
        returnOnEquity = dbl(.returnOnEquity, .roe)
        returnOnAssets = dbl(.returnOnAssets, .roa)
        profitMargin = dbl(.profitMargin, .profit_margin)
        debtToEquity = dbl(.debtToEquity, .debt_to_equity)
        currentRatio = dbl(.currentRatio, .current_ratio)
        revenue = dbl(.revenue)
        netIncome = dbl(.netIncome, .net_income)
        balanceSheet = try? c.decodeIfPresent([BalanceSheetYear].self, forKey: .balanceSheet)
        incomeStatement = try? c.decodeIfPresent([IncomeStatementYear].self, forKey: .incomeStatement)
        taxonomies = try? c.decodeIfPresent([String: AnyDecodable].self, forKey: .taxonomies)
    }

    init(peRatio: Double?, eps: Double?, dividendYield: Double?, marketCap: Double?,
         fiftyTwoWeekHigh: Double?, fiftyTwoWeekLow: Double?, taxonomies: [String: AnyDecodable]?) {
        self.peRatio = peRatio; self.eps = eps; self.dividendYield = dividendYield
        self.marketCap = marketCap; self.fiftyTwoWeekHigh = fiftyTwoWeekHigh
        self.fiftyTwoWeekLow = fiftyTwoWeekLow; self.taxonomies = taxonomies
        priceToBook = nil; returnOnEquity = nil; returnOnAssets = nil
        profitMargin = nil; debtToEquity = nil; currentRatio = nil
        revenue = nil; netIncome = nil; balanceSheet = nil; incomeStatement = nil
    }
}

// MARK: - Subscription & Payment Models

struct SubscriptionOptionsResponse: Decodable {
    let current: CompetitionOption?
    let next: CompetitionOption?
    let plan: String?
}

struct CompetitionOption: Decodable, Identifiable {
    var id: String { label ?? startDate ?? UUID().uuidString }
    let label: String?
    let startDate: String?
    let endDate: String?
    let startTimestamp: Double?
    let endTimestamp: Double?

    enum CodingKeys: String, CodingKey {
        case label, startDate, endDate, startTimestamp, endTimestamp
        case start_date, end_date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try? c.decodeIfPresent(String.self, forKey: .label)
        startDate = (try? c.decodeIfPresent(String.self, forKey: .startDate)) ?? (try? c.decodeIfPresent(String.self, forKey: .start_date))
        endDate = (try? c.decodeIfPresent(String.self, forKey: .endDate)) ?? (try? c.decodeIfPresent(String.self, forKey: .end_date))
        startTimestamp = try? c.decodeIfPresent(Double.self, forKey: .startTimestamp)
        endTimestamp = try? c.decodeIfPresent(Double.self, forKey: .endTimestamp)
    }
}

struct ActiveSubscription: Decodable, Identifiable {
    var id: String { plan ?? UUID().uuidString }
    let plan: String?
    let isActive: Bool?
    let is_active: Bool?
    let startDate: String?
    let start_date: String?
    let endDate: String?
    let end_date: String?
    let autoRenew: Bool?
    let auto_renew: Bool?
    let competitionChoice: String?

    var active: Bool { isActive ?? is_active ?? false }
    var autoRenewEnabled: Bool { autoRenew ?? auto_renew ?? false }
    var planName: String { plan?.capitalized ?? "Unknown" }
    var start: String { startDate ?? start_date ?? "" }
    var end: String { endDate ?? end_date ?? "" }
}

struct RevolutOrderResponse {
    let publicId: String
    let checkoutUrl: String
    let orderId: String
}

struct PaymentVerifyResponse {
    let paid: Bool
    let status: String
}

struct AutoRenewSettings: Codable {
    let weekly: Bool?
    let monthly: Bool?
    let annual: Bool?
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
