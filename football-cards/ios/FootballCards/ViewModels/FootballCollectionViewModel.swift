import Foundation

struct FootballLeagueSelection: Codable, Equatable {
    let leagueName: String
    let formation: String
    let clubId: String
    let clubName: String
    let clubLogoUrl: String?
}

enum FootballPositionFamily: String, CaseIterable {
    case goalkeeper
    case defender
    case midfielder
    case winger
    case attacker

    var displayName: String {
        switch self {
        case .goalkeeper:
            return "Goalkeeper"
        case .defender:
            return "Defender"
        case .midfielder:
            return "Midfielder"
        case .winger:
            return "Winger"
        case .attacker:
            return "Attacker"
        }
    }

    var displayNamePlural: String {
        switch self {
        case .goalkeeper:
            return "Goalkeepers"
        case .defender:
            return "Defenders"
        case .midfielder:
            return "Midfielders"
        case .winger:
            return "Wingers"
        case .attacker:
            return "Attackers"
        }
    }
}

struct FootballFormationSlot: Identifiable, Equatable {
    let id: String
    let displayName: String
    let acceptedFamilies: [FootballPositionFamily]

    var eligibilitySummary: String {
        acceptedFamilies.map(\.displayNamePlural).joined(separator: " + ")
    }
}

@MainActor
final class FootballCollectionViewModel: ObservableObject {
    private enum StorageKey {
        static let lockedLeagueSelections = "football_locked_league_selections"
        static let squadAssignments = "football_squad_assignments"
        static let tradeQueue = "football_trade_queue"
        static let swapQueue = "football_swap_queue"
        static let discardedCards = "football_discarded_cards"
        static let generatedSwapRewards = "football_generated_swap_rewards"
        static let swapsUsedToday = "football_swaps_used_today"
        static let swapUsageDate = "football_swap_usage_date"
    }

    let maxTradeQueueCount = 5
    let maxSwapQueueCount = 5
    let maxSwapsPerDay = 5

    let leagueOrder = ["Premier League", "Championship", "League One", "League Two"]
    let formationOptions = ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2", "3-4-3"]
    let bonusTeamKey = "Bonus Club"

    private let formationBlueprints: [String: [FootballFormationSlot]] = [
        "4-4-2": [
            FootballFormationSlot(id: "gk", displayName: "Goalkeeper", acceptedFamilies: [.goalkeeper]),
            FootballFormationSlot(id: "lb", displayName: "Left Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "lcb", displayName: "Left Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "rcb", displayName: "Right Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "rb", displayName: "Right Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "lm", displayName: "Left Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "lcm", displayName: "Left Centre Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "rcm", displayName: "Right Centre Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "rm", displayName: "Right Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "lst", displayName: "Left Striker", acceptedFamilies: [.attacker, .winger]),
            FootballFormationSlot(id: "rst", displayName: "Right Striker", acceptedFamilies: [.attacker, .winger]),
        ],
        "4-3-3": [
            FootballFormationSlot(id: "gk", displayName: "Goalkeeper", acceptedFamilies: [.goalkeeper]),
            FootballFormationSlot(id: "lb", displayName: "Left Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "lcb", displayName: "Left Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "rcb", displayName: "Right Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "rb", displayName: "Right Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "lcm", displayName: "Left Centre Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "cm", displayName: "Central Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "rcm", displayName: "Right Centre Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "lw", displayName: "Left Wing", acceptedFamilies: [.attacker, .winger]),
            FootballFormationSlot(id: "cf", displayName: "Centre Forward", acceptedFamilies: [.attacker, .winger]),
            FootballFormationSlot(id: "rw", displayName: "Right Wing", acceptedFamilies: [.attacker, .winger]),
        ],
        "4-2-3-1": [
            FootballFormationSlot(id: "gk", displayName: "Goalkeeper", acceptedFamilies: [.goalkeeper]),
            FootballFormationSlot(id: "lb", displayName: "Left Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "lcb", displayName: "Left Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "rcb", displayName: "Right Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "rb", displayName: "Right Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "ldm", displayName: "Left Defensive Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "rdm", displayName: "Right Defensive Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "lam", displayName: "Left Attacking Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "cam", displayName: "Central Attacking Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "ram", displayName: "Right Attacking Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "st", displayName: "Striker", acceptedFamilies: [.attacker, .winger]),
        ],
        "3-5-2": [
            FootballFormationSlot(id: "gk", displayName: "Goalkeeper", acceptedFamilies: [.goalkeeper]),
            FootballFormationSlot(id: "lcb", displayName: "Left Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "cb", displayName: "Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "rcb", displayName: "Right Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "lm", displayName: "Left Midfield", acceptedFamilies: [.midfielder, .winger]),
            FootballFormationSlot(id: "lcm", displayName: "Left Centre Midfield", acceptedFamilies: [.midfielder, .winger]),
            FootballFormationSlot(id: "cm", displayName: "Central Midfield", acceptedFamilies: [.midfielder, .winger]),
            FootballFormationSlot(id: "rcm", displayName: "Right Centre Midfield", acceptedFamilies: [.midfielder, .winger]),
            FootballFormationSlot(id: "rm", displayName: "Right Midfield", acceptedFamilies: [.midfielder, .winger]),
            FootballFormationSlot(id: "lst", displayName: "Left Striker", acceptedFamilies: [.attacker, .winger]),
            FootballFormationSlot(id: "rst", displayName: "Right Striker", acceptedFamilies: [.attacker, .winger]),
        ],
        "3-4-3": [
            FootballFormationSlot(id: "gk", displayName: "Goalkeeper", acceptedFamilies: [.goalkeeper]),
            FootballFormationSlot(id: "lcb", displayName: "Left Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "cb", displayName: "Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "rcb", displayName: "Right Centre Back", acceptedFamilies: [.defender]),
            FootballFormationSlot(id: "lm", displayName: "Left Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "lcm", displayName: "Left Centre Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "rcm", displayName: "Right Centre Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "rm", displayName: "Right Midfield", acceptedFamilies: [.midfielder]),
            FootballFormationSlot(id: "lw", displayName: "Left Wing", acceptedFamilies: [.attacker, .winger]),
            FootballFormationSlot(id: "cf", displayName: "Centre Forward", acceptedFamilies: [.attacker, .winger]),
            FootballFormationSlot(id: "rw", displayName: "Right Wing", acceptedFamilies: [.attacker, .winger]),
        ],
    ]

    private let formationRowBlueprints: [String: [Int]] = [
        "4-4-2": [1, 4, 4, 2],
        "4-3-3": [1, 4, 3, 3],
        "4-2-3-1": [1, 4, 2, 3, 1],
        "3-5-2": [1, 3, 5, 2],
        "3-4-3": [1, 3, 4, 3],
    ]

    @Published var isLoading = false
    @Published var cards: [FootballOwnedCard] = []
    @Published var clubs: [FootballClub] = []
    @Published var profile: FootballProfile?
    @Published var availableSlots: [String] = []
    @Published var availableClubs: [String] = []
    @Published var summary: FootballCollectionSummary?
    @Published var errorMessage: String?
    @Published var clubsErrorMessage: String?
    @Published var selectedSlot: String = "All"
    @Published var selectedClub: String = "All"
    @Published var searchText: String = ""
    @Published var draftFormationByLeague: [String: String] = [:]
    @Published var draftClubIdByLeague: [String: String] = [:]
    @Published private(set) var lockedLeagueSelections: [String: FootballLeagueSelection] = [:]
    @Published private(set) var squadAssignmentsByLeague: [String: [String: String]] = [:]
    @Published private(set) var queuedTradeCardIds: Set<String> = []
    @Published private(set) var queuedSwapCardIds: Set<String> = []
    @Published private(set) var discardedCardIds: Set<String> = []
    @Published private(set) var generatedSwapRewardCards: [FootballOwnedCard] = []
    @Published private(set) var swapsUsedToday = 0

    private var baseCollectionCards: [FootballOwnedCard] = []

    init() {
        restoreLockedLeagueSelections()
        restoreSquadAssignments()
        restoreActionQueues()
        restoreDiscardedCards()
        restoreGeneratedSwapRewards()
        restoreDailySwapUsage()
    }

    func reloadPersistedState() {
        restoreLockedLeagueSelections()
        restoreSquadAssignments()
        restoreActionQueues()
        restoreDiscardedCards()
        restoreGeneratedSwapRewards()
        restoreDailySwapUsage()
    }

    func loadCollection() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let collectionRequest = FootballAPIClient.shared.fetchCollection(
                slot: selectedSlot == "All" ? nil : selectedSlot,
                club: selectedClub == "All" ? nil : selectedClub,
                search: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : searchText,
                limit: 250
            )

            async let profileRequest = FootballAPIClient.shared.fetchProfile()
            async let clubsRequest = FootballAPIClient.shared.fetchClubs(limit: 100)

            let (collectionResult, profileResult, clubsResult) = try await (collectionRequest, profileRequest, clubsRequest)

            baseCollectionCards = collectionResult.cards
            cards = mergedCollectionCards(baseCards: collectionResult.cards)
            sanitizeDuplicateAssignments()
            availableSlots = ["All"] + collectionResult.availableSlots
            availableClubs = ["All"] + collectionResult.availableClubs
            summary = collectionResult.summary
            profile = profileResult.profile
            clubs = clubsResult.sorted {
                let lhsLeague = leagueOrder.firstIndex(of: $0.leagueName ?? "") ?? .max
                let rhsLeague = leagueOrder.firstIndex(of: $1.leagueName ?? "") ?? .max
                if lhsLeague != rhsLeague { return lhsLeague < rhsLeague }
                return $0.name < $1.name
            }
            clubsErrorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clubs(for leagueName: String) -> [FootballClub] {
        let onboardingClubId = profile?.supportedClubId
        let idsUsedByOtherLeagues = Set(
            lockedLeagueSelections
                .filter { $0.key != leagueName }
                .map { $0.value.clubId }
        )

        let currentDraftClubId = draftClubIdByLeague[leagueName]
        let lockedClubId = lockedLeagueSelections[leagueName]?.clubId

        return clubs.filter { club in
            guard club.leagueName == leagueName else { return false }
            if club.id == onboardingClubId { return false }
            if idsUsedByOtherLeagues.contains(club.id) { return false }
            if let lockedClubId, club.id == lockedClubId { return true }
            if let currentDraftClubId, club.id == currentDraftClubId { return true }
            return true
        }
    }

    func lockedSelection(for leagueName: String) -> FootballLeagueSelection? {
        lockedLeagueSelections[leagueName]
    }

    func activeFormation(for leagueName: String) -> String? {
        lockedLeagueSelections[leagueName]?.formation ?? draftFormationByLeague[leagueName]
    }

    func formationSlots(for leagueName: String) -> [FootballFormationSlot] {
        guard let formation = activeFormation(for: leagueName) else { return [] }
        return formationBlueprints[formation] ?? []
    }

    func formationRows(for leagueName: String) -> [[FootballFormationSlot]] {
        let slots = formationSlots(for: leagueName)
        guard let formation = activeFormation(for: leagueName),
              let rowBlueprint = formationRowBlueprints[formation]
        else {
            return slots.isEmpty ? [] : [slots]
        }

        var rows: [[FootballFormationSlot]] = []
        var startIndex = 0

        for rowCount in rowBlueprint {
            let endIndex = min(startIndex + rowCount, slots.count)
            guard startIndex < endIndex else { break }
            rows.append(Array(slots[startIndex..<endIndex]))
            startIndex = endIndex
        }

        if startIndex < slots.count {
            rows.append(Array(slots[startIndex...]))
        }

        return rows
    }

    func visibleFormationSlots(for leagueName: String) -> [FootballFormationSlot] {
        formationSlots(for: leagueName).filter { slot in
            assignedCard(for: leagueName, slot: slot) != nil || !eligibleCards(for: leagueName, slot: slot).isEmpty
        }
    }

    func eligibleCards(for leagueName: String, slot: FootballFormationSlot) -> [FootballOwnedCard] {
        guard let lockedSelection = lockedSelection(for: leagueName) else { return [] }

        let assignedCardIds = Set((squadAssignmentsByLeague[leagueName] ?? [:]).values)
        let currentAssignedCardId = squadAssignmentsByLeague[leagueName]?[slot.id]
        let blockedPlayerIds = assignedPlayerIds(for: leagueName, excluding: slot.id)

        return cards
            .filter { $0.ownershipStatus == "owned" }
            .filter { !isDiscarded($0) }
            .filter { card in
                if let clubId = card.clubId {
                    return clubId == lockedSelection.clubId
                }

                return card.clubName == lockedSelection.clubName
            }
            .filter { card in
                if assignedCardIds.contains(card.userCardId) && card.userCardId != currentAssignedCardId {
                    return false
                }
                if blockedPlayerIds.contains(card.playerId) {
                    return false
                }
                guard let family = positionFamily(for: card) else { return false }
                return slot.acceptedFamilies.contains(family)
            }
            .sorted { lhs, rhs in
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
    }

    func assignedCard(for leagueName: String, slot: FootballFormationSlot) -> FootballOwnedCard? {
        guard let cardId = squadAssignmentsByLeague[leagueName]?[slot.id] else { return nil }
        return cards.first(where: { $0.userCardId == cardId })
    }

    func assignedSlot(for card: FootballOwnedCard, in leagueName: String) -> FootballFormationSlot? {
        formationSlots(for: leagueName).first { slot in
            assignedCard(for: leagueName, slot: slot)?.userCardId == card.userCardId
        }
    }

    func matchingLockedLeague(for card: FootballOwnedCard) -> String? {
        lockedLeagueSelections.first { _, selection in
            if let clubId = card.clubId {
                return selection.clubId == clubId
            }

            return selection.clubName == card.clubName
        }?.key
    }

    func eligibleSlots(for card: FootballOwnedCard, in leagueName: String) -> [FootballFormationSlot] {
        formationSlots(for: leagueName).filter { slot in
            eligibleCards(for: leagueName, slot: slot).contains(where: { $0.userCardId == card.userCardId })
        }
    }

    func openEligibleSlots(for card: FootballOwnedCard, in leagueName: String) -> [FootballFormationSlot] {
        eligibleSlots(for: card, in: leagueName).filter { assignedCard(for: leagueName, slot: $0) == nil }
    }

    func upgradeEligibleSlots(for card: FootballOwnedCard, in leagueName: String) -> [FootballFormationSlot] {
        eligibleSlots(for: card, in: leagueName).filter { slot in
            guard let assigned = assignedCard(for: leagueName, slot: slot), assigned.userCardId != card.userCardId else {
                return false
            }

            return normalizedRating(for: card) > normalizedRating(for: assigned)
        }
    }

    func isTeamComplete(for leagueName: String) -> Bool {
        let slots = formationSlots(for: leagueName)
        guard !slots.isEmpty else { return false }
        return assignedUniquePlayerCount(for: leagueName) >= slots.count
    }

    func assignCard(_ card: FootballOwnedCard, to leagueName: String, slot: FootballFormationSlot) {
        if let existingSlot = assignedSlot(for: card, in: leagueName), existingSlot.id != slot.id {
            return
        }

        var leagueAssignments = squadAssignmentsByLeague[leagueName] ?? [:]
        leagueAssignments[slot.id] = card.userCardId
        squadAssignmentsByLeague[leagueName] = leagueAssignments
        sanitizeDuplicateAssignments()
        persistSquadAssignments()
    }

    func clearAssignment(for leagueName: String, slot: FootballFormationSlot) {
        var leagueAssignments = squadAssignmentsByLeague[leagueName] ?? [:]
        leagueAssignments.removeValue(forKey: slot.id)
        squadAssignmentsByLeague[leagueName] = leagueAssignments
        persistSquadAssignments()
    }

    func assignedCount(for leagueName: String) -> Int {
        assignedUniquePlayerCount(for: leagueName)
    }

    func assignedCards(for leagueName: String) -> [FootballOwnedCard] {
        var seenPlayerIds: Set<String> = []

        return formationSlots(for: leagueName).compactMap { slot in
            guard let card = assignedCard(for: leagueName, slot: slot) else { return nil }
            guard seenPlayerIds.insert(card.playerId).inserted else { return nil }
            return card
        }
    }

    func assignedUniquePlayerCount(for leagueName: String) -> Int {
        Set(assignedCards(for: leagueName).map(\.playerId)).count
    }

    func ownedCopyCount(for card: FootballOwnedCard) -> Int {
        cards
            .filter { $0.ownershipStatus == "owned" }
            .filter { !isDiscarded($0) }
            .filter { $0.playerId == card.playerId }
            .count
    }

    func teamScore(for leagueName: String) -> Double {
        let baseScore = assignedCards(for: leagueName).reduce(0) { partialResult, card in
            partialResult + normalizedRating(for: card)
        }

        if leagueName == bonusTeamKey {
            return baseScore * 1.5
        }

        return baseScore
    }

    func buildableCardCount(for leagueName: String) -> Int {
        let slots = formationSlots(for: leagueName)
        guard !slots.isEmpty else { return 0 }

        let assignedIds = Set((squadAssignmentsByLeague[leagueName] ?? [:]).values)
        let buildableIds = Set(
            slots.flatMap { slot in
                eligibleCards(for: leagueName, slot: slot)
                    .filter { !assignedIds.contains($0.userCardId) }
                    .map(\.userCardId)
            }
        )

        return buildableIds.count
    }

    func draftBuildableCardCount(for leagueName: String, club: FootballClub) -> Int {
        draftEligibleCards(for: leagueName, club: club).count
    }

    func draftEligibleCards(for leagueName: String, club: FootballClub) -> [FootballOwnedCard] {
        let slots = formationSlots(for: leagueName)
        let matchingCards = cards
            .filter { $0.ownershipStatus == "owned" }
            .filter { cardMatchesClub($0, club: club) }

        guard !slots.isEmpty else {
            return matchingCards.sorted(by: draftCardSort(lhs:rhs:))
        }

        let buildableIds = Set<String>(
            slots.flatMap { slot in
                matchingCards.compactMap { card in
                    guard let family = positionFamily(for: card), slot.acceptedFamilies.contains(family) else {
                        return nil
                    }
                    return card.userCardId
                }
            }
        )

        return matchingCards
            .filter { buildableIds.contains($0.userCardId) }
            .sorted(by: draftCardSort(lhs:rhs:))
    }

    func positionDisplayName(for card: FootballOwnedCard) -> String {
        let raw = (card.detailedPositionLabel ?? card.positionLabel ?? card.starterSlotCode ?? "Player")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "Player" : raw
    }

    private func normalizedClubName(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func assignedPlayerIds(for leagueName: String, excluding slotId: String? = nil) -> Set<String> {
        formationSlots(for: leagueName).compactMap { slot in
            guard slot.id != slotId else { return nil }
            return assignedCard(for: leagueName, slot: slot)?.playerId
        }.reduce(into: Set<String>()) { partialResult, playerId in
            partialResult.insert(playerId)
        }
    }

    private func sanitizeDuplicateAssignments() {
        var sanitizedAssignments = squadAssignmentsByLeague
        var hasChanges = false

        for leagueName in sanitizedAssignments.keys {
            var leagueAssignments = sanitizedAssignments[leagueName] ?? [:]
            var seenPlayerIds: Set<String> = []

            for slot in formationSlots(for: leagueName) {
                guard let cardId = leagueAssignments[slot.id],
                      let card = cards.first(where: { $0.userCardId == cardId }) else {
                    continue
                }

                if seenPlayerIds.contains(card.playerId) {
                    leagueAssignments.removeValue(forKey: slot.id)
                    hasChanges = true
                } else {
                    seenPlayerIds.insert(card.playerId)
                }
            }

            sanitizedAssignments[leagueName] = leagueAssignments
        }

        if hasChanges {
            squadAssignmentsByLeague = sanitizedAssignments
        }
    }

    private func mergedCollectionCards(baseCards: [FootballOwnedCard]) -> [FootballOwnedCard] {
        baseCards + generatedSwapRewardCards
    }

    private func generateSwapRewards(count: Int, excludingPlayerIds: Set<String> = []) -> [FootballOwnedCard] {
        let allRewardTemplates = (baseCollectionCards.isEmpty ? cards : baseCollectionCards)
            .filter { $0.ownershipStatus == "owned" }

        let rewardTemplates = allRewardTemplates.filter { !excludingPlayerIds.contains($0.playerId) }
        let candidateTemplates = rewardTemplates.isEmpty ? allRewardTemplates : rewardTemplates

        guard !candidateTemplates.isEmpty else { return [] }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        return (0..<count).compactMap { _ in
            guard let template = candidateTemplates.randomElement() else { return nil }
            return template.swappedRewardCopy(
                userCardId: "swap-\(UUID().uuidString.lowercased())",
                acquiredAt: timestamp
            )
        }
    }

    private func cardMatchesClub(_ card: FootballOwnedCard, club: FootballClub) -> Bool {
        if let clubId = card.clubId, clubId == club.id {
            return true
        }

        let cardClubName = normalizedClubName(card.clubName)
        guard !cardClubName.isEmpty else { return false }

        let candidateNames = [club.name, club.shortName, club.code]
            .map(normalizedClubName)
            .filter { !$0.isEmpty }

        return candidateNames.contains(cardClubName)
    }

    private func draftCardSort(lhs: FootballOwnedCard, rhs: FootballOwnedCard) -> Bool {
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

    func shortDisplayName(for card: FootballOwnedCard) -> String {
        let cleaned = card.playerName
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard let surname = cleaned.last else { return card.playerName }
        guard let first = cleaned.first, cleaned.count > 1, let initial = first.first else {
            return surname
        }

        return "\(initial). \(surname)"
    }

    func selectedDraftClub(for leagueName: String) -> FootballClub? {
        guard let clubId = draftClubIdByLeague[leagueName] else { return nil }
        return clubs.first(where: { $0.id == clubId })
    }

    func setFormation(_ formation: String, for leagueName: String) {
        guard lockedLeagueSelections[leagueName] == nil else { return }
        draftFormationByLeague[leagueName] = formation
    }

    func setDraftClub(_ clubId: String, for leagueName: String) {
        guard lockedLeagueSelections[leagueName] == nil else { return }
        draftClubIdByLeague[leagueName] = clubId
    }

    func canLockSelection(for leagueName: String) -> Bool {
        lockedLeagueSelections[leagueName] == nil &&
        !(draftFormationByLeague[leagueName] ?? "").isEmpty &&
        draftClubIdByLeague[leagueName] != nil
    }

    func lockSelection(for leagueName: String) {
        guard canLockSelection(for: leagueName),
              let formation = draftFormationByLeague[leagueName],
              let club = selectedDraftClub(for: leagueName)
        else {
            return
        }

        lockedLeagueSelections[leagueName] = FootballLeagueSelection(
            leagueName: leagueName,
            formation: formation,
            clubId: club.id,
            clubName: club.name,
            clubLogoUrl: club.logoUrl
        )
        persistLockedLeagueSelections()
    }

    func canLockBonusSelection() -> Bool {
        lockedLeagueSelections[bonusTeamKey] == nil &&
        !(draftFormationByLeague[bonusTeamKey] ?? "").isEmpty &&
        profile?.supportedClubId != nil
    }

    func lockBonusSelection() {
        guard canLockBonusSelection(),
              let formation = draftFormationByLeague[bonusTeamKey],
              let supportedClubId = profile?.supportedClubId,
              let supportedClubName = profile?.supportedClubName
        else {
            return
        }

        lockedLeagueSelections[bonusTeamKey] = FootballLeagueSelection(
            leagueName: bonusTeamKey,
            formation: formation,
            clubId: supportedClubId,
            clubName: supportedClubName,
            clubLogoUrl: profile?.supportedClubLogoUrl
        )
        persistLockedLeagueSelections()
    }

    var onboardingBonusClubName: String? {
        profile?.supportedClubName
    }

    var onboardingBonusLeagueName: String? {
        profile?.supportedLeagueName
    }

    var onboardingBonusLogoURL: String? {
        profile?.supportedClubLogoUrl
    }

    var totalAssignedCount: Int {
        let leagues = Set(lockedLeagueSelections.keys).union(squadAssignmentsByLeague.keys)
        return leagues.reduce(0) { partialResult, leagueName in
            partialResult + assignedCount(for: leagueName)
        }
    }

    var totalTeamScore: Double {
        let leagues = Set(lockedLeagueSelections.keys).union(squadAssignmentsByLeague.keys)
        return leagues.reduce(0) { partialResult, leagueName in
            partialResult + teamScore(for: leagueName)
        }
    }

    var assignedLeagueCount: Int {
        let leagues = Set(lockedLeagueSelections.keys).union(squadAssignmentsByLeague.keys)
        return leagues.filter { assignedCount(for: $0) > 0 }.count
    }

    var lockedLeagueCount: Int {
        lockedLeagueSelections.count
    }

    func isQueuedForTrade(_ card: FootballOwnedCard) -> Bool {
        queuedTradeCardIds.contains(card.userCardId)
    }

    func isQueuedForSwap(_ card: FootballOwnedCard) -> Bool {
        queuedSwapCardIds.contains(card.userCardId)
    }

    func canQueueForTrade(_ card: FootballOwnedCard) -> Bool {
        queuedTradeCardIds.contains(card.userCardId) || queuedTradeCardIds.count < maxTradeQueueCount
    }

    func canQueueForSwap(_ card: FootballOwnedCard) -> Bool {
        queuedSwapCardIds.contains(card.userCardId) || queuedSwapCardIds.count < maxSwapQueueCount
    }

    var swapsRemainingToday: Int {
        max(0, maxSwapsPerDay - swapsUsedToday)
    }

    var swapUsageDisplay: String {
        "\(swapsUsedToday)/\(maxSwapsPerDay)"
    }

    var canExecuteQueuedSwap: Bool {
        return !queuedSwapCardIds.isEmpty && swapsUsedToday < maxSwapsPerDay
    }

    func queueForTrade(_ card: FootballOwnedCard) {
        guard canQueueForTrade(card) else { return }
        queuedSwapCardIds.remove(card.userCardId)
        queuedTradeCardIds.insert(card.userCardId)
        persistActionQueues()
    }

    func queueForSwap(_ card: FootballOwnedCard) {
        guard canQueueForSwap(card) else { return }
        queuedTradeCardIds.remove(card.userCardId)
        queuedSwapCardIds.insert(card.userCardId)
        persistActionQueues()
    }

    func removeFromQueues(_ card: FootballOwnedCard) {
        queuedTradeCardIds.remove(card.userCardId)
        queuedSwapCardIds.remove(card.userCardId)
        persistActionQueues()
    }

    /// Called after exchange view loads to align local queue with server truth.
    func syncTradeQueueWithServer(listedCardIds: Set<String>) {
        queuedTradeCardIds = listedCardIds
        persistActionQueues()
    }

    /// Add a card the user acquired via the exchange (card transfers to them).
    func addAcquiredCard(_ card: FootballOwnedCard) {
        if !cards.contains(where: { $0.userCardId == card.userCardId }) {
            cards.append(card)
        }
    }

    func isDiscarded(_ card: FootballOwnedCard) -> Bool {
        discardedCardIds.contains(card.userCardId)
    }

    func discardCard(_ card: FootballOwnedCard) {
        queuedTradeCardIds.remove(card.userCardId)
        queuedSwapCardIds.remove(card.userCardId)
        discardedCardIds.insert(card.userCardId)
        persistActionQueues()
        persistDiscardedCards()
    }

    @discardableResult
    func executeSwap() async -> [FootballOwnedCard] {
        errorMessage = nil
        refreshDailySwapUsageIfNeeded()
        guard swapsUsedToday < maxSwapsPerDay else { return [] }

        guard let queuedCard = cards
            .sorted(by: draftCardSort(lhs:rhs:))
            .first(where: { queuedSwapCardIds.contains($0.userCardId) })
        else {
            return []
        }

        do {
            let swapResult = try await FootballAPIClient.shared.executeSwap(
                swappedOutUserCardId: queuedCard.userCardId,
                excludedPlayerIds: excludedSwapPoolPlayerIds()
            )

            queuedSwapCardIds.remove(queuedCard.userCardId)
            swapsUsedToday += 1
            persistActionQueues()
            persistDailySwapUsage()
            await loadCollection()
            reloadPersistedState()
            sanitizeDuplicateAssignments()

            return [swapResult.rewardCard]
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    private func excludedSwapPoolPlayerIds() -> [String] {
        let selectedCardIds = Set(squadAssignmentsByLeague.values.flatMap { $0.values })

        return Array(
            Set(
                cards
                    .filter { $0.ownershipStatus == "owned" }
                    .filter { !discardedCardIds.contains($0.userCardId) }
                    .filter { !selectedCardIds.contains($0.userCardId) }
                    .map(\.playerId)
            )
        )
    }

    private func restoreLockedLeagueSelections() {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.lockedLeagueSelections) else {
            lockedLeagueSelections = [:]
            return
        }

        lockedLeagueSelections = (try? JSONDecoder().decode([String: FootballLeagueSelection].self, from: data)) ?? [:]
    }

    private func persistLockedLeagueSelections() {
        guard let data = try? JSONEncoder().encode(lockedLeagueSelections) else { return }
        UserDefaults.standard.set(data, forKey: StorageKey.lockedLeagueSelections)
    }

    private func restoreSquadAssignments() {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.squadAssignments) else {
            squadAssignmentsByLeague = [:]
            return
        }

        squadAssignmentsByLeague = (try? JSONDecoder().decode([String: [String: String]].self, from: data)) ?? [:]
    }

    private func persistSquadAssignments() {
        guard let data = try? JSONEncoder().encode(squadAssignmentsByLeague) else { return }
        UserDefaults.standard.set(data, forKey: StorageKey.squadAssignments)
    }

    private func restoreActionQueues() {
        if let tradeData = UserDefaults.standard.data(forKey: StorageKey.tradeQueue),
           let tradeIds = try? JSONDecoder().decode(Set<String>.self, from: tradeData) {
            queuedTradeCardIds = tradeIds
        } else {
            queuedTradeCardIds = []
        }

        if let swapData = UserDefaults.standard.data(forKey: StorageKey.swapQueue),
           let swapIds = try? JSONDecoder().decode(Set<String>.self, from: swapData) {
            queuedSwapCardIds = swapIds
        } else {
            queuedSwapCardIds = []
        }
    }

    private func persistActionQueues() {
        if let tradeData = try? JSONEncoder().encode(queuedTradeCardIds) {
            UserDefaults.standard.set(tradeData, forKey: StorageKey.tradeQueue)
        }

        if let swapData = try? JSONEncoder().encode(queuedSwapCardIds) {
            UserDefaults.standard.set(swapData, forKey: StorageKey.swapQueue)
        }
    }

    private func restoreDiscardedCards() {
        if let discardedData = UserDefaults.standard.data(forKey: StorageKey.discardedCards),
           let discardedIds = try? JSONDecoder().decode(Set<String>.self, from: discardedData) {
            discardedCardIds = discardedIds
        } else {
            discardedCardIds = []
        }
    }

    private func persistDiscardedCards() {
        if let discardedData = try? JSONEncoder().encode(discardedCardIds) {
            UserDefaults.standard.set(discardedData, forKey: StorageKey.discardedCards)
        }
    }

    private func restoreGeneratedSwapRewards() {
        if let rewardData = UserDefaults.standard.data(forKey: StorageKey.generatedSwapRewards),
           let rewardCards = try? JSONDecoder().decode([FootballOwnedCard].self, from: rewardData) {
            generatedSwapRewardCards = rewardCards
        } else {
            generatedSwapRewardCards = []
        }
    }

    private func persistGeneratedSwapRewards() {
        if let rewardData = try? JSONEncoder().encode(generatedSwapRewardCards) {
            UserDefaults.standard.set(rewardData, forKey: StorageKey.generatedSwapRewards)
        }
    }

    private func restoreDailySwapUsage() {
        refreshDailySwapUsageIfNeeded()
        swapsUsedToday = UserDefaults.standard.integer(forKey: StorageKey.swapsUsedToday)
    }

    private func persistDailySwapUsage() {
        UserDefaults.standard.set(swapsUsedToday, forKey: StorageKey.swapsUsedToday)
        UserDefaults.standard.set(todaySwapUsageKey, forKey: StorageKey.swapUsageDate)
    }

    private func refreshDailySwapUsageIfNeeded() {
        let storedDay = UserDefaults.standard.string(forKey: StorageKey.swapUsageDate)
        guard storedDay == todaySwapUsageKey else {
            swapsUsedToday = 0
            persistDailySwapUsage()
            return
        }

        swapsUsedToday = UserDefaults.standard.integer(forKey: StorageKey.swapsUsedToday)
    }

    private var todaySwapUsageKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func normalizedRating(for card: FootballOwnedCard) -> Double {
        card.ratingOutOfTen ?? -1
    }

    private func positionFamily(for card: FootballOwnedCard) -> FootballPositionFamily? {
        let source = [card.detailedPositionLabel, card.positionLabel, card.starterSlotCode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .first { !$0.isEmpty } ?? ""
        let normalizedSource = source
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        if normalizedSource.isEmpty { return nil }

        if normalizedSource == "gk" || normalizedSource.contains("goalkeeper") {
            return .goalkeeper
        }

        if normalizedSource.contains("wing back") || ["rb", "lb", "cb", "lcb", "rcb"].contains(normalizedSource) || normalizedSource.contains("back") || normalizedSource.contains("defender") {
            return .defender
        }

        if ["lw", "rw"].contains(normalizedSource)
            || normalizedSource == "wing"
            || normalizedSource.contains("left wing")
            || normalizedSource.contains("right wing")
            || normalizedSource.contains("winger")
            || normalizedSource.contains("inside forward") {
            return .winger
        }

        if ["cm", "cdm", "cam", "dm", "am", "lm", "rm"].contains(normalizedSource) || normalizedSource.contains("midfield") || normalizedSource.contains("midfielder") {
            return .midfielder
        }

        if ["st", "cf", "ss"].contains(normalizedSource) || normalizedSource.contains("striker") || normalizedSource.contains("forward") || normalizedSource.contains("attacker") {
            return .attacker
        }

        return nil
    }
}
