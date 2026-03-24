//
//  ProfileView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI
import Combine
import PhotosUI

@MainActor
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutConfirm = false
    @State private var showSubscriptions = false
    @State private var showHelp = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @Environment(\.dismiss) private var dismiss
    @State private var avatarItem: PhotosPickerItem? = nil
    @State private var avatarImage: UIImage? = ProfileView.loadSavedAvatar()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        userCard
                        levelCard
                        streakRow
                        statsRow
                        if !viewModel.achievements.isEmpty {
                            achievementsSection
                        }
                        settingsSection
                        versionFooter
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .refreshable { await viewModel.loadAll(user: authManager.currentUser) }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView().environmentObject(authManager)
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task {
            await viewModel.loadAll(user: authManager.currentUser)
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - User Card

    private var userCard: some View {
        // Capture main-actor properties before entering PhotosPicker's nonisolated closure
        let capturedAvatar = avatarImage
        let capturedInitials = viewModel.initials
        return HStack(spacing: 16) {
            // Avatar with level badge + edit button
            ZStack(alignment: .bottomTrailing) {
                // Avatar circle
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack {
                        if let img = capturedAvatar {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                        } else {
                            LinearGradient(
                                colors: [Theme.primaryBlue, Theme.accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .overlay(
                                Text(capturedInitials)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        }
                    }
                    .overlay(Circle().stroke(Theme.primaryBlue.opacity(0.5), lineWidth: 2))
                }
                .onChange(of: avatarItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            avatarImage = img
                            ProfileView.saveAvatar(img)
                        }
                    }
                }

                // Edit pencil badge
                ZStack {
                    Circle()
                        .fill(Theme.primaryBlue)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color(red: 0.059, green: 0.090, blue: 0.165), lineWidth: 2))
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: 4)
                .allowsHitTesting(false)

                // Level badge (top-left of avatar)
                ZStack {
                    Circle()
                        .fill(Theme.accentYellow)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color(red: 0.059, green: 0.090, blue: 0.165), lineWidth: 2))
                    Text("\(viewModel.level)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                }
                .offset(x: -50, y: -26)
                .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(.white)
                Text(viewModel.email)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                if !viewModel.memberSince.isEmpty {
                    Text("Member since \(viewModel.memberSince)")
                        .font(.caption2)
                        .foregroundColor(Theme.textMuted)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Theme.primaryBlue.opacity(0.2), Theme.accentPurple.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Avatar Persistence

    static func saveAvatar(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: "profile_avatar")
        }
    }

    static func loadSavedAvatar() -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: "profile_avatar") else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Level / XP Card

    private var levelCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(viewModel.level)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(viewModel.levelName)
                        .font(.caption)
                        .foregroundColor(Theme.primaryBlue)
                }
                Spacer()
                Text("\(viewModel.xp) / \(viewModel.xpForNextLevel) XP")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(Theme.accentYellow)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Theme.primaryBlue, Theme.accentPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(viewModel.xpProgress))
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Streak Row

    private var streakRow: some View {
        HStack(spacing: 12) {
            streakBox(icon: "flame.fill", color: .orange, value: viewModel.currentStreak, label: "Current Streak")
            streakBox(icon: "trophy.fill", color: Theme.accentYellow, value: viewModel.longestStreak, label: "Best Streak")
        }
    }

    private func streakBox(icon: String, color: Color, value: Int, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statBox(icon: "arrow.left.arrow.right", color: Theme.primaryBlue,
                    value: "\(viewModel.totalTrades)", label: "Trades")
            statBox(icon: "briefcase.fill", color: Theme.accentGreen,
                    value: "\(viewModel.portfoliosCount)", label: "Portfolios")
            statBox(icon: "person.3.fill", color: Theme.accentPurple,
                    value: "\(viewModel.leaguesCount)", label: "Leagues")
        }
    }

    private func statBox(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                let unlocked = viewModel.achievements.filter { $0.isUnlocked }.count
                Text("\(unlocked)/\(viewModel.achievements.count)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.achievements.sorted { $0.isUnlocked && !$1.isUnlocked }) { achievement in
                        ProfileAchievementBadge(achievement: achievement)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 20) {
            profileSettingsGroup(title: "ACCOUNT") {
                Button {
                    showSubscriptions = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.accentYellow.opacity(0.2))
                                .frame(width: 34, height: 34)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.accentYellow)
                        }
                        Text("Subscriptions")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                ProfileSettingsRow(icon: "bell.fill", title: "Push Notifications", color: Theme.primaryBlue, trailing: .toggle($viewModel.notificationsEnabled))
                ProfileSettingsRow(icon: "faceid", title: "Face ID / Touch ID", color: Theme.accentGreen, trailing: .toggle($viewModel.biometricsEnabled))
            }
            .sheet(isPresented: $showSubscriptions) {
                SubscriptionsView()
            }
            .sheet(isPresented: $showHelp) {
                HelpCenterView()
            }
            .sheet(isPresented: $showTerms) {
                TermsView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
            }

            profileSettingsGroup(title: "SUPPORT") {
                ProfileSettingsRow(icon: "questionmark.circle.fill", title: "Help Center", color: Theme.accentPurple, trailing: .chevron) {
                    showHelp = true
                }
                ProfileSettingsRow(icon: "envelope.fill", title: "Send Feedback", color: Theme.primaryBlue, trailing: .chevron) {
                    showHelp = true
                }
                ProfileSettingsRow(icon: "star.fill", title: "Rate the App", color: Theme.accentYellow, trailing: .chevron) {
                    if let url = URL(string: "itms-apps://itunes.apple.com/app/id") {
                        UIApplication.shared.open(url)
                    }
                }
            }

            profileSettingsGroup(title: "LEGAL") {
                ProfileSettingsRow(icon: "doc.text.fill", title: "Terms of Service", color: Theme.textSecondary, trailing: .chevron) {
                    showTerms = true
                }
                ProfileSettingsRow(icon: "shield.fill", title: "Privacy Policy", color: Theme.textSecondary, trailing: .chevron) {
                    showPrivacy = true
                }
            }

            profileSettingsGroup(title: "DEVELOPER") {
                NavigationLink {
                    DebugAPISettingsView().environmentObject(authManager)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.textMuted.opacity(0.2))
                                .frame(width: 34, height: 34)
                            Image(systemName: "network")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textMuted)
                        }
                        Text("API Backend")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    authManager.resetAllState()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 34, height: 34)
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15))
                                .foregroundColor(.orange)
                        }
                        Text("Reset Onboarding")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Sign Out
            Button {
                showSignOutConfirm = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.accentRed.opacity(0.2))
                            .frame(width: 34, height: 34)
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.accentRed)
                    }
                    Text("Sign Out")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.accentRed)
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentRed.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func profileSettingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textMuted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Version Footer

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("ShareQuest")
                .font(.caption)
                .foregroundColor(Theme.textMuted)
            Text("Version 1.0.0")
                .font(.caption2)
                .foregroundColor(Theme.textMuted.opacity(0.6))
        }
        .padding(.top, 8)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Settings Row

enum ProfileSettingsTrailing {
    case chevron
    case toggle(Binding<Bool>)
}

struct ProfileSettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let trailing: ProfileSettingsTrailing
    var action: (() -> Void)?

    init(icon: String, title: String, color: Color, trailing: ProfileSettingsTrailing, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.color = color
        self.trailing = trailing
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.2))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Spacer()

                switch trailing {
                case .chevron:
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                case .toggle(let binding):
                    Toggle("", isOn: binding)
                        .labelsHidden()
                        .tint(Theme.primaryBlue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(alignment: .bottom) {
            Color.white.opacity(0.06).frame(height: 1)
        }
    }
}

// MARK: - Achievement Badge

struct ProfileAchievementBadge: View {
    let achievement: AchievementData

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Theme.accentYellow.opacity(0.25) : Color.white.opacity(0.05))
                    .frame(width: 56, height: 56)
                Text(achievement.displayIcon)
                    .font(.title2)
                    .opacity(achievement.isUnlocked ? 1 : 0.3)
            }
            Text(achievement.displayName)
                .font(.caption2)
                .foregroundColor(achievement.isUnlocked ? .white : Theme.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 64)
        }
    }
}

// MARK: - Profile ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var initials = "?"
    @Published var email = ""
    @Published var memberSince = ""
    @Published var level = 1
    @Published var levelName = "Rookie"
    @Published var xp = 0
    @Published var xpForNextLevel = 100
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var totalTrades = 0
    @Published var portfoliosCount = 0
    @Published var leaguesCount = 0
    @Published var achievements: [AchievementData] = []
    @Published var notificationsEnabled = true
    @Published var biometricsEnabled = false

    var xpProgress: Double {
        xpForNextLevel > 0 ? min(Double(xp) / Double(xpForNextLevel), 1.0) : 0
    }

    func loadAll(user: User?) async {
        // Fill name/email from auth immediately
        if let user = user {
            displayName = user.displayName
            email = user.email
            initials = String((user.displayName.first ?? "?").uppercased())
            if displayName.count >= 2 {
                initials = String(displayName.prefix(2).uppercased())
            }
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadProfile() }
            group.addTask { await self.loadGamification() }
            group.addTask { await self.loadPortfolioCount() }
            group.addTask { await self.loadLeagueCount() }
        }
    }

    private func loadProfile() async {
        do {
            let profile = try await APIService.shared.getProfile()
            if let name = profile.username, !name.isEmpty {
                displayName = name
                initials = String(name.prefix(2).uppercased())
            }
            if let e = profile.email { email = e }
            if let created = profile.created_at {
                memberSince = formatDate(created)
            }
        } catch {}
    }

    private func loadGamification() async {
        do {
            let gam = try await APIService.shared.getGamificationProfile()
            level = gam.playerLevel
            levelName = gam.playerLevelName
            xp = gam.xp
            xpForNextLevel = gam.xpForNextLevel
            currentStreak = gam.streak
            longestStreak = gam.bestStreak
            achievements = gam.achievements ?? []
        } catch {}
    }

    private func loadPortfolioCount() async {
        do {
            let dashboard = try await APIService.shared.fetchDashboard()
            portfoliosCount = dashboard.data?.portfolios?.filter { $0.isSubscribed }.count ?? 0
        } catch {}
    }

    private func loadLeagueCount() async {
        leaguesCount = await APIService.shared.fetchLeaguesCount()
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) {
            let out = DateFormatter()
            out.dateFormat = "MMMM yyyy"
            return out.string(from: date)
        }
        return iso
    }
}

// MARK: - Settings View (retained for gear icon)

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            List {
                Section("Account") {
                    Text("Change Password").foregroundColor(.white)
                    Text("Two-Factor Authentication").foregroundColor(.white)
                }
                Section("About") {
                    Text("Terms of Service").foregroundColor(.white)
                    Text("Privacy Policy").foregroundColor(.white)
                    Text("Version 1.0.0").foregroundColor(Theme.textSecondary)
                }
                Section {
                    Button(role: .destructive) {
                        authManager.signOut()
                        dismiss()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                Section("Developer") {
                    Button {
                        authManager.resetAllState()
                        dismiss()
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.orange)
                    }
                    NavigationLink {
                        DebugAPISettingsView()
                    } label: {
                        Label("API Backend", systemImage: "network")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundColor(Theme.primaryBlue)
            }
        }
    }
}

// MARK: - Debug API Settings View

struct DebugAPISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEnvironment: APIConfig.Environment = APIService.shared.currentEnvironment
    @State private var localHost: String = APIConfig.localHost
    @State private var remoteBaseURL: String = APIConfig.remoteBaseURL
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
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("Local Host") {
                TextField("localhost:3000", text: $localHost)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("Simulator: localhost:3000. Device: your Mac LAN IP:3000.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("Remote Base URL") {
                TextField("https://sharequest.co.uk/api", text: $remoteBaseURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section("Actions") {
                Button("Save Settings") {
                    APIService.shared.setAPIEnvironment(selectedEnvironment)
                    APIService.shared.setLocalAPIHost(localHost.trimmingCharacters(in: .whitespacesAndNewlines))
                    APIService.shared.setRemoteBaseURL(remoteBaseURL.trimmingCharacters(in: .whitespacesAndNewlines))
                    selectedEnvironment = APIService.shared.currentEnvironment
                    localHost = APIConfig.localHost
                    remoteBaseURL = APIConfig.remoteBaseURL
                    statusMessage = "Saved. Active base URL: \(APIConfig.mainAppURL)"
                    Task { await runHealthCheck() }
                }
                Button {
                    Task { await runHealthCheck() }
                } label: {
                    if isCheckingHealth {
                        HStack { ProgressView(); Text("Checking...") }
                    } else {
                        Text("Health Check")
                    }
                }
                .disabled(isCheckingHealth)
            }
            if !statusMessage.isEmpty {
                Section("Status") {
                    Text(statusMessage).font(.footnote)
                }
            }
        }
        .navigationTitle("API Backend")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedEnvironment = APIService.shared.currentEnvironment
            localHost = APIConfig.localHost
            remoteBaseURL = APIConfig.remoteBaseURL
        }
    }

    @MainActor
    private func runHealthCheck() async {
        isCheckingHealth = true
        defer { isCheckingHealth = false }
        do {
            let ok = try await APIService.shared.checkAPIHealth()
            statusMessage = ok ? "Health check passed for \(APIConfig.mainAppURL)" : "Health check failed for \(APIConfig.mainAppURL)"
        } catch {
            statusMessage = "Health check error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
