//
//  NativePaymentSheet.swift
//  ShareQuest
//
//  Native Apple Pay + card payment using Revolut Merchant API.
//
//  SETUP REQUIRED:
//  1. Apple Developer portal: create Merchant ID "merchant.co.uk.sharequest"
//  2. Revolut Business dashboard: register the same Merchant ID under Apple Pay
//  3. Xcode project: add "Apple Pay" capability and select the merchant ID
//  4. The entitlements key com.apple.developer.in-app-payments must list the merchant ID
//

import SwiftUI
import PassKit

// MARK: - Apple Pay Merchant Config
private enum ApplePay {
    static let merchantIdentifier = "merchant.co.uk.sharequest"
    static let countryCode = "GB"
    static let currencyCode = "GBP"
    static let supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex]
    static let merchantCapabilities: PKMerchantCapability = [.threeDSecure]
}

// MARK: - NativePaymentSheet

struct NativePaymentSheet: View {
    let plan: SubscriptionPlan
    let order: RevolutOrderResponse
    let onSuccess: () -> Void
    let onError: (String) -> Void

    @State private var isProcessing = false
    @State private var showCardFallback = false

    var canApplePay: Bool {
        PKPaymentAuthorizationController.canMakePayments(
            usingNetworks: ApplePay.supportedNetworks,
            capabilities: ApplePay.merchantCapabilities
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            // Order summary
            VStack(spacing: 8) {
                Image(systemName: plan.icon)
                    .font(.system(size: 36))
                    .foregroundColor(plan.color)
                Text(plan.title + " Subscription")
                    .font(.title3).fontWeight(.bold).foregroundColor(.white)
                Text(plan.price + " " + plan.priceDetail)
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
            }
            .padding(.top, 8)

            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.3).tint(.white)
                    Text("Processing payment…")
                        .font(.subheadline).foregroundColor(Theme.textSecondary)
                }
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 14) {
                    // Apple Pay button
                    if canApplePay {
                        ApplePayButtonView {
                            presentApplePay()
                        }
                        .frame(height: 54)
                        .cornerRadius(14)

                        Text("or")
                            .font(.caption).foregroundColor(Theme.textMuted)
                    }

                    // Card / web checkout fallback
                    Button {
                        showCardFallback = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "creditcard.fill")
                            Text("Pay with Card")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primaryBlue)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showCardFallback) {
            if let url = URL(string: order.checkoutUrl) {
                CardCheckoutSheet(url: url, plan: plan, onSuccess: onSuccess, onError: onError)
            }
        }
    }

    // MARK: - Apple Pay Flow

    private func presentApplePay() {
        let paymentRequest = PKPaymentRequest()
        paymentRequest.merchantIdentifier = ApplePay.merchantIdentifier
        paymentRequest.countryCode = ApplePay.countryCode
        paymentRequest.currencyCode = ApplePay.currencyCode
        paymentRequest.supportedNetworks = ApplePay.supportedNetworks
        paymentRequest.merchantCapabilities = ApplePay.merchantCapabilities
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: "ShareQuest \(plan.title) Subscription",
                amount: NSDecimalNumber(value: Double(plan.amount) / 100.0)
            ),
            PKPaymentSummaryItem(
                label: "ShareQuest",
                amount: NSDecimalNumber(value: Double(plan.amount) / 100.0)
            )
        ]

        let controller = PKPaymentAuthorizationController(paymentRequest: paymentRequest)

        let coordinator = ApplePayCoordinator(
            orderId: order.orderId,
            plan: plan.id,
            onSuccess: {
                isProcessing = false
                onSuccess()
            },
            onError: { msg in
                isProcessing = false
                onError(msg)
            },
            onProcessing: {
                isProcessing = true
            }
        )
        controller.delegate = coordinator

        // Hold coordinator alive for the session
        ApplePayCoordinator.activeCoordinator = coordinator

        controller.present { presented in
            if !presented {
                self.onError("Could not present Apple Pay. Check device settings.")
            }
        }
    }
}

// MARK: - Apple Pay Coordinator

private class ApplePayCoordinator: NSObject, PKPaymentAuthorizationControllerDelegate {
    /// Prevents ARC from deallocating before payment completes
    static var activeCoordinator: ApplePayCoordinator?

    let orderId: String
    let plan: String
    let onSuccess: () -> Void
    let onError: (String) -> Void
    let onProcessing: () -> Void

    init(orderId: String, plan: String, onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void, onProcessing: @escaping () -> Void) {
        self.orderId = orderId
        self.plan = plan
        self.onSuccess = onSuccess
        self.onError = onError
        self.onProcessing = onProcessing
    }

    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                        didAuthorizePayment payment: PKPayment,
                                        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        onProcessing()
        let tokenData = payment.token.paymentData

        Task {
            do {
                let paid = try await APIService.shared.confirmApplePayment(
                    orderId: orderId,
                    plan: plan,
                    applePayTokenData: tokenData
                )
                if paid {
                    completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
                    // Small delay so the Apple Pay success animation plays
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await MainActor.run { onSuccess() }
                } else {
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                    await MainActor.run { onError("Payment was not confirmed by the server. Please try again.") }
                }
            } catch {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                await MainActor.run { onError("Apple Pay failed: \(error.localizedDescription)") }
            }
            ApplePayCoordinator.activeCoordinator = nil
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss(completion: nil)
        ApplePayCoordinator.activeCoordinator = nil
    }
}

// MARK: - Apple Pay Button (UIKit bridge)

struct ApplePayButtonView: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
        button.cornerRadius = 14
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

// MARK: - Card Checkout Sheet (SFSafari fallback)

struct CardCheckoutSheet: View {
    let url: URL
    let plan: SubscriptionPlan
    let onSuccess: () -> Void
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var verifying = false
    @State private var verifyError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                SafariView(url: url) {
                    // Safari dismissed — check payment
                    verifyPayment()
                }
                .ignoresSafeArea()

                if verifying {
                    ZStack {
                        Color.black.opacity(0.55).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView().scaleEffect(1.3).tint(.white)
                            Text("Verifying payment…")
                                .font(.subheadline).foregroundColor(.white)
                        }
                        .padding(32)
                        .background(Color(white: 0.12))
                        .cornerRadius(16)
                    }
                }
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if verifying {
                        ProgressView().tint(.white)
                    } else {
                        Button("Done") { verifyPayment() }
                    }
                }
            }
            .alert("Payment Not Confirmed", isPresented: Binding(
                get: { verifyError != nil },
                set: { if !$0 { verifyError = nil } }
            )) {
                Button("Retry") { verifyPayment() }
                Button("Cancel", role: .cancel) { dismiss() }
            } message: {
                Text(verifyError ?? "")
            }
        }
    }

    private func verifyPayment() {
        verifying = true
        Task {
            defer { verifying = false }
            for attempt in 1...6 {
                let isPaid = (try? await APIService.shared.checkSubscriptionStatus(plan: plan.id)) ?? false
                if isPaid {
                    await MainActor.run {
                        dismiss()
                        onSuccess()
                    }
                    return
                }
                if attempt < 6 { try? await Task.sleep(nanoseconds: 2_000_000_000) }
            }
            verifyError = "Subscription not confirmed yet. If you completed payment, it may take a moment. You can close and refresh."
        }
    }
}
