import Foundation

struct FootballSyncStatusResponse: Decodable {
    let success: Bool
    let data: FootballSyncStatusData
}

struct FootballSyncStatusData: Decodable {
    let latest: FootballSyncJob?
    let recent: [FootballSyncJob]
    let aggregates: FootballSyncAggregates
}

struct FootballSyncJob: Decodable, Identifiable {
    let id: String
    let source: String
    let jobType: String
    let status: String
    let startedAt: String?
    let completedAt: String?
    let durationSeconds: Int?
    let requestedByUserId: String?
    let createdAt: String?
    let details: [String: JSONValue]?
}

struct FootballSyncAggregates: Decodable {
    let totalRuns: Int
    let completedRuns: Int
    let failedRuns: Int
    let runningRuns: Int
    let lastRunAt: String?
}

enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }

        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }

        throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
    }
}
