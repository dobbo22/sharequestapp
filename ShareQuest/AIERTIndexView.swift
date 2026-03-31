//
//  AIERTIndexView.swift
//  ShareQuest
//
//  SQ Index — top 100 stocks ranked by the AIERT scoring model.
//  Requires an active subscription.
//

import SwiftUI
import Combine
import Charts

// MARK: - Sub-tab

enum SQIndexTab: String, CaseIterable {
    case rankings = "Rankings"
    case tracker  = "Tracker Fund"
    case chart    = "Comparison"
}

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
    @State private var selectedTab: SQIndexTab = .rankings

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                subTabSelector

                if vm.isLoading && vm.stocks.isEmpty {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                    Spacer()
                } else if let error = vm.errorMessage {
                    Spacer()
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
                    Spacer()
                } else {
                    switch selectedTab {
                    case .rankings:
                        rankingsContent
                    case .tracker:
                        SQTrackerView(stocks: vm.stocks)
                    case .chart:
                        SQComparisonView(stocks: vm.stocks)
                    }
                }
            }
        }
        .task { await vm.fetch() }
    }

    // MARK: Sub-tab selector

    private var subTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SQIndexTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: scaled(14), weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Theme.primaryBlue.opacity(0.25) : Theme.glassBackground)
                            .foregroundColor(selectedTab == tab ? Theme.primaryBlue : Theme.textSecondary)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(selectedTab == tab ? Theme.primaryBlue : Theme.glassBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
    }

    // MARK: Rankings list

    private var rankingsContent: some View {
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

            // Name (bold) on top, symbol below
            VStack(alignment: .leading, spacing: 2) {
                Text(stock.name ?? stock.symbol)
                    .font(.system(size: scaled(14), weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(stock.symbol)
                    .font(.system(size: scaled(11)))
                    .foregroundColor(Theme.textMuted)
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

// MARK: - Tracker Fund View

struct SQTrackerView: View {
    let stocks: [AIERTStock]

    // Equal-weight average of 1Y performance across index members
    private var avg1y: Double? {
        let vals = stocks.compactMap { $0.infront1y }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var avgYtd: Double? {
        let vals = stocks.compactMap { $0.infrontYtd }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var avg3y: Double? {
        let vals = stocks.compactMap { $0.infront3y }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                VStack(spacing: 6) {
                    Text("SQ Tracker Fund")
                        .font(.system(size: scaled(20), weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Equal-weight index of top 100 AIERT stocks")
                        .font(.system(size: scaled(13)))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.top, 16)

                // Performance cards
                HStack(spacing: 12) {
                    trackerCard(title: "YTD", value: avgYtd)
                    trackerCard(title: "1 Year", value: avg1y)
                    trackerCard(title: "3 Year", value: avg3y)
                }
                .padding(.horizontal)

                // Top holdings
                VStack(alignment: .leading, spacing: 0) {
                    Text("Top 10 Holdings")
                        .font(.system(size: scaled(14), weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)

                    ForEach(Array(stocks.prefix(10).enumerated()), id: \.element.id) { index, stock in
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: scaled(12)))
                                .foregroundColor(Theme.textMuted)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stock.name ?? stock.symbol)
                                    .font(.system(size: scaled(14), weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(stock.symbol)
                                    .font(.system(size: scaled(11)))
                                    .foregroundColor(Theme.textMuted)
                            }
                            Spacer()
                            Text("1%")
                                .font(.system(size: scaled(13)))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        Divider().background(Theme.glassBorder).padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .background(Theme.glassBackground)
                .cornerRadius(14)
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }

    private func trackerCard(title: String, value: Double?) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: scaled(12)))
                .foregroundColor(Theme.textMuted)
            if let v = value {
                Text(String(format: "%+.1f%%", v))
                    .font(.system(size: scaled(18), weight: .bold))
                    .foregroundColor(v >= 0 ? Theme.accentGreen : Color(red: 0.94, green: 0.27, blue: 0.27))
            } else {
                Text("—")
                    .font(.system(size: scaled(18), weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.glassBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.glassBorder, lineWidth: 1))
    }
}

// MARK: - Comparison Chart View

@MainActor
class SQComparisonViewModel: ObservableObject {
    @Published var data: AIERTComparisonResponse? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetch() async {
        isLoading = true
        errorMessage = nil
        do {
            data = try await APIService.shared.fetchAIERTComparison()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct SQComparisonView: View {
    let stocks: [AIERTStock]
    @StateObject private var vm = SQComparisonViewModel()

    private struct PerfBar: Identifiable {
        let id = UUID()
        let period: String
        let sqIndex: Double
        let ftse100: Double
    }

    private func avg(_ values: [Double?]) -> Double {
        let v = values.compactMap { $0 }
        return v.isEmpty ? 0 : v.reduce(0, +) / Double(v.count)
    }

    private var bars: [PerfBar] {
        let ftse = vm.data?.ftse100
        return [
            PerfBar(period: "YTD", sqIndex: avg(stocks.map(\.infrontYtd)), ftse100: ftse?.ytd   ?? 0),
            PerfBar(period: "1M",  sqIndex: avg(stocks.map(\.infront1m)),  ftse100: ftse?.perf1m ?? 0),
            PerfBar(period: "3M",  sqIndex: avg(stocks.map(\.infront3m)),  ftse100: ftse?.perf3m ?? 0),
            PerfBar(period: "1Y",  sqIndex: avg(stocks.map(\.infront1y)),  ftse100: ftse?.perf1y ?? 0),
            PerfBar(period: "3Y",  sqIndex: avg(stocks.map(\.infront3y)),  ftse100: ftse?.perf3y ?? 0),
        ]
    }

    private var historyPoints: [ComparisonHistoryPoint] {
        vm.data?.history ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("SQ Index vs FTSE 100")
                        .font(.system(size: scaled(20), weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Live performance comparison")
                        .font(.system(size: scaled(13)))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.top, 16)

                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                        .padding(.vertical, 20)
                } else if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: scaled(13)))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    // Legend
                    HStack(spacing: 20) {
                        legendDot(color: Theme.primaryBlue, label: "SQ Index")
                        legendDot(color: Theme.textMuted.opacity(0.6), label: "FTSE 100")
                    }

                    // YTD line chart from history
                    if !historyPoints.isEmpty {
                        ytdLineChart
                            .padding(.horizontal)
                    }

                    // Bar chart by period
                    Chart {
                        ForEach(bars) { bar in
                            BarMark(x: .value("Period", bar.period), y: .value("Return", bar.sqIndex), width: .fixed(16))
                                .foregroundStyle(Theme.primaryBlue)
                                .position(by: .value("Series", "SQ Index"))
                            BarMark(x: .value("Period", bar.period), y: .value("Return", bar.ftse100), width: .fixed(16))
                                .foregroundStyle(Theme.textMuted.opacity(0.5))
                                .position(by: .value("Series", "FTSE 100"))
                        }
                        RuleMark(y: .value("Zero", 0))
                            .foregroundStyle(Theme.glassBorder)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine().foregroundStyle(Theme.glassBorder.opacity(0.4))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(String(format: "%.0f%%", v))
                                        .font(.system(size: scaled(10)))
                                        .foregroundColor(Theme.textMuted)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)

                    // Table
                    comparisonTable
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .task { await vm.fetch() }
        .refreshable { await vm.fetch() }
    }

    // YTD line chart showing history
    private var ytdLineChart: some View {
        Chart {
            ForEach(Array(historyPoints.enumerated()), id: \.element.id) { i, point in
                LineMark(
                    x: .value("Date", i),
                    y: .value("SQ", point.sharequestYtd ?? 0)
                )
                .foregroundStyle(Theme.primaryBlue)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", i),
                    y: .value("FTSE", point.ftse100Ytd ?? 0)
                )
                .foregroundStyle(Theme.textMuted.opacity(0.6))
                .interpolationMethod(.catmullRom)
            }
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Theme.glassBorder)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Theme.glassBorder.opacity(0.3))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f%%", v))
                            .font(.system(size: scaled(10)))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
        .frame(height: 160)
        .overlay(alignment: .topLeading) {
            Text("YTD History")
                .font(.system(size: scaled(11), weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .padding(6)
        }
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Period").frame(width: 52, alignment: .leading)
                Spacer()
                Text("SQ Index").frame(width: 76, alignment: .trailing)
                Text("FTSE 100").frame(width: 76, alignment: .trailing)
                Text("Delta").frame(width: 64, alignment: .trailing)
            }
            .font(.system(size: scaled(11), weight: .semibold))
            .foregroundColor(Theme.textMuted)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Theme.glassBackground)

            ForEach(bars) { bar in
                let delta = bar.sqIndex - bar.ftse100
                HStack {
                    Text(bar.period).frame(width: 52, alignment: .leading)
                    Spacer()
                    Text(String(format: "%+.1f%%", bar.sqIndex))
                        .foregroundColor(bar.sqIndex >= 0 ? Theme.accentGreen : Color(red: 0.94, green: 0.27, blue: 0.27))
                        .frame(width: 76, alignment: .trailing)
                    Text(String(format: "%+.1f%%", bar.ftse100))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 76, alignment: .trailing)
                    Text(String(format: "%+.1f%%", delta))
                        .foregroundColor(delta >= 0 ? Theme.accentGreen : Color(red: 0.94, green: 0.27, blue: 0.27))
                        .frame(width: 64, alignment: .trailing)
                }
                .font(.system(size: scaled(13), weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal)
                .padding(.vertical, 10)
                Divider().background(Theme.glassBorder).padding(.horizontal)
            }
        }
        .background(Theme.glassBackground)
        .cornerRadius(14)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: scaled(12)))
                .foregroundColor(Theme.textSecondary)
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
                    featureRow(icon: "building.columns", text: "Tracker fund view with equal-weight returns")
                    featureRow(icon: "chart.bar.fill", text: "Comparison chart vs FTSE 100")
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
