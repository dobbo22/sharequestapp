//
//  Theme.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI

// MARK: - Adaptive Font Scale
//
// Base design width is 390pt (iPhone 15/16 Pro).
// On larger screens (iPhone 16 Pro Max = 430pt, 17 Pro Max = ~440pt) fonts
// scale up proportionally. Clamped so small phones don't shrink too much.

private let baseWidth: CGFloat  = 390
private let baseHeight: CGFloat = 852   // iPhone 15/16 Pro logical height

/// Returns a size scaled to the current screen width (fonts, icons).
func scaled(_ size: CGFloat) -> CGFloat {
    let factor = min(max(UIScreen.main.bounds.width / baseWidth, 0.85), 1.20)
    return (size * factor).rounded()
}

/// Returns a vertical size (padding, spacing, frame height) scaled to screen height.
/// Smaller phones get tighter spacing so more content fits on screen.
func vscaled(_ size: CGFloat) -> CGFloat {
    let factor = min(max(UIScreen.main.bounds.height / baseHeight, 0.80), 1.15)
    return (size * factor).rounded()
}

/// True on compact-height devices (iPhone SE, 16 Pro etc.) — use tighter layouts.
var isCompactHeight: Bool { UIScreen.main.bounds.height < 900 }

// MARK: - App Theme

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

/// Solid pill showing a % change — blue=up, red=down, green=unchanged
struct ChangePill: View {
    let percent: Double
    /// Override the displayed text (e.g. pre-formatted "+1.4%")
    var label: String? = nil
    /// Compact mode for tight spaces like the stock ticker
    var compact: Bool = false

    private var text: String {
        label ?? String(format: "%+.2f%%", percent)
    }

    private var pillColor: Color {
        if percent > 0 { return Color(red: 0.18, green: 0.45, blue: 0.90) }  // blue
        if percent < 0 { return Color(red: 0.78, green: 0.15, blue: 0.15) }  // red
        return Color(red: 0.05, green: 0.55, blue: 0.37)                      // green (unchanged)
    }

    private var arrowIcon: String {
        if percent > 0 { return "arrow.up.right" }
        if percent < 0 { return "arrow.down.right" }
        return "minus"
    }

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            Image(systemName: arrowIcon)
                .font(.system(size: compact ? scaled(8) : scaled(10), weight: .bold))
            Text(text)
                .font(.system(size: compact ? scaled(10) : scaled(12), weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background(pillColor)
        .cornerRadius(20)
    }
}
