import SwiftUI
import MessageUI

// MARK: - Data

private struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let category: FAQCategory
}

private enum FAQCategory: String, CaseIterable {
    case general = "General"
    case subscriptions = "Subscriptions"
    case competitions = "Competitions"
    case leagues = "Leagues"
    case technical = "Technical"

    var icon: String {
        switch self {
        case .general:       return "questionmark.circle.fill"
        case .subscriptions: return "creditcard.fill"
        case .competitions:  return "trophy.fill"
        case .leagues:       return "person.3.fill"
        case .technical:     return "lock.shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .general:       return Theme.primaryBlue
        case .subscriptions: return Theme.accentYellow
        case .competitions:  return Theme.accentPurple
        case .leagues:       return .green
        case .technical:     return .pink
        }
    }
}

private let faqs: [FAQItem] = [
    // General
    FAQItem(question: "Is ShareQuest free to use?",
            answer: "You can register, explore the platform, and use practice mode for free. To enter real competitions and win cash prizes, a small entry fee applies for each competition type.",
            category: .general),
    FAQItem(question: "Do I need trading experience to join?",
            answer: "No trading experience is required. ShareQuest is designed for all skill levels, including beginners. You can practice and learn as you go.",
            category: .general),
    FAQItem(question: "Is it risk-free?",
            answer: "Yes, ShareQuest is a virtual trading platform. You compete with virtual money, so there is no financial risk involved.",
            category: .general),
    FAQItem(question: "Who can participate in ShareQuest competitions?",
            answer: "Anyone who is 18 or older and meets eligibility requirements can participate. Please see our terms for details.",
            category: .general),
    FAQItem(question: "Can I win real money on ShareQuest?",
            answer: "Yes! ShareQuest awards real cash prizes to top performers in each competition. The prize pot is funded by entry fees and distributed to winners at the end of each competition period. Prizes are paid via bank transfer within 3–5 business days of competition closure. Minimum payout is £5. Winners are responsible for any applicable taxes.",
            category: .general),

    // Subscriptions
    FAQItem(question: "What are the entry fees and prizes?",
            answer: "Entry fees vary by competition: Weekly (£1), Monthly (£5), Annual (£50). Prize pots depend on the number of participants.",
            category: .subscriptions),
    FAQItem(question: "Can I cancel my subscription or withdraw from a competition?",
            answer: "Your subscription continues for the period you paid for and does not auto-renew. You must resubscribe to join new competitions. After your subscription ends you still have access to your account, but some features will be restricted.",
            category: .subscriptions),
    FAQItem(question: "Why do I have to pay for ShareQuest and a private league separately?",
            answer: "Each ShareQuest competition and private league has its own prize fund, kept separate to ensure fairness. Entry fees for ShareQuest go into the main prize pool, while private league fees fund their own prize pots.",
            category: .subscriptions),
    FAQItem(question: "How do I pay entry fees or subscribe?",
            answer: "You can subscribe via the ShareQuests tab in the app. Supported payment methods are shown at checkout via our secure Revolut payment link.",
            category: .subscriptions),

    // Competitions
    FAQItem(question: "How do ShareQuest competitions work?",
            answer: "Register and subscribe to enter ShareQuests. Choose from weekly, monthly, or annual competitions, trade UK stocks with live prices, and compete for real cash prizes.",
            category: .competitions),
    FAQItem(question: "What's the difference between weekly and annual competitions?",
            answer: "Weekly competitions last one week, monthly last one month, and annual run for a full year. Each has its own entry fee, prize pot, and leaderboard.",
            category: .competitions),
    FAQItem(question: "How are winners determined?",
            answer: "Winners are determined based on portfolio performance over the competition period. The top performers on the leaderboard win the prizes.",
            category: .competitions),
    FAQItem(question: "How are competition results verified?",
            answer: "Competition results are automatically calculated and verified by our system using live market prices to ensure fairness.",
            category: .competitions),
    FAQItem(question: "Can I practice trading before entering a competition?",
            answer: "Yes, you can use practice mode to trade with virtual money before joining any competitions. Your practice portfolio starts with £100,000.",
            category: .competitions),

    // Leagues
    FAQItem(question: "How much does it cost to join a private league?",
            answer: "Private leagues cost £5 for a monthly league or £50 for an annual league. The prize pot is half the total entry fees collected, awarded to the winner.",
            category: .leagues),
    FAQItem(question: "Can I join multiple leagues at once?",
            answer: "Yes, you can join multiple leagues and competitions at the same time.",
            category: .leagues),
    FAQItem(question: "Can I create a private league for friends or colleagues?",
            answer: "Yes, you can create private leagues in the ShareQuests tab and invite others using your unique join code.",
            category: .leagues),
    FAQItem(question: "How do I invite others to my league?",
            answer: "After creating a league, you'll see a join code in the league detail screen. Share this code with friends — they can enter it in the app to join.",
            category: .leagues),

    // Technical
    FAQItem(question: "Is my personal and payment information secure?",
            answer: "Yes, we use industry-standard security measures. Payments are processed securely via Revolut — we never store your card details.",
            category: .technical),
    FAQItem(question: "I'm having trouble logging in. What should I do?",
            answer: "Make sure you're using the correct email or username. Login is case-insensitive. If you've forgotten your password, use the reset option on the login screen or contact support@sharequest.co.uk.",
            category: .technical),
    FAQItem(question: "Why isn't my XP or leaderboard updating?",
            answer: "Make sure the app is set to Remote in settings (gear icon on the dashboard). Pull to refresh or restart the app. If the issue persists, contact support.",
            category: .technical),
]

// MARK: - HelpCenterView

struct HelpCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: FAQCategory? = nil
    @State private var expandedId: UUID? = nil
    @State private var searchText = ""
    @State private var showFeedback = false

    private var filteredFAQs: [FAQItem] {
        var items = faqs
        if let cat = selectedCategory { items = items.filter { $0.category == cat } }
        if !searchText.isEmpty {
            items = items.filter {
                $0.question.localizedCaseInsensitiveContains(searchText) ||
                $0.answer.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Search
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Theme.textSecondary)
                            TextField("Search help articles...", text: $searchText)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Category chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                categoryChip(nil, label: "All", icon: "square.grid.2x2.fill", color: Theme.primaryBlue)
                                ForEach(FAQCategory.allCases, id: \.self) { cat in
                                    categoryChip(cat, label: cat.rawValue, icon: cat.icon, color: cat.color)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // FAQ list
                        if filteredFAQs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                                Text("No results found")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.top, 40)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(filteredFAQs) { item in
                                    faqRow(item)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Contact / Feedback card
                        contactCard
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.primaryBlue)
                }
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ cat: FAQCategory?, label: String, icon: String, color: Color) -> some View {
        let selected = selectedCategory == cat
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = cat
                expandedId = nil
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption).fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? color : Color.white.opacity(0.08))
            .foregroundColor(selected ? .white : Theme.textSecondary)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? color : Color.clear, lineWidth: 1))
        }
    }

    // MARK: - FAQ Row

    private func faqRow(_ item: FAQItem) -> some View {
        let expanded = expandedId == item.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedId = expanded ? nil : item.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 14))
                        .foregroundColor(item.category.color)
                        .frame(width: 22)
                    Text(item.question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(14)
            }

            if expanded {
                Text(item.answer)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(expanded ? item.category.color.opacity(0.08) : Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            expanded ? item.category.color.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1
        ))
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.primaryBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Still need help?")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Our support team is here for you.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    showFeedback = true
                } label: {
                    Label("Send Feedback", systemImage: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.primaryBlue)
                        .cornerRadius(10)
                }

                Button {
                    if let url = URL(string: "mailto:support@sharequest.co.uk") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Email Us", systemImage: "envelope.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - FeedbackView

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var message = ""
    @State private var category = "General"
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String? = nil

    private let categories = ["General", "Bug Report", "Feature Request", "Payment Issue", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()
                if sent {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Feedback Sent!")
                            .font(.title2).fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Thanks for your message. We'll get back to you at the email address on your account.")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Done") { dismiss() }
                            .padding(.horizontal, 32).padding(.vertical, 12)
                            .background(Theme.primaryBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            // Category picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category").font(.caption).foregroundColor(Theme.textSecondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(categories, id: \.self) { cat in
                                            Button {
                                                category = cat
                                            } label: {
                                                Text(cat)
                                                    .font(.caption).fontWeight(.semibold)
                                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                                    .background(category == cat ? Theme.primaryBlue : Color.white.opacity(0.08))
                                                    .foregroundColor(category == cat ? .white : Theme.textSecondary)
                                                    .cornerRadius(16)
                                            }
                                        }
                                    }
                                }
                            }

                            // Subject
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Subject").font(.caption).foregroundColor(Theme.textSecondary)
                                TextField("Brief summary...", text: $subject)
                                    .padding(12)
                                    .background(Color.white.opacity(0.07))
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                            }

                            // Message
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Message").font(.caption).foregroundColor(Theme.textSecondary)
                                ZStack(alignment: .topLeading) {
                                    if message.isEmpty {
                                        Text("Describe your issue or feedback...")
                                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                                            .padding(16)
                                    }
                                    TextEditor(text: $message)
                                        .frame(minHeight: 140)
                                        .padding(8)
                                        .scrollContentBackground(.hidden)
                                        .foregroundColor(.white)
                                }
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(10)
                            }

                            if let err = errorMessage {
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                Task { await sendFeedback() }
                            } label: {
                                HStack {
                                    if isSending {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                                    }
                                    Text(isSending ? "Sending..." : "Send Feedback")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(subject.isEmpty || message.isEmpty ? Theme.primaryBlue.opacity(0.4) : Theme.primaryBlue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(subject.isEmpty || message.isEmpty || isSending)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.primaryBlue)
                }
            }
        }
    }

    private func sendFeedback() async {
        isSending = true
        errorMessage = nil
        do {
            try await APIService.shared.sendFeedback(category: category, subject: subject, message: message)
            sent = true
        } catch {
            errorMessage = "Could not send feedback. Please try emailing support@sharequest.co.uk directly."
        }
        isSending = false
    }
}

#Preview {
    HelpCenterView()
}
