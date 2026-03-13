//
//  AuthManager.swift
//  ShareQuest
//
//  Created by MartinD on 13/03/2026.
//

import Foundation
import SwiftUI
import Combine

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
            
            if let user = response.user {
                currentUser = User(
                    id: user.id ?? "",
                    username: user.username ?? "",
                    email: user.email ?? "",
                    firstName: user.first_name,
                    lastName: user.last_name
                )
                isAuthenticated = true
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
    
    func register(email: String, username: String, password: String, firstName: String? = nil, lastName: String? = nil, dateOfBirth: String? = nil) async -> Bool {
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
        } catch {
            // If profile load fails, user might need to re-authenticate
            print("Failed to load user profile: \(error)")
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
