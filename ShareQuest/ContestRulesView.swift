import SwiftUI

struct ContestRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Official Competition Rules")
                            .font(.largeTitle).bold()
                        Text("Last updated: 1 January 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("By entering any competition within the ShareQuest app you confirm that you have read and accept these rules.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Apple disclaimer notice — prominent at top per guideline 5.3.2
                    LegalNoticeBox(
                        title: "Apple is not a Sponsor",
                        message: "These competitions are in no way sponsored, endorsed, administered by, or associated with Apple Inc. Any questions or complaints should be directed to Aiert Ltd at admin@sharequest.co.uk, not to Apple.",
                        color: .blue
                    )

                    LegalSection(number: "1", title: "Sponsor") {
                        Text("All competitions within the ShareQuest app (\"App\") are organised and sponsored by Aiert Ltd (\"Sponsor\"), the owner and operator of the ShareQuest app.")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aiert Ltd")
                            Text("Email: admin@sharequest.co.uk")
                                .foregroundStyle(.blue)
                        }
                        .font(.subheadline)
                    }

                    LegalSection(number: "2", title: "Types of Competition") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("2a. Annual ShareQuest").font(.subheadline).bold()
                            Text("A year-long competition open to all eligible subscribers, running 1 January – 31 December each year. Entry requires an Annual ShareQuest subscription (£50/year).")
                        }
                        .padding()
                        .background(Color(red: 0.95, green: 0.65, blue: 0.15).opacity(0.1))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("2b. User-Created Leagues").font(.subheadline).bold()
                            Text("Monthly or annual competitions created by individual users. Leagues can be public (open to anyone) or private (join by code only). The entry fee is set at the time of creation and displayed to participants before joining, starting from £5. Aiert Ltd provides the platform; the league creator is responsible for inviting participants and managing their league.")
                        }
                        .padding()
                        .background(Theme.primaryBlue.opacity(0.1))
                        .cornerRadius(10)
                    }

                    LegalSection(number: "3", title: "Eligibility") {
                        Text("Open to residents of the United Kingdom aged 18 or over. Employees of Aiert Ltd and their immediate family members are not eligible. By entering, participants confirm they have read and accept these rules.")
                    }

                    LegalSection(number: "4", title: "How to Enter") {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Annual ShareQuest").font(.subheadline).bold()
                                Text("Purchase an Annual ShareQuest subscription (£50/year) through the App. Each subscription constitutes one entry. No purchase is necessary to participate — free entry requests may be submitted in writing to admin@sharequest.co.uk.")
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("User-Created Leagues").font(.subheadline).bold()
                                Text("Pay the entry fee set by the league creator, starting from £5. Entry fees and terms vary by league and are displayed before joining.")
                            }
                        }
                    }

                    LegalSection(number: "5", title: "Starting Balance") {
                        Text("All participants begin each competition with a simulated cash balance of £100,000. No real money is invested. Returns are calculated using prices sourced from ShareQuest's market data providers.")
                    }

                    LegalSection(number: "6", title: "Prize Pool") {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Annual ShareQuest").font(.subheadline).bold()
                                Text("50% of each entry fee collected during the competition period is contributed to the prize pool, distributed as follows:")
                                BulletList(items: [
                                    "1st place — 60% of the prize pool",
                                    "2nd place — 25% of the prize pool",
                                    "3rd place — 15% of the prize pool"
                                ])
                            }
                            .padding()
                            .background(Color(red: 0.95, green: 0.65, blue: 0.15).opacity(0.1))
                            .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("User-Created Leagues").font(.subheadline).bold()
                                Text("Prize distribution is determined by the league creator at the time of creation and is displayed within the league details.")
                            }
                            .padding()
                            .background(Theme.primaryBlue.opacity(0.1))
                            .cornerRadius(10)

                            Text("Prizes are paid in GBP by bank transfer within 30 days of the competition ending. Winners must provide valid UK bank details to claim their prize.")
                        }
                    }

                    LegalSection(number: "7", title: "How to Win") {
                        Text("The participant whose simulated portfolio achieves the highest total percentage return over the competition period wins. Return is calculated from the standardised £100,000 starting balance using prices sourced from ShareQuest's market data providers. In the event of a tie, the participant who achieved the return in fewer trades wins.")
                    }

                    LegalSection(number: "8", title: "Notification of Winners") {
                        Text("Winners will be notified by email within 14 days of the competition ending. If a winner cannot be contacted or does not claim their prize within 28 days, Aiert Ltd reserves the right to award the prize to the next eligible participant.")
                    }

                    LegalSection(number: "9", title: "Disqualification") {
                        Text("Aiert Ltd reserves the right to disqualify any participant reasonably believed to have acted fraudulently, dishonestly, or in breach of these rules, including any attempt to manipulate portfolio values artificially.")
                    }

                    LegalSection(number: "10", title: "Liability") {
                        Text("Aiert Ltd accepts no responsibility for any loss or damage arising from participation in competitions within the App. Simulated trading results do not reflect real investment outcomes. Past performance is not indicative of future results.")
                    }

                    LegalSection(number: "11", title: "Data & Privacy") {
                        Text("Participant data is processed in accordance with Aiert Ltd's Privacy Policy, available within the App.")
                    }

                    LegalSection(number: "12", title: "Governing Law") {
                        Text("These rules are governed by the laws of England and Wales. Any disputes shall be subject to the exclusive jurisdiction of the courts of England and Wales.")
                    }

                    LegalSection(number: "13", title: "Contact") {
                        Text("For any questions relating to competitions, contact Aiert Ltd at:")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aiert Ltd")
                            Text("Email: admin@sharequest.co.uk")
                                .foregroundStyle(.blue)
                        }
                        .font(.subheadline)
                    }

                    LegalSection(number: "14", title: "Apple Disclaimer") {
                        Text("These competitions are in no way sponsored, endorsed, administered by, or associated with Apple Inc. Any questions or complaints relating to the competitions should be directed to Aiert Ltd at admin@sharequest.co.uk, not to Apple.")
                    }

                    Text("© 2026 Aiert Ltd. All rights reserved. ShareQuest is a trading name of Aiert Ltd.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Competition Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
