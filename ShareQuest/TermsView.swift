import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if #available(iOS 15.0, *) {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .opacity(0.85)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 24)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terms & Conditions")
                            .font(.largeTitle).bold()
                        Text("Last updated: July 30, 2025")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Please read these terms carefully before using ShareQuest.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Online Safety Act Notice
                    LegalNoticeBox(
                        title: "UK Online Safety Act 2023 Compliance",
                        message: "These terms have been updated to reflect our compliance with the UK Online Safety Act 2023, including mandatory age verification, community safety standards, and content moderation requirements.",
                        color: .red
                    )

                    LegalSection(number: "1", title: "Introduction") {
                        Text("Welcome to ShareQuest Trading App (\"we,\" \"our,\" or \"us\"). These Terms and Conditions govern your use of the ShareQuest Trading App, including all related websites, applications, and services (collectively, the \"Service\").")
                        Text("By accessing or using the Service, you agree to be bound by these Terms. If you disagree with any part of the Terms, you may not access the Service.")
                        Text("The ShareQuest Trading App is a platform designed for educational purposes that allows users to participate in share trading competitions using simulated currency in a skill-based environment. We comply with all applicable UK laws, including the Online Safety Act 2023.")
                    }

                    LegalSection(number: "2", title: "Intellectual Property Rights") {
                        Text("All content and software related to the Service is the property of ShareQuest Trading App or its licensors. You may not copy, modify, distribute, or exploit any part of the Service except as expressly permitted.")
                        Text("This includes all text, graphics, user interfaces, visual interfaces, photographs, trademarks, logos, sounds, music, artwork, and computer code.")
                    }

                    LegalSection(number: "3", title: "User License") {
                        Text("Users are granted a limited, non-exclusive license to use the Service. Users are responsible for all activity under their account and must not engage in prohibited conduct such as hacking, impersonation, or automated data scraping.")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Permitted Uses").font(.subheadline).bold().foregroundStyle(.green)
                            BulletList(items: [
                                "Participate in trading competitions and educational activities",
                                "Interact respectfully with other users",
                                "Use reporting features to maintain community safety",
                                "Access your personal account information and trading history"
                            ])
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "4", title: "Online Safety & Community Standards") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Age Verification Requirements").font(.subheadline).bold().foregroundStyle(.red)
                            Text("In compliance with the UK Online Safety Act 2023, all users must be 18 years or older.")
                            BulletList(items: [
                                "You confirm that you are at least 18 years of age",
                                "You provide accurate date of birth information for mandatory verification",
                                "Providing false age information constitutes a breach of these terms",
                                "You consent to age verification checks and audit logging",
                                "Age verification data will be retained as required by law"
                            ])
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Prohibited Content & Behavior").font(.subheadline).bold().foregroundStyle(.blue)
                            Text("The following are strictly prohibited:").foregroundStyle(.secondary)
                            BulletList(items: [
                                "Content promoting self-harm, suicide, or dangerous activities",
                                "Harassment, bullying, or abusive language",
                                "Hate speech, discrimination, or targeting protected groups",
                                "Threats, intimidation, or doxxing",
                                "Spam, misleading information, or market manipulation",
                                "Multiple account creation or circumventing restrictions"
                            ])
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Content Moderation").font(.subheadline).bold().foregroundStyle(.green)
                            BulletList(items: [
                                "All user-generated content is automatically scanned in real-time",
                                "Violating content will be removed immediately without prior notice",
                                "Repeat violations may result in warnings, suspension, or termination",
                                "AI moderation may be supplemented by human review"
                            ])
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "5", title: "Enforcement & Appeals") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Enforcement Actions").font(.subheadline).bold().foregroundStyle(.orange)
                            BulletList(items: [
                                "Content Removal: Immediate removal of violating content",
                                "Warning: Official warning for first-time minor violations",
                                "Temporary Suspension: Account suspension for 7–30 days",
                                "Permanent Ban: Permanent account termination",
                                "Legal Referral: Reporting to authorities for illegal content"
                            ])
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Appeals Process").font(.subheadline).bold().foregroundStyle(.indigo)
                            BulletList(items: [
                                "Submit appeals within 30 days of the enforcement action",
                                "Provide detailed explanation of why the action was incorrect",
                                "Include any additional context or evidence",
                                "Appeals are reviewed by human moderators within 7 business days"
                            ])
                        }
                        .padding()
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "6", title: "Subscriptions & Payments") {
                        Text("Some features of the Service require a paid subscription. All subscription fees are charged in advance and are non-refundable except where required by law.")
                        BulletList(items: [
                            "Subscription fees are billed on a recurring basis",
                            "You may cancel your subscription at any time",
                            "Cancellation takes effect at the end of the current billing period",
                            "We reserve the right to modify pricing with advance notice"
                        ])
                    }

                    LegalSection(number: "7", title: "Disclaimer of Warranties") {
                        Text("The Service is provided \"as is\" and \"as available\" without warranties of any kind, either express or implied. We do not warrant that the Service will be uninterrupted, error-free, or free of harmful components.")
                        Text("ShareQuest is a simulated trading platform for educational purposes only. Nothing on this platform constitutes financial advice. Past performance in simulated trading does not indicate future results in real markets.")
                    }

                    LegalSection(number: "8", title: "Limitation of Liability") {
                        Text("To the maximum extent permitted by applicable law, ShareQuest Trading App shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the Service.")
                    }

                    LegalSection(number: "9", title: "Governing Law") {
                        Text("These Terms shall be governed by and construed in accordance with the laws of England and Wales. Any disputes arising under or in connection with these Terms shall be subject to the exclusive jurisdiction of the courts of England and Wales.")
                    }

                    LegalSection(number: "10", title: "Contact Us") {
                        Text("If you have questions about these Terms, please contact us:")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ShareQuest Trading App")
                            Text("Email: support@sharequest.co.uk")
                                .foregroundStyle(.blue)
                        }
                        .font(.subheadline)
                    }

                    Text("© 2025 ShareQuest Trading App. All rights reserved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
}

// MARK: - Shared Helpers

struct LegalSection<Content: View>: View {
    let number: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(number). \(title)")
                .font(.title2).bold()
            content()
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
        }
    }
}

struct LegalNoticeBox: View {
    let title: String
    let message: String
    let color: Color

    var body: some View {
        ZStack {
            if #available(iOS 15.0, *) {
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(0.8)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.subheadline).bold().foregroundStyle(color)
                Text(message).font(.caption).foregroundStyle(color.opacity(0.85))
            }
            .padding()
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
        .cornerRadius(10)
    }
}

struct BulletList: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundStyle(.secondary)
                    Text(item)
                }
            }
        }
        .font(.subheadline)
    }
}
