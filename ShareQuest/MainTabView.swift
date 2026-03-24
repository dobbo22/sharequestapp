//
//  MainTabView.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import SwiftUI

/// Main tab navigation - mirrors the React Native app structure
struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .environmentObject(authManager)
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                }
                .tag(0)
            
            PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: selectedTab == 1 ? "briefcase.fill" : "briefcase")
                }
                .tag(1)
            
            StocksView()
                .tabItem {
                    Label("Stocks", systemImage: selectedTab == 2 ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                }
                .tag(2)
            
            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: selectedTab == 3 ? "trophy.fill" : "trophy")
                }
                .tag(3)

            LeaguesView()
                .tabItem {
                    Label("ShareQuests", systemImage: selectedTab == 4 ? "trophy.circle.fill" : "trophy.circle")
                }
                .tag(4)
        }
        .tint(Color(red: 0.29, green: 0.68, blue: 0.91)) // #4AAEE8 active color
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
}
