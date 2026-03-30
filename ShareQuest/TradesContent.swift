import SwiftUI

struct TradesContent: View {
    @ObservedObject var vm: StockDetailViewModel
    @State private var showSubscriptions = false

    var body: some View {
        if vm.requiresSubscriptionForTrades {
            // Show subscription required card
            VStack {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.title)
                        .foregroundColor(.pink)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subscription Required")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Viewing live trade ticks requires a subscription.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding()

                Button(action: { showSubscriptions = true }) {
                    Text("Subscribe Now")
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Theme.primaryBlue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
                .adaptiveSheet(isPresented: $showSubscriptions) {
                    SubscriptionsView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            InfoCard(title: "RECENT TRADES", icon: "list.bullet.rectangle") {
                if vm.latest20TradeTicks.isEmpty {
                    Text("No trade ticks available.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Time")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 80, alignment: .leading)
                            Text("Price")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("Volume")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.bottom, 8)

                        ForEach(vm.latest20TradeTicks) { tick in
                            HStack {
                                Text(vm.tradeTimeString(tick.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .frame(width: 80, alignment: .leading)
                                Text(vm.tradePriceString(tick.tradePrice))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(vm.tradeVolumeString(tick.tradeVolume))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.vertical, 6)

                            Divider()
                                .background(Color.white.opacity(0.15))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TradesContent(vm: StockDetailViewModel(symbol: "AZN.L"))
}
