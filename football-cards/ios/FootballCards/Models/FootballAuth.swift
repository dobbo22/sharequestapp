import Foundation

struct FootballAuthResponse: Decodable {
    let success: Bool
    let token: String?
    let user: FootballAuthenticatedUser?
    let error: String?
    let message: String?
    let data: FootballAuthPayload?
}

struct FootballAuthPayload: Decodable {
    let token: String
    let user: FootballAuthenticatedUser
}

struct FootballAuthenticatedUser: Decodable, Identifiable {
    let id: String
    let username: String
    let email: String
    let firstName: String?
    let lastName: String?
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case isAdmin
    }

    var displayName: String {
        if let firstName, !firstName.isEmpty {
            return firstName
        }
        return username
    }
}

struct FootballLoginRequest: Encodable {
    let email: String
    let password: String
}

struct FootballRegisterRequest: Encodable {
    let email: String
    let username: String
    let password: String
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case username
        case password
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct FootballAppleAuthRequest: Encodable {
    let identityToken: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let appleUserId: String
}
