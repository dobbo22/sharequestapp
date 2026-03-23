import SwiftUI

struct CompletionPopupView: View {
    let completions: [ChallengeCompletion]
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🎉").font(.system(size: 64))
                Text("Challenge Complete!")
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                Text(completions.first?.displayName ?? "Challenge")
                    .font(.subheadline).foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                if completions.count > 1 {
                    Text("+ \(completions.count - 1) more completed!")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                }
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundColor(Theme.accentYellow)
                    Text("+\(completions.reduce(0) { $0 + $1.xp }) XP Earned")
                        .font(.headline).fontWeight(.bold).foregroundColor(Theme.accentYellow)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Theme.accentYellow.opacity(0.15))
                .cornerRadius(12)
                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .font(.headline).fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accentGreen)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 30)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.13, blue: 0.2))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.accentGreen.opacity(0.4), lineWidth: 1.5))
            )
            .padding(.horizontal, 24)
        }
    }
}
