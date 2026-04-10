import SwiftUI
import AuthenticationServices

// MARK: - Brand colours
private extension Color {
    static let kcNavy      = Color(red: 0.051, green: 0.106, blue: 0.165)   // #0D1B2A
    static let kcLime      = Color(red: 0.776, green: 0.945, blue: 0.208)   // #C6F135
    static let kcCard      = Color(red: 0.118, green: 0.176, blue: 0.239)   // #1E2D3D
    static let kcSteel     = Color(red: 0.176, green: 0.416, blue: 0.624)   // #2D6A9F
    static let kcMuted     = Color(red: 0.541, green: 0.608, blue: 0.690)   // #8A9BB0
}

// MARK: - FootyCards logo mark
private struct FootyCardsLogo: View {
    var body: some View {
        ZStack {
            // Card shape backdrop
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.kcLime)
                .frame(width: 64, height: 80)
                .rotationEffect(.degrees(-8))
                .shadow(color: Color.kcLime.opacity(0.45), radius: 12, y: 4)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.kcCard)
                .frame(width: 64, height: 80)

            VStack(spacing: 2) {
                // Boot icon built from system image
                Image(systemName: "figure.soccer")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.kcLime)
                Text("FC")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(2)
            }
        }
    }
}

// MARK: - Login view
struct FootballLoginView: View {
    @EnvironmentObject private var session: FootballSessionViewModel

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""

    enum Mode: String, CaseIterable, Identifiable {
        case login
        case register
        var id: String { rawValue }
    }

    private var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == .login { return !e.isEmpty && !p.isEmpty }
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return !e.isEmpty && !u.isEmpty && p.count >= 8
    }

    var body: some View {
        ZStack {
            Color.kcNavy.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    modePicker
                    form
                    appleButton
                    if let error = session.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(24)
                .padding(.top, 16)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            FootyCardsLogo()

            VStack(alignment: .leading, spacing: 4) {
                // Brand wordmark
                HStack(spacing: 0) {
                    Text("Footy")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Cards")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Color.kcLime)
                }

                Text(mode == .login ? "Sign in" : "Create account")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                Text(mode == .login
                     ? "Sign in to access your FootyCards collection."
                     : "Create an account to start collecting.")
                    .font(.subheadline)
                    .foregroundStyle(Color.kcMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Mode picker
    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                } label: {
                    Text(m == .login ? "Login" : "Register")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mode == m ? Color.kcLime : Color.clear)
                        .foregroundStyle(mode == m ? Color.kcNavy : Color.kcMuted)
                }
            }
        }
        .background(Color.kcCard)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Form
    private var form: some View {
        VStack(spacing: 12) {
            if mode == .register {
                kcField("Username", text: $username, autocap: false)
                kcField("First name", text: $firstName)
                kcField("Last name", text: $lastName)
            }

            kcField("Email", text: $email, keyboard: .emailAddress, autocap: false)
            kcSecureField("Password", text: $password)

            Button(action: submit) {
                if session.isLoading {
                    ProgressView()
                        .tint(Color.kcNavy)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(mode == .login ? "Login" : "Create account")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 50)
            .background(canSubmit && !session.isLoading ? Color.kcLime : Color.kcMuted.opacity(0.3))
            .foregroundStyle(canSubmit && !session.isLoading ? Color.kcNavy : Color.kcMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(session.isLoading || !canSubmit)
            .animation(.easeInOut(duration: 0.2), value: canSubmit)

            if mode == .register && !password.isEmpty &&
               password.trimmingCharacters(in: .whitespacesAndNewlines).count < 8 {
                Text("Password must be at least 8 characters.")
                    .font(.caption)
                    .foregroundStyle(Color.kcMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Apple button
    private var appleButton: some View {
        SignInWithAppleButton(mode == .login ? .signIn : .signUp) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            Task { await handleApple(result) }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(maxWidth: 375, minHeight: 50, maxHeight: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity)
        .disabled(session.isLoading)
    }

    // MARK: Helpers
    @ViewBuilder
    private func kcField(
        _ placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        autocap: Bool = true
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocap ? .words : .never)
            .autocorrectionDisabled(!autocap)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.kcCard)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .tint(Color.kcLime)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func kcSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.kcCard)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .tint(Color.kcLime)
            .environment(\.colorScheme, .dark)
    }

    // MARK: Actions
    private func submit() {
        Task {
            switch mode {
            case .login:
                _ = await session.signIn(email: email, password: password)
            case .register:
                _ = await session.register(
                    email: email,
                    username: username,
                    password: password,
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName
                )
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                session.errorMessage = "Apple Sign In failed: missing credentials"
                return
            }
            _ = await session.signInWithApple(
                identityToken: token,
                email: credential.email,
                firstName: credential.fullName?.givenName,
                lastName: credential.fullName?.familyName,
                appleUserId: credential.user
            )
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                session.errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    FootballLoginView()
        .environmentObject(FootballSessionViewModel())
}
