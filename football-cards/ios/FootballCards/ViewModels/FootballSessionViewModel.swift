import Foundation

@MainActor
final class FootballSessionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var currentUser: FootballAuthenticatedUser?
    @Published var errorMessage: String?

    var isAuthenticated: Bool {
        currentUser != nil && FootballAPIClient.shared.authToken != nil
    }

    var isAdmin: Bool {
        currentUser?.isAdmin == true
    }

    init() {
        if FootballAPIClient.shared.authToken != nil {
            Task {
                await restoreSession()
            }
        }
    }

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await FootballAPIClient.shared.fetchCurrentUser()
            errorMessage = nil
        } catch {
            // Only clear auth on 401 — network errors should not sign the user out
            if case FootballAPIError.serverError(let status, _) = error, status == 401 {
                FootballAPIClient.shared.clearAuth()
                currentUser = nil
            }
            errorMessage = nil
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            errorMessage = "Email and password are required"
            return false
        }

        do {
            let user = try await FootballAPIClient.shared.login(email: normalizedEmail, password: normalizedPassword)
            currentUser = user
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func register(email: String, username: String, password: String, firstName: String?, lastName: String?) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedEmail.isEmpty, !normalizedUsername.isEmpty, !normalizedPassword.isEmpty else {
            errorMessage = "Email, username, and password are required"
            return false
        }

        guard normalizedPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return false
        }

        do {
            let user = try await FootballAPIClient.shared.register(
                email: normalizedEmail,
                username: normalizedUsername,
                password: normalizedPassword,
                firstName: firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            currentUser = user
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signInWithApple(identityToken: String, email: String?, firstName: String?, lastName: String?, appleUserId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user = try await FootballAPIClient.shared.signInWithApple(
                identityToken: identityToken,
                email: email,
                firstName: firstName,
                lastName: lastName,
                appleUserId: appleUserId
            )
            currentUser = user
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() {
        FootballAPIClient.shared.clearAuth()
        currentUser = nil
        errorMessage = nil
    }
}
