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
    let is_private: Bool?
    let join_code: String?
    let competition_type: String?
    let status: String?
    let start_date: String?
    let end_date: String?
    let prize_pool: Double?
    let created_at: String?
    let is_member: Bool?
}

struct LeagueMember: Codable {
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

    enum LeagueTab { case myLeagues, discover }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.primaryGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabSelector
                    leagueList
                }
            }
            .navigationTitle("Leagues")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
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
        .task { await viewModel.fetchLeagues() }
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
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedTab == tab ? Theme.primaryBlue : Theme.glassBackground)
            .foregroundColor(selectedTab == tab ? .white : Theme.textSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedTab == tab ? Theme.primaryBlue : Theme.glassBorder, lineWidth: 1)
            )
        }
    }

    // MARK: League List

    @ViewBuilder
    private var leagueList: some View {
        let leagues = selectedTab == .myLeagues ? viewModel.myLeagues : viewModel.publicLeagues

        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                .scaleEffect(1.4)
            Spacer()
        } else if let error = viewModel.errorMessage {
            errorView(error)
        } else if leagues.isEmpty {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(leagues) { league in
                        LeagueCard(league: league) {
                            selectedLeague = league
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
            .refreshable { await viewModel.fetchLeagues() }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") { Task { await viewModel.fetchLeagues() } }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(12)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.3")
                .font(.system(size: 64))
                .foregroundColor(Theme.textMuted)
            Text(selectedTab == .myLeagues ? "No leagues yet" : "No public leagues")
                .font(.title3).fontWeight(.bold).foregroundColor(.white)
            Text(selectedTab == .myLeagues
                ? "Create a league or join one to compete with friends!"
                : "Check back later for public leagues to join")
                .font(.subheadline).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            if selectedTab == .myLeagues {
                HStack(spacing: 12) {
                    Button { showCreateSheet = true } label: {
                        Label("Create", systemImage: "plus")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .background(Theme.accentGreen)
                            .cornerRadius(12)
                    }
                    Button { showJoinSheet = true } label: {
                        Label("Join", systemImage: "arrow.right.square")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .background(Theme.primaryBlue)
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 8)
            }
            Spacer()
        }
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
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(league.name)
                            .font(.headline).fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Text(memberText)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    if let status = league.status {
                        Text(status.capitalized)
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(8)
                    }
                }

                if let desc = league.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }

                HStack {
                    if let creator = league.creator_username {
                        Text("By \(creator)")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    if let type = league.competition_type {
                        Text(type.capitalized)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(Theme.accentYellow)
                    }
                    if let code = league.join_code {
                        Text("Code: \(code)")
                            .font(.caption).fontWeight(.semibold)
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
                                    .font(.subheadline)
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
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    Text(code)
                                        .font(.subheadline).fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = code
                                    } label: {
                                        Image(systemName: "doc.on.doc")
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
                                    .font(.headline).fontWeight(.bold)
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
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.top)
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
        }
        .task { await loadMembers() }
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundColor(Theme.textSecondary)
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.glassBackground)
        .cornerRadius(12)
    }

    private func memberRow(member: LeagueMember, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                Circle()
                    .fill(Theme.primaryBlue.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(Theme.primaryBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.username)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.white)
                if let plPercent = member.profit_loss_percent {
                    ChangePill(percent: plPercent)
                }
            }

            Spacer()

            if let value = member.total_value {
                Text("£\(String(format: "%.2f", value / 100))")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Theme.glassBackground)
        .cornerRadius(12)
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

// MARK: - Create League Sheet

struct CreateLeagueSheet: View {
    @ObservedObject var viewModel: LeaguesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isPrivate = false
    @State private var competitionType = "annual"
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
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
                                                    .font(.system(size: 16))
                                                    .foregroundColor(color)
                                            }
                                            Text(label)
                                                .font(.subheadline).foregroundColor(.white)
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
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text(isPrivate ? "Only people with the code can join" : "Anyone can discover and join")
                                        .font(.caption)
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
                                .font(.subheadline)
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
                            .font(.headline)
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

    private func fieldSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption).fontWeight(.semibold)
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
                            .font(.caption).fontWeight(.semibold)
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
                            .font(.subheadline)
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
                        .font(.headline)
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
