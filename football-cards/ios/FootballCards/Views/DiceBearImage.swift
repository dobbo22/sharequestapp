import SwiftUI

// MARK: - DiceBear fallback helpers (used when real photo/logo URL is unavailable)

enum DiceBear {
    static func playerURL(_ name: String) -> URL? {
        var c = URLComponents(string: "https://api.dicebear.com/7.x/footballgame/svg")
        c?.queryItems = [URLQueryItem(name: "seed", value: name)]
        return c?.url
    }

    static func clubURL(_ name: String) -> URL? {
        var c = URLComponents(string: "https://api.dicebear.com/7.x/initials/svg")
        c?.queryItems = [
            URLQueryItem(name: "seed", value: name),
            URLQueryItem(name: "fontWeight", value: "700"),
            URLQueryItem(name: "fontSize", value: "40"),
        ]
        return c?.url
    }
}

// MARK: - Player photo
// Uses photoUrl when provided, falls back to DiceBear avatar
struct PlayerAvatarImage: View {
    let playerName: String
    var photoUrl: String? = nil
    var size: CGFloat = 80

    private var resolvedURL: URL? {
        if let urlString = photoUrl, !urlString.isEmpty {
            return URL(string: urlString)
        }
        return DiceBear.playerURL(playerName)
    }

    var body: some View {
        AsyncImage(url: resolvedURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            default:
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

// MARK: - Club logo
// Uses logoUrl when provided, falls back to DiceBear initials badge
struct ClubLogoImage: View {
    let clubName: String
    var logoUrl: String? = nil
    var size: CGFloat = 40

    private var resolvedURL: URL? {
        if let urlString = logoUrl, !urlString.isEmpty {
            return URL(string: urlString)
        }
        return DiceBear.clubURL(clubName)
    }

    var body: some View {
        AsyncImage(url: resolvedURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFit()
            default:
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.35, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: String {
        clubName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}
