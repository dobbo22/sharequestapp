//
//  MainTabView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0

    private let tabs: [(label: String, icon: String, activeIcon: String)] = [
        ("Home",        "square.grid.2x2",          "square.grid.2x2.fill"),
        ("Portfolio",   "briefcase",                 "briefcase.fill"),
        ("Stocks",      "chart.line.uptrend.xyaxis", "chart.line.uptrend.xyaxis"),
        ("Leaderboard", "trophy",                    "trophy.fill"),
        ("Leagues",     "trophy.circle",             "trophy.circle.fill"),
    ]

    /// Pick a Dynamic Type size based on screen width.
    /// Also caps maximum so accessibility settings don't balloon the UI.
    private var dynamicTypeSize: DynamicTypeSize {
        let width = (UIScreen.screens.first ?? UIScreen()).bounds.width
        if width >= 430 { return .large }   // Pro Max / Plus — step up one size
        return .medium                      // Pro and smaller — system default
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keep TabView so each tab's NavigationStack is preserved
            TabView(selection: $selectedTab) {
                DashboardView(selectedTab: $selectedTab)
                    .environmentObject(authManager)
                    .tag(0)

                PortfolioView()
                    .tag(1)

                StocksView()
                    .tag(2)

                LeaderboardView()
                    .tag(3)

                LeaguesView()
                    .tag(4)
            }
            // Hide the system tab bar — we draw our own below
            .toolbar(.hidden, for: .tabBar)
            // Cap range: never smaller than .small, never larger than .xLarge
            // so system accessibility settings don't blow up the layout
            .dynamicTypeSize(.small ... .xLarge)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            // Push content up so it isn't hidden behind the custom bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 60)
            }

            customTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                tabButton(index: i)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, bottomPadding)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea(edges: .bottom)
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
    }

    private func tabButton(index: Int) -> some View {
        let tab = tabs[index]
        let isSelected = selectedTab == index
        let activeColor = Color(red: 0.29, green: 0.68, blue: 0.91)
        let inactiveColor = Color(red: 0.55, green: 0.58, blue: 0.63)

        return Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.activeIcon : tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? activeColor : inactiveColor)
                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? activeColor : inactiveColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var bottomPadding: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0) > 0 ? 16 : 8
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
}
