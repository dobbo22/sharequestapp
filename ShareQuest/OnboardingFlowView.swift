//
//  OnboardingFlowView.swift
//  ShareQuest
//
//  Created by MartinD on 13/03/2026.
//

import SwiftUI
import Combine

// MARK: - Onboarding Flow Coordinator

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case firstTrade = 1
    case portfolio = 2
    case search = 3
    case sectors = 4
    case complete = 5
}

@MainActor
class OnboardingFlowViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var xp: Int = 0
    @Published var holdings: [OnboardingHolding] = []
    @Published var purchasedSymbols: Set<String> = []
    @Published var foundNatWest = false
    @Published var foundRollsRoyce = false
    // Published last XP gain - used by views to show transient XP toasts
    @Published var lastXPGain: Int = 0
    
    func addXP(_ amount: Int) {
        xp += amount
        KeychainHelper.save(String(xp), for: "onboarding_xp")
        // Surface a short-lived XP gain indicator
        lastXPGain = amount
    }
    
    func clearLastXPGain() {
        lastXPGain = 0
    }
    func deductXP(_ amount: Int) {
        xp = max(0, xp - amount)
        KeychainHelper.save(String(xp), for: "onboarding_xp")
    }
    
    func nextStep() {
        if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }
    
    func goToStep(_ step: OnboardingStep) {
        currentStep = step
    }
}

struct OnboardingHolding: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let amount: Int
    let buyPrice: Double
    var currentPrice: Double
    
    var value: Double { Double(amount) * currentPrice }
    var profit: Double { (currentPrice - buyPrice) * Double(amount) }
    var profitPercent: Double { ((currentPrice - buyPrice) / buyPrice) * 100 }
}

// Shared helpers: format pence display
func formatPence(_ priceInPounds: Double) -> String {
    let pence = priceInPounds * 100.0
    if pence.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(pence))p"
    } else {
        var s = String(format: "%.2f", pence)
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.removeLast() }
        return "\(s)p"
    }
}

func formatPenceFromPence(_ pence: Double) -> String {
    if pence.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(pence))p"
    } else {
        var s = String(format: "%.2f", pence)
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.removeLast() }
        return "\(s)p"
    }
}

// MARK: - Main Onboarding Flow View

struct OnboardingFlowView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = OnboardingFlowViewModel()
    @State private var showXPToast = false
    @State private var xpToastAmount = 0
    @State private var showConfetti = false
    @State private var showFloatingXP = false
    @State private var floatingXPAmt = 0
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.039, green: 0.110, blue: 0.173)
                .ignoresSafeArea()

            // Content based on step
            switch viewModel.currentStep {
            case .welcome:
                OnboardingWelcomeView(viewModel: viewModel)
            case .firstTrade:
                FirstTradeView(viewModel: viewModel)
            case .portfolio:
                OnboardingPortfolioView(viewModel: viewModel)
            case .search:
                OnboardingSearchView(viewModel: viewModel)
            case .sectors:
                OnboardingSectorsView(viewModel: viewModel)
            case .complete:
                OnboardingCompleteView(viewModel: viewModel)
                    .environmentObject(authManager)
            }

            // Confetti layer (covers whole screen when active)
            if showConfetti {
                OnboardingConfettiView(isActive: $showConfetti)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Floating XP (near center, appears briefly)
            if showFloatingXP {
                OnboardingFloatingXP(amount: floatingXPAmt)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // XP Toast overlay (top center)
            if showXPToast {
                VStack { Spacer().frame(height: 40)
                    OnboardingXPToast(amount: xpToastAmount, isVisible: $showXPToast)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
        }
        // Ensure the XP bar reserves space so content (buttons) never get overlapped
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.currentStep != .welcome && viewModel.currentStep != .complete {
                HStack { Spacer(); XPBarView(xp: viewModel.xp); Spacer() }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(Color.clear)
            } else {
                EmptyView()
            }
        }
        .onReceive(viewModel.$lastXPGain) { gain in
            guard gain > 0 else { return }
            xpToastAmount = gain
            showXPToast = true
            // Trigger confetti and floating XP when XP is awarded
            floatingXPAmt = gain
            showFloatingXP = true
            showConfetti = true
            // Dismiss floating XP after short delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                withAnimation { showFloatingXP = false }
                try? await Task.sleep(nanoseconds: 200_000_000)
                viewModel.clearLastXPGain()
            }
        }
    }
}

// MARK: - XP Bar

struct XPBarView: View {
    let xp: Int
    
    var body: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundColor(Color(red: 1, green: 0.88, blue: 0.4))
            Text("XP")
                .fontWeight(.bold)
                .foregroundColor(Color(red: 1, green: 0.88, blue: 0.4))
            Text("\(xp)")
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
        .padding(.bottom, 30)
    }
}

// MARK: - XP Toast View

struct OnboardingXPToast: View {
    let amount: Int
    @Binding var isVisible: Bool
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundColor(Color(red: 1, green: 0.88, blue: 0.4))
            Text("+\(amount) XP")
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1
                opacity = 1
            }
            // Auto-dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.25)) {
                    opacity = 0
                    scale = 0.8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - Welcome View (Carousel)

struct OnboardingWelcomeView: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel
    @State private var currentPage = 0
    
    private let slides = [
        (title: "Practice Trading", description: "Trade stocks with virtual money and build your skills risk-free.", icon: "chart.line.uptrend.xyaxis", color: Color(red: 0.231, green: 0.510, blue: 0.965)),
        (title: "Compete in Leagues", description: "Join competitions, climb leaderboards, and win rewards.", icon: "trophy.fill", color: Color(red: 0.961, green: 0.620, blue: 0.043)),
        (title: "Learn & Earn", description: "Access tutorials, improve your knowledge, and earn badges.", icon: "star.fill", color: Color(red: 0.545, green: 0.361, blue: 0.965))
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Page Content
            TabView(selection: $currentPage) {
                ForEach(0..<slides.count, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Icon
                        ZStack {
                            Circle()
                                .fill(slides[index].color.opacity(0.2))
                                .frame(width: 180, height: 180)
                            
                            Circle()
                                .fill(slides[index].color.opacity(0.1))
                                .frame(width: 240, height: 240)
                            
                            Image(systemName: slides[index].icon)
                                .font(.system(size: 80))
                                .foregroundColor(slides[index].color)
                        }
                        .padding(.bottom, 20)
                        
                        // Text Content
                        VStack(spacing: 16) {
                            Text(slides[index].title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text(slides[index].description)
                                .font(.body)
                                .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0.094, green: 0.157, blue: 0.282))
                        )
                        .padding(.horizontal, 24)
                        
                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color(red: 0.231, green: 0.510, blue: 0.965) : Color.gray.opacity(0.5))
                        .frame(width: 10, height: 10)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 24)
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: { viewModel.nextStep() }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.231, green: 0.510, blue: 0.965))
                        .cornerRadius(12)
                }
                
                Button(action: { viewModel.goToStep(.complete) }) {
                    Text("Skip Tutorial")
                        .font(.subheadline)
                        .foregroundColor(Color.gray)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - First Trade View

struct FirstTradeView: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    private let stocks = [
        (symbol: "TSCO.L", name: "Tesco PLC", price: 2.755, icon: "cart.fill"),
        (symbol: "MKS.L", name: "Marks & Spencer", price: 2.452, icon: "bag.fill"),
        (symbol: "SBRY.L", name: "J Sainsbury PLC", price: 2.678, icon: "basket.fill")
    ]

    @State private var selectedStock: Int = 0
    @State private var amount: String = "1000"
    @State private var isTrading = false
    
    var availableStocks: [(symbol: String, name: String, price: Double, icon: String)] {
        stocks.filter { !viewModel.purchasedSymbols.contains($0.symbol) }
    }
    
    var selectedStockData: (symbol: String, name: String, price: Double, icon: String)? {
        guard selectedStock < availableStocks.count else { return nil }
        return availableStocks[selectedStock]
    }
    
    var totalCost: Double {
        guard let stock = selectedStockData, let qty = Int(amount) else { return 0 }
        return stock.price * Double(qty)
    }
    
    var isSecondTrade: Bool {
        !viewModel.purchasedSymbols.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(isSecondTrade ? "Buy Another Stock!" : "Let's Go Shopping!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(isSecondTrade ? "Great trade! Now pick another supermarket to diversify your portfolio." : "Did you know you can buy shares in your favorite supermarket? Pick one below and make your first practice trade!")
                        .font(.subheadline)
                        .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Stock Selection
                VStack(spacing: 12) {
                    ForEach(Array(availableStocks.enumerated()), id: \.element.symbol) { index, stock in
                        Button(action: { selectedStock = index }) {
                            HStack {
                                Image(systemName: stock.icon)
                                    .font(.title2)
                                    .foregroundColor(selectedStock == index ? .white : Color(red: 0.231, green: 0.510, blue: 0.965))
                                    .frame(width: 50, height: 50)
                                    .background(selectedStock == index ? Color(red: 0.231, green: 0.510, blue: 0.965) : Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.2))
                                    .cornerRadius(12)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stock.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(stock.symbol)
                                        .font(.caption)
                                        .foregroundColor(Color.gray)
                                }
                                
                                Spacer()
                                
                                // Price + checkmark column on the right of the tile
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(formatPence(stock.price))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    if selectedStock == index {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 0.063, green: 0.725, blue: 0.506))
                                    }
                                }
                                .frame(minWidth: 72)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedStock == index ? Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.2) : Color(red: 0.118, green: 0.161, blue: 0.216))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedStock == index ? Color(red: 0.231, green: 0.510, blue: 0.965) : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount (shares)")
                        .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                    
                    TextField("1000", text: $amount)
                        .keyboardType(.numberPad)
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Total
                if let _ = selectedStockData, let qty = Int(amount), qty > 0 {
                    HStack {
                        Text("Total:")
                            .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                        Text("£\(String(format: "%.2f", totalCost))")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                // Buy Button
                Button(action: executeTrade) {
                    HStack {
                        if isTrading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Buy")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.231, green: 0.510, blue: 0.965))
                    .cornerRadius(12)
                }
                .disabled(isTrading || (Int(amount) ?? 0) <= 0)
                .opacity(Int(amount) ?? 0 > 0 ? 1 : 0.5)
                .padding(.horizontal)
                // Extra bottom padding so the XPBar overlay won't cover the button in simulator/device
                .padding(.bottom, 80)
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // Implement trade action: simulate a trade, add to viewModel and award XP
    private func executeTrade() {
        guard let stock = selectedStockData, let qty = Int(amount), qty > 0 else { return }
        isTrading = true

        // Simulate network/trade delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            // Create holding (prices in pounds)
            let holding = OnboardingHolding(symbol: stock.symbol, name: stock.name, amount: qty, buyPrice: stock.price, currentPrice: stock.price)
            viewModel.holdings.append(holding)
            viewModel.purchasedSymbols.insert(stock.symbol)

            // Award XP for first trade
            viewModel.addXP(50)

            isTrading = false

            // Advance to portfolio phase so user can see their holdings
            viewModel.nextStep()
        }
    }
}

// MARK: - Onboarding Portfolio View

struct OnboardingPortfolioView: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel
    @State private var animatedHoldings: [OnboardingHolding] = []
    @State private var phase: PortfolioPhase = .rising
    @State private var canContinue = false
    @State private var riseXP = 0

    enum PortfolioPhase {
        case rising, action, selling, sold
    }

    var totalValue: Double {
        animatedHoldings.reduce(0) { $0 + $1.value }
    }

    var totalProfit: Double {
        animatedHoldings.reduce(0) { $0 + $1.profit }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Your Portfolio")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Only show a hint while prices are rising; remove the 'stocks have risen' message per request
                    if phase == .rising {
                        Text("Watch your stocks grow! 📈")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                    }
                }
                .padding(.top, 40)
                
                // Portfolio Value Card (smaller)
                VStack(spacing: 6) {
                    Text("Portfolio Value")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                    
                    // Reduced size to avoid taking too much vertical space on small devices
                    Text("£\(String(format: "%.2f", totalValue))")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.8)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right")
                            .font(.subheadline)
                        Text("+£\(String(format: "%.2f", totalProfit))")
                            .font(.subheadline)
                    }
                    .foregroundColor(Color(red: 0.063, green: 0.725, blue: 0.506))
                }
                .padding(12)
                .frame(minHeight: 96)
                 .frame(maxWidth: .infinity)
                 .background(
                     LinearGradient(
                         colors: [Color(red: 0.231, green: 0.510, blue: 0.965), Color(red: 0.149, green: 0.388, blue: 0.918)],
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing
                     )
                 )
                 .cornerRadius(16)
                 .padding(.horizontal)
                
                // Holdings List
                VStack(spacing: 12) {
                    ForEach(animatedHoldings) { holding in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(holding.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(holding.amount) shares")
                                    .font(.caption)
                                    .foregroundColor(Color.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("£\(String(format: "%.2f", holding.value))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.up")
                                    Text("+\(String(format: "%.1f", holding.profitPercent))%")
                                }
                                .font(.caption)
                                .foregroundColor(Color(red: 0.063, green: 0.725, blue: 0.506))
                            }
                        }
                        .padding()
                        .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                        .cornerRadius(12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .id(holding.id)
                    }
                }
                .padding(.horizontal)

                // When in action phase, show Sell buttons inline for each holding with animation
                if phase == .action {
                    VStack(spacing: 12) {
                        ForEach(animatedHoldings) { h in
                            Button(action: { sellStock(h) }) {
                                HStack {
                                    Text("Sell \(h.name)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("£\(String(format: "%.2f", h.value))")
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color(red: 0.961, green: 0.620, blue: 0.043))
                                .cornerRadius(12)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Instruction to sell when action phase
                if phase == .action {
                    VStack(spacing: 8) {
                        Text("Great — your holdings have increased in value!")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Tap 'Sell' on a holding below to realise the gains and continue the tutorial.")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                    }
                    .padding(.horizontal)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Buy Another (if less than 2 stocks)
                    if viewModel.holdings.count < 2 {
                        Button(action: buyAnother) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Buy Another Stock")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.063, green: 0.725, blue: 0.506))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Sell (if we have stocks)
                    if phase == .action {
                        ForEach(animatedHoldings.prefix(1)) { h in
                            Button(action: { sellStock(h) }) {
                                HStack {
                                    Image(systemName: "arrow.up.right.circle.fill")
                                    Text("Sell \(h.name)")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.961, green: 0.620, blue: 0.043))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Continue after selling
                    if phase == .sold {
                        Button(action: { viewModel.nextStep() }) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.231, green: 0.510, blue: 0.965))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            animatedHoldings = viewModel.holdings
            animatePriceRise()
        }
    }
    
    private func animatePriceRise() {
        // Animate prices rising ~5%
        let duration = 2.0
        let steps = 60
        let stepDuration = duration / Double(steps)
        
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let progress = Double(step) / Double(steps)
                // animate changes to animatedHoldings for smooth UI updates
                withAnimation(.easeOut(duration: 0.18)) {
                    animatedHoldings = viewModel.holdings.map { holding in
                        var updated = holding
                        let targetPrice = holding.buyPrice * 1.05
                        updated.currentPrice = holding.buyPrice + (targetPrice - holding.buyPrice) * progress
                        return updated
                    }
                }
                
                // Calculate rise XP
                let totalRise = animatedHoldings.reduce(0) { $0 + ($1.currentPrice - $1.buyPrice) * 100 }
                riseXP = Int(totalRise)
                
                if step == steps {
                    viewModel.addXP(riseXP)
                    phase = .action
                    canContinue = true
                }
            }
        }
    }

    private func buyAnother() {
        viewModel.goToStep(.firstTrade)
    }
    
    private func sellStock(_ holding: OnboardingHolding) {
        // Begin selling animation/state
        phase = .selling

        // Capture index in case holdings change
        guard let idx = viewModel.holdings.firstIndex(where: { $0.id == holding.id }) else {
            // fallback: just mark sold and continue
            phase = .sold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                viewModel.nextStep()
            }
            return
        }

        // Simulate sell delay & update portfolio
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Remove the sold holding from the model with animation
            withAnimation(.easeInOut) {
                let _ = viewModel.holdings.remove(at: idx)
                animatedHoldings = viewModel.holdings
            }

            // Award XP for selling
            viewModel.addXP(50)

            // Update phase and then advance to the next onboarding step (stock search)
            withAnimation {
                phase = .sold
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                viewModel.nextStep()
            }
         }
     }
}

// MARK: - Onboarding Search View

struct OnboardingSearchView: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var selectedStock: SearchResult?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    
    private let apiService = APIService.shared
    
    struct SearchResult: Identifiable {
        let id = UUID()
        let symbol: String
        let name: String
        let price: Double
    }
    
    var foundNatWest: Bool {
        guard let stock = selectedStock else { return false }
        return stock.name.lowercased().contains("natwest") || stock.symbol.uppercased() == "NWG.L"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Find NatWest Bank")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("There are 100's of stocks to trade. Try searching for \"NatWest\" to find it.")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.gray)
                
                TextField("Search stocks...", text: $query)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, newValue in
                        // Debounced search to match mobile app behaviour
                        debounceSearch(newValue)
                    }
                
                if !query.isEmpty {
                    Button(action: {
                        query = ""
                        results = []
                        selectedStock = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.gray)
                    }
                }
            }
            .padding()
            .background(Color(red: 0.118, green: 0.161, blue: 0.216))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Results
            if isSearching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if !results.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(results) { result in
                            Button(action: { selectStock(result) }) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(Color(red: 0.231, green: 0.510, blue: 0.965))
                                        .frame(width: 40, height: 40)
                                        .background(Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.2))
                                        .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Text(result.symbol)
                                            .font(.caption)
                                            .foregroundColor(Color.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    // Show price in pence on the right
                                    VStack(alignment: .trailing) {
                                        Text(formatPenceFromPence(result.price))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Selected Stock
            if let stock = selectedStock {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(stock.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(stock.symbol)
                                .font(.caption)
                                .foregroundColor(Color.gray)
                        }
                        Spacer()
                        // Show price for selected stock (stock.price is stored in pence)
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(formatPenceFromPence(stock.price))
                                .font(.headline)
                                .foregroundColor(.white)
                            if foundNatWest {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(red: 0.063, green: 0.725, blue: 0.506))
                                    .font(.title)
                            }
                        }
                    }
                    .padding()
                    .background(foundNatWest ? Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.2) : Color(red: 0.118, green: 0.161, blue: 0.216))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(foundNatWest ? Color(red: 0.063, green: 0.725, blue: 0.506) : Color.clear, lineWidth: 2)
                    )
                    
                    if foundNatWest {
                        Text("🎉 You found NatWest! +100 XP")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.063, green: 0.725, blue: 0.506))
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Continue Button
            if selectedStock != nil {
                Button(action: continueToNext) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.231, green: 0.510, blue: 0.965))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
        }
    }
    
    /// Debounced search that mirrors the mobile app implementation
    private func debounceSearch(_ q: String) {
        // Cancel any previous pending search
        searchTask?.cancel()

        // Clear results for short queries
        guard q.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        // Start a new debounced task
        searchTask = Task {
            // Wait 300ms debounce
            try? await Task.sleep(nanoseconds: 300_000_000)

            // If task was cancelled during sleep, exit
            if Task.isCancelled { return }

            await MainActor.run { isSearching = true }

            do {
                let stockData = try await apiService.searchStocks(query: q)

                if Task.isCancelled { return }

                await MainActor.run {
                    results = stockData.prefix(10).map { stock in
                        // Use raw pence from API (`price` or `current_price`) so our pence formatter is correct
                        let pence = stock.price ?? stock.current_price ?? 0
                        return SearchResult(symbol: stock.symbol, name: stock.displayName, price: pence)
                    }
                    isSearching = false
                    // Dismiss keyboard so results are visible
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    results = []
                    isSearching = false
                }
            }
        }
    }
    
    private func selectStock(_ stock: SearchResult) {
        selectedStock = stock
        query = ""
        results = []
        
        // Check if NatWest
        if stock.name.lowercased().contains("natwest") || stock.symbol.uppercased() == "NWG.L" {
            viewModel.foundNatWest = true
            viewModel.addXP(100)
        }
    }
    
    private func continueToNext() {
        viewModel.nextStep()
    }
}

// MARK: - Onboarding Sectors View

struct OnboardingSectorsView: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel
    @State private var selectedSector: String?
    @State private var showPenalty = false
    
    private let sectors = [
        "Aerospace & Defence", "Banks", "Consumer Goods", "Energy",
        "Financials", "Healthcare", "Industrials", "Real Estate",
        "Technology", "Utilities"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Find Rolls-Royce")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Stocks are organized by sector. Rolls-Royce makes jet engines - which sector do you think it's in?")
                        .font(.subheadline)
                        .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Show the currently selected sector as a small pill so the user can see their choice
                if let sel = selectedSector {
                    HStack {
                        Spacer()
                        Text("Sector: \(sel)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                            .cornerRadius(12)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // Penalty Toast
                if showPenalty {
                    Text("-1 XP Oops!")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.937, green: 0.267, blue: 0.267))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Sector Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(sectors, id: \.self) { sector in
                        Button(action: { selectSector(sector) }) {
                            VStack {
                                Text(sector)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                selectedSector == sector
                                    ? (sector == "Industrials" ? Color(red: 0.063, green: 0.725, blue: 0.506) : Color(red: 0.937, green: 0.267, blue: 0.267))
                                    : Color(red: 0.118, green: 0.161, blue: 0.216)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Success Message
                if selectedSector == "Aerospace & Defence" {
                    VStack(spacing: 8) {
                        Text("🎉 Correct! Rolls-Royce is in Aerospace & Defence!")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.063, green: 0.725, blue: 0.506))

                        // Move Continue button up; remove duplicated sector pill and XP badge to avoid overlap
                        Button(action: { viewModel.nextStep() }) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.231, green: 0.510, blue: 0.965))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 100)
            }
        }
    }
    
    private func selectSector(_ sector: String) {
        selectedSector = sector
        
        if sector == "Aerospace & Defence" {
            viewModel.foundRollsRoyce = true
            viewModel.addXP(100)
        } else {
             // Wrong answer penalty
             viewModel.deductXP(1)
             withAnimation {
                 showPenalty = true
             }
             DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                 withAnimation {
                     showPenalty = false
                 }
             }
             // Reset selection after showing penalty
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                 selectedSector = nil
             }
         }
    }
}

// MARK: - Onboarding Complete View

struct OnboardingCompleteView: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel
    @EnvironmentObject var authManager: AuthManager
    @State private var showRegister = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Trophy Icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.961, green: 0.620, blue: 0.043).opacity(0.2))
                    .frame(width: 150, height: 150)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 70))
                    .foregroundColor(Color(red: 0.961, green: 0.620, blue: 0.043))
            }

            // Congratulations
            VStack(spacing: 12) {
                Text("Tutorial Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("You've learned the basics of trading. Now it's time to compete!")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.69, green: 0.77, blue: 0.87))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // XP Earned
            VStack(spacing: 8) {
                Text("XP Earned")
                    .font(.caption)
                    .foregroundColor(Color.gray)
                
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(Color(red: 1, green: 0.88, blue: 0.4))
                    Text("\(viewModel.xp)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(red: 1, green: 0.88, blue: 0.4))
                }
            }
            .padding()
            .background(Color(red: 0.118, green: 0.161, blue: 0.216))
            .cornerRadius(16)

            Spacer()

            // Buttons
            VStack(spacing: 16) {
                Button(action: completeOnboarding) {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.545, green: 0.361, blue: 0.965))
                        .cornerRadius(12)
                }
                
                Button(action: skipToLogin) {
                    Text("I already have an account")
                        .font(.subheadline)
                        .foregroundColor(Color(red: 0.231, green: 0.510, blue: 0.965))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        // Present the Register screen when the user chooses to create an account
        .fullScreenCover(isPresented: $showRegister, onDismiss: {
            // Only mark onboarding complete when the user actually registered/logged in and onboarding wasn't already marked complete.
            if authManager.isAuthenticated && !authManager.hasCompletedOnboarding {
                authManager.completeOnboarding(withXP: viewModel.xp)
            }
        }) {
            NavigationStack {
                RegisterView(onboardingXP: viewModel.xp)
                    .environmentObject(authManager)
            }
        }
    }
    
    private func completeOnboarding() {
        // Present the Register flow; do not persist XP here — RegisterView will persist/sync on success
        showRegister = true
    }
    
    private func skipToLogin() {
        // Save XP and complete onboarding - will navigate to login screen
        authManager.completeOnboarding(withXP: viewModel.xp)
    }
}

// Confetti: lightweight SwiftUI particle emitter (no external libs)
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var size: CGFloat
    var color: Color
    var rotation: Angle = .degrees(0)
    var delay: Double
    var duration: Double
}

struct OnboardingConfettiView: View {
    @Binding var isActive: Bool
    @State private var particles: [ConfettiParticle] = []
    @State private var offsets: [UUID: CGFloat] = [:]
    private let count = 22
    private let colors: [Color] = [Color(red: 0.961, green: 0.620, blue: 0.043), Color(red: 0.063, green: 0.725, blue: 0.506), Color(red: 0.231, green: 0.510, blue: 0.965), Color.pink, Color.purple, Color.yellow]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .rotationEffect(p.rotation)
                        .position(x: p.x * geo.size.width, y: offsets[p.id] ?? -20)
                        .opacity((offsets[p.id] ?? -20) > geo.size.height ? 0 : 1)
                        .shadow(color: .black.opacity(0.15), radius: 1)
                }
            }
            .onAppear {
                // generate particles
                particles = (0..<count).map { i in
                    ConfettiParticle(
                        x: CGFloat(Double.random(in: 0.08...0.92)),
                        size: CGFloat(Double.random(in: 6...14)),
                        color: colors.randomElement() ?? .yellow,
                        delay: Double.random(in: 0...0.35),
                        duration: Double.random(in: 1.2...2.2)
                    )
                }

                // start animations
                for p in particles {
                    offsets[p.id] = -30
                    let finalY = geo.size.height + 80
                    DispatchQueue.main.asyncAfter(deadline: .now() + p.delay) {
                        withAnimation(.interpolatingSpring(stiffness: 30, damping: 10).speed(1.0)) {
                            offsets[p.id] = finalY
                        }
                    }
                }

                // Auto-stop after longest duration
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    withAnimation { isActive = false }
                    // clear particles
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        particles = []
                        offsets = [:]
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// Floating XP: small text that floats upward and fades
struct OnboardingFloatingXP: View {
    let amount: Int
    @State private var yOffset: CGFloat = 30
    @State private var opacity: Double = 0

    var body: some View {
        Text("+\(amount) XP")
            .font(.headline)
            .fontWeight(.bold)
            .padding(10)
            .background(Color.black.opacity(0.8))
            .foregroundColor(Color(red: 1, green: 0.88, blue: 0.4))
            .cornerRadius(12)
            .opacity(opacity)
            .offset(y: yOffset)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    yOffset = 0
                    opacity = 1
                }
                withAnimation(.easeOut(duration: 0.9).delay(0.9)) {
                    yOffset = -40
                    opacity = 0
                }
            }
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AuthManager.shared)
}
