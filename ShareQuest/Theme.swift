//
//  Theme.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI

/// App theme colors - matches React Native theme
enum Theme {
    // Primary colors
    static let primaryBlue = Color(red: 0.29, green: 0.68, blue: 0.91)  // #4AAEE8
    static let accentGreen = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
    static let accentRed = Color(red: 0.937, green: 0.267, blue: 0.267)  // #EF4444
    static let accentYellow = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
    static let accentPurple = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
    
    // Background colors
    static let backgroundPrimary = Color(red: 0.067, green: 0.094, blue: 0.153) // #111827
    static let backgroundSecondary = Color(red: 0.118, green: 0.227, blue: 0.373) // #1E3A5F
    static let backgroundCard = Color(red: 0.110, green: 0.161, blue: 0.227) // #1C2937
    
    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.78) // Brighter for contrast
    static let textMuted = Color(white: 0.55) // Brighter muted
    
    // Glass effect
    static let glassBackground = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.1)
    
    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 0.118, green: 0.227, blue: 0.373), Color(red: 0.067, green: 0.094, blue: 0.153)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color(red: 0.231, green: 0.510, blue: 0.965), Color(red: 0.149, green: 0.388, blue: 0.918)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Custom view modifier for glass card style
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.glassBackground)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.glassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
