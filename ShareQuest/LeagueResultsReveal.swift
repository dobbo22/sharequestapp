//
//  LeagueResultsReveal.swift
//  ShareQuest
//
//  Full-screen animated podium shown once when a completed league is first opened.
//  Persists dismissal in UserDefaults so it never shows again for the same league.
//

import SwiftUI

// MARK: - Entry point helper

/// Call this from LeagueDetailSheet to decide whether to show the reveal.
/// Returns true only the first time a completed league is opened.
func shouldShowResultsReveal(for leagueId: String) -> Bool {
    let key = "resultsRevealSeen_\(leagueId)"
    return !UserDefaults.standard.bool(forKey: key)
}

func markResultsRevealSeen(for leagueId: String) {
    UserDefaults.standard.set(true, forKey: "resultsRevealSeen_\(leagueId)")
}

// MARK: - LeagueResultsRevealView

struct LeagueResultsRevealView: View {
    let league: League
    let members: [LeagueMember]   // already sorted by rank (rank 1 first)
    let onDismiss: () -> Void

    private var currentUserId: String { KeychainHelper.read("user_id") ?? "" }

    // Animation state
    @State private var showBackground  = false
    @State private var showTitle       = false
    @State private var showPodium      = false
    @State private var showRest        = false
    @State private var showButton      = false
    @State private var showConfetti    = false
    @State private var podiumHeights: [CGFloat] = [0, 0, 0]

    // Medal colours
    private let goldGrad   = LinearGradient(colors: [Color(red:1.0,  green:0.84, blue:0.0),   Color(red:0.85, green:0.65, blue:0.13)], startPoint:.topLeading, endPoint:.bottomTrailing)
    private let silverGrad = LinearGradient(colors: [Color(red:0.85, green:0.85, blue:0.92),  Color(red:0.60, green:0.60, blue:0.70)], startPoint:.topLeading, endPoint:.bottomTrailing)
    private let bronzeGrad = LinearGradient(colors: [Color(red:0.80, green:0.50, blue:0.20),  Color(red:0.55, green:0.27, blue:0.07)], startPoint:.topLeading, endPoint:.bottomTrailing)

    private func medalGrad(_ rank: Int) -> LinearGradient {
        switch rank { case 1: return goldGrad; case 2: return silverGrad; default: return bronzeGrad }
    }
    private func medalGlow(_ rank: Int) -> Color {
        switch rank { case 1: return Color(red:1.0,green:0.84,blue:0.0); case 2: return Color(red:0.75,green:0.75,blue:0.85); default: return Color(red:0.80,green:0.50,blue:0.20) }
    }
    private func podiumTargetHeight(_ rank: Int) -> CGFloat {
        switch rank { case 1: return 120; case 2: return 90; default: return 70 }
    }

    // Display order on podium: 2nd left, 1st centre, 3rd right
    private var podiumOrder: [(member: LeagueMember, rank: Int)] {
        let top3 = members.prefix(3)
        var ordered: [(LeagueMember, Int)] = []
        if top3.count >= 2 { ordered.append((top3[1], 2)) }
        if top3.count >= 1 { ordered.append((top3[0], 1)) }
        if top3.count >= 3 { ordered.append((top3[2], 3)) }
        return ordered.map { (member: $0.0, rank: $0.1) }
    }

    private func prize(for rank: Int) -> String? {
        guard let pool = league.prize_pool, pool > 0 else { return nil }
        let dist: [Double] = [0.5, 0.3, 0.2]
        guard rank >= 1 && rank <= 3 else { return nil }
        let amount = pool * dist[rank - 1]
        if amount >= 100 { return "£\(Int(amount))" }
        return String(format: "£%.2f", amount)
    }

    private func formatValue(_ pence: Double) -> String {
        let pounds = pence / 100.0
        if pounds >= 1_000_000 { return String(format: "£%.2fM", pounds / 1_000_000) }
        if pounds >= 1_000 { return String(format: "£%.1fK", pounds / 1_000) }
        return String(format: "£%.0f", pounds)
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.14),
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    Color(red: 0.04, green: 0.06, blue: 0.14)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(showBackground ? 1 : 0)

            // Glass overlay for frosted effect
            if showBackground, #available(iOS 15.0, *) {
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    .ignoresSafeArea()
                    .opacity(0.7)
            }

            // Confetti layer — shown after podium rises
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {

                // ── Title ─────────────────────────────────────────────────
                VStack(spacing: 8) {
                    Text("🏆")
                        .font(.system(size: scaled(52)))
                    Text("Final Results")
                        .font(.system(size: scaled(28), weight: .black))
                        .foregroundColor(.white)
                    Text(league.name)
                        .font(.system(size: scaled(15), weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : -20)
                .padding(.top, 60)
                .padding(.bottom, 32)

                // ── Podium ────────────────────────────────────────────────
                if !podiumOrder.isEmpty {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(Array(podiumOrder.enumerated()), id: \.offset) { index, entry in
                            podiumSlot(entry.member, rank: entry.rank, animIndex: index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(showPodium ? 1 : 0)
                }

                // ── Rest of leaderboard ───────────────────────────────────
                if members.count > 3 {
                    VStack(spacing: 0) {
                        Text("Other Results")
                            .font(.system(size: scaled(13), weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 28)
                            .padding(.bottom, 10)

                        VStack(spacing: 6) {
                            ForEach(Array(members.dropFirst(3).enumerated()), id: \.element.user_id) { i, member in
                                ZStack {
                                    if #available(iOS 15.0, *) {
                                        VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .opacity(0.85)
                                    }
                                    restRow(member, rank: (member.rank ?? (i + 4)))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .opacity(showRest ? 1 : 0)
                    .offset(y: showRest ? 0 : 20)
                }

                Spacer()

                // ── Dismiss button ────────────────────────────────────────
                Button {
                    markResultsRevealSeen(for: league.id)
                    onDismiss()
                } label: {
                    Text("View Full Leaderboard")
                        .font(.system(size: scaled(17), weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primaryBlue)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                }
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear { runEntrance() }
    }

    // ── Podium slot ───────────────────────────────────────────────────────

    @ViewBuilder
    private func podiumSlot(_ member: LeagueMember, rank: Int, animIndex: Int) -> some View {
        let isUser = member.user_id == currentUserId
        let glow = medalGlow(rank)

        VStack(spacing: 6) {
            // Username
            Text(isUser ? "You" : member.username)
                .font(.system(size: scaled(rank == 1 ? 13 : 11), weight: .bold))
                .foregroundColor(isUser ? Theme.primaryBlue : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Prize amount
            if let prize = prize(for: rank) {
                Text(prize)
                    .font(.system(size: scaled(12), weight: .black))
                    .foregroundColor(glow)
            }

            // Portfolio value
            if let val = member.total_value {
                Text(formatValue(val))
                    .font(.system(size: scaled(11)))
                    .foregroundColor(Theme.textSecondary)
            }

            // Avatar circle
            ZStack {
                Circle()
                    .fill(medalGrad(rank))
                    .frame(width: rank == 1 ? 64 : 52, height: rank == 1 ? 64 : 52)
                    .shadow(color: glow.opacity(0.9), radius: rank == 1 ? 18 : 12)
                VStack(spacing: 1) {
                    Text(rank == 1 ? "👑" : (rank == 2 ? "🥈" : "🥉"))
                        .font(.system(size: scaled(rank == 1 ? 18 : 14)))
                    Text(String(member.username.prefix(2)).uppercased())
                        .font(.system(size: scaled(rank == 1 ? 14 : 11), weight: .black))
                        .foregroundColor(.black.opacity(0.75))
                }
            }
            .scaleEffect(showPodium ? 1 : 0.4)
            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(animIndex) * 0.15 + 0.2), value: showPodium)

            // Podium block
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(medalGrad(rank))
                    .opacity(0.85)
                    .frame(width: rank == 1 ? 110 : 90, height: podiumHeights[safe: animIndex] ?? 0)
                    .shadow(color: glow.opacity(0.5), radius: 10)

                Text("#\(rank)")
                    .font(.system(size: scaled(rank == 1 ? 20 : 16), weight: .black))
                    .foregroundColor(.black.opacity(0.6))
                    .padding(.top, 8)
            }
        }
    }

    // ── Rest-of-table row ─────────────────────────────────────────────────

    private func restRow(_ member: LeagueMember, rank: Int) -> some View {
        let isUser = member.user_id == currentUserId
        return HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: scaled(13), weight: .bold))
                .foregroundColor(Theme.textMuted)
                .frame(width: 24)

            Text(isUser ? "You (\(member.username))" : member.username)
                .font(.system(size: scaled(13), weight: isUser ? .semibold : .regular))
                .foregroundColor(isUser ? Theme.primaryBlue : .white)
                .lineLimit(1)

            Spacer()

            if let val = member.total_value {
                Text(formatValue(val))
                    .font(.system(size: scaled(12), weight: .semibold))
                    .foregroundColor(.white)
            }
            if let pct = member.profit_loss_percent {
                ChangePill(percent: pct, compact: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            isUser
                ? Theme.primaryBlue.opacity(0.12)
                : Color.white.opacity(0.04)
        )
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(isUser ? Theme.primaryBlue.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1))
    }

    // ── Entrance animation sequence ───────────────────────────────────────

    private func runEntrance() {
        withAnimation(.easeOut(duration: 0.4)) { showBackground = true }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) { showTitle = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.2)) { showPodium = true }
            // Animate podium blocks rising one at a time: 2nd, 1st, 3rd
            let order = podiumOrder
            for (i, entry) in order.enumerated() {
                let target = podiumTargetHeight(entry.rank)
                let delay = Double(i) * 0.18 + 0.1
                withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(delay)) {
                    if podiumHeights.count > i { podiumHeights[i] = target }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showConfetti = true
        }

        withAnimation(.easeOut(duration: 0.5).delay(1.4)) { showRest = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.6)) { showButton = true }
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
