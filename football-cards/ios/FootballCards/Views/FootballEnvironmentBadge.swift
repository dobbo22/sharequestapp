import SwiftUI

struct FootballEnvironmentBadge: View {
    let label: String
    let isLocal: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isLocal ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
