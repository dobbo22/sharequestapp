import SwiftUI

struct FootballPackRevealView: View {
    let cards: [FootballOwnedCard]
    let packId: String
    let onDone: () -> Void

    @State private var revealedCount = 0
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.051, green: 0.106, blue: 0.165).ignoresSafeArea()

            // Subtle radial lime glow behind pack
            if revealedCount == 0 {
                RadialGradient(
                    colors: [Color(red: 0.776, green: 0.945, blue: 0.208).opacity(0.18), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 280
                )
                .ignoresSafeArea()
                .scaleEffect(glowPulse ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)
            }

            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        Text("Footy")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Cards")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.776, green: 0.945, blue: 0.208))
                    }

                    Text(revealedCount == 0 ? "Starter Pack" : "Reveal Your Squad")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)

                    Text(revealedCount == 0
                         ? "Tap to open your 22-card starter pack."
                         : "\(min(revealedCount, cards.count)) of \(cards.count) cards revealed")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.541, green: 0.608, blue: 0.690))
                }

                // Card / pack area
                if let currentCard = currentCard {
                    FootballPlayerCardView(card: currentCard)
                        .scaleEffect(1.05)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                        .id(currentCard.id)
                } else {
                    packReadyView
                }

                Spacer()

                // CTA button
                Button(action: advance) {
                    HStack(spacing: 10) {
                        if revealedCount == 0 {
                            Image(systemName: "gift.fill")
                                .font(.headline)
                        } else if revealedCount < cards.count {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.headline)
                        }
                        Text(buttonTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(red: 0.776, green: 0.945, blue: 0.208))
                    .foregroundStyle(Color(red: 0.051, green: 0.106, blue: 0.165))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear { glowPulse = true }
    }

    // MARK: - Pack ready view
    private var packReadyView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.118, green: 0.176, blue: 0.239))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            Color(red: 0.776, green: 0.945, blue: 0.208).opacity(0.35),
                            lineWidth: 1.5
                        )
                )

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.776, green: 0.945, blue: 0.208).opacity(0.12))
                        .frame(width: 100, height: 100)
                    Circle()
                        .fill(Color(red: 0.776, green: 0.945, blue: 0.208).opacity(0.08))
                        .frame(width: 130, height: 130)
                        .scaleEffect(glowPulse ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)

                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(Color(red: 0.776, green: 0.945, blue: 0.208))
                }

                VStack(spacing: 6) {
                    Text("Pack Ready")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("22 players ready to join your squad")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.541, green: 0.608, blue: 0.690))
                }
            }
        }
        .frame(height: 280)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers
    private var currentCard: FootballOwnedCard? {
        guard revealedCount > 0, revealedCount <= cards.count else { return nil }
        return cards[revealedCount - 1]
    }

    private var buttonTitle: String {
        if revealedCount == 0 { return "Open Pack" }
        if revealedCount < cards.count { return "Next Card" }
        return "Go to Dashboard"
    }

    private func advance() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            if revealedCount < cards.count {
                revealedCount += 1
            } else {
                onDone()
            }
        }
    }
}
