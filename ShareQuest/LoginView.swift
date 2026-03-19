//
//  LoginView.swift
//  ShareQuest
//
//  Created by MartinD on 13/03/2026.
//

import SwiftUI
import Combine
import AuthenticationServices
import WebKit

/// Login screen - ported from React Native login.tsx and manual-signin.tsx
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showManualSignIn = false
    @State private var showRegister = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.059, green: 0.090, blue: 0.165),
                    Color(red: 0.118, green: 0.227, blue: 0.541),
                    Color(red: 0.345, green: 0.110, blue: 0.529)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)
                    
                    // Logo
                    VStack(spacing: 8) {
                        LogoView(size: .large)
                        
                        Text("UK Stock Trading Competitions")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Login Card
                    VStack(spacing: 20) {
                        // Social Login Buttons
                        SocialAuthButtons()

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Theme.glassBorder)
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Rectangle()
                                .fill(Theme.glassBorder)
                                .frame(height: 1)
                        }

                        // Manual Sign In Button
                        Button(action: { showManualSignIn = true }) {
                            Text("Sign in with Email")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.primaryBlue)
                                .cornerRadius(12)
                        }

                        // Register Link
                        Button(action: { showRegister = true }) {
                            HStack(spacing: 0) {
                                Text("Don't have an account? ")
                                    .foregroundColor(Theme.textSecondary)
                                Text("Register")
                                    .foregroundColor(Theme.accentPurple)
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(24)
                    .background(Color(red: 0.067, green: 0.094, blue: 0.153).opacity(0.85))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showManualSignIn) {
            ManualSignInView()
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showRegister) {
            NavigationStack {
                RegisterView()
                    .environmentObject(authManager)
            }
        }
    }
}

// MARK: - Social Auth Buttons (Apple + Google + Facebook + LinkedIn)

struct SocialAuthButtons: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 10) {
            // Apple Sign In (native)
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleApple(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .cornerRadius(12)

            // Google
            SocialLoginButton(provider: "google", icon: "g.circle.fill", title: "Continue with Google",
                              bg: .white, fg: .black)
            // Facebook
            SocialLoginButton(provider: "facebook", icon: "f.circle.fill", title: "Continue with Facebook",
                              bg: Color(red: 0.23, green: 0.35, blue: 0.60), fg: .white)
            // LinkedIn
            SocialLoginButton(provider: "linkedin", icon: "network", title: "Continue with LinkedIn",
                              bg: Color(red: 0.0, green: 0.47, blue: 0.71), fg: .white)
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                authManager.errorMessage = "Apple Sign In failed: missing credentials"
                return
            }
            let email = cred.email
            let firstName = cred.fullName?.givenName
            let lastName = cred.fullName?.familyName
            _ = await authManager.signInWithApple(
                identityToken: token, email: email,
                firstName: firstName, lastName: lastName,
                appleUserId: cred.user
            )
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                authManager.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Web OAuth Button (Google / Facebook / LinkedIn)

struct SocialLoginButton: View {
    let provider: String
    let icon: String
    let title: String
    let bg: Color
    let fg: Color

    @EnvironmentObject var authManager: AuthManager
    @State private var session: ASWebAuthenticationSession?

    var body: some View {
        Button { startOAuth() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(fg)
            .frame(maxWidth: .infinity)
            .padding()
            .background(bg)
            .cornerRadius(12)
        }
    }

    private func startOAuth() {
        let baseURL = "https://sharequest.co.uk"
        guard let url = URL(string: "\(baseURL)/api/mobile/auth/oauth-start?provider=\(provider)") else { return }
        authManager.isLoading = true
        authManager.errorMessage = nil

        let s = ASWebAuthenticationSession(url: url, callbackURLScheme: "sharequest") { callbackURL, error in
            DispatchQueue.main.async {
                if let callbackURL {
                    _ = authManager.handleOAuthCallback(url: callbackURL)
                } else {
                    authManager.isLoading = false
                    if let error, (error as NSError).code != 1 { // 1 = canceledLogin
                        authManager.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        s.prefersEphemeralWebBrowserSession = false
        session = s
        s.start()
    }
}


// MARK: - Manual Sign In View

struct ManualSignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.059, green: 0.090, blue: 0.165),
                        Color(red: 0.118, green: 0.227, blue: 0.541),
                        Color(red: 0.345, green: 0.110, blue: 0.529)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo
                        LogoView(size: .medium)
                            .padding(.top, 40)
                        
                        Text("Sign In")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Form
                        VStack(spacing: 16) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email or Username")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(Theme.textMuted)
                                    TextField("Enter your email", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .foregroundColor(.white)
                                        .focused($focusedField, equals: .email)
                                }
                                .padding()
                                .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .email ? Theme.primaryBlue : Theme.glassBorder, lineWidth: 1)
                                )
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(Theme.textMuted)
                                    
                                    if showPassword {
                                        TextField("Enter your password", text: $password)
                                            .foregroundColor(.white)
                                            .focused($focusedField, equals: .password)
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                            .foregroundColor(.white)
                                            .focused($focusedField, equals: .password)
                                    }
                                    
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(Theme.textMuted)
                                    }
                                }
                                .padding()
                                .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .password ? Theme.primaryBlue : Theme.glassBorder, lineWidth: 1)
                                )
                            }
                            
                            // Error Message
                            if let error = authManager.errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(error)
                                }
                                .font(.caption)
                                .foregroundColor(Theme.accentRed)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Theme.accentRed.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Sign In Button
                            Button(action: signIn) {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Theme.primaryBlue, Color(red: 0.149, green: 0.388, blue: 0.918)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                            
                            // Forgot Password
                            Button(action: {}) {
                                Text("Forgot Password?")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.primaryBlue)
                            }
                        }
                        .padding(24)
                        .background(Color(red: 0.067, green: 0.094, blue: 0.153).opacity(0.85))
                        .cornerRadius(20)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.primaryBlue)
                }
            }
        }
    }
    
    private func signIn() {
        Task {
            let success = await authManager.signIn(email: email, password: password)
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Register View

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    // XP earned during onboarding, passed in from Onboarding flow
    var onboardingXP: Int = 0
    
    // Form fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var dateOfBirth = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // UI state
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showForm = false
    @State private var showDatePicker = false
    @State private var selectedDate = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    
    // Onboarding completion animations
    @State private var showConfetti = false
    @State private var showXPGainToast = false
    
    // Validation
    var passwordStrength: (score: Int, feedback: String, color: Color) {
        guard !password.isEmpty else { return (0, "", Theme.textMuted) }
        
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) { score += 1 }
        
        let feedback: String
        let color: Color
        if score < 3 {
            feedback = "Weak password. Add numbers, symbols, or uppercase letters."
            color = Theme.accentRed
        } else if score < 5 {
            feedback = "Good password, but could be stronger."
            color = Theme.accentYellow
        } else {
            feedback = "Strong password!"
            color = Theme.accentGreen
        }
        
        return (score, feedback, color)
    }
    
    var ageValidation: (isValid: Bool, age: Int, error: String?) {
        guard !dateOfBirth.isEmpty else { return (false, 0, nil) }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = formatter.date(from: dateOfBirth) else {
            return (false, 0, "Invalid date format")
        }
        
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        let age = ageComponents.year ?? 0
        
        if age < 18 {
            return (false, age, "You must be 18 or older to register")
        }
        return (true, age, nil)
    }
    
    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }
    
    var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        !dateOfBirth.isEmpty &&
        ageValidation.isValid &&
        !password.isEmpty &&
        password.count >= 8 &&
        passwordStrength.score >= 3 &&
        passwordsMatch
    }
    
    var body: some View {
        ZStack {
            // Confetti & XP toast overlays when registration succeeds
            if showConfetti {
                OnboardingConfettiView(isActive: $showConfetti)
                    .allowsHitTesting(false)
            }
            if showXPGainToast {
                VStack { Spacer().frame(height: 40)
                    OnboardingXPToast(amount: authManager.onboardingXP, isVisible: $showXPGainToast)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }

            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    LogoView(size: .medium)
                        .padding(.top, 20)
                    
                    // Main Card
                    VStack(spacing: 20) {
                        // Social Login Buttons
                        SocialAuthButtons()
                        
                        // Error Message
                        if let error = authManager.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Theme.accentRed)
                                Text(error)
                                    .foregroundColor(Color(red: 0.988, green: 0.647, blue: 0.647))
                            }
                            .font(.caption)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.accentRed.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Form Header
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(Theme.accentPurple)
                            Text("Create Account")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accentPurple.opacity(0.2))
                        .cornerRadius(12)
                        
                        // Show Form Button or Form
                        if !showForm {
                            Button(action: { withAnimation { showForm = true } }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Create Account with Email")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Theme.accentPurple, Color(red: 0.486, green: 0.227, blue: 0.929)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        } else {
                            // Full Registration Form
                            VStack(spacing: 16) {
                                // Name Fields (side by side)
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("First Name *")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        TextField("First name", text: $firstName)
                                            .textFieldStyle(RegisterTextFieldStyle())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Last Name *")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        TextField("Last name", text: $lastName)
                                            .textFieldStyle(RegisterTextFieldStyle())
                                    }
                                }
                                
                                // Username
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Username *")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    HStack {
                                        Image(systemName: "at")
                                            .foregroundColor(Theme.textMuted)
                                        TextField("Choose a unique username", text: $username)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                    .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.glassBorder, lineWidth: 1)
                                    )
                                }
                                
                                // Email
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Email Address *")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    HStack {
                                        Image(systemName: "envelope")
                                            .foregroundColor(Theme.textMuted)
                                        TextField("Enter your email", text: $email)
                                            .keyboardType(.emailAddress)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                    .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.glassBorder, lineWidth: 1)
                                    )
                                }
                                
                                // Date of Birth
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Date of Birth *")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        Text("(Required for age verification)")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textMuted)
                                    }
                                    
                                    Button(action: { showDatePicker = true }) {
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(Theme.textMuted)
                                            Text(dateOfBirth.isEmpty ? "Select date" : dateOfBirth)
                                                .foregroundColor(dateOfBirth.isEmpty ? Theme.textMuted : .white)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(Theme.textMuted)
                                        }
                                        .padding()
                                        .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.glassBorder, lineWidth: 1)
                                        )
                                    }
                                    
                                    // Age validation feedback
                                    if !dateOfBirth.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: ageValidation.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            Text(ageValidation.isValid ? "Age verified: \(ageValidation.age) years old" : (ageValidation.error ?? "Invalid"))
                                        }
                                        .font(.caption)
                                        .foregroundColor(ageValidation.isValid ? Theme.accentGreen : Theme.accentRed)
                                    }
                                }
                                
                                // Password
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Password *")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    HStack {
                                        Image(systemName: "lock")
                                            .foregroundColor(Theme.textMuted)
                                        if showPassword {
                                            TextField("Password", text: $password)
                                                .foregroundColor(.white)
                                        } else {
                                            SecureField("Password", text: $password)
                                                .foregroundColor(.white)
                                        }
                                        Button(action: { showPassword.toggle() }) {
                                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                                .foregroundColor(Theme.textMuted)
                                        }
                                    }
                                    .padding()
                                    .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.glassBorder, lineWidth: 1)
                                    )
                                    
                                    // Password strength indicator
                                    if !password.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(Color.gray.opacity(0.3))
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(passwordStrength.color)
                                                        .frame(width: geometry.size.width * CGFloat(passwordStrength.score) / 5)
                                                }
                                            }
                                            .frame(height: 4)
                                            
                                            Text(passwordStrength.feedback)
                                                .font(.caption2)
                                                .foregroundColor(passwordStrength.color)
                                        }
                                    }
                                }
                                
                                // Confirm Password
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Confirm Password *")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    HStack {
                                        Image(systemName: "lock.shield")
                                            .foregroundColor(Theme.textMuted)
                                        if showConfirmPassword {
                                            TextField("Confirm password", text: $confirmPassword)
                                                .foregroundColor(.white)
                                        } else {
                                            SecureField("Confirm password", text: $confirmPassword)
                                                .foregroundColor(.white)
                                        }
                                        Button(action: { showConfirmPassword.toggle() }) {
                                            Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                                .foregroundColor(Theme.textMuted)
                                        }
                                    }
                                    .padding()
                                    .background(Color(red: 0.118, green: 0.161, blue: 0.216))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.glassBorder, lineWidth: 1)
                                    )
                                    
                                    // Password match indicator
                                    if !confirmPassword.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                                        }
                                        .font(.caption)
                                        .foregroundColor(passwordsMatch ? Theme.accentGreen : Theme.accentRed)
                                    }
                                }
                                
                                // Terms Agreement
                                Text("By creating an account, you confirm you are 18+ and agree to our Terms of Service and Privacy Policy.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 8)
                                
                                // Register Button
                                Button(action: register) {
                                    HStack {
                                        if authManager.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "person.badge.plus")
                                            Text("Create Account")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: isFormValid ? [Theme.accentPurple, Color(red: 0.486, green: 0.227, blue: 0.929)] : [Color.gray, Color.gray.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                .disabled(authManager.isLoading || !isFormValid)
                            }
                        }
                        
                        // Already have account link
                        Button(action: { dismiss() }) {
                            HStack(spacing: 0) {
                                Text("Already have an account? ")
                                    .foregroundColor(Theme.textSecondary)
                                Text("Sign In")
                                    .foregroundColor(Theme.primaryBlue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(24)
                    .background(Color(red: 0.067, green: 0.094, blue: 0.153).opacity(0.85))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate, dateString: $dateOfBirth, isPresented: $showDatePicker)
        }
    }
    
    private func register() {
        Task {
            let success = await authManager.register(
                email: email,
                username: username,
                password: password,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                onboardingXP: onboardingXP
            )
            if success {
                // AuthManager now persisted and attempted to sync onboarding XP. Trigger confetti/toast then dismiss.
                await MainActor.run {
                    showConfetti = true
                    showXPGainToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation { showXPGainToast = false }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation { showConfetti = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var dateString: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Date of Birth",
                    selection: $selectedDate,
                    in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Date of Birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        dateString = formatter.string(from: selectedDate)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Register Text Field Style

struct RegisterTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
            .padding()
            .background(Color(red: 0.118, green: 0.161, blue: 0.216))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.glassBorder, lineWidth: 1)
            )
    }
}

// MARK: - Form Field Component

struct FormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    @State private var showText = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.textMuted)
                .frame(width: 24)
            
            if isSecure && !showText {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
            }
            
            if isSecure {
                Button(action: { showText.toggle() }) {
                    Image(systemName: showText ? "eye.slash" : "eye")
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding()
        .background(Color(red: 0.118, green: 0.161, blue: 0.216))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Logo View Component

enum LogoSize {
    case small, medium, large
    
    var imageMaxWidth: CGFloat {
        switch self {
        case .small: return 150
        case .medium: return 220
        case .large: return 300
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 50
        case .medium: return 70
        case .large: return 90
        }
    }
    
    var textSize: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 28
        case .large: return 36
        }
    }
}

struct LogoView: View {
    let size: LogoSize
    var showText: Bool = true
    
    var body: some View {
        VStack(spacing: 8) {
            // Use SplashLogo as primary (same as splash screen)
            if let _ = UIImage(named: "SplashLogo") {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: size.imageMaxWidth)
            } else if let _ = UIImage(named: "ShareQuestLogo") {
                Image("ShareQuestLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: size.imageMaxWidth)
            } else if let _ = UIImage(named: "Logo") {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: size.imageMaxWidth)
            } else {
                // Fallback to SF Symbol with text
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.primaryBlue, Theme.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                if showText {
                    Text("ShareQuest")
                        .font(.system(size: size.textSize, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthManager.shared)
    }
}
