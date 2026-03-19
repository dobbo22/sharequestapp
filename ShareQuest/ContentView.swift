//
//  ContentView.swift
//  ShareQuest
//
//  Created by MartinD on 11/03/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            Group {
                if !authManager.hasCompletedOnboarding {
                    // Show full onboarding flow with trade tutorial for new users
                    OnboardingFlowView()
                        .environmentObject(authManager)
                } else if !authManager.isAuthenticated {
                    // Show login screen
                    NavigationStack {
                        LoginView()
                            .environmentObject(authManager)
                    }
                } else {
                    // Show main app
                    MainTabView()
                        .environmentObject(authManager)
                }
            }
            .opacity(showSplash ? 0 : 1)
            
            // Splash screen overlay
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: authManager.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.5), value: authManager.isAuthenticated)
        .onAppear {
            // Show splash for 2 seconds then fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
        .onOpenURL { url in
            // Handle sharequest://auth/callback?token=... from OAuth web flow
            _ = authManager.handleOAuthCallback(url: url)
        }
    }
}

#Preview {
    ContentView()
}
