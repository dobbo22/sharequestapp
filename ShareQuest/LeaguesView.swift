//
//  LeaguesView.swift
//  ShareQuest
//
//  Created by MartinD on 19/03/2026.
//

import SwiftUI
import Combine
import SafariServices

// MARK: - Models

struct League: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let creator_id: String?
    let creator_username: String?
    let member_count: Int?
    let max_members: Int?
    let min_members: Int?
    let is_private: Bool?
    let join_code: String?
    let competition_type: String?
    let status: String?
    let start_date: String?
    let end_date: String?
    let prize_pool: Double?
    let created_at: String?
    let is_member: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case creator_id, creator_username, member_count, max_members, min_members
        case competition_type, start_date, end_date, created_at
        case is_private = "isPrivate"
        case join_code = "code"
        case prize_pool = "prizePool"
        case is_member = "isMember"
    }
}

struct LeagueMember: Codable, Identifiable {
    var id: String { user_id }
    let user_id: String
    let username: String
    let rank: Int?
    let total_value: Double?
    let profit_loss: Double?
    let profit_loss_percent: Double?
}

// MARK: - LeaguesView

struct LeaguesView: View {
    @StateObject private var viewModel = LeaguesViewModel()
    @State private var selectedTab: LeagueTab = .myLeagues
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var selectedLeague: League? = nil
    @State private var showSubscriptions = false
    @State private var isAnnualSubscriber: Bool = false
    @State private var isLoadingSubscription = true

    enum LeagueTab { case myLeagues, discover }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        if isLoadingSubscription {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                                .scaleEffect(1.4)
                                .padding(.top, 60)
                        } else if isAnnualSubscriber {
                            // Subscribed: show leagues only
                            VStack(spacing: 0) {
                                tabSelector
                                leagueListContent
                            }
                        } else {
                            // Not subscribed: show Annual ShareQuest card + Leagues card
                            annualShareQuestCard
                                .padding(.horizontal)
                                .padding(.top, 8)

                            leaguesUpsellCard
                                .padding(.horizontal)
                                .padding(.top, 4)
                        }

                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    await loadData()
                }
            }
            .navigationTitle("ShareQuests")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if isAnnualSubscriber {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            Button { showJoinSheet = true } label: {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(Theme.primaryBlue)
                            }
                            Button { showCreateSheet = true } label: {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(Theme.accentGreen)
                            }
                        }
                    }
                }
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionsView()
                .onDisappear { Task { await refreshSubscription() } }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateLeagueSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinLeagueSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedLeague) { league in
            LeagueDetailSheet(league: league)
        }
    }

    // MARK: Annual ShareQuest Card

    private var annualShareQuestCard: some View {
        let goldColor = Color(red: 0.95, green: 0.65, blue: 0.15)

        return Button {
            if !isAnnualSubscriber { showSubscriptions = true }
        } label: {
            ZStack(alignment: .topTrailing) {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.18, green: 0.12, blue: 0.04), Color(red: 0.38, green: 0.25, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(
                    LinearGradient(
                        colors: [goldColor.opacity(0.15), Color.clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(goldColor.opacity(0.4), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 12) {
                    // Icon + title
                    HStack(spacing: 10) {
                        Image(systemName: "trophy.circle.fill")
                            .font(.system(size: scaled(32)))
                            .foregroundColor(goldColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Annual ShareQuest")
                                .font(.system(size: scaled(20), weight: .bold))
                                .foregroundColor(.white)
                            Text("2026 Competition")
                                .font(.system(size: scaled(12)))
                                .foregroundColor(goldColor.opacity(0.8))
                        }
                        Spacer()
                    }

                    Text("Compete in the year-long trading competition. Best portfolio wins the prize pool.")
                        .font(.system(size: scaled(15)))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)

                    // Prize pool highlight
                    HStack(spacing: 10) {
                        Image(systemName: "sterlingsign.circle.fill")
                            .foregroundColor(goldColor)
                            .font(.system(size: scaled(18)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("50% of every entry fee goes into the prize pool")
                                .font(.system(size: scaled(13), weight: .semibold))
                                .foregroundColor(.white)
                            Text("Real cash prizes paid to the winner")
                                .font(.system(size: scaled(12)))
                                .foregroundColor(goldColor.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(goldColor.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(goldColor.opacity(0.25), lineWidth: 1))

                    // Subscribe CTA
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("£50 / year")
                                .font(.system(size: scaled(15), weight: .bold))
                                .foregroundColor(.white)
                            Text("Tap to subscribe and compete")
                                .font(.system(size: scaled(12)))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(goldColor)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(goldColor.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(goldColor.opacity(0.3), lineWidth: 1))
                }
                .padding(18)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Leagues Upsell Card (non-subscriber)

    private var leaguesUpsellCard: some View {
        let blueColor = Theme.primaryBlue
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: scaled(28)))
                    .foregroundColor(blueColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leagues")
                        .font(.system(size: scaled(20), weight: .bold))
                        .foregroundColor(.white)
                    Text("From £5 to join or create")
                        .font(.system(size: scaled(12)))
                        .foregroundColor(blueColor.opacity(0.9))
                }
                Spacer()
            }

            Text("Create a private league with friends or join a public league open to everyone. Compete to top the leaderboard.")
                .font(.system(size: scaled(15)))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button { showCreateSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create League")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(blueColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                Button { showJoinSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.square.fill")
                        Text("Join League")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.glassBackground)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.glassBorder, lineWidth: 1))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.22))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(blueColor.opacity(0.35), lineWidth: 1))
        )
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 10) {
            tabButton(tab: .myLeagues, icon: "trophy", label: "My Leagues")
            tabButton(tab: .discover, icon: "safari", label: "Discover")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func tabButton(tab: LeagueTab, icon: String, label: String) -> some View {
        Button { selectedTab = tab } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: scaled(12)))
                Text(label).font(.system(size: scaled(15), weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedTab == tab ? Theme.primaryBlue : Theme.glassBackground)
            .foregroundColor(selectedTab == tab ? .white : Theme.textSecondary)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selectedTab == tab ? Theme.primaryBlue : Theme.glassBorder, lineWidth: 1))
        }
    }

    // MARK: League List

    @ViewBuilder
    private var leagueListContent: some View {
        let leagues = selectedTab == .myLeagues ? viewModel.myLeagues : viewModel.publicLeagues

        if viewModel.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                .scaleEffect(1.4)
                .padding(.top, 40)
        } else if let error = viewModel.errorMessage {
            errorView(error)
        } else if leagues.isEmpty {
            emptyView
        } else {
            LazyVStack(spacing: 12) {
                ForEach(leagues) { league in
                    LeagueCard(league: league) { selectedLeague = league }
                }
            }
            .padding(.horizontal)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: scaled(48))).foregroundColor(.red)
            Text(message).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal)
            Button("Retry") { Task { await viewModel.fetchLeagues() } }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Color.red.opacity(0.15)).foregroundColor(.red).cornerRadius(12)
        }
        .padding(.top, 40)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: scaled(64))).foregroundColor(Theme.textMuted)
            Text(selectedTab == .myLeagues ? "No leagues yet" : "No public leagues")
                .font(.system(size: scaled(20), weight: .bold)).foregroundColor(.white)
            Text(selectedTab == .myLeagues
                 ? "Create a league or join one to compete with friends!"
                 : "Check back later for public leagues to join")
                .font(.system(size: scaled(15))).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            if selectedTab == .myLeagues {
                HStack(spacing: 12) {
                    Button { showCreateSheet = true } label: {
                        Label("Create", systemImage: "plus")
                            .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .background(Theme.accentGreen).cornerRadius(12)
                    }
                    Button { showJoinSheet = true } label: {
                        Label("Join", systemImage: "arrow.right.square")
                            .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .background(Theme.primaryBlue).cornerRadius(12)
                    }
                }
            }
        }
        .padding(.top, 40)
    }

    // MARK: Data Loading

    private func loadData() async {
        async let leagues: () = viewModel.fetchLeagues()
        async let sub: () = refreshSubscription()
        _ = await (leagues, sub)
    }

    @MainActor
    private func refreshSubscription() async {
        isLoadingSubscription = true
        let subs = try? await APIService.shared.fetchUserSubscriptions()
        isAnnualSubscriber = subs?.annual ?? false
        isLoadingSubscription = false
    }
}

// MARK: - League Card

struct LeagueCard: View {
    let league: League
    let onTap: () -> Void

    private var iconColor: Color {
        league.is_private == true ? Theme.accentPurple : Theme.primaryBlue
    }

    private var statusColor: Color {
        switch league.status {
        case "active": return Theme.accentGreen
        case "completed": return Theme.textMuted
        case "pending": return Theme.accentYellow
        default: return Theme.textMuted
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(iconColor)
                            .frame(width: 44, height: 44)
                        Image(systemName: league.is_private == true ? "lock.fill" : "person.3.fill")
                            .font(.system(size: scaled(18)))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(league.name)
                            .font(.system(size: scaled(17), weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Text(memberText)
                            .font(.system(size: scaled(12)))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    if let status = league.status {
                        Text(status.capitalized)
                            .font(.system(size: scaled(12), weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(8)
                    }
                }

                if let desc = league.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: scaled(15)))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }

                HStack {
                    if let creator = league.creator_username {
                        Text("By \(creator)")
                            .font(.system(size: scaled(12)))
                            .foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    if let type = league.competition_type {
                        Text(type.capitalized)
                            .font(.system(size: scaled(12), weight: .semibold))
                            .foregroundColor(Theme.accentYellow)
                    }
                    if let code = league.join_code {
                        Text("Code: \(code)")
                            .font(.system(size: scaled(12), weight: .semibold))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .padding(.top, 4)
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var memberText: String {
        let count = league.member_count ?? 0
        if let max = league.max_members {
            return "\(count)/\(max) members"
        }
        return "\(count) members"
    }
}

// MARK: - League Detail Sheet

struct LeagueDetailSheet: View {
    let league: League
    @Environment(\.dismiss) private var dismiss
    @State private var members: [LeagueMember] = []
    @State private var isLoading = true
    @State private var isPaying = false
    @State private var paymentURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var isPaid: Bool? = nil
    @State private var justPaid: Bool = false
    @State private var paymentPollingTask: Task<Void, Never>? = nil
    @State private var selectedMember: LeagueMember? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.118, green: 0.176, blue: 0.243), Color(red: 0.067, green: 0.094, blue: 0.153)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                        .scaleEffect(1.4)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            // Payment success banner — only shown briefly right after payment
                            if justPaid {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: scaled(36)))
                                        .foregroundColor(.green)
                                    Text("Payment Successful!")
                                        .font(.system(size: scaled(17), weight: .bold))
                                        .foregroundColor(.white)
                                    Text("You're in! Share the invite code below.")
                                        .font(.system(size: scaled(15)))
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        withAnimation { justPaid = false }
                                    }
                                }
                            }
                            // Payment button — only show while not paid
                            if isPaid == false && !justPaid {
                                Button(action: onPayButtonTapped) {
                                    HStack {
                                        Image(systemName: "creditcard")
                                        Text(isPaying ? "Opening Payment..." : "Complete Payment")
                                    }
                                    .font(.system(size: scaled(17), weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24).padding(.vertical, 14)
                                    .background(Theme.primaryBlue)
                                    .cornerRadius(12)
                                }
                                .disabled(isPaying)
                            }
                            // Stats
                            HStack(spacing: 10) {
                                statBox(label: "Members", value: "\(league.member_count ?? 0)")
                                if let max = league.max_members {
                                    statBox(label: "Max", value: "\(max)")
                                }
                                if let type = league.competition_type {
                                    statBox(label: "Type", value: type.capitalized)
                                }
                            }
                            .padding(.horizontal)

                            if let desc = league.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: scaled(15)))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                            }

                            // Join code
                            if let code = league.join_code {
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundColor(Theme.primaryBlue)
                                    Text("Join Code: ")
                                        .font(.system(size: scaled(15)))
                                        .foregroundColor(Theme.textSecondary)
                                    Text(code)
                                        .font(.system(size: scaled(15), weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = code
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(Theme.primaryBlue)
                                    }
                                    Button {
                                        let message = "Join my ShareQuest league \"\(league.name)\"! Use code: \(code) 🏆"
                                        let av = UIActivityViewController(activityItems: [message], applicationActivities: nil)
                                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let root = scene.windows.first?.rootViewController {
                                            var top = root
                                            while let presented = top.presentedViewController { top = presented }
                                            top.present(av, animated: true)
                                        }
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(Theme.primaryBlue)
                                    }
                                }
                                .padding()
                                .glassCard()
                                .padding(.horizontal)
                            }

                            // Leaderboard
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Leaderboard")
                                    .font(.system(size: scaled(17), weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal)

                                if members.isEmpty {
                                    Text("No members yet")
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    ForEach(Array(members.enumerated()), id: \.element.user_id) { index, member in
                                        memberRow(member: member, rank: member.rank ?? (index + 1))
                                            .onTapGesture { selectedMember = member }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.top)
                    }
                    // Payment SafariView
                    .sheet(isPresented: Binding(
                        get: { paymentURL != nil },
                        set: { if !$0 { paymentURL = nil } }
                    )) {
                        if let url = paymentURL {
                            SafariView(url: url, onDismiss: {
                                paymentURL = nil
                                justPaid = true
                            })
                            .ignoresSafeArea()
                        }
                    }
                }
            }
            .navigationTitle(league.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.primaryBlue)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedMember) { member in
                LeagueMemberPortfolioSheet(member: member, league: league)
            }
        }
        .task {
            await loadMembers()
            await refreshPaymentStatus()
        }
        .onChange(of: paymentURL) { _, newURL in
            if newURL != nil {
                startPaymentPolling()
            } else {
                paymentPollingTask?.cancel()
            }
        }
    }

    func startPaymentPolling() {
        paymentPollingTask?.cancel()
        paymentPollingTask = Task {
            // Poll every 2s while Safari is open; auto-close after payment confirmed
            for _ in 0..<15 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await refreshPaymentStatus()
                if isPaid == true {
                    justPaid = true
                    paymentURL = nil  // dismisses the sheet
                    return
                }
            }
        }
    }

    func onPayButtonTapped() {
        isPaying = true
        errorMessage = nil
        Task { await startPayment() }
    }

    func startPayment() async {
        isPaying = true
        errorMessage = nil
        do {
            let result = try await APIService.shared.createLeaguePayment(leagueId: league.id)
            if let url = URL(string: result.checkoutUrl) {
                paymentURL = url
            } else {
                errorMessage = "Could not open payment page."
            }
        } catch {
            errorMessage = "Failed to start payment: \(error.localizedDescription)"
        }
        isPaying = false
    }

    func refreshPaymentStatus() async {
        do {
            let paid = try await APIService.shared.checkLeaguePaymentStatus(leagueId: league.id)
            isPaid = paid
        } catch {
            // Ignore error, keep previous state
        }
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
            Text(value).font(.system(size: scaled(15), weight: .bold)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.glassBackground)
        .cornerRadius(12)
    }

    private func memberRow(member: LeagueMember, rank: Int) -> some View {
        let currentUserId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let isUser = member.user_id == currentUserId
        let isMedal = rank <= 3

        func medalGradient(_ r: Int) -> LinearGradient? {
            switch r {
            case 1: return LinearGradient(colors: [Color(red:1.0,green:0.84,blue:0.0), Color(red:0.85,green:0.65,blue:0.13)], startPoint:.topLeading, endPoint:.bottomTrailing)
            case 2: return LinearGradient(colors: [Color(red:0.85,green:0.85,blue:0.92), Color(red:0.60,green:0.60,blue:0.70)], startPoint:.topLeading, endPoint:.bottomTrailing)
            case 3: return LinearGradient(colors: [Color(red:0.80,green:0.50,blue:0.20), Color(red:0.55,green:0.27,blue:0.07)], startPoint:.topLeading, endPoint:.bottomTrailing)
            default: return nil
            }
        }
        func medalGlow(_ r: Int) -> Color {
            switch r {
            case 1: return Color(red:1.0,green:0.84,blue:0.0)
            case 2: return Color(red:0.75,green:0.75,blue:0.85)
            case 3: return Color(red:0.80,green:0.50,blue:0.20)
            default: return .clear
            }
        }

        func formattedValue(_ pence: Double) -> String {
            let pounds = pence / 100.0
            let fmt = NumberFormatter()
            fmt.numberStyle = .decimal
            fmt.minimumFractionDigits = 2
            fmt.maximumFractionDigits = 2
            let s = fmt.string(from: NSNumber(value: pounds)) ?? String(format: "%.2f", pounds)
            return "£\(s)"
        }

        return HStack(spacing: 10) {
            // Rank badge
            ZStack {
                if isMedal, let grad = medalGradient(rank) {
                    Circle()
                        .fill(grad)
                        .frame(width: 40, height: 40)
                        .shadow(color: medalGlow(rank).opacity(0.8), radius: 8, x: 0, y: 0)
                } else {
                    Circle()
                        .fill(isUser ? Theme.primaryBlue.opacity(0.2) : Color.white.opacity(0.07))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(isUser ? Theme.primaryBlue.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1.5))
                }
                Text("\(rank)")
                    .font(.system(size: isMedal ? 14 : 11, weight: .black))
                    .foregroundColor(isMedal ? .black.opacity(0.75) : (isUser ? Theme.primaryBlue : .white.opacity(0.6)))
            }

            // Name
            VStack(alignment: .leading, spacing: 1) {
                if isUser {
                    Text("Your Position")
                        .font(.system(size: scaled(9)))
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(member.username)
                    .font(.system(size: scaled(13), weight: isUser ? .semibold : .medium))
                    .foregroundColor(isUser ? Theme.primaryBlue : .white)
                    .lineLimit(1)
            }

            Spacer()

            // Value + return
            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedValue(member.total_value ?? 10_000_000))
                    .font(.system(size: scaled(12), weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ChangePill(percent: member.profit_loss_percent ?? 0, compact: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            isMedal
                ? LinearGradient(colors: [medalGlow(rank).opacity(0.15), medalGlow(rank).opacity(0.04)], startPoint: .leading, endPoint: .trailing)
                : isUser
                    ? LinearGradient(colors: [Theme.primaryBlue.opacity(0.18), Theme.primaryBlue.opacity(0.06)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)], startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            isMedal ? medalGlow(rank).opacity(0.35) : (isUser ? Theme.primaryBlue.opacity(0.4) : Color.white.opacity(0.08)),
            lineWidth: isMedal ? 1.5 : 1
        ))
    }

    private func loadMembers() async {
        defer { isLoading = false }
        do {
            members = try await APIService.shared.fetchLeagueMembers(leagueId: league.id)
        } catch {
            members = []
        }
    }
}

// MARK: - League Member Portfolio Sheet

struct LeagueMemberPortfolioSheet: View {
    let member: LeagueMember
    let league: League
    @Environment(\.dismiss) private var dismiss
    @State private var portfolio: LeaderboardUserPortfolio? = nil
    @State private var isLoading = true
    @State private var selectedHolding: LeaderboardUserPortfolio.Holding? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary stats
                        HStack(spacing: 10) {
                            statBox(label: "Rank", value: member.rank.map { "#\($0)" } ?? "—")
                            statBox(label: "Total Value", value: formattedPounds(member.total_value ?? 0))
                            statBox(label: "Return", value: member.profit_loss_percent.map { String(format: "%+.2f%%", $0) } ?? "—")
                        }
                        .padding(.horizontal)

                        if let p = portfolio {
                            HStack(spacing: 10) {
                                statBox(label: "Cash", value: formattedPounds(p.cashBalance / 100))
                                statBox(label: "Holdings", value: "\(p.holdings.count)")
                                Spacer().frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Holdings")
                                .font(.system(size: scaled(17), weight: .semibold)).foregroundColor(.white)
                                .padding(.horizontal)

                            if isLoading {
                                HStack { Spacer(); ProgressView().tint(Theme.primaryBlue); Spacer() }.padding()
                            } else if let holdings = portfolio?.holdings, !holdings.isEmpty {
                                ForEach(holdings) { holding in
                                    Button { selectedHolding = holding } label: {
                                        holdingRow(holding: holding)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal)
                                }
                            } else {
                                Text("No holdings").foregroundColor(Theme.textSecondary).padding()
                            }
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("\(member.username)'s Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Theme.primaryBlue)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedHolding) { holding in
                StockDetailView(stock: Stock(
                    id: holding.symbol,
                    symbol: holding.symbol,
                    companyName: holding.companyName ?? holding.symbol,
                    price: holding.currentPrice / 100.0,
                    changeAmount: 0,
                    changePercent: 0,
                    sector: "Portfolio",
                    marketCap: 0
                ))
            }
        }
        .task { await loadPortfolio() }
    }

    private func formattedPounds(_ pence: Double) -> String {
        let pounds = pence / 100.0
        if pounds >= 1_000 { return String(format: "£%.1fK", pounds / 1_000) }
        return String(format: "£%.2f", pounds)
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
            Text(value).font(.system(size: scaled(15), weight: .bold)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    private func holdingRow(holding: LeaderboardUserPortfolio.Holding) -> some View {
        let value = holding.quantity * holding.currentPrice
        let cost = holding.quantity * holding.averagePrice
        let plPercent = cost > 0 ? ((value - cost) / cost) * 100 : 0
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.companyName ?? holding.symbol)
                    .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text("\(holding.symbol) · \(Int(holding.quantity)) shares")
                    .font(.system(size: scaled(12))).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedPounds(value / 100))
                    .font(.system(size: scaled(15), weight: .semibold)).foregroundColor(.white)
                ChangePill(percent: plPercent, compact: true)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func loadPortfolio() async {
        defer { isLoading = false }
        do {
            portfolio = try await APIService.shared.fetchLeagueMemberPortfolio(
                leagueId: league.id,
                memberId: member.user_id
            )
        } catch {
            portfolio = LeaderboardUserPortfolio(rank: member.rank, cashBalance: 0, holdings: [])
        }
    }
}

// MARK: - Create League Sheet

struct CreateLeagueSheet: View {
    @ObservedObject var viewModel: LeaguesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isPrivate = false
    @State private var competitionType = "annual"
    @State private var endDate = Self.defaultEndDate(for: "annual")
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var checkoutURL: URL?
    @State private var pendingLeagueId: String?
    @State private var showPaymentConfirmation = false

    private let competitionTypes = [
        ("annual",  "Annual",  "star.circle.fill",    Color(red: 0.95, green: 0.65, blue: 0.15)),
        ("monthly", "Monthly", "calendar.badge.clock", Color(red: 0.54, green: 0.36, blue: 0.88)),
        // ("weekly", "Weekly", "calendar", Color(red: 0.29, green: 0.68, blue: 0.91)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.067, green: 0.094, blue: 0.153).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        fieldSection(label: "League Name *") {
                            TextField("Enter league name", text: $name)
                                .foregroundColor(.white)
                                .padding()
                                .background(Theme.glassBackground)
                                .cornerRadius(12)
                        }

                        // Description
                        fieldSection(label: "Description") {
                            TextField("Describe your league (optional)", text: $description, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .foregroundColor(.white)
                                .padding()
                                .background(Theme.glassBackground)
                                .cornerRadius(12)
                        }

                        // ShareQuest type picker
                        fieldSection(label: "ShareQuest Type") {
                            VStack(spacing: 0) {
                                ForEach(Array(competitionTypes.enumerated()), id: \.element.0) { idx, item in
                                    let (id, label, icon, color) = item
                                    Button { competitionType = id } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(color.opacity(0.2))
                                                    .frame(width: 36, height: 36)
                                                Image(systemName: icon)
                                                    .font(.system(size: scaled(16)))
                                                    .foregroundColor(color)
                                            }
                                            Text(label)
                                                .font(.system(size: scaled(15))).foregroundColor(.white)
                                            Spacer()
                                            ZStack {
                                                Circle().stroke(competitionType == id ? color : Color.white.opacity(0.3), lineWidth: 2)
                                                    .frame(width: 20, height: 20)
                                                if competitionType == id {
                                                    Circle().fill(color).frame(width: 11, height: 11)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(competitionType == id ? color.opacity(0.08) : Color.clear)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    if idx < competitionTypes.count - 1 {
                                        Divider().background(Color.white.opacity(0.08))
                                    }
                                }
                            }
                            .background(Theme.glassBackground)
                            .cornerRadius(12)
                        }

                        // End date
                        fieldSection(label: "End Date") {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Theme.primaryBlue)
                                DatePicker(
                                    "",
                                    selection: $endDate,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(Theme.primaryBlue)
                                Spacer()
                            }
                            .padding()
                            .background(Theme.glassBackground)
                            .cornerRadius(12)
                        }

                        // Private toggle
                        Button { isPrivate.toggle() } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isPrivate ? Theme.accentPurple.opacity(0.3) : Theme.primaryBlue.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: isPrivate ? "lock.fill" : "globe")
                                        .foregroundColor(isPrivate ? Theme.accentPurple : Theme.primaryBlue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isPrivate ? "Private League" : "Public League")
                                        .font(.system(size: scaled(15), weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(isPrivate ? "Only people with the code can join" : "Anyone can discover and join")
                                        .font(.system(size: scaled(12)))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                // Toggle pill
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isPrivate ? Theme.accentPurple : Theme.glassBackground)
                                    .frame(width: 50, height: 28)
                                    .overlay(
                                        Circle().fill(.white).frame(width: 24, height: 24)
                                            .offset(x: isPrivate ? 11 : -11)
                                    )
                                    .animation(.easeInOut(duration: 0.2), value: isPrivate)
                            }
                            .padding()
                            .glassCard()
                        }
                        .buttonStyle(PlainButtonStyle())

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: scaled(15)))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Create button
                        Button {
                            Task { await create() }
                        } label: {
                            HStack {
                                if isCreating {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create League")
                                }
                            }
                            .font(.system(size: scaled(17), weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.accentGreen.opacity(0.4) : Theme.accentGreen)
                            .cornerRadius(14)
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    }
                    .padding()
                }
            }
            .navigationTitle("Create League")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.primaryBlue)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onChange(of: competitionType) { _, newType in
                endDate = Self.defaultEndDate(for: newType)
            }
            .sheet(item: Binding(
                get: { checkoutURL.map { IdentifiableURL(url: $0) } },
                set: { if $0 == nil { handlePaymentReturn() } }
            )) { identifiable in
                SafariView(url: identifiable.url) { handlePaymentReturn() }
                    .ignoresSafeArea()
            }
            .alert("Payment Confirmed", isPresented: $showPaymentConfirmation) {
                Button("OK") {
                    Task { await viewModel.fetchLeagues() }
                    dismiss()
                }
            } message: {
                Text("Your league has been created and your entry fee paid. Good luck!")
            }
        }
    }

    /// Returns the appropriate default end date for the given competition type.
    /// - Annual: last trading day of the current year (Dec 31, rolling back over weekends)
    /// - Monthly (default): one month from today
    static func defaultEndDate(for type: String) -> Date {
        let cal = Calendar.current
        let today = Date()
        if type == "annual" {
            let year = cal.component(.year, from: today)
            // Dec 31 of current year
            let components = DateComponents(year: year, month: 12, day: 31)
            guard var candidate = cal.date(from: components) else {
                return cal.date(byAdding: .year, value: 1, to: today) ?? today
            }
            // Roll back to last weekday (Mon–Fri) if Dec 31 falls on a weekend
            while cal.isDateInWeekend(candidate) {
                candidate = cal.date(byAdding: .day, value: -1, to: candidate) ?? candidate
            }
            return candidate
        } else {
            return cal.date(byAdding: .month, value: 1, to: today) ?? today
        }
    }

    private func fieldSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: scaled(12), weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            content()
        }
    }

    private func handlePaymentReturn() {
        checkoutURL = nil
        guard let leagueId = pendingLeagueId else { return }
        Task {
            let paid = (try? await APIService.shared.checkLeaguePaymentStatus(leagueId: leagueId)) ?? false
            if paid {
                showPaymentConfirmation = true
            } else {
                errorMessage = "Payment not confirmed yet. Your league is saved — you can pay later from the Leagues screen."
                await viewModel.fetchLeagues()
                dismiss()
            }
        }
    }

    private func create() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        do {
            let result = try await APIService.shared.createLeague(
                name: trimmedName,
                description: description.trimmingCharacters(in: .whitespaces),
                isPrivate: isPrivate,
                competitionType: competitionType,
                endDate: endDate
            )
            if result.requiresPayment {
                pendingLeagueId = result.id
                let payment = try await APIService.shared.createLeaguePayment(leagueId: result.id)
                if let url = URL(string: payment.checkoutUrl) {
                    checkoutURL = url
                } else {
                    errorMessage = "Could not open payment page. League saved — pay from Leagues screen."
                    await viewModel.fetchLeagues()
                    dismiss()
                }
            } else {
                await viewModel.fetchLeagues()
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Join League Sheet

struct JoinLeagueSheet: View {
    @ObservedObject var viewModel: LeaguesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.067, green: 0.094, blue: 0.153).ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("League Code")
                            .font(.system(size: scaled(12), weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        TextField("Enter join code", text: $code)
                            .textInputAutocapitalization(.characters)
                            .foregroundColor(.white)
                            .padding()
                            .background(Theme.glassBackground)
                            .cornerRadius(12)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: scaled(15)))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await join() }
                    } label: {
                        HStack {
                            if isJoining {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.right.square.fill")
                                Text("Join League")
                            }
                        }
                        .font(.system(size: scaled(17), weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(code.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.primaryBlue.opacity(0.4) : Theme.primaryBlue)
                        .cornerRadius(14)
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Join League")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.primaryBlue)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func join() async {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        guard !trimmedCode.isEmpty else { return }
        isJoining = true
        errorMessage = nil
        do {
            try await APIService.shared.joinLeagueByCode(code: trimmedCode)
            await viewModel.fetchLeagues()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isJoining = false
    }
}

// MARK: - ViewModel

@MainActor
class LeaguesViewModel: ObservableObject {
    @Published var myLeagues: [League] = []
    @Published var publicLeagues: [League] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchLeagues() async {
        isLoading = true
        errorMessage = nil
        do {
            myLeagues = try await APIService.shared.fetchUserLeagues()
        } catch {
            errorMessage = "Unable to load leagues"
        }
        isLoading = false
    }
}

#Preview {
    LeaguesView()
}
