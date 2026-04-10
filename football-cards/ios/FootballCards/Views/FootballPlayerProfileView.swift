import SwiftUI

private extension Color {
    static let kcNavy  = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let kcLime  = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let kcCard  = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let kcMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
}

struct FootballPlayerProfileView: View {
    let card: FootballOwnedCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { dismiss() }

            // The card
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    // Tier gradient background
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(cardGradient)

                    // Photo — full, contained
                    PlayerAvatarImage(playerName: card.playerName, size: 240)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Fade into card body
                    LinearGradient(
                        colors: [.clear, cardGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)

                    // Top row: slot badge (left) + club badge (right)
                    HStack {
                        Text(card.starterSlotCode ?? card.positionLabel ?? "")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Capsule())

                        Spacer()

                        if let clubName = card.clubName {
                            ClubLogoImage(clubName: clubName, size: 40)
                                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(height: 280)

                // ── Info body ──
                VStack(spacing: 0) {
                    // Name + club
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.playerName)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        HStack(spacing: 6) {
                            Text(card.clubName ?? "")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.kcMuted)
                            if let league = card.leagueName {
                                Text("·").foregroundStyle(Color.kcMuted)
                                Text(league).font(.subheadline).foregroundStyle(Color.kcMuted)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // Rating + tier strip
                    if let rating = card.ratingOutOfTen {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rating")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.kcMuted)
                                Text(String(format: "%.1f / 10", rating))
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.kcLime)
                            }
                            Spacer()
                            Text((card.ratingTier ?? "").uppercased())
                                .font(.caption.weight(.black))
                                .tracking(1.5)
                                .foregroundStyle(tierColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(tierColor.opacity(0.15))
                                .overlay(Capsule().strokeBorder(tierColor.opacity(0.5), lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                    }

                    Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 18)

                    // Stats — two column grid
                    let stats: [(String, String)] = [
                        ("Age", card.age.map(String.init) ?? "—"),
                        ("Position", card.detailedPositionLabel ?? card.positionLabel ?? "—"),
                        ("Height", card.heightCm.map { "\($0) cm" } ?? "—"),
                        ("Weight", card.weightKg.map { "\($0) kg" } ?? "—"),
                        ("Appearances", card.appearances.map(String.init) ?? "—"),
                        ("Goals", card.goals.map(String.init) ?? "—"),
                        ("Assists", card.assists.map(String.init) ?? "—"),
                        ("Tackles", card.tackles.map(String.init) ?? "—"),
                        ("Shots on Target", card.shotsOnTarget.map(String.init) ?? "—"),
                        ("Passes", card.passes.map(String.init) ?? "—"),
                    ]

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                        ForEach(stats, id: \.0) { stat in
                            HStack {
                                Text(stat.0)
                                    .font(.caption)
                                    .foregroundStyle(Color.kcMuted)
                                Spacer()
                                Text(stat.1)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(stat.1 == "—" ? Color.kcMuted : .white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.kcCard.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .background(Color.kcNavy)
                .clipShape(
                    .rect(bottomLeadingRadius: 28, bottomTrailingRadius: 28)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(tierStrokeColor, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .presentationBackground(.clear)
    }

    // MARK: - Helpers
    private var cardGradient: LinearGradient {
        switch (card.ratingTier ?? "standard").lowercased() {
        case "elite":  return LinearGradient(colors: [Color(red: 0.18, green: 0.17, blue: 0.08), Color(red: 0.77, green: 0.66, blue: 0.21)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "gold":   return LinearGradient(colors: [Color(red: 0.28, green: 0.18, blue: 0.06), Color(red: 0.78, green: 0.47, blue: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "silver": return LinearGradient(colors: [Color(red: 0.20, green: 0.24, blue: 0.30), Color(red: 0.63, green: 0.69, blue: 0.77)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "bronze": return LinearGradient(colors: [Color(red: 0.29, green: 0.17, blue: 0.13), Color(red: 0.62, green: 0.37, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:       return LinearGradient(colors: [Color(red: 0.10, green: 0.22, blue: 0.36), Color(red: 0.17, green: 0.46, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var cardGradientBottom: Color {
        switch (card.ratingTier ?? "standard").lowercased() {
        case "elite":  return Color(red: 0.18, green: 0.17, blue: 0.08)
        case "gold":   return Color(red: 0.28, green: 0.18, blue: 0.06)
        case "silver": return Color(red: 0.20, green: 0.24, blue: 0.30)
        case "bronze": return Color(red: 0.29, green: 0.17, blue: 0.13)
        default:       return Color(red: 0.10, green: 0.22, blue: 0.36)
        }
    }

    private var tierColor: Color {
        switch (card.ratingTier ?? "").lowercased() {
        case "elite":  return Color(red: 0.98, green: 0.90, blue: 0.62)
        case "gold":   return Color(red: 0.96, green: 0.76, blue: 0.37)
        case "silver": return Color(red: 0.84, green: 0.88, blue: 0.94)
        case "bronze": return Color(red: 0.83, green: 0.60, blue: 0.42)
        default:       return Color.kcMuted
        }
    }

    private var tierStrokeColor: Color { tierColor.opacity(0.7) }
}
