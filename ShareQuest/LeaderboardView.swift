//
//  LeaderboardView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

/// Leaderboard screen - matches React Native leaderboards.tsx
struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedType: LeaderboardType = .weekly
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.primaryGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Type Selector
                    typeSelector
                    
                    // Leaderboard Content
                    leaderboardContent
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.fetchLeaderboard(type: selectedType)
        }
        .onChange(of: selectedType) { _, newType in
            Task {
                await viewModel.fetchLeaderboard(type: newType)
            }
        }
    }
    
    // MARK: - Type Selector
    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LeaderboardType.allCases, id: \.self) { type in
                    LeaderboardTypeButton(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Leaderboard Content
    private var leaderboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top 3 Podium
                if viewModel.entries.count >= 3 {
                    podiumView
                }
                
                // Rest of leaderboard
                VStack(spacing: 12) {
                    ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                        if index >= 3 {
                            LeaderboardRowView(rank: index + 1, entry: entry)
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.fetchLeaderboard(type: selectedType)
        }
    }
    
    // MARK: - Podium View
    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 2nd Place
            PodiumPosition(
                rank: 2,
                entry: viewModel.entries[1],
                height: 100,
                color: Color(red: 0.75, green: 0.75, blue: 0.78) // Silver
            )
            
            // 1st Place
            PodiumPosition(
                rank: 1,
                entry: viewModel.entries[0],
                height: 130,
                color: Theme.accentYellow // Gold
            )
            
            // 3rd Place
            PodiumPosition(
                rank: 3,
                entry: viewModel.entries[2],
                height: 80,
                color: Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
            )
        }
        .padding(.vertical)
    }
}

// MARK: - Podium Position
struct PodiumPosition: View {
    let rank: Int
    let entry: LeaderboardEntry
    let height: CGFloat
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 60, height: 60)
                Text(entry.username.prefix(2).uppercased())
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            // Username
            Text(entry.username)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            
            // Return
            Text(entry.formattedReturn)
                .font(.caption2)
                .foregroundColor(entry.returnPercent >= 0 ? Theme.accentGreen : Theme.accentRed)
            
            // Podium
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(height: height)
                
                Text("\(rank)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Leaderboard Type Button
struct LeaderboardTypeButton: View {
    let type: LeaderboardType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(type.emoji)
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? type.color.opacity(0.3) : Theme.glassBackground)
            .foregroundColor(isSelected ? type.color : Theme.textSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? type.color : Theme.glassBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Leaderboard Row View
struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .foregroundColor(Theme.textMuted)
                .frame(width: 30)
            
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.primaryBlue.opacity(0.3))
                    .frame(width: 40, height: 40)
                Text(entry.username.prefix(2).uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primaryBlue)
            }
            
            // Username
            Text(entry.username)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            // Return
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.formattedValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Text(entry.formattedReturn)
                    .font(.caption)
                    .foregroundColor(entry.returnPercent >= 0 ? Theme.accentGreen : Theme.accentRed)
            }
        }
        .padding()
        .glassCard()
    }
}

// MARK: - Leaderboard Type Enum
enum LeaderboardType: String, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case annual = "annual"
    case allTime = "all-time"
    
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .allTime: return "All Time"
        }
    }
    
    var emoji: String {
        switch self {
        case .weekly: return "⚡"
        case .monthly: return "📅"
        case .annual: return "🏆"
        case .allTime: return "👑"
        }
    }
    
    var color: Color {
        switch self {
        case .weekly: return Theme.primaryBlue
        case .monthly: return Theme.accentPurple
        case .annual: return Theme.accentYellow
        case .allTime: return Theme.accentGreen
        }
    }
}

// MARK: - Leaderboard Entry Model
struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let portfolioValue: Double
    let returnPercent: Double
    
    var formattedValue: String {
        "£\(String(format: "%.0f", portfolioValue))"
    }
    
    var formattedReturn: String {
        String(format: "%+.2f%%", returnPercent)
    }
}

// MARK: - Leaderboard ViewModel
@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    func fetchLeaderboard(type: LeaderboardType) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchLeaderboard(type: type.rawValue)
            
            if let leaderboardData = response.leaderboard {
                entries = leaderboardData.enumerated().map { index, entry in
                    LeaderboardEntry(
                        id: entry.id,
                        username: entry.username ?? "User \(entry.rank)",
                        portfolioValue: entry.displayValue,
                        returnPercent: entry.profit_loss_percent ?? 0
                    )
                }
            }
            
        } catch {
            // Keep last loaded values, just show error
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    LeaderboardView()
}
