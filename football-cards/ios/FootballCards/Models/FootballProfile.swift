import Foundation

struct FootballProfileResponse: Decodable {
    let success: Bool
    let data: FootballProfileData
}

struct FootballProfileData: Decodable {
    let profile: FootballProfile?
    let collectionSummary: FootballCollectionSummary
    let starterPackCards: [FootballOwnedCard]
    let allocation: FootballStarterPackAllocation?
}

struct FootballCollectionResponse: Decodable {
    let success: Bool
    let data: FootballCollectionData
}

struct FootballCollectionData: Decodable {
    let cards: [FootballOwnedCard]
    let availableSlots: [String]
    let availableClubs: [String]
    let summary: FootballCollectionSummary
}

struct FootballProfile: Decodable {
    let id: String
    let userId: String
    let supportedClubId: String?
    let displayName: String?
    let teamName: String?
    let starterPackStatus: String
    let onboardingCompletedAt: String?
    let supportedClubName: String?
    let supportedClubLogoUrl: String?
    let supportedLeagueName: String?

    var hasCompletedOnboarding: Bool {
        supportedClubId != nil && onboardingCompletedAt != nil
    }
}

struct FootballCollectionSummary: Decodable {
    let totalCards: Int
    let ownedCards: Int
    let starterSlotsFilled: Int
}

struct FootballOwnedCard: Decodable, Identifiable {
    let userCardId: String
    let playerId: String
    let cardTemplateId: String
    let clubId: String?
    let starterSlotCode: String?
    let starterSlotCopy: Int?
    let ownershipStatus: String
    let acquiredAt: String?
    let playerName: String
    let age: Int?
    let positionLabel: String?
    let detailedPositionLabel: String?
    let heightCm: Int?
    let weightKg: Int?
    let appearances: Int?
    let goals: Int?
    let assists: Int?
    let tackles: Int?
    let shotsOnTarget: Int?
    let saves: Int?
    let cleanSheets: Int?
    let goalsConceded: Int?
    let passes: Int?
    let latestTransferAmount: Double?
    let ratingOutOfTen: Double?
    let ratingSource: String?
    let ratingTier: String?
    let photoUrl: String?
    let clubName: String?
    let clubLogoUrl: String?
    let leagueName: String?
    let seasonYear: Int?

    var id: String { userCardId }
}

struct FootballStarterPackAllocation: Decodable, Identifiable {
    let starterPackId: String
    let createdCardCount: Int
    let alreadyExisted: Bool
    let warnings: [String]

    var id: String { starterPackId }

    var revealStorageKey: String {
        "football_revealed_starter_pack_\(starterPackId)"
    }

    var needsReveal: Bool {
        !alreadyExisted && !UserDefaults.standard.bool(forKey: revealStorageKey)
    }

    func markRevealed() {
        UserDefaults.standard.set(true, forKey: revealStorageKey)
    }
}

struct FootballClubListResponse: Decodable {
    let success: Bool
    let data: [FootballClub]
}

struct FootballClub: Decodable, Identifiable {
    let id: String
    let apiFootballTeamId: Int
    let name: String
    let shortName: String?
    let code: String?
    let logoUrl: String?
    let venueName: String?
    let venueCity: String?
    let leagueId: String?
    let leagueName: String?
    let leagueTier: Int?
    let seasonYear: Int?
}

struct FootballProfileUpdateRequest: Encodable {
    let supportedClubId: String
    let displayName: String?
    let teamName: String?
}
