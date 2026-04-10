import SwiftUI

private extension Color {
    static let kcNavy  = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let kcLime  = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let kcCard  = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let kcMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
}

struct FootballDevResetView: View {
    @EnvironmentObject private var session: FootballSessionViewModel
    @ObservedObject var profileViewModel: FootballProfileViewModel
    @State private var isResetting = false
    @State private var lastResult: String?

    var body: some View {
        ZStack {
            Color.kcNavy.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon + title
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.kcLime.opacity(0.12))
                            .frame(width: 90, height: 90)
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.kcLime)
                    }

                    Text("Dev Reset")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Resets your onboarding so you can test the full FootyCards flow again. Only available on Local API.")
                        .font(.subheadline)
                        .foregroundStyle(Color.kcMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Result message
                if let result = lastResult {
                    Text(result)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(result.contains("✓") ? Color.kcLime : .red)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.kcCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Reset button
                Button {
                    Task { await resetOnboarding() }
                } label: {
                    if isResetting {
                        ProgressView()
                            .tint(Color.kcNavy)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Reset My Onboarding", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 54)
                .background(isResetting ? Color.kcMuted.opacity(0.3) : Color.kcLime)
                .foregroundStyle(Color.kcNavy)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(isResetting)
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
        }
    }

    private func resetOnboarding() async {
        isResetting = true
        lastResult = nil
        defer { isResetting = false }

        guard FootballAPIClient.shared.authToken != nil else {
            lastResult = "Not signed in"
            return
        }

        let didReset = await profileViewModel.resetOnboarding()
        if didReset {
            lastResult = "✓ Reset successful"
        } else if let error = profileViewModel.errorMessage {
            lastResult = "Failed: \(error)"
        } else {
            lastResult = "Failed: Unknown error"
        }
    }
}
