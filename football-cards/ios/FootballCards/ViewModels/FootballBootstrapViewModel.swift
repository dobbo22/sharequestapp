import Foundation

@MainActor
final class FootballBootstrapViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isLoadingSyncStatus = false
    @Published var isTriggeringSync = false
    @Published var bootstrap: FootballBootstrapData?
    @Published var syncStatus: FootballSyncStatusData?
    @Published var errorMessage: String?
    @Published var syncStatusErrorMessage: String?
    @Published var syncTriggerMessage: String?

    let syncSource = FootballAPIClient.defaultSyncSource
    let syncSeason = FootballAPIClient.defaultSyncSeason

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            bootstrap = try await FootballAPIClient.shared.fetchBootstrap()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadSyncStatus() async {
        isLoadingSyncStatus = true
        syncStatusErrorMessage = nil

        do {
            syncStatus = try await FootballAPIClient.shared.fetchSyncStatus(limit: 5, source: syncSource)
        } catch {
            syncStatus = nil
            syncStatusErrorMessage = error.localizedDescription
        }

        isLoadingSyncStatus = false
    }

    func triggerSync() async {
        isTriggeringSync = true
        syncTriggerMessage = nil

        do {
            try await FootballAPIClient.shared.triggerSync(source: syncSource, season: syncSeason)
            syncTriggerMessage = "\(syncSource.capitalized) \(syncSeason) sync started"
            await loadSyncStatus()
            await load()
        } catch {
            syncTriggerMessage = error.localizedDescription
        }

        isTriggeringSync = false
    }

    func refreshAll() async {
        await load()
        await loadSyncStatus()
    }
}