import SwiftUI

private extension Color {
    static let kcNavy  = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let kcLime  = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let kcCard  = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let kcMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
}

struct FootballCardDetailView: View {
    let card: FootballOwnedCard
    var actionContext: FootballCardActionContext? = nil
    var onActionSelected: ((FootballCardActionKind) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isFlipped = false
    @State private var showsBackStats = false

    init(
        card: FootballOwnedCard,
        actionContext: FootballCardActionContext? = nil,
        onActionSelected: ((FootballCardActionKind) -> Void)? = nil,
        startsOnBack: Bool = false
    ) {
        self.card = card
        self.actionContext = actionContext
        self.onActionSelected = onActionSelected
        _isFlipped = State(initialValue: startsOnBack)
    }

    var body: some View {
        ZStack {
            Color.kcNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    Spacer()

                    Text(isFlipped ? "Action Side" : "Player Side")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.kcMuted)

                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)

                Spacer(minLength: 0)

                // Keep the 3D flip effect, but only let the visible face receive touches.
                ZStack {
                    cardBack
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                        .allowsHitTesting(isFlipped)
                        .zIndex(isFlipped ? 1 : 0)

                    cardFront
                        .opacity(isFlipped ? 0 : 1)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                        .allowsHitTesting(!isFlipped)
                        .zIndex(isFlipped ? 0 : 1)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Card front (large)
    private var cardFront: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 20)
                HStack(alignment: .top, spacing: 16) {
                    positionPill

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 8) {
                        if let clubName = card.clubName {
                            ClubLogoImage(clubName: clubName, logoUrl: card.clubLogoUrl, size: 62)
                                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                        }

                        if let rating = card.ratingOutOfTen {
                            Text(String(format: "%.1f / 10", rating))
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(ratingBadgeBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.horizontal, 18)

                HStack(alignment: .top, spacing: 14) {
                    playerPhotoPanel

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                identityTile
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                detailStatsBlock
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                Spacer(minLength: 24)
            }
        }
        .frame(width: detailCardWidth, height: detailCardHeight)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: detailCardCornerRadius, style: .continuous))
        .overlay {
            tierFinishOverlay
                .clipShape(RoundedRectangle(cornerRadius: detailCardCornerRadius, style: .continuous))
                .allowsHitTesting(false)
        }
        .overlay {
            detailCardBorderOverlay
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            detailFlipCornerHint
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .shadow(color: detailCardShadowColor, radius: 28, y: 14)
    }

    private var detailFlipCornerHint: some View {
        Button {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                isFlipped.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .black))
                Text("TAP TO FLIP")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.24))
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isFlipped ? 0 : 1)
    }

    private var detailBackFlipButton: some View {
        Button {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                isFlipped.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .black))
                Text("TAP TO FLIP")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundStyle(Color.kcNavy)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.88))
            .overlay(
                Capsule()
                    .strokeBorder(Color.kcNavy.opacity(0.12), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var playerPhotoContent: some View {
        PlayerAvatarImage(playerName: card.playerName, photoUrl: card.photoUrl, size: 160)
    }

    private var playerPhotoPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.black.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.2)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .padding(4)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                .padding(4)

            playerPhotoContent
                .frame(width: 132, height: 164)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.24), radius: 10, y: 6)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.clear, Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(4)
                .blendMode(.screen)
        }
        .frame(width: 152, height: 184)
        .shadow(color: .black.opacity(0.22), radius: 16, y: 10)
    }

    private var fallbackPhoto: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "person.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var identityTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.playerName)
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundStyle(primaryInfoTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .shadow(color: Color.black.opacity(0.18), radius: 1, y: 1)

            HStack(alignment: .center, spacing: 10) {
                Text(card.clubName ?? "Unknown Club")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(secondaryInfoTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)

                if let leagueName = card.leagueName {
                    Text(leagueName)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(secondaryInfoTextColor.opacity(0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.18))
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(infoTileBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(infoTileStrokeColor, lineWidth: 1.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var detailStatsBlock: some View {
        VStack(spacing: 8) {
            ForEach(Array(detailStatRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        detailStatPill(title: item.title, value: item.value)
                    }
                }
            }
        }
    }

    private func detailStatPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(secondaryInfoTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(primaryInfoTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(infoTileBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(infoTileStrokeColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var infoTileBackground: some ShapeStyle {
        detailInfoPanelBackground
    }

    private var infoTileStrokeColor: Color {
        detailInfoPanelStrokeColor
    }

    private var positionPill: some View {
        Text(positionDisplayName.uppercased())
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(1.0)
            .foregroundStyle(secondaryInfoTextColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(detailInfoPanelBackground)
            .overlay(
                Capsule()
                    .strokeBorder(detailInfoPanelStrokeColor, lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    private func formattedInt(_ value: Int?) -> String {
        guard let value else { return "-" }
        return String(value)
    }

    private var detailStatRows: [[(title: String, value: String)]] {
        let stats = detailStats
        return stride(from: 0, to: stats.count, by: 2).map { index in
            Array(stats[index..<min(index + 2, stats.count)])
        }
    }

    private var detailStats: [(title: String, value: String)] {
        switch positionProfile {
        case .goalkeeper:
            return [
                stat("Saves", card.saves),
                stat("Clean Sheets", card.cleanSheets),
                stat("Goals Conceded", card.goalsConceded),
                stat("Overall", formattedRating(card.ratingOutOfTen)),
                stat("Appearances", card.appearances),
                stat("Age", card.age)
            ]
        case .defender:
            return [
                stat("Age", card.age),
                stat("Appearances", card.appearances),
                stat("Tackles", card.tackles),
                stat("Passes", card.passes),
                stat("Assists", card.assists),
                stat("Goals", card.goals)
            ]
        case .midfielder:
            return [
                stat("Age", card.age),
                stat("Appearances", card.appearances),
                stat("Assists", card.assists),
                stat("Passes", card.passes),
                stat("Goals", card.goals),
                stat("Tackles", card.tackles)
            ]
        case .attacker:
            return [
                stat("Age", card.age),
                stat("Appearances", card.appearances),
                stat("Goals", card.goals),
                stat("Assists", card.assists),
                stat("Shots on Target", card.shotsOnTarget),
                stat("Passes", card.passes)
            ]
        }
    }

    private var positionDisplayName: String {
        let raw = (card.detailedPositionLabel ?? card.positionLabel ?? card.starterSlotCode ?? "Player").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "Player" : raw
    }

    private var positionProfile: PlayerPositionProfile {
        let source = [card.detailedPositionLabel, card.positionLabel, card.starterSlotCode]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if source.contains("gk") || source.contains("goalkeeper") {
            return .goalkeeper
        }

        if source.contains("cb") ||
            source.contains("back") ||
            source.contains("defender") ||
            source.contains("sweeper") {
            return .defender
        }

        if source.contains("mid") ||
            source.contains("cm") ||
            source.contains("dm") ||
            source.contains("am") ||
            source.contains("wing") {
            return .midfielder
        }

        return .attacker
    }

    private func stat(_ title: String, _ value: Int?) -> (title: String, value: String) {
        (title: title, value: formattedInt(value))
    }

    private func stat(_ title: String, _ value: String) -> (title: String, value: String) {
        (title: title, value: value)
    }

    private func formattedRating(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.1f", value)
    }

    private var normalizedTier: String {
        (card.ratingTier ?? "standard").lowercased()
    }

    private var detailInfoPanelBackground: Color {
        switch normalizedTier {
        case "elite":
            return Color(red: 0.24, green: 0.19, blue: 0.05).opacity(0.88)
        case "gold":
            return Color(red: 0.29, green: 0.19, blue: 0.03).opacity(0.86)
        case "silver":
            return Color(red: 0.21, green: 0.25, blue: 0.31).opacity(0.88)
        case "bronze":
            return Color(red: 0.24, green: 0.12, blue: 0.08).opacity(0.88)
        case "unscouted":
            return Color(red: 0.17, green: 0.12, blue: 0.27).opacity(0.88)
        default:
            return Color.kcNavy.opacity(0.80)
        }
    }

    private var detailInfoPanelStrokeColor: Color {
        switch normalizedTier {
        case "elite":
            return Color(red: 0.98, green: 0.90, blue: 0.62).opacity(0.55)
        case "gold":
            return Color(red: 1.00, green: 0.86, blue: 0.33).opacity(0.55)
        case "silver":
            return Color(red: 0.90, green: 0.94, blue: 0.99).opacity(0.45)
        case "bronze":
            return Color(red: 0.88, green: 0.58, blue: 0.33).opacity(0.45)
        case "unscouted":
            return Color(red: 0.87, green: 0.80, blue: 0.97).opacity(0.40)
        default:
            return Color.white.opacity(0.16)
        }
    }

    private var primaryInfoTextColor: Color {
        switch normalizedTier {
        case "silver":
            return Color.white
        case "elite", "gold":
            return Color(red: 1.0, green: 0.98, blue: 0.88)
        case "bronze":
            return Color(red: 1.0, green: 0.93, blue: 0.88)
        case "unscouted":
            return Color(red: 0.96, green: 0.92, blue: 1.0)
        default:
            return Color.white
        }
    }

    private var secondaryInfoTextColor: Color {
        switch normalizedTier {
        case "elite", "gold":
            return Color(red: 1.0, green: 0.88, blue: 0.42)
        case "silver":
            return Color(red: 0.93, green: 0.97, blue: 1.0)
        case "bronze":
            return Color(red: 0.98, green: 0.78, blue: 0.56)
        case "unscouted":
            return Color(red: 0.88, green: 0.82, blue: 1.0)
        default:
            return Color.kcLime.opacity(0.96)
        }
    }

    private enum PlayerPositionProfile {
        case goalkeeper
        case defender
        case midfielder
        case attacker
    }

    // MARK: - Card back (large)
    private var cardBack: some View {
        ZStack {
            Color.black.opacity(0.2)

            VStack(spacing: 0) {
                // FootyCards logo top
                HStack(spacing: 0) {
                    Text("Footy")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Cards")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.kcLime.opacity(0.55))
                }
                    .padding(.top, 28)

                    Spacer(minLength: 18)

                // Large club badge
                if let clubName = card.clubName {
                    ClubLogoImage(clubName: clubName, logoUrl: card.clubLogoUrl, size: 188)
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                }

                Spacer().frame(height: 28)

                // Tier badge
                VStack(spacing: 8) {
                    Text((card.ratingTier ?? "standard").uppercased())
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 34)
                        .padding(.vertical, 15)
                        .background(tierStrokeColor.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(tierStrokeColor.opacity(0.9), lineWidth: 1.6)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if let rating = card.ratingOutOfTen {
                        Text(String(format: "%.1f / 10", rating))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(tierStrokeColor)
                    }
                }

                backActionStatsPanel
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                Spacer(minLength: 88)
            }
        }
        .frame(width: detailCardWidth, height: detailCardHeight)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: detailCardCornerRadius, style: .continuous))
        .overlay {
            tierFinishOverlay
                .clipShape(RoundedRectangle(cornerRadius: detailCardCornerRadius, style: .continuous))
                .allowsHitTesting(false)
        }
        .overlay {
            detailCardBorderOverlay
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            detailBackFlipButton
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .shadow(color: detailCardShadowColor, radius: 28, y: 14)
    }

    // MARK: - Computed helpers
    private var cardGradient: LinearGradient {
        switch (card.ratingTier ?? "standard").lowercased() {
        case "elite":  return LinearGradient(colors: [Color(red: 0.18, green: 0.17, blue: 0.08), Color(red: 0.77, green: 0.66, blue: 0.21), Color(red: 0.95, green: 0.88, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "gold":   return LinearGradient(colors: [Color(red: 0.34, green: 0.23, blue: 0.03), Color(red: 0.86, green: 0.62, blue: 0.06), Color(red: 0.98, green: 0.84, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "silver": return LinearGradient(colors: [Color(red: 0.20, green: 0.24, blue: 0.30), Color(red: 0.63, green: 0.69, blue: 0.77)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "bronze": return LinearGradient(colors: [Color(red: 0.22, green: 0.10, blue: 0.08), Color(red: 0.50, green: 0.23, blue: 0.12), Color(red: 0.72, green: 0.38, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "unscouted": return LinearGradient(colors: [Color(red: 0.21, green: 0.15, blue: 0.30), Color(red: 0.68, green: 0.60, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            switch card.starterSlotCode {
            case "GK":          return LinearGradient(colors: [Color(red: 0.22, green: 0.26, blue: 0.18), Color(red: 0.66, green: 0.59, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "RB","LB","RCB","LCB": return LinearGradient(colors: [Color(red: 0.10, green: 0.22, blue: 0.36), Color(red: 0.17, green: 0.46, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "CM","RM","LM": return LinearGradient(colors: [Color(red: 0.14, green: 0.30, blue: 0.20), Color(red: 0.30, green: 0.56, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
            default:            return LinearGradient(colors: [Color(red: 0.33, green: 0.14, blue: 0.14), Color(red: 0.72, green: 0.27, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    @ViewBuilder
    private var tierFinishOverlay: some View {
        switch (card.ratingTier ?? "standard").lowercased() {
        case "gold":
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.24), Color.clear, Color.white.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.30), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 92)
                    .rotationEffect(.degrees(28))
                    .offset(x: 54, y: -30)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            center: .center,
                            startRadius: 8,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 140)
                    .offset(x: -26, y: -122)
            }
        case "bronze":
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.16), Color.clear, Color(red: 0.16, green: 0.08, blue: 0.05).opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.032))
                        .frame(width: 420, height: 2.2)
                        .rotationEffect(.degrees(-18))
                        .offset(x: 0, y: CGFloat(index * 38) - 176)
                }
            }
        default:
            Color.clear
        }
    }

    private var detailCardBorderOverlay: some View {
        RoundedRectangle(cornerRadius: detailCardCornerRadius, style: .continuous)
            .strokeBorder(tierStrokeColor.opacity(0.90), lineWidth: 2.5)
    }

    private var detailCardWidth: CGFloat { 360 }

    private var detailCardHeight: CGFloat { 640 }

    private var detailCardCornerRadius: CGFloat { 32 }

    private var detailCardShadowColor: Color {
        tierStrokeColor.opacity(0.42)
    }

    private var tierStrokeColor: Color {
        switch (card.ratingTier ?? "standard").lowercased() {
        case "elite":    return Color(red: 0.98, green: 0.90, blue: 0.62)
        case "gold":     return Color(red: 1.00, green: 0.88, blue: 0.36)
        case "silver":   return Color(red: 0.84, green: 0.88, blue: 0.94)
        case "bronze":   return Color(red: 0.78, green: 0.45, blue: 0.22)
        case "unscouted":return Color(red: 0.84, green: 0.77, blue: 0.96)
        default:         return Color.white.opacity(0.25)
        }
    }

    private var ratingBadgeBackground: some ShapeStyle {
        switch (card.ratingTier ?? "standard").lowercased() {
        case "elite":    return Color(red: 0.42, green: 0.34, blue: 0.06).opacity(0.74)
        case "gold":     return Color(red: 0.69, green: 0.46, blue: 0.02).opacity(0.80)
        case "silver":   return Color(red: 0.33, green: 0.39, blue: 0.47).opacity(0.74)
        case "bronze":   return Color(red: 0.38, green: 0.16, blue: 0.10).opacity(0.82)
        case "unscouted":return Color(red: 0.25, green: 0.17, blue: 0.35).opacity(0.78)
        default:         return Color.black.opacity(0.2)
        }
    }

    private func unavailableActionState(for context: FootballCardActionContext) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: context.emptyStateIcon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(context.emptyStateTint)

            Text(context.emptyStateMessage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(context.emptyStateTint.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var backActionStatsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 0)
                backModeToggleButton
            }

            ZStack {
                backActionsContent
                    .opacity(showsBackStats ? 0 : 1)
                    .rotation3DEffect(.degrees(showsBackStats ? 90 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                    .allowsHitTesting(!showsBackStats)
                    .zIndex(showsBackStats ? 0 : 1)

                backStatsContent
                    .opacity(showsBackStats ? 1 : 0)
                    .rotation3DEffect(.degrees(showsBackStats ? 0 : -90), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                    .allowsHitTesting(showsBackStats)
                    .zIndex(showsBackStats ? 1 : 0)
            }
            .frame(minHeight: 180)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.20))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var backModeToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                showsBackStats.toggle()
            }
        } label: {
            Image(systemName: showsBackStats ? "rectangle.grid.2x2.fill" : "chart.bar.xaxis")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(showsBackStats ? Color.kcNavy : .white)
                .frame(width: 34, height: 34)
                .background(showsBackStats ? Color.kcLime : Color.white.opacity(0.14))
                .overlay(
                    Circle()
                        .strokeBorder(showsBackStats ? Color.kcLime.opacity(0.9) : Color.white.opacity(0.10), lineWidth: 1)
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backActionsContent: some View {
        if let actionContext {
            let visibleActions = actionContext.actions.filter(\.isEnabled)

            VStack(alignment: .leading, spacing: 10) {
                if !actionContext.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(actionContext.title)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.9))
                }

                if let subtitle = actionContext.subtitle,
                   !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                }

                if visibleActions.isEmpty {
                    unavailableActionState(for: actionContext)
                } else {
                    VStack(spacing: 8) {
                        ForEach(visibleActions) { action in
                            actionButton(for: action)
                        }
                    }
                }
            }
        } else {
            backStatsContent
        }
    }

    private var backStatsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Player Stats")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.9))

            if let rating = card.ratingOutOfTen {
                HStack(spacing: 12) {
                    Text(String(format: "%.1f / 10", rating))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(tierStrokeColor)
                    Text(positionDisplayName.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(detailStats.enumerated()), id: \.offset) { _, item in
                    detailStatPill(title: item.title, value: item.value)
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(for action: FootballCardActionItem) -> some View {
        Button {
            handleActionTap(action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: actionButtonIcon(for: action))
                    .font(.system(size: 14, weight: .black))

                Text(action.title.uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(0.5)

                Spacer(minLength: 0)
            }
            .foregroundStyle(actionButtonForeground(for: action))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(actionButtonBackground(for: action))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(actionButtonBorder(for: action), lineWidth: 1.2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func actionButtonIcon(for action: FootballCardActionItem) -> String {
        switch action.kind {
        case .build:
            return "plus.circle.fill"
        case .upgrade:
            return "arrow.up.circle.fill"
        case .trade:
            return action.title.localizedCaseInsensitiveContains("remove") ? "arrow.uturn.left.circle.fill" : "arrow.left.arrow.right.circle.fill"
        case .swap:
            return action.title.localizedCaseInsensitiveContains("remove") ? "arrow.uturn.left.circle.fill" : "arrow.triangle.2.circlepath.circle.fill"
        case .discard:
            return "trash.circle.fill"
        }
    }

    private func actionButtonBackground(for action: FootballCardActionItem) -> Color {
        switch action.kind {
        case .build:
            return Color(red: 0.78, green: 0.95, blue: 0.22)
        case .upgrade:
            return Color(red: 0.45, green: 0.78, blue: 0.98)
        case .trade:
            return action.title.localizedCaseInsensitiveContains("remove")
                ? Color(red: 0.12, green: 0.33, blue: 0.56)
                : Color(red: 0.22, green: 0.57, blue: 0.93)
        case .swap:
            return action.title.localizedCaseInsensitiveContains("remove")
                ? Color(red: 0.10, green: 0.39, blue: 0.23)
                : Color(red: 0.18, green: 0.72, blue: 0.38)
        case .discard:
            return Color(red: 0.86, green: 0.18, blue: 0.18)
        }
    }

    private func actionButtonForeground(for action: FootballCardActionItem) -> Color {
        switch action.kind {
        case .build, .upgrade:
            return Color.kcNavy
        case .trade, .swap, .discard:
            return .white
        }
    }

    private func actionButtonBorder(for action: FootballCardActionItem) -> Color {
        actionButtonForeground(for: action).opacity(0.16)
    }

    private func handleActionTap(_ action: FootballCardActionItem) {
        onActionSelected?(action.kind)
        dismiss()
    }
}

enum FootballCardActionKind: String, Identifiable {
    case build
    case upgrade
    case swap
    case trade
    case discard

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .build:
            return Color.kcLime
        case .upgrade:
            return Color(red: 0.55, green: 0.72, blue: 0.97)
        case .swap:
            return Color(red: 0.97, green: 0.49, blue: 0.50)
        case .trade:
            return Color(red: 0.99, green: 0.78, blue: 0.36)
        case .discard:
            return Color(red: 0.90, green: 0.37, blue: 0.33)
        }
    }
}

struct FootballCardActionItem: Identifiable {
    let kind: FootballCardActionKind
    let title: String
    let message: String
    let isEnabled: Bool

    var id: String { kind.id }
    var accent: Color { kind.accent }
}

struct FootballCardActionContext {
    let title: String
    let subtitle: String?
    let actions: [FootballCardActionItem]
    let emptyStateMessage: String
    let emptyStateIcon: String
    let emptyStateTint: Color

    init(
        title: String,
        subtitle: String?,
        actions: [FootballCardActionItem],
        emptyStateMessage: String = "No live actions available for this card yet.",
        emptyStateIcon: String = "lock.circle",
        emptyStateTint: Color = .white.opacity(0.55)
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
        self.emptyStateMessage = emptyStateMessage
        self.emptyStateIcon = emptyStateIcon
        self.emptyStateTint = emptyStateTint
    }
}
