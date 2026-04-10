import SwiftUI

// MARK: - DiceBear avatar helpers
// Player photos → footballgame style (unique per player name)
// Club logos    → initials style (coloured badge per club name)

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
struct PlayerAvatarImage: View {
    let playerName: String
    var size: CGFloat = 80

    var body: some View {
        AsyncImage(url: DiceBear.playerURL(playerName)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFit()
            default:
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(size * 0.2)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Club logo
struct ClubLogoImage: View {
    let clubName: String
    var size: CGFloat = 40

    var body: some View {
        AsyncImage(url: DiceBear.clubURL(clubName)) { phase in
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
