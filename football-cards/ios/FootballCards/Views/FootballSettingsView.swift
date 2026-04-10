import SwiftUI

struct FootballSettingsView: View {
    @EnvironmentObject private var session: FootballSessionViewModel
    private let client = FootballAPIClient.shared

    @AppStorage("football_api_base_url") private var footballAPIBaseURL = FootballAPIClient.shared.defaultFootballBaseURL
    @AppStorage("football_admin_token") private var adminToken = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Environment") {
                    FootballEnvironmentBadge(label: client.environmentLabel, isLocal: client.isUsingLocalEnvironment)
                    Text(client.isUsingLocalEnvironment ? "Simulator requests will use your local Vercel dev server." : "Requests will use the deployed ShareQuest API.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Environment") {
                    TextField("Football API base URL", text: $footballAPIBaseURL)
                        .autocorrectionDisabled()
                    Button("Use Production URLs") {
                        footballAPIBaseURL = "https://sharequestapp.vercel.app/api/football"
                    }
                    Button("Use Local URLs") {
                        footballAPIBaseURL = client.defaultFootballBaseURL
                    }
                    Button("Reset to Build Defaults") {
                        footballAPIBaseURL = client.defaultFootballBaseURL
                    }
                }

                Section("Admin Override") {
                    TextField("Admin token override", text: $adminToken)
                        .autocorrectionDisabled()
                    Text("If empty, admin football endpoints use the signed-in user's JWT.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Session") {
                    Button("Sign Out", role: .destructive) {
                        session.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
