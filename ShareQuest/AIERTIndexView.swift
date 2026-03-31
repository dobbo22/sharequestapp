//
//  AIERTIndexView.swift
//  ShareQuest
//
//  SQ Index — top 100 stocks ranked by the AIERT scoring model.
//  Requires an active subscription.
//

import SwiftUI

// MARK: - ViewModel

@MainActor
class AIERTIndexViewModel: ObservableObject {
    @Published var stocks: [AIERTStock] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetch() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.fetchAIERTIndex()
            stocks = response.stocks ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Main View

struct AIERTIndexView: View {
    @StateObject private var vm = AIERTIndexViewModel()

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            if vm.isLoading && vm.stocks.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
            } else if let error = vm.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: scaled(40)))
                        .foregroundColor(Theme.textMuted)
                    Text(error)
                        .font(.system(size: scaled(14)))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") { Task { await vm.fetch() } }
                        .font(.system(size: scaled(15), weight: .semibold))
                        .foregroundColor(Theme.primaryBlue)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        headerRow
                        ForEach(Array(vm.stocks.enumerated()), id: \.element.id) { index, stock in
                            AIERTRowView(rank: index + 1, stock: stock)
                            Divider()
                                .background(Theme.glassBorder)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .refreshable { await vm.fetch() }
            }
        }
        .task { await vm.fetch() }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 36, alignment: .center)
            Text("Stock")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Score")
                .frame(width: 56, alignment: .trailing)
            Text("YTD")
                .frame(width: 56, alignment: .trailing)
            Text("1Y")
                .frame(width: 56, alignment: .trailing)
        }
        .font(.system(size: scaled(11), weight: .semibold))
        .foregroundColor(Theme.textMuted)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.glassBackground)
    }
}

// MARK: - Row View

struct AIERTRowView: View {
    let rank: Int
    let stock: AIERTStock

    private var scoreColor: Color {
        guard let s = stock.aiert_score?.score else { return Theme.textSecondary }
        if s >= 70 { return Theme.accentGreen }
        if s >= 50 { return Color(red: 0.95, green: 0.65, blue: 0.15) }
        return Color(red: 0.94, green: 0.27, blue: 0.27)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Rank
            Text("\(rank)")
                .font(.system(size: scaled(13), weight: .bold))
                .foregroundColor(rank <= 3 ? Theme.primaryBlue : Theme.textMuted)
                .frame(width: 36, alignment: .center)

            // Name + symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(stock.symbol)
                    .font(.system(size: scaled(14), weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if let name = stock.name {
                    Text(name)
                        .font(.system(size: scaled(11)))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // AIERT score
            if let score = stock.aiert_score?.score {
                Text(String(format: "%.1f", score))
                    .font(.system(size: scaled(14), weight: .bold))
                    .foregroundColor(scoreColor)
                    .frame(width: 56, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: scaled(14)))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 56, alignment: .trailing)
            }

            // YTD
            perfCell(value: stock.infrontYtd)
                .frame(width: 56, alignment: .trailing)

            // 1Y
            perfCell(value: stock.infront1y)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func perfCell(value: Double?) -> some View {
        if let v = value {
            Text(String(format: "%+.1f%%", v))
                .font(.system(size: scaled(12), weight: .medium))
                .foregroundColor(v >= 0 ? Theme.accentGreen : Color(red: 0.94, green: 0.27, blue: 0.27))
        } else {
            Text("—")
                .font(.system(size: scaled(12)))
                .foregroundColor(Theme.textMuted)
        }
    }
}

// MARK: - Paywall

struct AIERTPaywallView: View {
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: scaled(56)))
                    .foregroundColor(Theme.primaryBlue)
                Text("SQ Index")
                    .font(.system(size: scaled(26), weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("Our proprietary AIERT ranking of the top 100 UK stocks — scored on liquidity, technicals, fundamentals and performance.")
                    .font(.system(size: scaled(15)))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    featureRow(icon: "chart.line.uptrend.xyaxis", text: "AIERT composite score for every stock")
                    featureRow(icon: "gauge.medium", text: "Liquidity, technical & fundamental breakdown")
                    featureRow(icon: "arrow.up.right", text: "Performance figures: YTD, 1M, 3M, 1Y, 3Y")
                }
                .padding(.horizontal, 24)

                NavigationLink(destination: SubscriptionsView()) {
                    Text("Unlock SQ Index")
                        .font(.system(size: scaled(16), weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primaryBlue)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                }
                Spacer()
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: scaled(18)))
                .foregroundColor(Theme.primaryBlue)
                .frame(width: 28)
            Text(text)
                .font(.system(size: scaled(14)))
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
    }
}
