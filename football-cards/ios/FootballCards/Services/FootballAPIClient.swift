import Foundation

enum FootballAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String?)
    case decodingError
    case missingAdminToken
    case missingAuthToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid football API URL"
        case .invalidResponse:
            return "Invalid football API response"
        case .serverError(let statusCode, let message):
            return message?.isEmpty == false ? message : "Football API request failed with status \(statusCode)"
        case .decodingError:
            return "Failed to decode football API response"
        case .missingAdminToken:
            return "Missing admin token for sync status"
        case .missingAuthToken:
            return "Missing auth token"
        }
    }
}

private struct FootballAPIErrorResponse: Decodable {
    let success: Bool?
    let error: String?
    let message: String?
    let details: String?
}

final class FootballAPIClient {
    static let shared = FootballAPIClient()

    static let defaultSyncSource = "sportmonks"
    static let defaultSyncSeason = 2025

#if DEBUG
    private let debugLocalBaseURLs = [
        "http://localhost:3001/api/football",
        "http://localhost:3000/api/football",
    ]
#endif

    private enum StorageKey {
        static let authToken = "football_auth_token"
        static let userID = "football_user_id"
    }

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    var footballBaseURL: String {
        UserDefaults.standard.string(forKey: "football_api_base_url") ?? defaultFootballBaseURL
    }

    var defaultFootballBaseURL: String {
#if DEBUG
        debugLocalBaseURLs[0]
#else
        "https://www.sharequest.co.uk/api/football"
#endif
    }

    var isUsingLocalEnvironment: Bool {
        footballBaseURL.contains("localhost") || footballBaseURL.contains("127.0.0.1")
    }

    var environmentLabel: String {
        isUsingLocalEnvironment ? "Local API" : "Production API"
    }

    var adminToken: String? {
        UserDefaults.standard.string(forKey: "football_admin_token")
    }

    var authToken: String? {
        KeychainHelper.read(StorageKey.authToken)
    }

    func clearAuth() {
        KeychainHelper.delete(StorageKey.authToken)
        KeychainHelper.delete(StorageKey.userID)
    }

    private func storeAuth(token: String, userID: String) {
        KeychainHelper.save(token, for: StorageKey.authToken)
        KeychainHelper.save(userID, for: StorageKey.userID)
    }

    private func makeRequest(url: URL, method: String, token: String?, body: Data?) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FootballAPIError.invalidResponse
        }

        return (data, httpResponse)
    }

    private func fallbackBaseURLs(for baseURL: String) -> [String] {
#if DEBUG
        guard baseURL.contains("localhost") || baseURL.contains("127.0.0.1") else {
            return []
        }

        return debugLocalBaseURLs.filter { $0 != baseURL }
#else
        return []
#endif
    }

    private func sendRequest(baseURL: String, path: String, method: String = "GET", token: String? = nil, body: Data? = nil) async throws -> Data {
        guard let primaryURL = URL(string: "\(baseURL)\(path)") else {
            throw FootballAPIError.invalidURL
        }

        do {
            let (data, httpResponse) = try await makeRequest(url: primaryURL, method: method, token: token, body: body)
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let payload = try? decoder.decode(FootballAPIErrorResponse.self, from: data)
                let message = payload?.details ?? payload?.message ?? payload?.error
                throw FootballAPIError.serverError(httpResponse.statusCode, message)
            }

            return data
        } catch let error as FootballAPIError {
            if case .serverError(let statusCode, _) = error, statusCode == 404 {
                for fallbackBaseURL in fallbackBaseURLs(for: baseURL) {
                    guard let fallbackURL = URL(string: "\(fallbackBaseURL)\(path)") else {
                        continue
                    }

                    do {
                        let (data, httpResponse) = try await makeRequest(url: fallbackURL, method: method, token: token, body: body)
                        guard (200 ... 299).contains(httpResponse.statusCode) else {
                            continue
                        }

                        UserDefaults.standard.set(fallbackBaseURL, forKey: "football_api_base_url")
                        return data
                    } catch {
                        continue
                    }
                }
            }

            throw error
        } catch {
            for fallbackBaseURL in fallbackBaseURLs(for: baseURL) {
                guard let fallbackURL = URL(string: "\(fallbackBaseURL)\(path)") else {
                    continue
                }

                do {
                    let (data, httpResponse) = try await makeRequest(url: fallbackURL, method: method, token: token, body: body)
                    guard (200 ... 299).contains(httpResponse.statusCode) else {
                        continue
                    }

                    UserDefaults.standard.set(fallbackBaseURL, forKey: "football_api_base_url")
                    return data
                } catch {
                    continue
                }
            }

            throw error
        }
    }

    func fetchBootstrap() async throws -> FootballBootstrapData {
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/bootstrap")

        do {
            return try decoder.decode(FootballBootstrapResponse.self, from: data).data
        } catch {
            throw FootballAPIError.decodingError
        }
    }

    func fetchProfile() async throws -> FootballProfileData {
        guard let token = authToken else {
            throw FootballAPIError.missingAuthToken
        }

        let data = try await sendRequest(baseURL: footballBaseURL, path: "/profile", token: token)
        do {
            return try decoder.decode(FootballProfileResponse.self, from: data).data
        } catch {
            if let raw = String(data: data, encoding: .utf8) {
                print("⚠️ fetchProfile decode error: \(error)")
                print("⚠️ Raw response: \(raw.prefix(2000))")
            }
            throw FootballAPIError.decodingError
        }
    }

    func fetchClubs(search: String? = nil, limit: Int = 100) async throws -> [FootballClub] {
        var path = "/clubs?limit=\(min(max(limit, 1), 100))"
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let encodedSearch = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&search=\(encodedSearch)"
        }

        let data = try await sendRequest(baseURL: footballBaseURL, path: path)
        do {
            return try decoder.decode(FootballClubListResponse.self, from: data).data
        } catch {
            throw FootballAPIError.decodingError
        }
    }

    func fetchCollection(slot: String? = nil, club: String? = nil, search: String? = nil, limit: Int = 250) async throws -> FootballCollectionData {
        guard let token = authToken else {
            throw FootballAPIError.missingAuthToken
        }

        var components = ["limit=\(min(max(limit, 1), 250))"]
        if let slot, !slot.isEmpty, let encoded = slot.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            components.append("slot=\(encoded)")
        }
        if let club, !club.isEmpty, let encoded = club.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            components.append("club=\(encoded)")
        }
        if let search, !search.isEmpty, let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            components.append("search=\(encoded)")
        }

        let path = "/collection?\(components.joined(separator: "&"))"
        let data = try await sendRequest(baseURL: footballBaseURL, path: path, token: token)
        do {
            return try decoder.decode(FootballCollectionResponse.self, from: data).data
        } catch {
            throw FootballAPIError.decodingError
        }
    }

    func completeOnboarding(displayName: String?, teamName: String?, supportedClubId: String) async throws -> FootballProfileData {
        guard let token = authToken else {
            throw FootballAPIError.missingAuthToken
        }

        let body = try encoder.encode(
            FootballProfileUpdateRequest(
                supportedClubId: supportedClubId,
                displayName: displayName,
                teamName: teamName
            )
        )

        let data = try await sendRequest(baseURL: footballBaseURL, path: "/profile", method: "POST", token: token, body: body)
        do {
            return try decoder.decode(FootballProfileResponse.self, from: data).data
        } catch {
            if let raw = String(data: data, encoding: .utf8) {
                print("⚠️ completeOnboarding decode error: \(error)")
                print("⚠️ Raw response: \(raw.prefix(2000))")
            }
            throw FootballAPIError.decodingError
        }
    }

    // MARK: - Daily Pack

    func fetchDailyPackStatus(reserveCount: Int) async throws -> FootballDailyPackStatus {
        guard let token = authToken else { throw FootballAPIError.missingAuthToken }
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/pack/daily?reserveCount=\(reserveCount)", token: token)
        do {
            return try decoder.decode(FootballDailyPackStatusResponse.self, from: data).data
        } catch { throw FootballAPIError.decodingError }
    }

    func claimDailyPack(reserveCount: Int) async throws -> FootballDailyPackResult {
        guard let token = authToken else { throw FootballAPIError.missingAuthToken }
        let body = try encoder.encode(["reserveCount": reserveCount])
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/pack/daily", method: "POST", token: token, body: body)
        do {
            return try decoder.decode(FootballDailyPackClaimResponse.self, from: data).data
        } catch { throw FootballAPIError.decodingError }
    }

    func discardCard(userCardId: String) async throws -> FootballDiscardResult {
        guard let token = authToken else { throw FootballAPIError.missingAuthToken }
        let body = try encoder.encode(["userCardId": userCardId])
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/collection/discard", method: "POST", token: token, body: body)
        do {
            return try decoder.decode(FootballDiscardResponse.self, from: data).data
        } catch { throw FootballAPIError.decodingError }
    }

    // MARK: - Exchange

    func fetchExchangeListings() async throws -> FootballExchangeData {
        guard let token = authToken else { throw FootballAPIError.missingAuthToken }
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/exchange", token: token)
        do {
            return try decoder.decode(FootballExchangeResponse.self, from: data).data
        } catch {
            throw FootballAPIError.decodingError
        }
    }

    func createExchangeListing(userCardId: String) async throws -> FootballCreateListingResult {
        guard let token = authToken else { throw FootballAPIError.missingAuthToken }
        let body = try encoder.encode(["userCardId": userCardId])
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/exchange", method: "POST", token: token, body: body)
        do {
            return try decoder.decode(FootballCreateListingResponse.self, from: data).data
        } catch {
            throw FootballAPIError.decodingError
        }
    }

    func removeExchangeListing(listingId: String) async throws {
        guard let token = authToken else { throw FootballAPIError.missingAuthToken }
        _ = try await sendRequest(baseURL: footballBaseURL, path: "/exchange?listingId=\(listingId)", method: "DELETE", token: token)
    }

    func buyExchangeListing(listingId: String) async throws -> FootballBuyListingResult {
        guard let token = authToken else { throw FootballAPIError.missingAuthToken }
        let body = try encoder.encode(FootballBuyListingRequest(listingId: listingId))
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/exchange/buy", method: "POST", token: token, body: body)
        do {
            return try decoder.decode(FootballBuyListingResponse.self, from: data).data
        } catch {
            throw FootballAPIError.decodingError
        }
    }

    // MARK: - Swap

    func executeSwap(swappedOutUserCardId: String, excludedPlayerIds: [String]) async throws -> FootballSwapResult {
        guard let token = authToken else {
            throw FootballAPIError.missingAuthToken
        }

        let body = try encoder.encode(
            FootballSwapRequest(
                swappedOutUserCardId: swappedOutUserCardId,
                excludedPlayerIds: excludedPlayerIds
            )
        )

        let data = try await sendRequest(baseURL: footballBaseURL, path: "/swap", method: "POST", token: token, body: body)
        do {
            return try decoder.decode(FootballSwapResponse.self, from: data).data
        } catch {
            if let raw = String(data: data, encoding: .utf8) {
                print("⚠️ executeSwap decode error: \(error)")
                print("⚠️ Raw response: \(raw.prefix(2000))")
            }
            throw FootballAPIError.decodingError
        }
    }

    func resetOnboarding() async throws {
        guard let token = authToken else {
            throw FootballAPIError.missingAuthToken
        }

        _ = try await sendRequest(baseURL: footballBaseURL, path: "/dev/reset", method: "POST", token: token)
    }

    func login(email: String, password: String) async throws -> FootballAuthenticatedUser {
        let requestBody = try encoder.encode(FootballLoginRequest(email: email, password: password))
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/auth/login", method: "POST", body: requestBody)
        let response = try decoder.decode(FootballAuthResponse.self, from: data)
        return try extractAndStoreUser(from: response)
    }

    func register(email: String, username: String, password: String, firstName: String?, lastName: String?) async throws -> FootballAuthenticatedUser {
        let requestBody = try encoder.encode(
            FootballRegisterRequest(
                email: email,
                username: username,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
        )
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/auth/register", method: "POST", body: requestBody)
        let response = try decoder.decode(FootballAuthResponse.self, from: data)
        return try extractAndStoreUser(from: response)
    }

    func signInWithApple(identityToken: String, email: String?, firstName: String?, lastName: String?, appleUserId: String) async throws -> FootballAuthenticatedUser {
        let requestBody = try encoder.encode(
            FootballAppleAuthRequest(
                identityToken: identityToken,
                email: email,
                firstName: firstName,
                lastName: lastName,
                appleUserId: appleUserId
            )
        )
        let data = try await sendRequest(baseURL: footballBaseURL, path: "/auth/apple", method: "POST", body: requestBody)
        let response = try decoder.decode(FootballAuthResponse.self, from: data)
        return try extractAndStoreUser(from: response)
    }

    func fetchCurrentUser() async throws -> FootballAuthenticatedUser {
        guard let token = authToken else {
            throw FootballAPIError.missingAuthToken
        }

        let data = try await sendRequest(baseURL: footballBaseURL, path: "/auth/me", token: token)
        return try decoder.decode(FootballAuthenticatedUser.self, from: data)
    }

    func fetchSyncStatus(limit: Int = 5, source: String = FootballAPIClient.defaultSyncSource) async throws -> FootballSyncStatusData {
        let token = adminToken ?? authToken
        guard let token, !token.isEmpty else {
            throw FootballAPIError.missingAdminToken
        }

        let safeLimit = min(max(limit, 1), 50)
        let encodedSource = source.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? FootballAPIClient.defaultSyncSource
        let path = "/admin/sync-status?source=\(encodedSource)&limit=\(safeLimit)&includeDetails=false"
        let data = try await sendRequest(baseURL: footballBaseURL, path: path, token: token)

        do {
            return try decoder.decode(FootballSyncStatusResponse.self, from: data).data
        } catch {
            throw FootballAPIError.decodingError
        }
    }

    func triggerSync(
        source: String = FootballAPIClient.defaultSyncSource,
        season: Int = FootballAPIClient.defaultSyncSeason,
        maxRequests: Int = 60,
        maxTeamsPerLeague: Int = 20
    ) async throws {
        let token = adminToken ?? authToken
        guard let token, !token.isEmpty else {
            throw FootballAPIError.missingAdminToken
        }

        let body = try JSONSerialization.data(withJSONObject: [
            "source": source,
            "season": season,
            "maxRequests": maxRequests,
            "maxTeamsPerLeague": maxTeamsPerLeague,
        ])

        _ = try await sendRequest(
            baseURL: footballBaseURL,
            path: "/admin/sync",
            method: "POST",
            token: token,
            body: body
        )
    }

    private func extractAndStoreUser(from response: FootballAuthResponse) throws -> FootballAuthenticatedUser {
        if let payload = response.data {
            storeAuth(token: payload.token, userID: payload.user.id)
            return payload.user
        }

        if let token = response.token, let user = response.user {
            storeAuth(token: token, userID: user.id)
            return user
        }

        throw FootballAPIError.decodingError
    }
}