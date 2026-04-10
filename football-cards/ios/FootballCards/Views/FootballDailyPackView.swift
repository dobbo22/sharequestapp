import SwiftUI

private extension Color {
    static let dpNavy  = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let dpLime  = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let dpCard  = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let dpMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
    static let dpGold  = Color(red: 0.99,  green: 0.78,  blue: 0.36)
}

// MARK: - Daily pack reveal screen (shown after a successful claim)
struct FootballDailyPackRevealView: View {
    let cards: [FootballOwnedCard]
    let onDone: () -> Void

    @State private var revealedCount = 0
    @State private var glowPulse = false

    private var currentCard: FootballOwnedCard? {
        guard revealedCount > 0, revealedCount <= cards.count else { return nil }
        return cards[revealedCount - 1]
    }

    var body: some View {
        ZStack {
            Color.dpNavy.ignoresSafeArea()

            if revealedCount == 0 {
                RadialGradient(
                    colors: [Color.dpGold.opacity(0.2), .clear],
                    center: .center, startRadius: 20, endRadius: 300
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
                        Text("Footy").font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("Cards").font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(Color.dpLime)
                    }

                    Text(revealedCount == 0 ? "Daily Pack" : "Your New Cards")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)

                    Text(revealedCount == 0
                         ? "Tap to open today's \(cards.count)-card daily pack."
                         : "\(min(revealedCount, cards.count)) of \(cards.count) cards revealed")
                        .font(.subheadline)
                        .foregroundStyle(Color.dpMuted)
                }

                // Card / pack area
                if let card = currentCard {
                    FootballPlayerCardView(card: card)
                        .scaleEffect(1.05)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                        .id(card.userCardId)
                } else if revealedCount == 0 {
                    // Sealed pack
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.dpGold.opacity(0.4), Color.dpGold.opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 200, height: 280)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.dpGold.opacity(0.7), lineWidth: 2)
                            )

                        VStack(spacing: 12) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 54))
                                .foregroundStyle(Color.dpGold)
                            Text("\(cards.count) CARDS")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color.dpGold)
                            Text("Daily Pack")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dpMuted)
                        }
                    }
                } else {
                    // All revealed
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(Color.dpLime)
                        Text("All \(cards.count) cards added!")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Check your available cards on the dashboard.")
                            .font(.subheadline)
                            .foregroundStyle(Color.dpMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                }

                Spacer()

                // Action button
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        if revealedCount < cards.count {
                            revealedCount += 1
                        } else {
                            onDone()
                        }
                    }
                } label: {
                    Text(revealedCount == 0 ? "Open Pack"
                         : revealedCount < cards.count ? "Next Card"
                         : "Done")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.dpNavy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(revealedCount < cards.count ? Color.dpGold : Color.dpLime)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear { glowPulse = true }
    }
}

