import Foundation

struct FootballBootstrapResponse: Decodable {
    let success: Bool
    let data: FootballBootstrapData
}

struct FootballBootstrapData: Decodable {
    let gameConfig: FootballGameConfig
    let starterSlots: [FootballStarterSlot]
    let leagues: [FootballLeague]
    let stats: FootballBootstrapStats
}

struct FootballGameConfig: Decodable {
    let country: String
    let sourceLeagues: [FootballSourceLeague]
    let starterSlots: [String]
    let starterCardsPerSlot: Int
}

struct FootballSourceLeague: Decodable, Identifiable {
    let name: String
    let apiFootballLeagueId: Int
    let tier: Int

    var id: Int { apiFootballLeagueId }
}

struct FootballStarterSlot: Decodable, Identifiable {
    let slotCode: String
    let displayName: String
    let sortOrder: Int
    let starterQuantity: Int

    var id: String { slotCode }
}

struct FootballLeague: Decodable, Identifiable {
    let id: String
    let apiFootballLeagueId: Int
    let seasonYear: Int
    let name: String
    let slug: String
    let tier: Int
    let logoUrl: String?
    let isActive: Bool
}

struct FootballBootstrapStats: Decodable {
    let leaguesCount: Int
    let clubsCount: Int
    let playersCount: Int
    let profilesCount: Int
    let userCardsCount: Int
}