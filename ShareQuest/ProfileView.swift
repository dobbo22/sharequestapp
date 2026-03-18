//
//  ProfileView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine

/// Profile screen - matches React Native profile.tsx
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.primaryGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        profileHeader
                        
                        // Stats Cards
                        statsSection
                        
                        // Level Progress
                        levelProgressSection
                        
                        // Achievements
                        achievementsSection
                        
                        // Settings Menu
                        settingsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authManager)
        }
        .onAppear {
            // Update viewModel with auth user data if available
            if let user = authManager.currentUser {
                viewModel.username = user.displayName
                viewModel.email = user.email
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.primaryBlue.opacity(0.3))
                    .frame(width: 100, height: 100)
                Text((authManager.currentUser?.displayName ?? viewModel.username).prefix(2).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Theme.primaryBlue)
            }
            
            // Username
            Text(viewModel.username)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            // Member since
            Text("Member since \(viewModel.memberSince)")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            // Edit Profile Button
            Button(action: { showEditProfile = true }) {
                Text("Edit Profile")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.primaryBlue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Theme.primaryBlue.opacity(0.2))
                    .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "chart.line.uptrend.xyaxis",
                value: "\(viewModel.totalTrades)",
                label: "Trades",
                color: Theme.primaryBlue
            )
            
            StatCard(
                icon: "trophy",
                value: "\(viewModel.competitionsWon)",
                label: "Wins",
                color: Theme.accentYellow
            )
            
            StatCard(
                icon: "flame",
                value: "\(viewModel.currentStreak)",
                label: "Streak",
                color: Theme.accentRed
            )
        }
    }
    
    // MARK: - Level Progress Section
    private var levelProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Level \(viewModel.level)")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.xp) / \(viewModel.xpToNextLevel) XP")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.glassBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.primaryBlue)
                        .frame(width: geometry.size.width * viewModel.levelProgress, height: 8)
                }
            }
            .frame(height: 8)
            
            Text(viewModel.levelName)
                .font(.caption)
                .foregroundColor(Theme.primaryBlue)
        }
        .padding()
        .glassCard()
    }
    
    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.unlockedAchievements)/\(viewModel.totalAchievements)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.achievements) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 12) {
            SettingsRow(icon: "bell", title: "Notifications", color: Theme.primaryBlue) {
                // Navigate to notifications
            }
            
            SettingsRow(icon: "lock.shield", title: "Privacy", color: Theme.accentGreen) {
                // Navigate to privacy
            }
            
            SettingsRow(icon: "questionmark.circle", title: "Help & Support", color: Theme.accentPurple) {
                // Navigate to help
            }
            
            SettingsRow(icon: "arrow.right.square", title: "Sign Out", color: Theme.accentRed) {
                // Sign out
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard()
    }
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.unlocked ? Theme.accentYellow.opacity(0.3) : Theme.glassBackground)
                    .frame(width: 60, height: 60)
                Text(achievement.emoji)
                    .font(.title)
                    .opacity(achievement.unlocked ? 1 : 0.3)
            }
            
            Text(achievement.name)
                .font(.caption2)
                .foregroundColor(achievement.unlocked ? Theme.textPrimary : Theme.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Theme.primaryBlue.opacity(0.3))
                            .frame(width: 100, height: 100)
                        Text(username.prefix(2).uppercased())
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Theme.primaryBlue)
                    }
                    .padding(.top)
                    
                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            TextField("Username", text: $username)
                                .padding()
                                .background(Theme.glassBackground)
                                .cornerRadius(12)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Theme.glassBackground)
                                .cornerRadius(12)
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: saveProfile) {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primaryBlue)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.primaryBlue)
                }
            }
        }
        .onAppear {
            username = viewModel.username
            email = viewModel.email
        }
    }
    
    private func saveProfile() {
        viewModel.username = username
        viewModel.email = email
        dismiss()
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary
                    .ignoresSafeArea()
                
                List {
                    Section("Account") {
                        Text("Change Password")
                        Text("Two-Factor Authentication")
                    }
                    
                    Section("Preferences") {
                        Text("Notifications")
                        Text("Display")
                        Text("Language")
                    }
                    
                    Section("About") {
                        Text("Terms of Service")
                        Text("Privacy Policy")
                        Text("Version 1.0.0")
                    }
                    
                    Section {
                        Button(action: signOut) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundColor(Theme.accentRed)
                        }
                    }
                    
                    // Debug section (for testing)
                    Section("Developer") {
                        Button(action: resetOnboarding) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset Onboarding")
                            }
                            .foregroundColor(.orange)
                        }

                        NavigationLink {
                            DebugAPISettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "network")
                                Text("API Backend")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.primaryBlue)
                }
            }
        }
    }
    
    @EnvironmentObject var authManager: AuthManager
    
    private func signOut() {
        authManager.signOut()
        dismiss()
    }
    
    private func resetOnboarding() {
        authManager.resetAllState()
        dismiss()
    }
}

// MARK: - API Debug Settings View
struct DebugAPISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEnvironment: APIConfig.Environment = APIService.shared.currentEnvironment
    @State private var localHost: String = APIConfig.localHost
    @State private var statusMessage: String = ""
    @State private var isCheckingHealth = false

    var body: some View {
        Form {
            Section("Environment") {
                Picker("API Mode", selection: $selectedEnvironment) {
                    Text("Local").tag(APIConfig.Environment.local)
                    Text("Remote").tag(APIConfig.Environment.remote)
                }
                .pickerStyle(.segmented)

                Text("Current base URL: \(APIConfig.mainAppURL)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Local Host") {
                TextField("localhost:3000", text: $localHost)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("Simulator: localhost:3000. Device: your Mac LAN IP:3000.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Actions") {
                Button("Save Settings") {
                    APIService.shared.setAPIEnvironment(selectedEnvironment)
                    APIService.shared.setLocalAPIHost(localHost.trimmingCharacters(in: .whitespacesAndNewlines))
                    statusMessage = "Saved. Active base URL: \(APIConfig.mainAppURL)"
                }

                Button {
                    Task { await runHealthCheck() }
                } label: {
                    if isCheckingHealth {
                        HStack {
                            ProgressView()
                            Text("Checking...")
                        }
                    } else {
                        Text("Health Check")
                    }
                }
                .disabled(isCheckingHealth)
            }

            if !statusMessage.isEmpty {
                Section("Status") {
                    Text(statusMessage)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("API Backend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedEnvironment = APIService.shared.currentEnvironment
            localHost = APIConfig.localHost
        }
    }

    @MainActor
    private func runHealthCheck() async {
        isCheckingHealth = true
        defer { isCheckingHealth = false }

        do {
            let ok = try await APIService.shared.checkAPIHealth()
            statusMessage = ok
                ? "Health check passed for \(APIConfig.mainAppURL)"
                : "Health check failed for \(APIConfig.mainAppURL)"
        } catch {
            statusMessage = "Health check error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Achievement Model
struct Achievement: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let unlocked: Bool
}

// MARK: - Profile ViewModel
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var username = "Trader"
    @Published var email = "trader@example.com"
    @Published var memberSince = "March 2026"
    @Published var totalTrades = 47
    @Published var competitionsWon = 3
    @Published var currentStreak = 12
    @Published var level = 5
    @Published var levelName = "Rising Star"
    @Published var xp = 2450
    @Published var xpToNextLevel = 3000
    @Published var unlockedAchievements = 8
    @Published var totalAchievements = 20
    @Published var achievements: [Achievement] = []
    
    var levelProgress: CGFloat {
        CGFloat(xp) / CGFloat(xpToNextLevel)
    }
    
    init() {
        loadAchievements()
    }
    
    private func loadAchievements() {
        achievements = [
            Achievement(id: "1", name: "First Trade", emoji: "🎯", unlocked: true),
            Achievement(id: "2", name: "Week Winner", emoji: "🏆", unlocked: true),
            Achievement(id: "3", name: "Diversified", emoji: "📊", unlocked: true),
            Achievement(id: "4", name: "Hot Streak", emoji: "🔥", unlocked: true),
            Achievement(id: "5", name: "Top 10", emoji: "⭐", unlocked: false),
            Achievement(id: "6", name: "Diamond Hands", emoji: "💎", unlocked: false)
        ]
    }
}

#Preview {
    ProfileView()
}
