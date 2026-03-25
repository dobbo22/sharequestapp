//
//  SubscriptionsView.swift
//  ShareQuest
//
//  Created by MartinD on 19/03/2026.
//

import SwiftUI
import SafariServices
import Combine

// MARK: - Safari Wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: (() -> Void)?
        init(onDismiss: (() -> Void)?) { self.onDismiss = onDismiss }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss?()
        }
    }
}

// MARK: - Plan Model

struct SubscriptionPlan: Identifiable {
    let id: String        // "weekly" | "monthly" | "annual"
    let title: String
    let price: String
    let priceDetail: String
    let amount: Int       // pence
    let color: Color
    let icon: String
    let badge: String?
}

private let plans: [SubscriptionPlan] = [
    // Weekly and Monthly ShareQuests not yet active — re-enable when live
    // SubscriptionPlan(id: "weekly",  title: "Weekly",  price: "£1",   priceDetail: "per week",  amount: 100,  color: Color(red: 0.29, green: 0.68, blue: 0.91), icon: "calendar",            badge: nil),
    // SubscriptionPlan(id: "monthly", title: "Monthly", price: "£5",   priceDetail: "per month", amount: 500,  color: Color(red: 0.54, green: 0.36, blue: 0.88), icon: "calendar.badge.clock", badge: nil),
    SubscriptionPlan(id: "annual",  title: "Annual",  price: "£50",  priceDetail: "per year",  amount: 5000, color: Color(red: 0.95, green: 0.65, blue: 0.15), icon: "star.circle.fill",    badge: nil),
]

// MARK: - ViewModel

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    enum Step { case plans, terms, payment, success }

    @Published var step: Step = .plans
    @Published var selectedPlan: SubscriptionPlan? = nil
    @Published var selectedChoice: String = "current"  // "current" | "next"
    @Published var options: SubscriptionOptionsResponse? = nil
    @Published var loadingOptions = false

    @Published var agreeTerms = false
    @Published var agreePrivacy = false
    @Published var agreeAge = false

    @Published var isLoadingPayment = false
    @Published var checkoutURL: URL? = nil
    @Published var showSafari = false
    @Published var verifyingPayment = false
    @Published var paymentError: String? = nil

    @Published var loadingActive = true   // true on first load so we show skeleton
    @Published var showManage = false
    @Published var actionError: String? = nil

    // Simple boolean status fetched from /mobile/user/subscriptions
    @Published var subStatus: UserSubscriptionsResponse? = nil

    // Store the current Revolut order for payment sheet
    @Published var currentOrder: RevolutOrderResponse? = nil

    // Public leagues for the join section
    @Published var publicLeagues: [League] = []
    @Published var privateLeagues: [League] = []
    @Published var joiningLeagueId: String? = nil
    @Published var joinLeagueError: String? = nil

    var termsValid: Bool { agreeTerms && agreePrivacy && agreeAge }

    func isSubscribed(_ planId: String) -> Bool {
        guard let s = subStatus else { return false }
        switch planId {
        case "weekly":  return s.weekly ?? false
        case "monthly": return s.monthly ?? false
        case "annual":  return s.annual ?? false
        default:        return false
        }
    }

    var anyActive: Bool {
        guard let s = subStatus else { return false }
        return (s.weekly ?? false) || (s.monthly ?? false) || (s.annual ?? false)
    }

    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
        selectedChoice = "current"
        options = nil
        step = .plans  // stay, fetch options
        Task { await fetchOptions(plan: plan) }
    }

    func fetchOptions(plan: SubscriptionPlan) async {
        loadingOptions = true
        defer { loadingOptions = false }
        options = try? await APIService.shared.fetchSubscriptionOptions(plan: plan.id)
    }

    func proceedToTerms() {
        agreeTerms = false; agreePrivacy = false; agreeAge = false
        step = .terms
    }

    func proceedToPayment() {
        step = .payment
        // startPayment() is called by .task on the payment view
    }

    func startPayment() async {
        guard let plan = selectedPlan else { return }
        isLoadingPayment = true
        paymentError = nil
        defer { isLoadingPayment = false }
        do {
            let orderResponse = try await APIService.shared.createSubscriptionOrder(plan: plan.id)
            currentOrder = orderResponse
            // If you still need to show Safari for web checkout, use orderResponse.checkoutUrl
            if let url = URL(string: orderResponse.checkoutUrl) {
                checkoutURL = url
                showSafari = true
            }
        } catch {
            paymentError = "Could not start payment: \(error.localizedDescription)"
        }
    }
    // Called when payment is successful
    func handlePaymentSuccess() async {
        // Refresh user subscriptions and update state
        let updated = try? await APIService.shared.fetchUserSubscriptions()
        subStatus = updated
        await loadManageData()
        step = .success
    }

    func handleSafariDismiss() {
        showSafari = false
        guard let plan = selectedPlan else { return }
        verifyingPayment = true
        Task {
            defer { verifyingPayment = false }
            // Poll up to 6 times (~12s); status endpoint does direct Revolut API
            // verification and self-heals the DB if webhook didn't fire
            for attempt in 1...6 {
                let isPaid = (try? await APIService.shared.checkSubscriptionStatus(plan: plan.id)) ?? false
                if isPaid {
                    let updated = try? await APIService.shared.fetchUserSubscriptions()
                    subStatus = updated
                    await loadManageData()
                    step = .success
                    return
                }
                if attempt < 6 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
            paymentError = "Subscription not confirmed yet. If you completed payment, it may take a moment to activate. You can close this and refresh."
        }
    }

    func loadManageData() async {
        loadingActive = true
        defer { loadingActive = false }
        // Only use the mobile endpoint — web-only endpoints (/api/subscriptions,
        // /api/subscriptions/auto-renew) require NextAuth session cookies and
        // always return 401 from a Bearer-token mobile client.
        async let statusFetch = APIService.shared.fetchUserSubscriptions()
        async let publicFetch = (try? APIService.shared.fetchPublicLeagues()) ?? []
        async let privateFetch = (try? APIService.shared.fetchUserLeagues()) ?? []
        let (status, publicList, userLeagues) = await (try? statusFetch, publicFetch, privateFetch)
        subStatus = status
        publicLeagues = publicList.filter { !($0.is_member ?? false) }
        // myLeagues are all from private_leagues table — show all of them
        privateLeagues = userLeagues
    }

    func joinLeague(_ league: League) {
        joiningLeagueId = league.id
        joinLeagueError = nil
        Task {
            defer { joiningLeagueId = nil }
            do {
                if let code = league.join_code, !code.isEmpty {
                    try await APIService.shared.joinLeagueByCode(code: code)
                }
                // Refresh leagues list after joining
                publicLeagues = ((try? await APIService.shared.fetchPublicLeagues()) ?? []).filter { !($0.is_member ?? false) }
            } catch {
                joinLeagueError = error.localizedDescription
            }
        }
    }

    func resetFlow() {
        step = .plans
        selectedPlan = nil
        agreeTerms = false; agreePrivacy = false; agreeAge = false
        paymentError = nil; checkoutURL = nil
    }
}

// MARK: - Main View

struct SubscriptionsView: View {
    var selectedTab: Binding<Int>? = nil
    var onNavigateAway: (() -> Void)? = nil   // called to also dismiss parent sheet
    @StateObject private var vm = SubscriptionsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLeague: League? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.059, green: 0.090, blue: 0.165),
                        Color(red: 0.118, green: 0.227, blue: 0.373),
                        Color(red: 0.345, green: 0.110, blue: 0.529)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Group {
                    switch vm.step {
                    case .plans:   planSelectionView
                    case .terms:   termsView
                    case .payment: nativePaymentSheetView
                    case .success: successView
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if vm.step != .success {
                        Button { handleBack() } label: {
                            Image(systemName: vm.step == .plans ? "xmark" : "chevron.left")
                                .foregroundColor(.white)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.step == .plans {
                        Button("Manage") { vm.showManage = true }
                            .foregroundColor(Theme.primaryBlue)
                    }
                }
            }
            .sheet(isPresented: $vm.showManage) {
                ManageSubscriptionsSheet(vm: vm)
            }
            .sheet(item: $selectedLeague) { league in
                LeagueDetailSheet(league: league)
            }
        }
        .task { await vm.loadManageData() }
    }

    private var navTitle: String {
        switch vm.step {
        case .plans:   return "Subscriptions"
        case .terms:   return "Terms & Conditions"
        case .payment: return "Payment"
        case .success: return "All Set!"
        }
    }

    private func handleBack() {
        switch vm.step {
        case .plans:   dismiss()
        case .terms:   vm.step = .plans
        case .payment: vm.step = .terms
        case .success: break
        }
    }

    // MARK: - Plan Selection

    private var planSelectionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.accentYellow)
                    Text("Join the ShareQuests")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    Text("Subscribe to enter competitions and win real prizes, or join a public league.")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 8)

                // Status loading indicator or active summary
                if vm.loadingActive {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8).tint(Theme.textSecondary)
                        Text("Checking your subscriptions...")
                            .font(.caption).foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal)
                } else if vm.anyActive {
                    activeStatusBanner
                        .padding(.horizontal)
                }

                // Plan Cards
                VStack(spacing: 14) {
                    ForEach(plans) { plan in
                        PlanCard(
                            plan: plan,
                            isSelected: vm.selectedPlan?.id == plan.id,
                            isActive: vm.isSubscribed(plan.id)
                        ) {
                            vm.selectPlan(plan)
                        }
                    }
                }
                .padding(.horizontal)

                // Competition Options (when plan selected and not already active)
                if let plan = vm.selectedPlan, !vm.isSubscribed(plan.id) {
                    competitionOptions(for: plan)
                        .padding(.horizontal)
                }

                // CTA Button
                if let plan = vm.selectedPlan {
                    if vm.isSubscribed(plan.id) {
                        Button {
                            NotificationCenter.default.post(name: .selectPortfolioType, object: PortfolioType.annual)
                            selectedTab?.wrappedValue = 1  // Portfolio tab
                            dismiss()
                            onNavigateAway?()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "briefcase.fill")
                                Text("Go to Annual Portfolio")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(plan.color)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)
                    } else {
                        Button { vm.proceedToTerms() } label: {
                            Text("Subscribe \(plan.title) – \(plan.price)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(plan.color)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal)
                    }
                }

                // Private Leagues
                if !vm.privateLeagues.isEmpty {
                    privateLeaguesSection
                        .padding(.horizontal)
                }

                // Public Leagues
                if !vm.publicLeagues.isEmpty || vm.loadingActive {
                    publicLeaguesSection
                        .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
    }

    private var privateLeaguesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PRIVATE LEAGUES")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.textMuted)
                Spacer()
                NavigationLink(destination: LeaguesView()) {
                    Text("See All")
                        .font(.caption).foregroundColor(Theme.primaryBlue)
                }
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(vm.privateLeagues.prefix(5).enumerated()), id: \.element.id) { idx, league in
                    if idx > 0 { Divider().background(Color.white.opacity(0.08)) }
                    Button { selectedLeague = league } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accentPurple.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.accentPurple)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(league.name)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text("\(league.member_count ?? 0)/\(league.max_members ?? 50) members")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                    if let status = league.status {
                                        Text("•").font(.caption2).foregroundColor(Theme.textMuted)
                                        Text(status.capitalized)
                                            .font(.caption2)
                                            .foregroundColor(status == "active" ? Theme.accentGreen : Theme.textSecondary)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private var publicLeaguesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PUBLIC LEAGUES")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.textMuted)
                Spacer()
                NavigationLink(destination: LeaguesView()) {
                    Text("See All")
                        .font(.caption).foregroundColor(Theme.primaryBlue)
                }
            }
            .padding(.leading, 4)

            if vm.loadingActive {
                HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.publicLeagues.prefix(5).enumerated()), id: \.element.id) { idx, league in
                        if idx > 0 { Divider().background(Color.white.opacity(0.08)) }
                        PublicLeagueRow(
                            league: league,
                            isJoining: vm.joiningLeagueId == league.id,
                            onJoin: { vm.joinLeague(league) },
                            onTap: { selectedLeague = league }
                        )
                    }
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }

            if let err = vm.joinLeagueError {
                Text(err)
                    .font(.caption).foregroundColor(Theme.accentRed)
                    .padding(.leading, 4)
            }
        }
    }

    private var activeStatusBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR ACTIVE PLANS")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(Theme.textMuted)
                .padding(.leading, 4)

            HStack(spacing: 8) {
                ForEach(plans.filter { vm.isSubscribed($0.id) }) { plan in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(plan.color)
                        Text(plan.title)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(plan.color.opacity(0.15))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(plan.color.opacity(0.3), lineWidth: 1))
                }
                Spacer()
                Button("Manage") { vm.showManage = true }
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.primaryBlue)
            }
        }
    }

    @ViewBuilder
    private func competitionOptions(for plan: SubscriptionPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPETITION ENTRY")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(Theme.textMuted)
                .padding(.leading, 4)

            if vm.loadingOptions {
                HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                    .padding()
            } else if let opts = vm.options {
                VStack(spacing: 8) {
                    if let cur = opts.current {
                        OptionRow(
                            label: "Current competition",
                            detail: cur.label ?? "Now",
                            isSelected: vm.selectedChoice == "current"
                        ) { vm.selectedChoice = "current" }
                    }
                    if let nxt = opts.next {
                        OptionRow(
                            label: "Next competition",
                            detail: nxt.label ?? "Upcoming",
                            isSelected: vm.selectedChoice == "next"
                        ) { vm.selectedChoice = "next" }
                    }
                    if opts.current == nil && opts.next == nil {
                        Text("Enter the current \(plan.title.lowercased()) competition")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .padding()
                    }
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            } else {
                Text("Join the current \(plan.title.lowercased()) competition")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Terms View

    private var termsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.primaryBlue)
                    Text("Before you continue")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    Text("Please review and accept our terms to proceed with your subscription.")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 8)

                VStack(spacing: 0) {
                    TermsRow(
                        isChecked: $vm.agreeTerms,
                        text: "I have read and agree to the ",
                        link: "Terms of Service",
                        url: "https://sharequest.co.uk/terms"
                    )
                    Divider().background(Color.white.opacity(0.08))
                    TermsRow(
                        isChecked: $vm.agreePrivacy,
                        text: "I have read and agree to the ",
                        link: "Privacy Policy",
                        url: "https://sharequest.co.uk/privacy"
                    )
                    Divider().background(Color.white.opacity(0.08))
                    CheckRow(isChecked: $vm.agreeAge, text: "I confirm I am 18 years of age or older")
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal)

                Button {
                    vm.proceedToPayment()
                } label: {
                    Text("Continue to Payment")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(vm.termsValid ? Theme.primaryBlue : Color.gray.opacity(0.3))
                        .cornerRadius(14)
                }
                .disabled(!vm.termsValid)
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Native Payment Sheet View
    @ViewBuilder
    private var nativePaymentSheetView: some View {
        if let plan = vm.selectedPlan, let order = vm.currentOrder {
            NativePaymentSheet(
                plan: plan,
                order: order,
                onSuccess: {
                    Task { await vm.handlePaymentSuccess() }
                },
                onError: { error in
                    vm.paymentError = error
                }
            )
        } else {
            ProgressView().scaleEffect(1.4).tint(.white)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accentGreen.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.accentGreen)
            }

            VStack(spacing: 10) {
                Text("You're in!")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Your \(vm.selectedPlan?.title ?? "") subscription is now active. Good luck in the competition!")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                dismiss()
            } label: {
                Text("Start Trading")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accentGreen)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Sub-components

private struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(plan.color.opacity(0.2))
                        .frame(width: 46, height: 46)
                    Image(systemName: plan.icon)
                        .font(.system(size: 20))
                        .foregroundColor(plan.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.title)
                            .font(.headline).foregroundColor(.white)
                        if isActive {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                Text("Active")
                                    .font(.caption2).fontWeight(.semibold)
                            }
                            .foregroundColor(Theme.accentGreen)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.accentGreen.opacity(0.15))
                            .cornerRadius(4)
                        } else if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(plan.color)
                                .cornerRadius(4)
                        }
                    }
                    Text("\(plan.price) \(plan.priceDetail)")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textMuted)
                } else {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? plan.color : Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle()
                                .fill(plan.color)
                                .frame(width: 13, height: 13)
                        }
                    }
                }
            }
            .padding(14)
            .background(isActive ? plan.color.opacity(0.07) : isSelected ? plan.color.opacity(0.1) : Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? Theme.accentGreen.opacity(0.4) : isSelected ? plan.color : Color.white.opacity(0.08),
                            lineWidth: (isActive || isSelected) ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct OptionRow: View {
    let label: String
    let detail: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline).foregroundColor(.white)
                    Text(detail)
                        .font(.caption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.primaryBlue : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(Theme.primaryBlue).frame(width: 11, height: 11)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct TermsRow: View {
    @Binding var isChecked: Bool
    let text: String
    let link: String
    let url: String
    @State private var showSafari = false

    private var termsAttributedString: AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = UIColor(Theme.textSecondary)
        var linked = AttributedString(link)
        linked.foregroundColor = UIColor(Theme.primaryBlue)
        linked.underlineStyle = .single
        result.append(linked)
        return result
    }

    var body: some View {
        HStack(spacing: 12) {
            CheckboxButton(isChecked: $isChecked)
            Text(termsAttributedString)
                .font(.subheadline)
                .onTapGesture { showSafari = true }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .sheet(isPresented: $showSafari) {
            if let u = URL(string: url) {
                SafariView(url: u).ignoresSafeArea()
            }
        }
    }
}

private struct CheckRow: View {
    @Binding var isChecked: Bool
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            CheckboxButton(isChecked: $isChecked)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

private struct CheckboxButton: View {
    @Binding var isChecked: Bool

    var body: some View {
        Button { isChecked.toggle() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isChecked ? Theme.primaryBlue : Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isChecked {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.primaryBlue)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Manage Subscriptions Sheet

struct ManageSubscriptionsSheet: View {
    @ObservedObject var vm: SubscriptionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showWebManage = false

    private var activePlans: [SubscriptionPlan] {
        plans.filter { vm.isSubscribed($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.059, green: 0.090, blue: 0.165),
                        Color(red: 0.118, green: 0.227, blue: 0.373)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if vm.loadingActive {
                    ProgressView().tint(.white)
                } else if activePlans.isEmpty {
                    emptyState
                } else {
                    activeList
                }
            }
            .navigationTitle("My Subscriptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Theme.primaryBlue)
                }
            }
        }
        .task { await vm.loadManageData() }
        .sheet(isPresented: $showWebManage) {
            if let url = URL(string: "\(APIConfig.remoteBaseURL.replacingOccurrences(of: "/api", with: ""))/subscription/manage") {
                SafariView(url: url) {
                    // Refresh status when returning from web manage
                    Task { await vm.loadManageData() }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 44))
                .foregroundColor(Theme.textMuted)
            Text("No Active Subscriptions")
                .font(.headline).foregroundColor(.white)
            Text("Subscribe to a plan to enter competitions.")
                .font(.subheadline).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var activeList: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(activePlans) { plan in
                    ActivePlanCard(plan: plan)
                }

                // Web manage link — cancel/auto-renew require session auth on web
                Button { showWebManage = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "safari")
                        Text("Manage on sharequest.co.uk")
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.primaryBlue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.primaryBlue.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

private struct ActivePlanCard: View {
    let plan: SubscriptionPlan

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(plan.color.opacity(0.2))
                    .frame(width: 46, height: 46)
                Image(systemName: plan.icon)
                    .font(.system(size: 20))
                    .foregroundColor(plan.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title + " Plan")
                    .font(.headline).foregroundColor(.white)
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.accentGreen)
                    Text("Active")
                        .font(.caption).foregroundColor(Theme.accentGreen)
                }
            }

            Spacer()

            Text(plan.price)
                .font(.headline).foregroundColor(plan.color)
        }
        .padding(14)
        .background(plan.color.opacity(0.07))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentGreen.opacity(0.3), lineWidth: 1.5))
    }
}

// MARK: - Public League Row

private struct PublicLeagueRow: View {
    let league: League
    let isJoining: Bool
    let onJoin: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.29, green: 0.68, blue: 0.91).opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: league.is_private == true ? "lock.fill" : "person.3.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.29, green: 0.68, blue: 0.91))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(league.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(league.member_count ?? 0) members")
                        .font(.caption).foregroundColor(Theme.textMuted)
                    if let maxM = league.max_members {
                        Text("/ \(maxM)")
                            .font(.caption).foregroundColor(Theme.textMuted)
                    }
                    if let type = league.competition_type, !type.isEmpty {
                        Text("•").font(.caption).foregroundColor(Theme.textMuted)
                        Text(type.capitalized).font(.caption).foregroundColor(Theme.textMuted)
                    }
                }
            }

            Spacer()

            Button(action: onJoin) {
                if isJoining {
                    ProgressView().scaleEffect(0.75).tint(.white).frame(width: 60)
                } else {
                    Text("Join")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color(red: 0.29, green: 0.68, blue: 0.91))
                        .cornerRadius(8)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SubscriptionsView()
}
