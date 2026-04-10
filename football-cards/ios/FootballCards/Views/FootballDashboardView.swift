import SwiftUI

// MARK: - Brand colours
private extension Color {
    static let kcNavy  = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let kcLime  = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let kcCard  = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let kcMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
}

struct FootballDashboardView: View {
    @ObservedObject var bootstrapViewModel: FootballBootstrapViewModel
    @ObservedObject var profileViewModel: FootballProfileViewModel
    let openCollection: () -> Void

    @EnvironmentObject private var session: FootballSessionViewModel
    @StateObject private var collectionDashboardViewModel = FootballCollectionViewModel()
    @State private var activeDeskPreview: FootballDashboardDesk?
    @State private var activeSection: FootballDashboardSection = .collection

    var body: some View {
        ZStack {
            Color.kcNavy.ignoresSafeArea()

            if bootstrapViewModel.isLoading && bootstrapViewModel.bootstrap == nil {
                ProgressView()
                    .tint(Color.kcLime)
            } else if let profileData = profileViewModel.profileData {
                ScrollView {
                    VStack(spacing: 20) {
                        clubHeroCard(profileData: profileData)
                        selectionTiles(profileData: profileData)
                        actionChoiceSection(profileData: profileData)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            } else if let error = bootstrapViewModel.errorMessage ?? profileViewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.kcMuted)
                    Text("Unable to Load")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color.kcMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            collectionDashboardViewModel.reloadPersistedState()
            if collectionDashboardViewModel.cards.isEmpty && !collectionDashboardViewModel.isLoading {
                Task {
                    await collectionDashboardViewModel.loadCollection()
                }
            }
        }
        .safeAreaInset(edge: .top) {
            topBar
        }
        .sheet(item: $activeDeskPreview) { desk in
            FootballDashboardDeskPreview(
                desk: desk,
                cards: cardsForDeskPreview(desk, fallback: profileViewModel.profileData?.starterPackCards ?? []),
                capacity: deskCapacity(for: desk),
                maxCapacity: deskMaxCapacity(for: desk),
                detailContext: detailContext(for:),
                onActionSelected: { action, card in
                    handleCardActionSelected(action, for: card)
                }
            )
        }
        .refreshable {
            await bootstrapViewModel.refreshAll()
            await profileViewModel.refreshAll()
            await session.restoreSession()
            await collectionDashboardViewModel.loadCollection()
            collectionDashboardViewModel.reloadPersistedState()
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack {
            HStack(spacing: 0) {
                Text("Footy")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Cards")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.kcLime)
            }
            Spacer()
            Button {
                session.signOut()
            } label: {
                Text("Sign Out")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.kcMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.kcCard)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.kcNavy)
    }

    // MARK: - Club hero card
    @ViewBuilder
    private func clubHeroCard(profileData: FootballProfileData) -> some View {
        let userName = (session.currentUser?.displayName ?? profileData.profile?.displayName ?? "Player")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let heroName = userName.isEmpty ? "PLAYER" : userName.uppercased()
        let totalScore = collectionDashboardViewModel.totalTeamScore

        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.kcCard)

            HStack(alignment: .top, spacing: 16) {
                if let logoUrl = profileData.profile?.supportedClubLogoUrl,
                   let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFit()
                        } else {
                            Image(systemName: "shield.fill")
                                .foregroundStyle(Color.kcMuted)
                        }
                    }
                    .frame(width: 64, height: 64)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(heroName)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let teamName = profileData.profile?.teamName, !teamName.isEmpty {
                        Text(teamName)
                            .font(.title3.bold())
                            .foregroundStyle(Color.kcLime)
                    }

                    Text(profileData.profile?.supportedClubName ?? "No club set")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(String(format: "%.1f", totalScore))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.kcNavy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.kcLime)
                    .clipShape(Capsule())
            }
            .padding(20)
        }
    }

    // MARK: - Dashboard tiles
    @ViewBuilder
    private func selectionTiles(profileData: FootballProfileData) -> some View {
        let selectedCount = collectionDashboardViewModel.totalAssignedCount
        let availableCards = dashboardAvailableCards(fallback: profileData.starterPackCards)
        let tradeCards = dashboardTradeCards(fallback: profileData.starterPackCards)
        let swapCards = dashboardSwapCards(fallback: profileData.starterPackCards)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            sectionTile(
                section: .collection,
                label: "Available",
                value: "\(availableCards.count)",
                accent: Color.kcLime
            )
            sectionTile(
                section: .selected,
                label: "Selected",
                value: "\(selectedCount)",
                accent: Color(red: 0.55, green: 0.72, blue: 0.97)
            )
            sectionTile(
                section: .trade,
                label: "Trade",
                value: "\(min(5, tradeCards.count))",
                accent: Color(red: 0.99, green: 0.78, blue: 0.36)
            )
            sectionTile(
                section: .swap,
                label: "Swap",
                value: "\(min(5, swapCards.count))",
                accent: Color(red: 0.97, green: 0.49, blue: 0.50)
            )
        }
    }

    @ViewBuilder
    private func sectionTile(section: FootballDashboardSection, label: String, value: String, accent: Color) -> some View {
        let isActive = activeSection == section

        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                activeSection = section
            }
        } label: {
            VStack(spacing: 8) {
                HStack {
                    Text(label)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(isActive ? Color.kcNavy.opacity(0.78) : .white.opacity(0.86))
                    Spacer()
                    Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isActive ? Color.kcNavy.opacity(0.82) : .white.opacity(0.72))
                }

                Text(value)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(isActive ? Color.kcNavy : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? accent : accent.opacity(0.30))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isActive ? accent.opacity(0.18) : accent.opacity(0.38), lineWidth: 1.2)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func actionChoiceSection(profileData: FootballProfileData) -> some View {
        let cards = cardsForActiveSection(profileData: profileData)
        let section = activeSection
        let sectionHeaderNote = headerNote(for: section)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(section.title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    if let sectionHeaderNote {
                        Text(sectionHeaderNote)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.kcMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    if section != .collection {
                        Button(section.ctaLabel) {
                            if let previewDesk = section.previewDesk {
                                activeDeskPreview = previewDesk
                            } else {
                                openCollection()
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(section.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(section.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                if cards.isEmpty {
                    emptyCardsState(for: section)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(cards) { card in
                                FootballPlayerCardView(
                                    card: card,
                                    detailContext: detailContext(for: card),
                                    onDetailActionSelected: { action in
                                        handleCardActionSelected(action, for: card)
                                    },
                                    opensDetailOnBack: section == .collection,
                                    showsFlipHint: section == .collection
                                )
                                .frame(width: 200)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.kcCard)
            )
        }
    }

    @ViewBuilder
    private func emptyCardsState(for section: FootballDashboardSection) -> some View {
        VStack(spacing: 10) {
            Image(systemName: section.emptyIcon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(section.accent)
            Text(section.emptyTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(section.emptyMessage)
                .font(.caption)
                .foregroundStyle(Color.kcMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func cardsForActiveSection(profileData: FootballProfileData) -> [FootballOwnedCard] {
        switch activeSection {
        case .collection:
            return dashboardAvailableCards(fallback: profileData.starterPackCards)
        case .selected:
            return dashboardSelectedCards(fallback: profileData.starterPackCards)
        case .trade:
            return Array(dashboardTradeCards(fallback: profileData.starterPackCards).prefix(8))
        case .swap:
            return Array(dashboardSwapCards(fallback: profileData.starterPackCards).prefix(8))
        }
    }

    private func dashboardOwnedCards(fallback: [FootballOwnedCard]) -> [FootballOwnedCard] {
        let owned = collectionDashboardViewModel.cards
            .filter { $0.ownershipStatus == "owned" }
            .filter { !collectionDashboardViewModel.isDiscarded($0) }
            .sorted(by: dashboardCardSort(lhs:rhs:))

        return owned.isEmpty ? fallback : owned
    }

    private func dashboardSelectedCards(fallback: [FootballOwnedCard]) -> [FootballOwnedCard] {
        let ownedCards = dashboardOwnedCards(fallback: fallback)
        let assignedIds = assignedCardIds()
        let selected = ownedCards.filter { assignedIds.contains($0.userCardId) }
        return selected.sorted(by: dashboardCardSort(lhs:rhs:))
    }

    private func dashboardAvailableCards(fallback: [FootballOwnedCard]) -> [FootballOwnedCard] {
        dashboardOwnedCards(fallback: fallback)
            .filter { !assignedCardIds().contains($0.userCardId) }
            .filter { !collectionDashboardViewModel.isQueuedForTrade($0) }
            .filter { !collectionDashboardViewModel.isQueuedForSwap($0) }
            .sorted(by: dashboardCardSort(lhs:rhs:))
    }

    private func dashboardReserveCards(fallback: [FootballOwnedCard]) -> [FootballOwnedCard] {
        let ownedCards = dashboardOwnedCards(fallback: fallback)
        let assignedIds = assignedCardIds()
        return ownedCards
            .filter { !assignedIds.contains($0.userCardId) }
            .sorted(by: dashboardCardSort(lhs:rhs:))
    }

    private func dashboardSwapCards(fallback: [FootballOwnedCard]) -> [FootballOwnedCard] {
        dashboardOwnedCards(fallback: fallback)
            .filter { collectionDashboardViewModel.isQueuedForSwap($0) }
            .sorted(by: dashboardCardSort(lhs:rhs:))
    }

    private func dashboardTradeCards(fallback: [FootballOwnedCard]) -> [FootballOwnedCard] {
        dashboardOwnedCards(fallback: fallback)
            .filter { collectionDashboardViewModel.isQueuedForTrade($0) }
            .sorted(by: dashboardCardSort(lhs:rhs:))
    }

    private func cardsForDeskPreview(_ desk: FootballDashboardDesk, fallback: [FootballOwnedCard]) -> [FootballOwnedCard] {
        switch desk {
        case .trade:
            return dashboardTradeCards(fallback: fallback)
        case .swap:
            return dashboardSwapCards(fallback: fallback)
        }
    }

    private func deskCapacity(for desk: FootballDashboardDesk) -> Int {
        switch desk {
        case .trade:
            return collectionDashboardViewModel.queuedTradeCardIds.count
        case .swap:
            return collectionDashboardViewModel.queuedSwapCardIds.count
        }
    }

    private func deskMaxCapacity(for desk: FootballDashboardDesk) -> Int {
        switch desk {
        case .trade:
            return collectionDashboardViewModel.maxTradeQueueCount
        case .swap:
            return collectionDashboardViewModel.maxSwapQueueCount
        }
    }

    private func dashboardCardSort(lhs: FootballOwnedCard, rhs: FootballOwnedCard) -> Bool {
        let lhsRating = lhs.ratingOutOfTen ?? -1
        let rhsRating = rhs.ratingOutOfTen ?? -1
        if lhsRating != rhsRating {
            return lhsRating > rhsRating
        }

        let lhsAppearances = lhs.appearances ?? -1
        let rhsAppearances = rhs.appearances ?? -1
        if lhsAppearances != rhsAppearances {
            return lhsAppearances > rhsAppearances
        }

        return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName) == .orderedAscending
    }

    private func assignedCardIds() -> Set<String> {
        Set(collectionDashboardViewModel.squadAssignmentsByLeague.values.flatMap { $0.values })
    }

    private func hasBuildOpportunity(_ card: FootballOwnedCard) -> Bool {
        guard let leagueName = collectionDashboardViewModel.matchingLockedLeague(for: card) else { return false }
        return !collectionDashboardViewModel.openEligibleSlots(for: card, in: leagueName).isEmpty
    }

    private func hasUpgradeOpportunity(_ card: FootballOwnedCard) -> Bool {
        guard let leagueName = collectionDashboardViewModel.matchingLockedLeague(for: card) else { return false }
        guard collectionDashboardViewModel.isTeamComplete(for: leagueName) else { return false }
        return !collectionDashboardViewModel.upgradeEligibleSlots(for: card, in: leagueName).isEmpty
    }

    private func isSwapEligible(_ card: FootballOwnedCard) -> Bool {
        !assignedCardIds().contains(card.userCardId) && !collectionDashboardViewModel.isDiscarded(card)
    }

    private func isTradeEligible(_ card: FootballOwnedCard) -> Bool {
        !assignedCardIds().contains(card.userCardId) && !collectionDashboardViewModel.isDiscarded(card)
    }

    private func canDiscard(_ card: FootballOwnedCard) -> Bool {
        !assignedCardIds().contains(card.userCardId) && !collectionDashboardViewModel.isDiscarded(card)
    }

    private func headerNote(for section: FootballDashboardSection) -> String? {
        switch section {
        case .collection:
            return "Tap a card to flip for options"
        case .trade:
            return "5 per day"
        case .swap:
            return "5 per day"
        case .selected:
            return nil
        }
    }

    private func tradeQueueHasCapacity(for card: FootballOwnedCard) -> Bool {
        collectionDashboardViewModel.canQueueForTrade(card)
    }

    private func swapQueueHasCapacity(for card: FootballOwnedCard) -> Bool {
        collectionDashboardViewModel.canQueueForSwap(card)
    }

    private func detailContext(for card: FootballOwnedCard) -> FootballCardActionContext {
        let isQueuedForTrade = collectionDashboardViewModel.isQueuedForTrade(card)
        let isQueuedForSwap = collectionDashboardViewModel.isQueuedForSwap(card)
        let discardEnabled = canDiscard(card)

        let tradeEnabled = isTradeEligible(card) && tradeQueueHasCapacity(for: card)
        let swapEnabled = isSwapEligible(card) && swapQueueHasCapacity(for: card)
        let tradeQueueFull = !collectionDashboardViewModel.isQueuedForTrade(card) && !tradeQueueHasCapacity(for: card)
        let swapQueueFull = !collectionDashboardViewModel.isQueuedForSwap(card) && !swapQueueHasCapacity(for: card)

        guard let leagueName = collectionDashboardViewModel.matchingLockedLeague(for: card) else {
            return FootballCardActionContext(
                title: "",
                subtitle: nil,
                actions: [
                    FootballCardActionItem(kind: .trade, title: isQueuedForTrade ? "Remove Trade" : "Trade", message: isQueuedForTrade ? "Return this card from trade to available cards." : (tradeQueueFull ? "Trade queue is full right now." : "Move this card into the trade lane."), isEnabled: isQueuedForTrade || tradeEnabled),
                    FootballCardActionItem(kind: .swap, title: isQueuedForSwap ? "Remove Swap" : "Swap", message: isQueuedForSwap ? "Return this card from swap to available cards." : (swapQueueFull ? "Swap queue is full right now." : "Move this card into the swap lane."), isEnabled: isQueuedForSwap || swapEnabled),
                    FootballCardActionItem(kind: .discard, title: "Discard", message: "Discard this card from your 20-card pool.", isEnabled: discardEnabled)
                ]
            )
        }

        let openSlots = collectionDashboardViewModel.openEligibleSlots(for: card, in: leagueName)
        let upgradeSlots = collectionDashboardViewModel.upgradeEligibleSlots(for: card, in: leagueName)
        let teamComplete = collectionDashboardViewModel.isTeamComplete(for: leagueName)
        let assignedSlot = collectionDashboardViewModel.assignedSlot(for: card, in: leagueName)

        if let assignedSlot {
            return FootballCardActionContext(
                title: "Selected in squad",
                subtitle: "Currently starting for \(leagueName) and \(card.clubName ?? "your locked club").",
                actions: [],
                emptyStateMessage: "This card is already selected in the \(assignedSlot.displayName) slot.",
                emptyStateIcon: "checkmark.circle.fill",
                emptyStateTint: Color.kcLime
            )
        }

        let buildMessage: String
        if let firstOpenSlot = openSlots.first {
            buildMessage = openSlots.count == 1
                ? "Add this card into the open \(firstOpenSlot.displayName) slot in \(leagueName)."
                : "Add this card into one of \(openSlots.count) open squad slots in \(leagueName)."
        } else if teamComplete {
            buildMessage = "This team is already full, so use Upgrade if this card improves it."
        } else {
            buildMessage = "No open slot fits this player in the current formation."
        }

        let upgradeMessage: String
        if let firstUpgradeSlot = upgradeSlots.first,
           let assigned = collectionDashboardViewModel.assignedCard(for: leagueName, slot: firstUpgradeSlot) {
            upgradeMessage = "Better rated than \(assigned.playerName) for \(firstUpgradeSlot.displayName)."
        } else if !teamComplete {
            upgradeMessage = "Finish this team first, then higher-rated cards can be used as upgrades."
        } else {
            upgradeMessage = "No lower-rated selected player is currently replaceable by this card."
        }

        return FootballCardActionContext(
            title: !openSlots.isEmpty ? "Add to Team" : "",
            subtitle: nil,
            actions: [
                FootballCardActionItem(kind: .build, title: "Add to Team", message: buildMessage, isEnabled: !openSlots.isEmpty),
                FootballCardActionItem(kind: .upgrade, title: "Upgrade Team", message: upgradeMessage, isEnabled: teamComplete && !upgradeSlots.isEmpty),
                FootballCardActionItem(kind: .trade, title: isQueuedForTrade ? "Remove Trade" : "Trade", message: isQueuedForTrade ? "Return this card from trade to available cards." : (tradeQueueFull ? "Trade queue is full right now." : "Move this card into the trade lane."), isEnabled: isQueuedForTrade || tradeEnabled),
                FootballCardActionItem(kind: .swap, title: isQueuedForSwap ? "Remove Swap" : "Swap", message: isQueuedForSwap ? "Return this card from swap to available cards." : (swapQueueFull ? "Swap queue is full right now." : "Move this card into the swap lane."), isEnabled: isQueuedForSwap || swapEnabled),
                FootballCardActionItem(kind: .discard, title: "Discard", message: "Discard this card from your 20-card pool.", isEnabled: discardEnabled)
            ]
        )
    }

    private func handleCardActionSelected(_ action: FootballCardActionKind, for card: FootballOwnedCard) {
        switch action {
        case .build, .upgrade:
            openCollection()
        case .swap:
            withAnimation(.easeInOut(duration: 0.18)) {
                if collectionDashboardViewModel.isQueuedForSwap(card) {
                    collectionDashboardViewModel.removeFromQueues(card)
                    activeSection = .collection
                } else {
                    collectionDashboardViewModel.queueForSwap(card)
                    activeSection = .swap
                }
            }
        case .trade:
            withAnimation(.easeInOut(duration: 0.18)) {
                if collectionDashboardViewModel.isQueuedForTrade(card) {
                    collectionDashboardViewModel.removeFromQueues(card)
                    activeSection = .collection
                } else {
                    collectionDashboardViewModel.queueForTrade(card)
                    activeSection = .trade
                }
            }
        case .discard:
            withAnimation(.easeInOut(duration: 0.18)) {
                collectionDashboardViewModel.discardCard(card)
                if activeSection == .trade || activeSection == .swap {
                    activeSection = activeSection
                } else {
                    activeSection = .collection
                }
            }
        }
    }
}

private enum FootballDashboardSection: String, CaseIterable, Identifiable {
    case collection
    case selected
    case trade
    case swap

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .collection:
            return Color.kcLime
        case .selected:
            return Color(red: 0.55, green: 0.72, blue: 0.97)
        case .trade:
            return Color(red: 0.99, green: 0.78, blue: 0.36)
        case .swap:
            return Color(red: 0.97, green: 0.49, blue: 0.50)
        }
    }

    var tabLabel: String {
        switch self {
        case .collection:
            return "Available"
        case .selected:
            return "Selected"
        case .trade:
            return "Trade"
        case .swap:
            return "Swap"
        }
    }

    var title: String {
        switch self {
        case .collection:
            return "Available cards"
        case .selected:
            return "Selected squad cards"
        case .trade:
            return "Trade-ready reserve cards"
        case .swap:
            return "Swap and upgrade lane"
        }
    }

    var ctaLabel: String {
        switch self {
        case .collection:
            return "Open collection"
        case .selected:
            return "Open squad"
        case .trade:
            return "Manage trade"
        case .swap:
            return "Manage swap"
        }
    }

    var previewDesk: FootballDashboardDesk? {
        switch self {
        case .collection, .selected:
            return nil
        case .trade:
            return .trade
        case .swap:
            return .swap
        }
    }

    var emptyIcon: String {
        switch self {
        case .collection:
            return "square.stack.3d.down.right"
        case .selected:
            return "person.3.sequence.fill"
        case .trade:
            return "arrow.left.arrow.right.circle"
        case .swap:
            return "arrow.triangle.2.circlepath.circle"
        }
    }

    var emptyTitle: String {
        switch self {
        case .collection:
            return "No available cards"
        case .selected:
            return "No selected players yet"
        case .trade:
            return "No reserve cards ready for trade"
        case .swap:
            return "No swap lane yet"
        }
    }

    var emptyMessage: String {
        switch self {
        case .collection:
            return "Every owned card is currently feeding a squad, trade lane, or swap lane."
        case .selected:
            return "Choose a formation and assign players so your selected squad appears here."
        case .trade:
            return "Once the collection has spare cards, this panel can surface the best trade candidates."
        case .swap:
            return "As soon as you have squad choices, this panel can highlight the cards worth swapping in."
        }
    }

}

private enum FootballDashboardDesk: String, Identifiable {
    case trade
    case swap

    var id: String { rawValue }
}

private struct FootballDashboardDeskPreview: View {
    let desk: FootballDashboardDesk
    let cards: [FootballOwnedCard]
    let capacity: Int
    let maxCapacity: Int
    let detailContext: (FootballOwnedCard) -> FootballCardActionContext
    let onActionSelected: (FootballCardActionKind, FootballOwnedCard) -> Void

    private var accent: Color {
        switch desk {
        case .trade:
            return Color(red: 0.99, green: 0.78, blue: 0.36)
        case .swap:
            return Color(red: 0.97, green: 0.49, blue: 0.50)
        }
    }

    private var title: String {
        switch desk {
        case .trade:
            return "Trade Desk"
        case .swap:
            return "Swap Desk"
        }
    }

    private var intro: String {
        switch desk {
        case .trade:
            return "Manage the cards already queued for trade from the same dashboard flow."
        case .swap:
            return "Manage the cards waiting in the swap lane for upgrade decisions."
        }
    }

    private var points: [String] {
        switch desk {
        case .trade:
            return [
                "Queued cards can be removed from trade and sent back to available cards.",
                "Trade uses the same card detail flow and action side already in the dashboard.",
                "Keep the queue capped at 5 cards so trade decisions stay controlled."
            ]
        case .swap:
            return [
                "Queued cards can be removed from swap and sent back to available cards.",
                "Swap stays focused on upgrade-ready cards and replacement choices.",
                "Keep the queue capped at 5 cards so the lane stays readable."
            ]
        }
    }

    var body: some View {
        ZStack {
            Color.kcNavy.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(intro)
                    .font(.subheadline)
                    .foregroundStyle(Color.kcMuted)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Queue summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)

                    ForEach(points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(accent)
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)
                            Text(point)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(16)
                .background(Color.kcCard)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 12) {
                    previewBadge(text: "\(capacity)/\(maxCapacity) queued", tint: accent)
                    previewBadge(text: desk == .trade ? "Trade lane" : "Swap lane", tint: accent)
                    previewBadge(text: "Dashboard managed", tint: Color.kcMuted)
                }

                if cards.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: desk == .trade ? "arrow.left.arrow.right.circle" : "arrow.triangle.2.circlepath.circle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(accent)
                        Text(desk == .trade ? "No trade cards queued" : "No swap cards queued")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(desk == .trade ? "Use the Trade tile or a card action to move cards into the trade lane." : "Use the Swap tile or a card action to move cards into the swap lane.")
                            .font(.caption)
                            .foregroundStyle(Color.kcMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 18)
                    .background(Color.kcCard)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(cards) { card in
                                FootballPlayerCardView(
                                    card: card,
                                    detailContext: detailContext(card),
                                    onDetailActionSelected: { action in
                                        onActionSelected(action, card)
                                    },
                                    opensDetailOnBack: true,
                                    showsFlipHint: true
                                )
                                .frame(width: 200)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func previewBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct FootballDashboardStatRow: View {
    let title: String
    let value: String

    init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    init(title: String, value: Int) {
        self.title = title
        self.value = String(value)
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
