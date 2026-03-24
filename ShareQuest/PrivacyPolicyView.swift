import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy Policy")
                            .font(.largeTitle).bold()
                        Text("Last updated: July 30, 2025")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("We respect your privacy and are committed to protecting your personal data.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Online Safety Act Notice
                    LegalNoticeBox(
                        title: "UK Online Safety Act 2023 Compliance",
                        body: "This privacy policy has been updated to reflect our compliance with the UK Online Safety Act 2023, including age verification requirements, content moderation processes, and safety reporting mechanisms.",
                        color: .red
                    )

                    LegalSection(number: "1", title: "Introduction") {
                        Text("ShareQuest Trading App (\"we,\" \"our,\" or \"us\") is committed to protecting your personal data. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our Service.")
                        Text("By using our Service, you acknowledge that you have read and understood this Privacy Policy. If you do not agree with our policies, please do not use the Service.")
                    }

                    LegalSection(number: "2", title: "Data We Collect") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Personal Data").font(.subheadline).bold().foregroundStyle(.blue)
                            Text("While using our Service, we may ask you to provide personally identifiable information, including:").foregroundStyle(.secondary)
                            BulletList(items: [
                                "First and last name",
                                "Email address",
                                "Username",
                                "Country of residence",
                                "Date of birth (required for age verification)",
                                "Payment information (for subscription payments only)"
                            ])
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Usage Data").font(.subheadline).bold().foregroundStyle(.green)
                            Text("We may also collect information about how you use our Service, including:").foregroundStyle(.secondary)
                            BulletList(items: [
                                "Your device's IP address",
                                "Browser type and version",
                                "Pages of our Service that you visit",
                                "Time and date of your visit",
                                "Trading activity and portfolio management within the app",
                                "Content moderation and safety interactions",
                                "Other diagnostic data"
                            ])
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Safety & Compliance Data").font(.subheadline).bold().foregroundStyle(.red)
                            Text("In compliance with the UK Online Safety Act 2023, we collect additional data for safety purposes:").foregroundStyle(.secondary)
                            BulletList(items: [
                                "Age verification status and audit logs",
                                "Content moderation actions and decisions",
                                "User reports of harmful content or behavior",
                                "Safety-related communications and appeals",
                                "Account restriction or suspension records"
                            ])
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "3", title: "How We Use Your Data") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Service Operations").font(.subheadline).bold()
                            BulletList(items: [
                                "To provide and maintain our Service",
                                "To notify you about changes to our Service",
                                "To allow you to participate in interactive features",
                                "To provide customer support",
                                "To process payments and manage subscriptions",
                                "To organise and manage trading competitions"
                            ])
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Legal Basis for Processing").font(.subheadline).bold().foregroundStyle(.purple)
                            BulletList(items: [
                                "To perform our contract with you",
                                "For our legitimate interests in operating and improving our Service",
                                "With your consent, where applicable",
                                "To comply with legal obligations under the Online Safety Act 2023"
                            ])
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "4", title: "Disclosure of Your Data") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Service Providers").font(.subheadline).bold().foregroundStyle(.orange)
                            Text("We may employ third-party companies to facilitate our Service. These third parties have access to your personal data only to perform tasks on our behalf and are obligated not to disclose or use it for any other purpose.")
                                .foregroundStyle(.orange.opacity(0.9))
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Legal Requirements & Safety").font(.subheadline).bold().foregroundStyle(.red)
                            Text("We may disclose your personal data if required by law. Under the Online Safety Act 2023, we may also disclose data:").foregroundStyle(.secondary)
                            BulletList(items: [
                                "To law enforcement regarding illegal content or activities",
                                "To regulatory authorities for compliance verification",
                                "To protect users from serious harm or risk",
                                "In response to court orders or legal processes"
                            ])
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "5", title: "Data Security") {
                        Text("The security of your personal data is important to us. We strive to use commercially acceptable means to protect your personal data, but no method of transmission over the Internet is 100% secure.")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("We implement the following measures:").foregroundStyle(.secondary)
                            BulletList(items: [
                                "Encryption of sensitive data including age verification information",
                                "Regular security assessments and vulnerability testing",
                                "Access controls and multi-factor authentication",
                                "Secure data storage systems with backup protocols",
                                "Staff training on data protection requirements",
                                "Automated monitoring for security threats"
                            ])
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "6", title: "Your Privacy Rights") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Standard Rights").font(.subheadline).bold().foregroundStyle(.green)
                            BulletList(items: [
                                "Right to access – Request copies of your personal data",
                                "Right to rectification – Request corrections to your information",
                                "Right to erasure – Request deletion of your personal data",
                                "Right to restrict processing",
                                "Right to object to processing",
                                "Right to data portability"
                            ])
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Safety-Related Rights").font(.subheadline).bold().foregroundStyle(.orange)
                            BulletList(items: [
                                "Right to report harmful content or behavior",
                                "Right to appeal moderation decisions",
                                "Right to request information about safety measures affecting you",
                                "Right to request review of age verification decisions",
                                "Right to confidential reporting without retaliation"
                            ])
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "7", title: "Cookies & Tracking") {
                        Text("We use cookies and similar tracking technologies to track activity on our Service and store certain information. You can instruct your browser to refuse all cookies or to indicate when a cookie is being sent.")
                        BulletList(items: [
                            "Session cookies – to operate our Service",
                            "Preference cookies – to remember your preferences and settings",
                            "Security cookies – for security purposes and fraud prevention",
                            "Analytics cookies – to understand how users interact with our Service"
                        ])
                    }

                    LegalSection(number: "8", title: "Data Retention") {
                        Text("We retain your personal data for as long as necessary to provide the Service and comply with our legal obligations. Age verification data and safety compliance records are retained as required by the Online Safety Act 2023.")
                        BulletList(items: [
                            "Account data: retained while your account is active",
                            "Transaction records: retained for 7 years for legal compliance",
                            "Safety and moderation logs: retained as required by law",
                            "Age verification records: retained per regulatory requirements"
                        ])
                    }

                    LegalSection(number: "9", title: "Children's Privacy") {
                        Text("Our Service is not directed to individuals under the age of 18. We do not knowingly collect personal data from anyone under 18. In compliance with the Online Safety Act 2023, we implement robust age verification measures.")
                        Text("If you are a parent or guardian and you believe your child has provided us with personal information, please contact us immediately at support@sharequest.co.uk.")
                    }

                    LegalSection(number: "10", title: "Changes to This Policy") {
                        Text("We may update this Privacy Policy periodically. We will notify you of any changes by posting the new Privacy Policy on this page and updating the \"Last updated\" date.")
                        Text("You are advised to review this Privacy Policy periodically for any changes. Changes to this Privacy Policy are effective when they are posted on this page.")
                    }

                    LegalSection(number: "11", title: "Contact Us") {
                        Text("If you have questions about this Privacy Policy or wish to exercise your data rights, please contact us:")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ShareQuest Trading App")
                            Text("Email: support@sharequest.co.uk")
                                .foregroundStyle(.blue)
                            Text("Website: sharequest.co.uk")
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
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
