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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Page content — extend under the tab bar using ignoresSafeArea
            Group {
                switch selectedTab {
                case 0: DashboardView(selectedTab: $selectedTab).environmentObject(authManager)
                case 1: PortfolioView()
                case 2: StocksView()
                case 3: LeaderboardView()
                case 4: LeaguesView()
                default: DashboardView(selectedTab: $selectedTab).environmentObject(authManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                // Reserve space so content isn't hidden behind the bar
                Color.clear.frame(height: tabBarHeight)
            }

            customTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Custom Tab Bar

    private var tabBarHeight: CGFloat { 60 }

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

    // Extra bottom padding for devices with a home indicator
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
