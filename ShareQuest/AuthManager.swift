//
//  AuthManager.swift
//  ShareQuest
//
//  Created by MartinD on 13/03/2026.
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices

/// Manages authentication state across the app
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var hasCompletedOnboarding = false
    @Published var onboardingXP: Int = 0
    
    private let apiService = APIService.shared
    
    private init() {
        // Check if user has completed onboarding
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Load any saved onboarding XP
        onboardingXP = UserDefaults.standard.integer(forKey: "onboarding_xp")
        
        // Check if we have a saved auth token
        if let _ = UserDefaults.standard.string(forKey: "auth_token") {
            isAuthenticated = true
            // Load user profile in background
            Task {
                await loadUserProfile()
            }
        }
    }
    
    // MARK: - Onboarding XP
    
    func setOnboardingXP(_ xp: Int) {
        onboardingXP = xp
        UserDefaults.standard.set(xp, forKey: "onboarding_xp")
    }
    
    func clearOnboardingXP() {
        onboardingXP = 0
        UserDefaults.standard.removeObject(forKey: "onboarding_xp")
    }
    
    // MARK: - Authentication
    
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.login(email: email, password: password)

            // If API returned a user object, populate it. If not, consider the presence of a token as success
            if let user = response.user {
                currentUser = User(
                    id: user.id ?? "",
                    username: user.username ?? "",
                    email: user.email ?? "",
                    firstName: user.first_name,
                    lastName: user.last_name
                )
                // Persist first name locally for immediate UI reads
                if let fn = user.first_name, !fn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    UserDefaults.standard.set(fn, forKey: "user_first_name")
                }
                isAuthenticated = true
                isLoading = false
                return true
            }

            // If a token was provided by the APIService.login call above, treat this as success and load profile
            if response.token != nil {
                // Token already saved by APIService; try to load profile in background
                Task {
                    await loadUserProfile()
                }
                isAuthenticated = true
                 // After authenticating, attempt to sync any locally-stored onboarding XP to the server
                 Task {
                     let localXP = UserDefaults.standard.integer(forKey: "onboarding_xp")
                     if localXP > 0 {
                         // persist in manager and best-effort sync
                         await MainActor.run { self.setOnboardingXP(localXP) }
                         do {
                             _ = try await APIService.shared.recordOnboardingXP(xp: localXP)
                         } catch {
                            // ignore sync errors - best-effort
                         }
                     }
                 }
                 isLoading = false
                 return true
             }

            if let error = response.error ?? response.message {
                errorMessage = error
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        // Fallback: if APIService saved an auth token to UserDefaults, consider login successful
        if let savedToken = UserDefaults.standard.string(forKey: "auth_token"), !savedToken.isEmpty {
            // try to load user profile but don't block
            Task {
                await loadUserProfile()
            }
            isAuthenticated = true
             // After authenticating, attempt to sync any locally-stored onboarding XP to the server
             Task {
                 let localXP = UserDefaults.standard.integer(forKey: "onboarding_xp")
                 if localXP > 0 {
                     await MainActor.run { self.setOnboardingXP(localXP) }
                     do {
                         _ = try await APIService.shared.recordOnboardingXP(xp: localXP)
                     } catch {
                        // ignore sync errors - best-effort
                     }
                 }
             }
             isLoading = false
             return true
         }
        
        isLoading = false
        return false
    }
    
    /// Register a new user. If `onboardingXP` is provided, persist it locally and attempt to sync to the server after successful registration (best-effort).
    func register(email: String, username: String, password: String, firstName: String? = nil, lastName: String? = nil, dateOfBirth: String? = nil, onboardingXP: Int? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.register(
                email: email,
                username: username,
                password: password,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth
            )

            if let user = response.user {
                currentUser = User(
                    id: user.id ?? "",
                    username: user.username ?? "",
                    email: user.email ?? "",
                    firstName: user.first_name ?? firstName,
                    lastName: user.last_name ?? lastName
                )
                isAuthenticated = true

                // If onboardingXP provided, persist locally and sync to server (best-effort)
                if let xp = onboardingXP {
                    setOnboardingXP(xp)
                    Task {
                        do {
                            _ = try await APIService.shared.recordOnboardingXP(xp: xp)
                        } catch {
                            // ignore sync errors - best-effort
                            // Onboarding XP sync failed (best-effort) - suppress console output in production
                        }
                    }
                }

                isLoading = false
                return true
            } else if let error = response.error ?? response.message {
                errorMessage = error
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        return false
    }
    
    func signOut() {
        apiService.clearAuth()
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }
    
    func loadUserProfile() async {
        do {
            let profile = try await apiService.getProfile()
            currentUser = User(
                id: profile.id ?? "",
                username: profile.username ?? "",
                email: profile.email ?? "",
                firstName: profile.first_name,
                lastName: profile.last_name
            )
            if let fn = profile.first_name, !fn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UserDefaults.standard.set(fn, forKey: "user_first_name")
            }
        } catch {
            // If profile load fails, user might need to re-authenticate
            // Suppress debug console output
        }
    }
    
    // MARK: - Onboarding
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func completeOnboarding(withXP xp: Int) {
        onboardingXP = xp
        UserDefaults.standard.set(xp, forKey: "onboarding_xp")
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        onboardingXP = 0
        UserDefaults.standard.removeObject(forKey: "onboarding_xp")
    }
    
    /// Reset all app state - useful for testing
    func resetAllState() {
        signOut()
        resetOnboarding()
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "user_id")
    }

    // MARK: - Sign in with Apple

    func signInWithApple(identityToken: String, email: String?, firstName: String?, lastName: String?, appleUserId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await apiService.signInWithApple(
                identityToken: identityToken, email: email,
                firstName: firstName, lastName: lastName, appleUserId: appleUserId
            )
            return handleOAuthResult(result)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Web OAuth (Google / Facebook / LinkedIn)
    // Called by the app's onOpenURL handler after ASWebAuthenticationSession completes

    func handleOAuthCallback(url: URL) -> Bool {
        print("[OAuth] Callback URL: \(url)")
        guard url.scheme == "sharequest", url.host == "auth",
              url.path == "/callback" else {
            print("[OAuth] Guard failed — scheme:\(url.scheme ?? "nil") host:\(url.host ?? "nil") path:\(url.path)")
            return false
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var params: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            params[item.name] = item.value ?? ""
        }
        print("[OAuth] Params: \(params.keys.sorted())")
        if let error = params["error"] {
            print("[OAuth] Error from server: \(error)")
            DispatchQueue.main.async { self.errorMessage = error; self.isLoading = false }
            return false
        }
        guard let token = params["token"] else {
            print("[OAuth] No token in callback — setting error")
            DispatchQueue.main.async { self.errorMessage = "Sign in failed — no token received"; self.isLoading = false }
            return false
        }
        let result = APIService.OAuthTokenResult(
            token: token,
            userId: params["userId"] ?? "",
            username: params["username"] ?? "",
            email: params["email"] ?? "",
            firstName: params["firstName"].flatMap { $0.isEmpty ? nil : $0 },
            lastName: params["lastName"].flatMap { $0.isEmpty ? nil : $0 }
        )
        return handleOAuthResult(result)
    }

    private func handleOAuthResult(_ result: APIService.OAuthTokenResult) -> Bool {
        apiService.saveToken(result.token)
        if !result.userId.isEmpty {
            apiService.setUserId(result.userId)  // updates in-memory + UserDefaults so x-user-id header is sent immediately
        }
        currentUser = User(
            id: result.userId,
            username: result.username,
            email: result.email,
            firstName: result.firstName,
            lastName: result.lastName
        )
        if let fn = result.firstName, !fn.isEmpty {
            UserDefaults.standard.set(fn, forKey: "user_first_name")
        }
        isAuthenticated = true
        isLoading = false
        return true
    }
}

// MARK: - User Model

struct User: Identifiable {
    let id: String
    let username: String
    let email: String
    let firstName: String?
    let lastName: String?
    
    var displayName: String {
        if let firstName = firstName, !firstName.isEmpty {
            return firstName
        }
        return username
    }
    
    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}
