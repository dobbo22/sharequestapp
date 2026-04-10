import SwiftUI

struct FootballAdminView: View {
    @ObservedObject var bootstrapViewModel: FootballBootstrapViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Sync Controls") {
                    Button {
                        Task {
                            await bootstrapViewModel.triggerSync()
                        }
                    } label: {
                        if bootstrapViewModel.isTriggeringSync {
                            ProgressView("Starting \(bootstrapViewModel.syncSource) sync")
                        } else {
                            Text("Run \(bootstrapViewModel.syncSeason) \(bootstrapViewModel.syncSource.capitalized) Sync")
                        }
                    }

                    if let syncTriggerMessage = bootstrapViewModel.syncTriggerMessage {
                        Text(syncTriggerMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Latest Sync") {
                    if bootstrapViewModel.isLoadingSyncStatus && bootstrapViewModel.syncStatus == nil {
                        ProgressView("Loading sync status")
                    } else if let syncStatus = bootstrapViewModel.syncStatus {
                        if let latest = syncStatus.latest {
                            FootballAdminStatRow(title: "Status", value: latest.status.capitalized)
                            FootballAdminStatRow(title: "Source", value: latest.source)
                            FootballAdminStatRow(title: "Job", value: latest.jobType)
                            FootballAdminStatRow(title: "Season", value: bootstrapViewModel.syncSeason)
                            if let duration = latest.durationSeconds {
                                FootballAdminStatRow(title: "Duration", value: "\(duration)s")
                            }
                        }
                        FootballAdminStatRow(title: "Completed", value: syncStatus.aggregates.completedRuns)
                        FootballAdminStatRow(title: "Failed", value: syncStatus.aggregates.failedRuns)
                        FootballAdminStatRow(title: "Running", value: syncStatus.aggregates.runningRuns)
                    } else if let error = bootstrapViewModel.syncStatusErrorMessage {
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Database Status") {
                    if let stats = bootstrapViewModel.bootstrap?.stats {
                        FootballAdminStatRow(title: "Leagues", value: stats.leaguesCount)
                        FootballAdminStatRow(title: "Clubs", value: stats.clubsCount)
                        FootballAdminStatRow(title: "Players", value: stats.playersCount)
                        FootballAdminStatRow(title: "Profiles", value: stats.profilesCount)
                        FootballAdminStatRow(title: "User Cards", value: stats.userCardsCount)
                    } else {
                        Text("Bootstrap data not loaded")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Admin")
            .refreshable {
                await bootstrapViewModel.refreshAll()
            }
        }
    }
}

private struct FootballAdminStatRow: View {
    let title: String
    let value: String

    init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    init(title: String, value: Int) {
        self.title = title
        self.value = String(value)
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
