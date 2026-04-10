import SwiftUI

private extension Color {
    static let kcNavy  = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let kcLime  = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let kcCard  = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let kcMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
}

// MARK: - Tab definition
private enum KCTab: CaseIterable {
    case dashboard, collection, settings, dev

    var label: String {
        switch self {
        case .dashboard:  return "Dashboard"
        case .collection: return "Collection"
        case .settings:   return "Settings"
        case .dev:        return "Dev"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:  return "rectangle.grid.2x2.fill"
        case .collection: return "square.grid.3x3.fill"
        case .settings:   return "slider.horizontal.3"
        case .dev:        return "arrow.counterclockwise.circle.fill"
        }
    }
}

// MARK: - Custom tab bar
private struct KCTabBar: View {
    @Binding var selected: KCTab
    var isAdmin: Bool

    var visibleTabs: [KCTab] {
        KCTab.allCases.filter { tab in
            if tab == .dev { return isAdmin || FootballAPIClient.shared.isUsingLocalEnvironment }
            return true
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selected == tab ? .bold : .regular))
                            .foregroundStyle(selected == tab ? Color.kcLime : Color.kcMuted)
                        Text(tab.label)
                            .font(.system(size: 10, weight: selected == tab ? .semibold : .regular))
                            .foregroundStyle(selected == tab ? Color.kcLime : Color.kcMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .background(
            Color.kcCard
                .ignoresSafeArea(edges: .bottom)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.white.opacity(0.07)),
                    alignment: .top
                )
        )
    }
}

// MARK: - Root view
struct FootballRootView: View {
    @EnvironmentObject private var session: FootballSessionViewModel
    @StateObject private var bootstrapViewModel = FootballBootstrapViewModel()
    @StateObject private var profileViewModel = FootballProfileViewModel()
    @State private var selectedTab: KCTab = .dashboard

    private func openCollectionTab() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTab = .collection
        }
    }

    var body: some View {
        Group {
            if !session.isAuthenticated {
                FootballLoginView()
            } else if profileViewModel.isLoadingProfile && profileViewModel.profileData == nil {
                ZStack {
                    Color.kcNavy.ignoresSafeArea()
                    ProgressView()
                        .tint(Color.kcLime)
                }
            } else if let profile = profileViewModel.profile, !profile.hasCompletedOnboarding {
                FootballOnboardingView(
                    profileViewModel: profileViewModel,
                    suggestedDisplayName: session.currentUser?.displayName ?? profile.displayName ?? ""
                )
            } else {
                mainTabView
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FootballEnvironmentBadge(
                label: FootballAPIClient.shared.environmentLabel,
                isLocal: FootballAPIClient.shared.isUsingLocalEnvironment
            )
            .padding(.trailing, 16)
            .padding(.bottom, 72)
        }
        .task(id: session.currentUser?.id) {
            guard session.isAuthenticated else { return }
            await bootstrapViewModel.refreshAll()
            await profileViewModel.refreshAll()
            await session.restoreSession()
        }
        .fullScreenCover(item: $profileViewModel.pendingRevealAllocation) { allocation in
            FootballPackRevealView(
                cards: profileViewModel.profileData?.starterPackCards ?? [],
                packId: allocation.starterPackId
            ) {
                selectedTab = .dashboard
                profileViewModel.markRevealPresented()
            }
        }
    }

    private var mainTabView: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.kcNavy.ignoresSafeArea()

                switch selectedTab {
                case .dashboard:
                    FootballDashboardView(
                        bootstrapViewModel: bootstrapViewModel,
                        profileViewModel: profileViewModel,
                        openCollection: openCollectionTab
                    )
                case .collection:
                    FootballCollectionView()
                case .settings:
                    FootballSettingsView()
                case .dev:
                    FootballDevResetView(profileViewModel: profileViewModel)
                }
            }

            KCTabBar(selected: $selectedTab, isAdmin: session.isAdmin)
        }
    }
}

#Preview {
    FootballRootView()
        .environmentObject(FootballSessionViewModel())
}
