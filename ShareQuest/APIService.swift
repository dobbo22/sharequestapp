//
//  APIService.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import Foundation

/// API configuration
enum APIConfig {
    // ShareQuest API endpoints
    static let baseURL = "https://sharequestapp.vercel.app/api"
    static let mainAppURL = "https://sharequestapp.vercel.app/api"  // Use same API for mobile auth
    
    // Store your API token securely - in production use Keychain
    static var apiToken: String {
        // TODO: Move to Keychain for production
        return "cxiOy5ZQ069lH4kgZTDiUGX8sF6xz0S0UukLeRpEQ0Y"
    }
}

/// API error types
enum APIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int)
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
        return authToken != nil || APIConfig.apiToken.isEmpty == false
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
        let url = try buildURL(path: "/mobile/stocks/search?q=\(encodedQuery)", base: APIConfig.mainAppURL)
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
    
    /// Get stock quote
    func getStockQuote(symbol: String) async throws -> StockQuote {
        let url = try buildURL(path: "/mobile/stocks/\(symbol)/quote", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(StockQuote.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
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
    
    /// Get current user profile
    func getProfile() async throws -> UserProfile {
        let url = try buildURL(path: "/mobile/auth/me", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(UserProfile.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Dashboard (unified endpoint)
    
    /// Fetch unified dashboard data
    func fetchDashboard(bypassCache: Bool = false) async throws -> DashboardResponse {
        let path = "/mobile/dashboard/unified\(bypassCache ? "?bypassCache=1" : "")"
        let url = try buildURL(path: path, base: APIConfig.mainAppURL)
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
    
    /// Fetch user subscriptions
    func fetchSubscriptions() async throws -> SubscriptionsResponse {
        let url = try buildURL(path: "/mobile/subscriptions", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(SubscriptionsResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Gamification
    
    /// Get gamification profile (XP, level, etc.)
    func getGamificationProfile() async throws -> GamificationProfileResponse {
        let url = try buildURL(path: "/mobile/gamification/profile", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(GamificationProfileResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Record daily login (for streak and XP)
    func recordDailyLogin() async throws -> DailyLoginResponse {
        let url = try buildURL(path: "/mobile/gamification/login", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(DailyLoginResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Get daily challenges
    func getDailyChallenges() async throws -> ChallengesResponse {
        let url = try buildURL(path: "/mobile/gamification/challenges", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(ChallengesResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Get achievements
    func getAchievements() async throws -> AchievementsResponse {
        let url = try buildURL(path: "/mobile/gamification/achievements", base: APIConfig.mainAppURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let data = try await performRequest(request)
        
        do {
            return try decoder.decode(AchievementsResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Helpers
    
    private func buildURL(path: String, base: String) throws -> URL {
        guard let url = URL(string: base + path) else {
            throw APIError.invalidURL
        }
        return url
    }
    
    private func addAuthHeader(to request: inout URLRequest) {
        let token = authToken ?? APIConfig.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func addHeaders(to request: inout URLRequest) {
        addAuthHeader(to: &request)
        if let userId = userId {
            request.setValue(userId, forHTTPHeaderField: "x-user-id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
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
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        default:
            // Try to extract error message from response
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let _ = errorResponse["error"] ?? errorResponse["message"] {
                throw APIError.serverError(httpResponse.statusCode)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
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

struct StockQuote: Codable {
    let symbol: String
    let companyName: String?
    let quote: QuoteData?
    let profile: ProfileData?
    
    struct QuoteData: Codable {
        let regularMarketPrice: Double?
        let regularMarketChange: Double?
        let regularMarketChangePercent: Double?
        let regularMarketVolume: Int?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?
        let longName: String?
    }
    
    struct ProfileData: Codable {
        let longName: String?
        let description: String?
        let sector: String?
        let sectorDisp: String?
        let country: String?
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
    // default is always true
    
    var hasWeekly: Bool { weekly ?? false }
    var hasMonthly: Bool { monthly ?? false }
    var hasAnnual: Bool { annual ?? false }
}

struct SubscriptionsResponse: Codable {
    let success: Bool?
    let subscriptions: UserSubscriptionsData?
    let data: UserSubscriptionsData?
    
    var subs: UserSubscriptionsData? {
        subscriptions ?? data
    }
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
