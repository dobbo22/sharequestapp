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

struct FootballOwnedCard: Codable, Identifiable {
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

    func swappedRewardCopy(userCardId: String, acquiredAt: String) -> FootballOwnedCard {
        FootballOwnedCard(
            userCardId: userCardId,
            playerId: playerId,
            cardTemplateId: cardTemplateId,
            clubId: clubId,
            starterSlotCode: starterSlotCode,
            starterSlotCopy: starterSlotCopy,
            ownershipStatus: "owned",
            acquiredAt: acquiredAt,
            playerName: playerName,
            age: age,
            positionLabel: positionLabel,
            detailedPositionLabel: detailedPositionLabel,
            heightCm: heightCm,
            weightKg: weightKg,
            appearances: appearances,
            goals: goals,
            assists: assists,
            tackles: tackles,
            shotsOnTarget: shotsOnTarget,
            saves: saves,
            cleanSheets: cleanSheets,
            goalsConceded: goalsConceded,
            passes: passes,
            latestTransferAmount: latestTransferAmount,
            ratingOutOfTen: ratingOutOfTen,
            ratingSource: ratingSource,
            ratingTier: ratingTier,
            photoUrl: photoUrl,
            clubName: clubName,
            clubLogoUrl: clubLogoUrl,
            leagueName: leagueName,
            seasonYear: seasonYear
        )
    }
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

// MARK: - Exchange

struct FootballExchangeListingCard: Decodable {
    let listingId: String
    let sellerUserId: String
    let sellerName: String?
    let cardRating: Double?
    let ratingCost: Double
    let listedAt: String
    let expiresAt: String
    let removableAt: String
    let status: String

    // Full card fields (inline from SQL join)
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

    var listedAtDate: Date? { ISO8601DateFormatter().date(from: listedAt) }
    var expiresAtDate: Date? { ISO8601DateFormatter().date(from: expiresAt) }
    var removableAtDate: Date? { ISO8601DateFormatter().date(from: removableAt) }

    var isExpired: Bool {
        guard let exp = expiresAtDate else { return false }
        return Date() >= exp
    }

    var canRemove: Bool {
        guard let rem = removableAtDate, let exp = expiresAtDate else { return false }
        return Date() >= rem && Date() < exp && status == "active"
    }

    var timeRemainingText: String {
        guard let exp = expiresAtDate else { return "Unknown" }
        let remaining = exp.timeIntervalSinceNow
        if remaining <= 0 { return "Expired" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m left" }
        return "\(minutes)m left"
    }

    var asOwnedCard: FootballOwnedCard {
        FootballOwnedCard(
            userCardId: userCardId, playerId: playerId, cardTemplateId: cardTemplateId,
            clubId: clubId, starterSlotCode: starterSlotCode, starterSlotCopy: starterSlotCopy,
            ownershipStatus: ownershipStatus, acquiredAt: acquiredAt,
            playerName: playerName, age: age, positionLabel: positionLabel,
            detailedPositionLabel: detailedPositionLabel, heightCm: heightCm, weightKg: weightKg,
            appearances: appearances, goals: goals, assists: assists, tackles: tackles,
            shotsOnTarget: shotsOnTarget, saves: saves, cleanSheets: cleanSheets,
            goalsConceded: goalsConceded, passes: passes,
            latestTransferAmount: latestTransferAmount, ratingOutOfTen: ratingOutOfTen,
            ratingSource: ratingSource, ratingTier: ratingTier, photoUrl: photoUrl,
            clubName: clubName, clubLogoUrl: clubLogoUrl, leagueName: leagueName, seasonYear: seasonYear
        )
    }
}

struct FootballExchangeResponse: Decodable {
    let success: Bool
    let data: FootballExchangeData
}

struct FootballExchangeData: Decodable {
    let marketplace: [FootballExchangeListingCard]
    let myListings: [FootballExchangeListingCard]
    let tradeRatingBalance: Double
}

struct FootballCreateListingResponse: Decodable {
    let success: Bool
    let data: FootballCreateListingResult
}

struct FootballCreateListingResult: Decodable {
    let listingId: String
    let listedAt: String
    let expiresAt: String
    let removableAt: String
}

struct FootballBuyListingRequest: Encodable {
    let listingId: String
}

struct FootballBuyListingResponse: Decodable {
    let success: Bool
    let data: FootballBuyListingResult
}

struct FootballBuyListingResult: Decodable {
    let listingId: String
    let acquiredCard: FootballOwnedCard?
    let costPaid: Double
}

// MARK: - Swap

struct FootballSwapRequest: Encodable {
    let swappedOutUserCardId: String
    let excludedPlayerIds: [String]
}

struct FootballSwapResponse: Decodable {
    let success: Bool
    let data: FootballSwapResult
}

struct FootballSwapResult: Decodable {
    let swappedOutUserCardId: String
    let rewardCard: FootballOwnedCard
}
