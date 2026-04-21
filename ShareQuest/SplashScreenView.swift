//
//  SplashScreenView.swift
//  ShareQuest
//
//  Created by MartinD on 13/03/2026.
//

import SwiftUI

/// Splash screen shown on app launch
struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background gradient matching app theme
            LinearGradient(
                colors: [
                    Color(red: 0.059, green: 0.090, blue: 0.165),
                    Color(red: 0.118, green: 0.227, blue: 0.541),
                    Color(red: 0.345, green: 0.110, blue: 0.529)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Glassmorphism effect behind logo and loading indicator
            if #available(iOS 15.0, *) {
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .opacity(0.85)
                    .frame(width: 340, height: 260)
            }

            VStack(spacing: 24) {
                // Logo
                if let _ = UIImage(named: "SplashLogo") {
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 100)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                } else {
                    // Fallback to SF Symbol if image not found
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 80))
                        .dynamicTypeSize(.xSmall ... .accessibility2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primaryBlue, Theme.accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .accessibilityHidden(true)
                    
                    Text("ShareQuest")
                        .font(.largeTitle.weight(.bold))
                        .dynamicTypeSize(.xSmall ... .accessibility2)
                        .foregroundColor(.white)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .accessibilityAddTraits(.isHeader)
                }

                // Loading indicator
                if showContent {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                        .scaleEffect(1.2)
                        .padding(.top, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showContent = true
            }
        }
    }
}

/// Launch screen that can be used as a static view
struct LaunchScreen: View {
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.059, green: 0.090, blue: 0.165)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Try to use the logo image, fallback to icon
                if let _ = UIImage(named: "ShareQuestLogo") {
                    Image("ShareQuestLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280)
                } else if let _ = UIImage(named: "SplashLogo") {
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280)
                } else {
                    // Fallback
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primaryBlue, Theme.accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("ShareQuest")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview("Splash Screen") {
    SplashScreenView()
}

#Preview("Launch Screen") {
    LaunchScreen()
}
