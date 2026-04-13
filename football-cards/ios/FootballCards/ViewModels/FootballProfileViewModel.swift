import Foundation

@MainActor
final class FootballProfileViewModel: ObservableObject {
    @Published var isLoadingProfile = false
    @Published var isLoadingClubs = false
    @Published var isSaving = false
    @Published var profileData: FootballProfileData?
    @Published var clubs: [FootballClub] = []
    @Published var pendingRevealAllocation: FootballStarterPackAllocation?
    @Published var errorMessage: String?
    @Published var clubsErrorMessage: String?

    var profile: FootballProfile? {
        profileData?.profile
    }

    func loadProfile(syncingTo collectionViewModel: FootballCollectionViewModel? = nil) async {
        isLoadingProfile = true
        errorMessage = nil
        defer { isLoadingProfile = false }

        do {
            profileData = try await FootballAPIClient.shared.fetchProfile()
            updatePendingRevealState()
            // Sync squad assignments from server onto this device
            if let serverAssignments = profileData?.squadAssignments,
               let vm = collectionViewModel {
                vm.syncSquadAssignmentsFromServer(serverAssignments, squadConfig: profileData?.squadConfig)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadClubs(search: String? = nil) async {
        isLoadingClubs = true
        clubsErrorMessage = nil
        defer { isLoadingClubs = false }

        do {
            clubs = try await FootballAPIClient.shared.fetchClubs(search: search, limit: 100)
        } catch {
            clubsErrorMessage = error.localizedDescription
        }
    }

    func completeOnboarding(displayName: String?, teamName: String?, supportedClubId: String) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            profileData = try await FootballAPIClient.shared.completeOnboarding(
                displayName: displayName,
                teamName: teamName,
                supportedClubId: supportedClubId
            )
            updatePendingRevealState()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func resetOnboarding() async -> Bool {
        isSaving = true
        errorMessage = nil
        pendingRevealAllocation = nil
        defer { isSaving = false }

        do {
            try await FootballAPIClient.shared.resetOnboarding()
            profileData = try await FootballAPIClient.shared.fetchProfile()
            await loadClubs()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshAll() async {
        await loadProfile()
        if clubs.isEmpty {
            await loadClubs()
        }
    }

    func markRevealPresented() {
        pendingRevealAllocation?.markRevealed()
        pendingRevealAllocation = nil
    }

    private func updatePendingRevealState() {
        if let allocation = profileData?.allocation, allocation.needsReveal {
            pendingRevealAllocation = allocation
        } else {
            pendingRevealAllocation = nil
        }
    }
}
