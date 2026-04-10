import SwiftUI

// MARK: - Brand colours (local)
private extension Color {
    static let exNavy  = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let exLime  = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let exCard  = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let exMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
    static let exGold  = Color(red: 0.99,  green: 0.78,  blue: 0.36)
    static let exRed   = Color(red: 0.97,  green: 0.35,  blue: 0.35)
}

// MARK: - Exchange listing model
struct FootballTradeListing: Identifiable {
    let id: String
    let card: FootballOwnedCard
    let sellerName: String
    let listedAt: Date
    let ratingCost: Double          // seller's accumulated ratings / 2
    let isOwnListing: Bool

    var expiresAt: Date { listedAt.addingTimeInterval(86_400) }   // 24 h window
    var removableAt: Date { listedAt.addingTimeInterval(21_600) } // 6 h minimum

    var timeRemainingText: String {
        let remaining = expiresAt.timeIntervalSinceNow
        if remaining <= 0 { return "Expired" }
        let hours   = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m left" }
        return "\(minutes)m left"
    }

    var canRemove: Bool {
        Date() >= removableAt && Date() < expiresAt
    }

    var isExpired: Bool { Date() >= expiresAt }
}

// MARK: - Main view
struct FootballCardExchangeView: View {
    @ObservedObject var collectionViewModel: FootballCollectionViewModel
    let profileData: FootballProfileData?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ExchangeTab = .marketplace
    @State private var listings: [FootballTradeListing] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var confirmRemoveId: String?

    private var myListings: [FootballTradeListing] {
        listings.filter { $0.isOwnListing }
    }

    private var marketListings: [FootballTradeListing] {
        listings.filter { !$0.isOwnListing && !$0.isExpired }
    }

    // Accumulated trade budget: sum of queued-for-trade card ratings / 2
    private var tradeBudget: Double {
        let tradeIds = collectionViewModel.queuedTradeCardIds
        let tradeCards = collectionViewModel.cards.filter { tradeIds.contains($0.userCardId) }
        let total = tradeCards.compactMap { $0.ratingOutOfTen }.reduce(0, +)
        return (total / 2).rounded(toPlaces: 1)
    }

    var body: some View {
        ZStack {
            Color.exNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabBar
                Divider()
                    .overlay(Color.white.opacity(0.08))

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color.exLime)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            budgetBanner
                            if selectedTab == .marketplace {
                                marketplaceSection
                            } else {
                                myListingsSection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .alert("Remove Listing", isPresented: Binding(
            get: { confirmRemoveId != nil },
            set: { if !$0 { confirmRemoveId = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let id = confirmRemoveId {
                    removeListing(id: id)
                }
                confirmRemoveId = nil
            }
            Button("Cancel", role: .cancel) { confirmRemoveId = nil }
        } message: {
            Text("Removing this card from trade will return it to your available cards. This cannot be undone.")
        }
        .task { await loadListings() }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.exCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("Card Exchange")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Trade cards with other players")
                    .font(.caption2)
                    .foregroundStyle(Color.exMuted)
            }

            Spacer()

            // Placeholder to balance layout
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.exNavy)
    }

    // MARK: - Tab bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ExchangeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? Color.exGold : Color.exMuted)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.exGold : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Budget banner
    private var budgetBanner: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your trade budget")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.exMuted)
                Text("\(tradeBudget, specifier: "%.1f") pts")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.exGold)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Listed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.exMuted)
                Text("\(myListings.count)/\(collectionViewModel.maxTradeQueueCount)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.exCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.exGold.opacity(0.22), lineWidth: 1.2)
                )
        )
    }

    // MARK: - Marketplace
    @ViewBuilder
    private var marketplaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available to buy")
                .font(.title3.bold())
                .foregroundStyle(.white)

            if marketListings.isEmpty {
                exchangeEmptyState(
                    icon: "storefront",
                    title: "No listings right now",
                    message: "Other players haven't listed any cards yet. Check back soon, or list your own cards to start trading."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(marketListings) { listing in
                        ExchangeListingRow(
                            listing: listing,
                            budget: tradeBudget,
                            onBuy: { buyListing(listing) }
                        )
                    }
                }
            }
        }

        rulesCard
    }

    // MARK: - My listings
    @ViewBuilder
    private var myListingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My listings")
                .font(.title3.bold())
                .foregroundStyle(.white)

            if myListings.isEmpty {
                exchangeEmptyState(
                    icon: "arrow.left.arrow.right.circle",
                    title: "No active listings",
                    message: "Flip a card from Available and tap Trade to list it here. Up to 5 cards can be listed at a time."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(myListings) { listing in
                        MyListingRow(listing: listing) {
                            if listing.canRemove {
                                confirmRemoveId = listing.id
                            }
                        }
                    }
                }
            }
        }

        rulesCard
    }

    // MARK: - Rules card
    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How it works", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.exGold)

            exchangeRule("List up to 5 cards for 24 hours on the exchange.")
            exchangeRule("Cost to buy = seller's accumulated ratings ÷ 2.")
            exchangeRule("Seller earns +2 bonus pts plus the sold card's rating.")
            exchangeRule("Unsold cards after 24 hours are permanently discarded.")
            exchangeRule("Listings can only be removed after 6 hours minimum.")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.exCard)
        )
    }

    private func exchangeRule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.exGold)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.exMuted)
        }
    }

    @ViewBuilder
    private func exchangeEmptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.exGold)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.exMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.exCard)
        )
    }

    // MARK: - Actions (wire to API when ready)
    private func loadListings() async {
        isLoading = true
        // TODO: fetch GET /api/football/exchange listings
        // listings = try await FootballAPIClient.shared.fetchExchangeListings()
        try? await Task.sleep(nanoseconds: 600_000_000)
        listings = []
        isLoading = false
    }

    private func buyListing(_ listing: FootballTradeListing) {
        // TODO: POST /api/football/exchange/buy { listingId }
        // On success: award buyer the card, award seller bonus 2 pts + card rating
    }

    private func removeListing(id: String) {
        // TODO: DELETE /api/football/exchange/{ listingId }
        // Returns card back to available pool
        listings.removeAll { $0.id == id }
        // Also remove from local trade queue
        if let card = collectionViewModel.cards.first(where: { $0.userCardId == id }) {
            collectionViewModel.removeFromQueues(card)
        }
    }
}

// MARK: - Marketplace listing row
private struct ExchangeListingRow: View {
    let listing: FootballTradeListing
    let budget: Double
    let onBuy: () -> Void

    private var canAfford: Bool { budget >= listing.ratingCost }

    var body: some View {
        HStack(spacing: 14) {
            // Player photo / initials
            playerThumb(listing.card)

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.card.playerName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let pos = listing.card.detailedPositionLabel ?? listing.card.positionLabel {
                    Text(pos.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.exMuted)
                        .kerning(0.6)
                }

                if let club = listing.card.clubName {
                    Text(club)
                        .font(.caption)
                        .foregroundStyle(Color.exMuted)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let rating = listing.card.ratingOutOfTen {
                        Text(String(format: "%.1f", rating))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.exLime)
                    }
                    Text("·")
                        .foregroundStyle(Color.exMuted)
                    Text(listing.sellerName)
                        .font(.caption)
                        .foregroundStyle(Color.exMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%.1f pts", listing.ratingCost))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(canAfford ? Color.exGold : Color.exMuted)

                Text(listing.timeRemainingText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(listing.expiresAt.timeIntervalSinceNow < 3600 ? Color.exRed : Color.exMuted)

                Button("Buy") { onBuy() }
                    .font(.caption.weight(.black))
                    .foregroundStyle(canAfford ? Color.exNavy : Color.exMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(canAfford ? Color.exGold : Color.exCard)
                    .clipShape(Capsule())
                    .disabled(!canAfford)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.exCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func playerThumb(_ card: FootballOwnedCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.exGold.opacity(0.14))
                .frame(width: 54, height: 54)

            if let urlStr = card.photoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        initialsView(card.playerName)
                    }
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                initialsView(card.playerName)
            }
        }
    }

    private func initialsView(_ name: String) -> some View {
        let initials = name.split(separator: " ").compactMap { $0.first }.prefix(2).map { String($0) }.joined()
        return Text(initials)
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(Color.exGold)
    }
}

// MARK: - Own listing row
private struct MyListingRow: View {
    let listing: FootballTradeListing
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.card.playerName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let pos = listing.card.detailedPositionLabel ?? listing.card.positionLabel {
                    Text(pos.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.exMuted)
                        .kerning(0.6)
                }

                HStack(spacing: 6) {
                    if let rating = listing.card.ratingOutOfTen {
                        Text(String(format: "%.1f", rating))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.exLime)
                    }
                    Text("·")
                        .foregroundStyle(Color.exMuted)
                    Text(String(format: "%.1f pts cost", listing.ratingCost))
                        .font(.caption)
                        .foregroundStyle(Color.exGold)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                // Time remaining
                VStack(alignment: .trailing, spacing: 2) {
                    Text(listing.timeRemainingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(listing.expiresAt.timeIntervalSinceNow < 3600 ? Color.exRed : Color.exMuted)

                    if !listing.canRemove && !listing.isExpired {
                        let minutesToRemovable = max(0, Int(listing.removableAt.timeIntervalSinceNow / 60))
                        let hoursLeft = minutesToRemovable / 60
                        let minsLeft  = minutesToRemovable % 60
                        Text("Removable in \(hoursLeft)h \(minsLeft)m")
                            .font(.caption2)
                            .foregroundStyle(Color.exMuted)
                    }
                }

                Button("Remove") { onRemove() }
                    .font(.caption.weight(.black))
                    .foregroundStyle(listing.canRemove ? Color.exRed : Color.exMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(listing.canRemove ? Color.exRed.opacity(0.14) : Color.exCard)
                    .clipShape(Capsule())
                    .disabled(!listing.canRemove)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.exCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(listing.isExpired ? Color.exRed.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .opacity(listing.isExpired ? 0.55 : 1)
    }
}

// MARK: - Tab
private enum ExchangeTab: CaseIterable {
    case marketplace
    case myListings

    var label: String {
        switch self {
        case .marketplace: return "Marketplace"
        case .myListings:  return "My Listings"
        }
    }
}

// MARK: - Double helper
private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
