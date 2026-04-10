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

// MARK: - Main view
struct FootballCardExchangeView: View {
    @ObservedObject var collectionViewModel: FootballCollectionViewModel
    let profileData: FootballProfileData?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ExchangeTab = .marketplace
    @State private var exchangeData: FootballExchangeData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var confirmRemoveListingId: String?
    @State private var confirmBuyListing: FootballExchangeListingCard?
    @State private var successMessage: String?
    @State private var isBuying = false

    // Budget = sum of own active listing card ratings / 2 + server bonus balance
    private var serverBonusBalance: Double { exchangeData?.tradeRatingBalance ?? 0 }
    private var myActiveListings: [FootballExchangeListingCard] {
        exchangeData?.myListings.filter { $0.status == "active" } ?? []
    }
    private var myAllListings: [FootballExchangeListingCard] { exchangeData?.myListings ?? [] }
    private var marketListings: [FootballExchangeListingCard] { exchangeData?.marketplace ?? [] }

    private var totalBudget: Double {
        let listingRatings = myActiveListings.compactMap { $0.cardRating }.reduce(0, +) / 2.0
        return (listingRatings + serverBonusBalance).rounded(toDecimalPlaces: 2)
    }

    var body: some View {
        ZStack {
            Color.exNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabBar
                Divider().overlay(Color.white.opacity(0.08))

                if isLoading && exchangeData == nil {
                    Spacer()
                    ProgressView().tint(Color.exLime)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            budgetBanner
                            if let msg = successMessage {
                                successBanner(msg)
                            }
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
                    .refreshable { await loadListings() }
                }
            }
        }
        // Remove listing confirmation
        .alert("Remove Listing", isPresented: Binding(
            get: { confirmRemoveListingId != nil },
            set: { if !$0 { confirmRemoveListingId = nil } }
        )) {
            Button("Remove", role: .destructive) {
                let id = confirmRemoveListingId
                confirmRemoveListingId = nil
                if let id { Task { await removeListing(listingId: id) } }
            }
            Button("Cancel", role: .cancel) { confirmRemoveListingId = nil }
        } message: {
            Text("This card will be returned to your available cards. Unsold cards are permanently discarded after 24 hours.")
        }
        // Buy confirmation
        .alert("Confirm Purchase", isPresented: Binding(
            get: { confirmBuyListing != nil },
            set: { if !$0 { confirmBuyListing = nil } }
        )) {
            Button("Buy for \(String(format: "%.1f", confirmBuyListing?.ratingCost ?? 0)) pts", role: .none) {
                let listing = confirmBuyListing
                confirmBuyListing = nil
                if let listing { Task { await buyListing(listing) } }
            }
            Button("Cancel", role: .cancel) { confirmBuyListing = nil }
        } message: {
            if let l = confirmBuyListing {
                Text("Buy \(l.playerName) from \(l.sellerName ?? "another player") for \(String(format: "%.1f", l.ratingCost)) rating points?")
            }
        }
        // Error banner
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
        .task { await loadListings() }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
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

            if isLoading {
                ProgressView().tint(Color.exGold).frame(width: 36, height: 36)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
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
                Text(String(format: "%.1f pts", totalBudget))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.exGold)
                if serverBonusBalance > 0 {
                    Text(String(format: "+%.1f bonus pts", serverBonusBalance))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.exLime)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Listed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.exMuted)
                Text("\(myActiveListings.count)/\(collectionViewModel.maxTradeQueueCount)")
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

    // MARK: - Success banner
    private func successBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.exLime)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Button { successMessage = nil } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.exMuted)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.exLime.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.exLime.opacity(0.3), lineWidth: 1)
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
                    ForEach(marketListings, id: \.listingId) { listing in
                        ExchangeListingRow(
                            listing: listing,
                            budget: totalBudget,
                            isBuying: isBuying
                        ) {
                            confirmBuyListing = listing
                        }
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

            if myAllListings.isEmpty {
                exchangeEmptyState(
                    icon: "arrow.left.arrow.right.circle",
                    title: "No active listings",
                    message: "Flip a card from Available and tap Trade to list it here. Up to 5 cards can be listed at a time."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(myAllListings, id: \.listingId) { listing in
                        MyListingRow(listing: listing) {
                            confirmRemoveListingId = listing.listingId
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
            exchangeRule("Cost to buy = card's rating ÷ 2 in points.")
            exchangeRule("Your budget = sum of your listed card ratings ÷ 2, plus any bonus points.")
            exchangeRule("Seller earns card's rating + 2 bonus points on each sale.")
            exchangeRule("Unsold cards after 24 hours are permanently discarded from your collection.")
            exchangeRule("Listings can only be removed after a 6-hour lock period.")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.exCard)
        )
    }

    private func exchangeRule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.exGold).frame(width: 5, height: 5).padding(.top, 6)
            Text(text).font(.caption).foregroundStyle(Color.exMuted)
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

    // MARK: - API actions

    private func loadListings() async {
        isLoading = true
        do {
            let data = try await FootballAPIClient.shared.fetchExchangeListings()
            exchangeData = data
            // Sync local trade queue with server listings
            let serverListedCardIds = Set(data.myListings.filter { $0.status == "active" }.map { $0.userCardId })
            collectionViewModel.syncTradeQueueWithServer(listedCardIds: serverListedCardIds)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func removeListing(listingId: String) async {
        // Find the card before removal so we can dequeue it locally
        let listing = myAllListings.first { $0.listingId == listingId }
        do {
            try await FootballAPIClient.shared.removeExchangeListing(listingId: listingId)
            // Remove from local queue
            if let cardId = listing?.userCardId,
               let card = collectionViewModel.cards.first(where: { $0.userCardId == cardId }) {
                collectionViewModel.removeFromQueues(card)
            }
            await loadListings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buyListing(_ listing: FootballExchangeListingCard) async {
        isBuying = true
        do {
            let result = try await FootballAPIClient.shared.buyExchangeListing(listingId: listing.listingId)
            successMessage = "\(listing.playerName) added to your collection!"
            if let card = result.acquiredCard {
                collectionViewModel.addAcquiredCard(card)
            }
            await loadListings()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBuying = false
    }
}

// MARK: - Marketplace listing row
private struct ExchangeListingRow: View {
    let listing: FootballExchangeListingCard
    let budget: Double
    let isBuying: Bool
    let onBuy: () -> Void

    private var canAfford: Bool { budget >= listing.ratingCost }
    private var isAlmostExpired: Bool {
        guard let exp = listing.expiresAtDate else { return false }
        return exp.timeIntervalSinceNow < 3600
    }

    var body: some View {
        HStack(spacing: 14) {
            playerThumb(listing)

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.playerName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let pos = listing.detailedPositionLabel ?? listing.positionLabel {
                    Text(pos.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.exMuted)
                        .kerning(0.6)
                }

                HStack(spacing: 6) {
                    if let rating = listing.ratingOutOfTen {
                        Text(String(format: "%.1f", rating))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.exLime)
                    }
                    if let seller = listing.sellerName {
                        Text("· \(seller)")
                            .font(.caption)
                            .foregroundStyle(Color.exMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%.1f pts", listing.ratingCost))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(canAfford ? Color.exGold : Color.exMuted)

                Text(listing.timeRemainingText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isAlmostExpired ? Color.exRed : Color.exMuted)

                Button("Buy") { onBuy() }
                    .font(.caption.weight(.black))
                    .foregroundStyle(canAfford ? Color.exNavy : Color.exMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(canAfford ? Color.exGold : Color.exCard)
                    .clipShape(Capsule())
                    .disabled(!canAfford || isBuying)
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
    private func playerThumb(_ listing: FootballExchangeListingCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.exGold.opacity(0.14))
                .frame(width: 54, height: 54)

            PlayerAvatarImage(playerName: listing.playerName, size: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    let listing: FootballExchangeListingCard
    let onRemove: () -> Void

    private var isAlmostExpired: Bool {
        guard let exp = listing.expiresAtDate else { return false }
        return exp.timeIntervalSinceNow < 3600
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(listing.playerName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(listing.isExpired ? Color.exMuted : .white)
                        .lineLimit(1)

                    statusPill(listing.status)
                }

                if let pos = listing.detailedPositionLabel ?? listing.positionLabel {
                    Text(pos.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.exMuted)
                        .kerning(0.6)
                }

                HStack(spacing: 6) {
                    if let rating = listing.ratingOutOfTen {
                        Text(String(format: "%.1f", rating))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.exLime)
                    }
                    Text(String(format: "· %.1f pts cost", listing.ratingCost))
                        .font(.caption)
                        .foregroundStyle(Color.exGold)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(listing.timeRemainingText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isAlmostExpired ? Color.exRed : Color.exMuted)

                if listing.status == "active" && !listing.canRemove {
                    if let rem = listing.removableAtDate {
                        let minutesLeft = max(0, Int(rem.timeIntervalSinceNow / 60))
                        Text("Removable in \(minutesLeft / 60)h \(minutesLeft % 60)m")
                            .font(.caption2)
                            .foregroundStyle(Color.exMuted)
                    }
                }

                if listing.status == "active" {
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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.exCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(listing.status == "expired" || listing.status == "discarded"
                                ? Color.exRed.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .opacity(listing.isExpired ? 0.6 : 1)
    }

    @ViewBuilder
    private func statusPill(_ status: String) -> some View {
        switch status {
        case "sold":
            Text("SOLD")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.exLime)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.exLime.opacity(0.15))
                .clipShape(Capsule())
        case "expired", "discarded":
            Text("EXPIRED")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.exRed)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.exRed.opacity(0.15))
                .clipShape(Capsule())
        case "removed":
            Text("REMOVED")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.exMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.exMuted.opacity(0.15))
                .clipShape(Capsule())
        default:
            EmptyView()
        }
    }
}

// MARK: - Tab
private enum ExchangeTab: CaseIterable {
    case marketplace, myListings

    var label: String {
        switch self {
        case .marketplace: return "Marketplace"
        case .myListings:  return "My Listings"
        }
    }
}

// MARK: - Helpers
private extension Double {
    func rounded(toDecimalPlaces places: Int) -> Double {
        let d = pow(10.0, Double(places))
        return (self * d).rounded() / d
    }
}
