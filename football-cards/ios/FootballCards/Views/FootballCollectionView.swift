import SwiftUI

private extension Color {
    static let kcNavy = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let kcLime = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let kcCard = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let kcMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
}

struct FootballCollectionView: View {
    private struct ClubAvailabilityEntry: Identifiable {
        let club: FootballClub
        let count: Int

        var id: String { club.id }
    }

    @StateObject private var viewModel = FootballCollectionViewModel()
    @State private var activeBuilderLeague: String?
    @State private var showBuildRules = false
    @State private var activeCollectionSelection: String?
    @State private var showOnlyAvailableClubsByLeague: [String: Bool] = [:]

    var body: some View {
        ZStack {
            Color.kcNavy.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.cards.isEmpty && viewModel.clubs.isEmpty {
                    ProgressView("Loading collection")
                        .tint(Color.kcLime)
                        .foregroundStyle(.white)
                } else if let error = viewModel.errorMessage, viewModel.cards.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.full")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.kcMuted)
                        Text("Unable to Load Collection")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Color.kcMuted)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            collectionHeader
                            buildRulesToggleSection
                            collectionSelectionTiles

                            if let selectedKey = selectedCollectionKey {
                                selectedCollectionSection(for: selectedKey)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                    }
                }
            }
            .task {
                if viewModel.cards.isEmpty && !viewModel.isLoading {
                    await viewModel.loadCollection()
                }
            }
            .refreshable {
                await viewModel.loadCollection()
            }
            .sheet(
                isPresented: Binding(
                    get: { activeBuilderLeague != nil },
                    set: { isPresented in
                        if !isPresented {
                            activeBuilderLeague = nil
                        }
                    }
                )
            ) {
                if let leagueName = activeBuilderLeague {
                    FootballFormationBuilderSheet(
                        leagueName: leagueName,
                        viewModel: viewModel
                    )
                }
            }
        }
    }

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collection")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var collectionSelectionKeys: [String] {
        var keys: [String] = []
        if viewModel.onboardingBonusClubName != nil {
            keys.append(viewModel.bonusTeamKey)
        }
        keys.append(contentsOf: viewModel.leagueOrder)
        return keys
    }

    private var selectedCollectionKey: String? {
        if let activeCollectionSelection, collectionSelectionKeys.contains(activeCollectionSelection) {
            return activeCollectionSelection
        }
        return collectionSelectionKeys.first
    }

    private var collectionSelectionTiles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Selection")
                .font(.title3.bold())
                .foregroundStyle(.white)

            GeometryReader { geometry in
                let metrics = collectionTileMetrics(for: geometry.size.width)

                HStack(spacing: metrics.spacing) {
                    ForEach(collectionSelectionKeys, id: \.self) { key in
                        collectionSelectionTile(for: key, width: metrics.itemWidth, height: metrics.itemHeight)
                    }
                }
                .frame(width: geometry.size.width, height: 84, alignment: .center)
            }
            .frame(height: 84)
        }
    }

    private func collectionSelectionTile(for key: String, width: CGFloat, height: CGFloat) -> some View {
        let isActive = selectedCollectionKey == key
        let selection = viewModel.lockedSelection(for: key)
        let buildableCount = viewModel.buildableCardCount(for: key)
        let badgeURL = selection?.clubLogoUrl ?? draftClubBadgeURL(for: key)
        let hasReadyCards = buildableCount > 0

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                activeCollectionSelection = key
            }
        } label: {
            VStack(spacing: 8) {
                selectionTileBadge(url: badgeURL)

                if hasReadyCards {
                    Text("\(buildableCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.kcNavy)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.kcLime)
                        .clipShape(Capsule())
                } else if selection != nil {
                    Image(systemName: "checkmark.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.kcMuted)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.kcNavy.opacity(0.92) : Color.kcCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isActive ? Color.kcLime.opacity(0.75) : Color.white.opacity(0.08), lineWidth: 1.2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func collectionTileMetrics(for availableWidth: CGFloat) -> (itemWidth: CGFloat, itemHeight: CGFloat, spacing: CGFloat) {
        let count = max(collectionSelectionKeys.count, 1)
        let spacing = max(4, min(10, availableWidth * 0.012))
        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
        let rawWidth = (availableWidth - totalSpacing) / CGFloat(count)
        let itemWidth = max(44, rawWidth)
        let itemHeight = max(62, min(76, itemWidth * 1.24))
        return (itemWidth, itemHeight, spacing)
    }

    private func selectedCollectionSection(for key: String) -> some View {
        Group {
            if key == viewModel.bonusTeamKey, let bonusClubName = viewModel.onboardingBonusClubName {
                bonusTeamTile(clubName: bonusClubName)
            } else {
                leagueSelectionCard(for: key)
            }
        }
    }

    private func compactCollectionLabel(for key: String) -> String {
        switch key {
        case "Premier League":
            return "Premiership"
        case "League One":
            return "League 1"
        case "League Two":
            return "League 2"
        default:
            return key
        }
    }

    private func draftOrPlaceholderClubName(for key: String) -> String {
        if key == viewModel.bonusTeamKey {
            return viewModel.onboardingBonusClubName ?? "Bonus Club"
        }

        return viewModel.selectedDraftClub(for: key)?.name ?? "Open"
    }

    private func draftClubBadgeURL(for key: String) -> String? {
        if key == viewModel.bonusTeamKey {
            return viewModel.onboardingBonusLogoURL
        }

        return viewModel.selectedDraftClub(for: key)?.logoUrl
    }

    private func showOnlyAvailableClubsBinding(for leagueName: String) -> Binding<Bool> {
        Binding(
            get: { showOnlyAvailableClubsByLeague[leagueName] ?? false },
            set: { showOnlyAvailableClubsByLeague[leagueName] = $0 }
        )
    }

    private func clubAvailabilityEntries(for leagueName: String) -> [ClubAvailabilityEntry] {
        viewModel.clubs(for: leagueName)
            .map { club in
                ClubAvailabilityEntry(
                    club: club,
                    count: viewModel.draftBuildableCardCount(for: leagueName, club: club)
                )
            }
    }

    private func alphabeticalClubEntries(for leagueName: String) -> [ClubAvailabilityEntry] {
        clubAvailabilityEntries(for: leagueName)
            .sorted { lhs, rhs in
                lhs.club.name.localizedCaseInsensitiveCompare(rhs.club.name) == .orderedAscending
            }
    }

    private func availableClubEntries(for leagueName: String) -> [ClubAvailabilityEntry] {
        clubAvailabilityEntries(for: leagueName)
            .filter { $0.count > 0 }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }

                return lhs.club.name.localizedCaseInsensitiveCompare(rhs.club.name) == .orderedAscending
            }
    }

    private func selectionTileBadge(url: String?) -> some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        Image(systemName: "shield.fill")
                            .foregroundStyle(Color.kcMuted)
                    }
                }
            } else {
                Image(systemName: "shield.fill")
                    .foregroundStyle(Color.kcMuted)
            }
        }
        .frame(width: 26, height: 26)
    }

    private func statusBadge(isLocked: Bool) -> some View {
        Group {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
            } else {
                Image(systemName: "lock.open")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.kcLime)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.kcLime.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
    }

    private func scoreBadge(for leagueName: String) -> some View {
        let score = viewModel.teamScore(for: leagueName)

        return Text("Score \(String(format: "%.1f", score))")
            .font(.caption.weight(.bold))
            .foregroundStyle(score > 0 ? Color.kcNavy : Color.kcMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(score > 0 ? Color.kcLime : Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private var completedCollectionKeys: [String] {
        collectionSelectionKeys.filter { key in
            viewModel.lockedSelection(for: key) != nil && viewModel.isTeamComplete(for: key)
        }
    }

    private func completedCollectionSection(currentLeagueName: String) -> some View {
        let completedKeys = completedCollectionKeys

        return VStack(alignment: .leading, spacing: 10) {
            Text("Completed Collection")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.kcMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(completedKeys, id: \.self) { key in
                        let isActive = currentLeagueName == key
                        let badgeURL = viewModel.lockedSelection(for: key)?.clubLogoUrl

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                activeCollectionSelection = key
                            }
                        } label: {
                            VStack(spacing: 6) {
                                selectionTileBadge(url: badgeURL)
                                    .frame(width: 34, height: 34)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.kcLime)
                            }
                            .frame(width: 62, height: 68)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isActive ? Color.kcNavy.opacity(0.92) : Color.kcNavy.opacity(0.50))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(isActive ? Color.kcLime.opacity(0.75) : Color.white.opacity(0.08), lineWidth: 1.2)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Completed teams can still be improved when stronger cards become available.")
                .font(.caption)
                .foregroundStyle(Color.kcMuted)
        }
        .padding(14)
        .background(Color.kcNavy.opacity(0.40))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var buildRulesToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showBuildRules.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Build Rules")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(showBuildRules ? "Hide rules" : "Tap to view rules")
                            .font(.caption)
                            .foregroundStyle(Color.kcMuted)
                    }

                    Spacer()

                    Image(systemName: showBuildRules ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.kcLime)
                }
                .padding(16)
                .background(Color.kcCard)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            if showBuildRules {
                planningOverview
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func bonusTeamTile(clubName: String) -> some View {
        let bonusKey = viewModel.bonusTeamKey
        let lockedSelection = viewModel.lockedSelection(for: bonusKey)
        let hasCompletedTeams = !completedCollectionKeys.isEmpty

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bonus Club")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                scoreBadge(for: bonusKey)
                statusBadge(isLocked: lockedSelection != nil)
            }

            if let lockedSelection {
                HStack(spacing: 12) {
                    leagueClubBadge(url: lockedSelection.clubLogoUrl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(clubName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Formation: \(lockedSelection.formation)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.kcMuted)
                    }

                    Spacer()

                    Button {
                        activeBuilderLeague = bonusKey
                    } label: {
                        Text("Build")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.kcNavy)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.kcLime)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color.kcNavy.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                formationProgressDropdown(for: bonusKey)

                if hasCompletedTeams {
                    completedCollectionSection(currentLeagueName: bonusKey)
                }
            } else {
                HStack(spacing: 14) {
                    if let logoUrl = viewModel.onboardingBonusLogoURL, let url = URL(string: logoUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFit()
                            } else {
                                bonusBadgePlaceholder
                            }
                        }
                        .frame(width: 46, height: 46)
                    } else {
                        bonusBadgePlaceholder
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(clubName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(viewModel.onboardingBonusLeagueName ?? "Onboarding selection")
                            .font(.caption)
                            .foregroundStyle(Color.kcMuted)
                    }

                    Spacer()

                    Text("Bonus scoring")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.kcMuted)
                        .multilineTextAlignment(.trailing)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Formation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.formationOptions, id: \.self) { formation in
                                Button {
                                    viewModel.setFormation(formation, for: bonusKey)
                                } label: {
                                    Text(formation)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(viewModel.draftFormationByLeague[bonusKey] == formation ? Color.kcNavy : .white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(viewModel.draftFormationByLeague[bonusKey] == formation ? Color.kcLime : Color.kcNavy.opacity(0.6))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    viewModel.lockBonusSelection()
                } label: {
                    Text("Lock Bonus Club")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.canLockBonusSelection() ? Color.kcLime : Color.kcMuted.opacity(0.25))
                        .foregroundStyle(viewModel.canLockBonusSelection() ? Color.kcNavy : Color.kcMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canLockBonusSelection())
            }
        }
        .padding(18)
        .background(Color.kcCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bonusBadgePlaceholder: some View {
        Image(systemName: "shield.fill")
            .font(.system(size: 22))
            .foregroundStyle(Color.kcMuted)
            .frame(width: 46, height: 46)
            .background(Color.kcNavy)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var planningOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Build Rules")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                buildRuleRow("Choose one club from each of the four leagues")
                buildRuleRow("Your onboarding club is shown separately as a bonus team")
                buildRuleRow("You cannot pick the same club twice")
                buildRuleRow("Lock a formation before locking a club")
                buildRuleRow("Formation fit uses Sportmonks-style positions, so defenders stay in defence and midfield stays midfield")
                buildRuleRow("Only 5-midfielder shapes allow wingers in midfield, and attack slots accept attackers plus wingers")
                buildRuleRow("Daily card drops and trading come next")
            }
        }
        .padding(18)
        .background(Color.kcCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func buildRuleRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.kcLime)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func leagueSelectionCard(for leagueName: String) -> some View {
        let lockedSelection = viewModel.lockedSelection(for: leagueName)
        let selectedDraftClub = viewModel.selectedDraftClub(for: leagueName)
        let showOnlyAvailableClubs = showOnlyAvailableClubsByLeague[leagueName] ?? false
        let clubEntries = alphabeticalClubEntries(for: leagueName)
        let filteredClubEntries = showOnlyAvailableClubs ? availableClubEntries(for: leagueName) : clubEntries
        let hasCompletedTeams = !completedCollectionKeys.isEmpty

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(leagueName)
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                scoreBadge(for: leagueName)
                statusBadge(isLocked: lockedSelection != nil)
            }

            if let lockedSelection {
                HStack(spacing: 12) {
                    leagueClubBadge(url: lockedSelection.clubLogoUrl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lockedSelection.clubName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Formation: \(lockedSelection.formation)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.kcMuted)
                    }

                    Spacer()

                    Button {
                        activeBuilderLeague = leagueName
                    } label: {
                        Text("Build")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.kcNavy)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.kcLime)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color.kcNavy.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                formationProgressDropdown(for: leagueName)

                if hasCompletedTeams {
                    completedCollectionSection(currentLeagueName: leagueName)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Choose Club")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        HStack(spacing: 8) {
                            Text("Show teams with my cards")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)

                            Toggle("", isOn: showOnlyAvailableClubsBinding(for: leagueName))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(Color.kcLime)
                                .scaleEffect(0.82)
                        }
                    }

                    if clubEntries.isEmpty {
                        Text("No clubs available for this league yet.")
                            .font(.subheadline)
                            .foregroundStyle(Color.kcMuted)
                    } else if filteredClubEntries.isEmpty {
                        Text("No clubs with cards available yet.")
                            .font(.subheadline)
                            .foregroundStyle(Color.kcMuted)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(filteredClubEntries) { entry in
                                    let club = entry.club
                                    let buildableCount = entry.count

                                    Button {
                                        viewModel.setDraftClub(club.id, for: leagueName)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack(spacing: 10) {
                                                leagueClubBadge(url: club.logoUrl)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(club.name)
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundStyle(.white)
                                                        .lineLimit(2)
                                                }

                                                Spacer(minLength: 8)

                                                Text("\(buildableCount)")
                                                    .font(.headline.weight(.black))
                                                    .foregroundStyle(.white)
                                            }

                                            HStack {
                                                Text(viewModel.draftClubIdByLeague[leagueName] == club.id ? "Selected" : "")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(viewModel.draftClubIdByLeague[leagueName] == club.id ? Color.kcLime : Color.kcMuted)

                                                Spacer()
                                            }
                                        }
                                        .padding(14)
                                        .frame(width: 220, alignment: .leading)
                                        .background(Color.kcNavy.opacity(0.55))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(viewModel.draftClubIdByLeague[leagueName] == club.id ? Color.kcLime.opacity(0.7) : Color.white.opacity(0.06), lineWidth: 1.5)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if selectedDraftClub != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Formation")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.formationOptions, id: \.self) { formation in
                                    Button {
                                        viewModel.setFormation(formation, for: leagueName)
                                    } label: {
                                        Text(formation)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(viewModel.draftFormationByLeague[leagueName] == formation ? Color.kcNavy : .white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(viewModel.draftFormationByLeague[leagueName] == formation ? Color.kcLime : Color.kcNavy.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if selectedDraftClub != nil && viewModel.activeFormation(for: leagueName) != nil {
                    formationProgressDropdown(for: leagueName)
                }

                Button {
                    viewModel.lockSelection(for: leagueName)
                } label: {
                    Text(unlockedLeagueButtonTitle(for: leagueName))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.canLockSelection(for: leagueName) ? Color.kcLime : Color.kcMuted.opacity(0.25))
                        .foregroundStyle(viewModel.canLockSelection(for: leagueName) ? Color.kcNavy : Color.kcMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canLockSelection(for: leagueName))

                if let selectedDraftClub {
                    draftClubCardPreviewSection(for: leagueName, club: selectedDraftClub)
                }

                Text("Once a club is locked here it cannot be changed. Squad-completion gating is the next step to wire in.")
                    .font(.caption)
                    .foregroundStyle(Color.kcMuted)
            }
        }
        .padding(18)
        .background(Color.kcCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func leagueClubBadge(url: String?) -> some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        Image(systemName: "shield.fill")
                            .foregroundStyle(Color.kcMuted)
                    }
                }
            } else {
                Image(systemName: "shield.fill")
                    .foregroundStyle(Color.kcMuted)
            }
        }
        .frame(width: 42, height: 42)
    }

    private func unlockedLeagueButtonTitle(for leagueName: String) -> String {
        let hasSelectedClub = viewModel.selectedDraftClub(for: leagueName) != nil
        let hasSelectedFormation = !(viewModel.draftFormationByLeague[leagueName] ?? "").isEmpty

        if !hasSelectedClub {
            return "Select a team first"
        }
        if !hasSelectedFormation {
            return "Now select a formation"
        }
        return "Lock \(leagueName) Team"
    }

    private func draftClubCardPreviewSection(for leagueName: String, club: FootballClub) -> some View {
        let previewCards = viewModel.draftEligibleCards(for: leagueName, club: club)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Available Cards")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(previewCards.isEmpty ? "No cards ready" : "\(previewCards.count) cards ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(previewCards.isEmpty ? Color.kcMuted : Color.kcLime)
            }

            if previewCards.isEmpty {
                Text("No owned cards currently fit this formation for \(club.name).")
                    .font(.caption)
                    .foregroundStyle(Color.kcMuted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.kcNavy.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(previewCards) { card in
                            FootballPlayerCardView(card: card)
                                .frame(width: 190)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(14)
        .background(Color.kcNavy.opacity(0.40))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formationProgressDropdown(for leagueName: String) -> some View {
        let slots = viewModel.formationSlots(for: leagueName)
        let filledCount = viewModel.assignedCount(for: leagueName)
        let buildableCount = viewModel.buildableCardCount(for: leagueName)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Squad Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.kcMuted)
                    Text("\(filledCount)/\(slots.count) filled")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if slots.isEmpty {
                    Text("Choose formation first")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.kcMuted)
                } else if buildableCount > 0 {
                    Text("\(buildableCount) cards ready")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.kcLime)
                } else {
                    Text("No cards ready")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.kcMuted)
                }
            }
            .padding(14)
            .background(Color.kcNavy.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct FootballFormationBuilderSheet: View {
    let leagueName: String
    @ObservedObject var viewModel: FootballCollectionViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var activeSlot: FootballFormationSlot?

    private var rows: [[FootballFormationSlot]] {
        viewModel.formationRows(for: leagueName)
    }

    private var slots: [FootballFormationSlot] {
        rows.flatMap { $0 }
    }

    private var formationName: String {
        viewModel.activeFormation(for: leagueName) ?? "Formation"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kcNavy.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(leagueName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.kcLime)
                            Text(formationName)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Tap any slot to choose from eligible cards in your collection. You can replace any slot later as better cards arrive.")
                                .font(.subheadline)
                                .foregroundStyle(Color.kcMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if slots.isEmpty {
                            Text("No selectable positions are available yet because you do not own matching cards for this club.")
                                .font(.subheadline)
                                .foregroundStyle(Color.kcMuted)
                                .padding(16)
                                .background(Color.kcCard)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        formationPitch
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Team Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $activeSlot) { slot in
                FootballSlotSelectionSheet(
                    leagueName: leagueName,
                    slot: slot,
                    viewModel: viewModel
                )
            }
        }
    }

    private var formationPitch: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.10, green: 0.30, blue: 0.18), Color(red: 0.05, green: 0.18, blue: 0.11)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(index.isMultiple(of: 2) ? Color.white.opacity(0.02) : Color.clear)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                pitchMarkings(in: geometry.size)

                VStack(spacing: 18) {
                    Spacer(minLength: 8)

                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                        HStack(spacing: 10) {
                            ForEach(Array(row.enumerated()), id: \.element.id) { columnIndex, slot in
                                Button {
                                    activeSlot = slot
                                } label: {
                                    pitchSlotCard(slot: slot)
                                }
                                .buttonStyle(.plain)
                                .offset(pitchSlotOffset(for: slot, rowIndex: rowIndex, columnIndex: columnIndex, rowCount: row.count))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, rowHorizontalInset(for: row, rowIndex: rowIndex))

                        if rowIndex != rows.count - 1 {
                            Spacer(minLength: rowSpacerHeight(for: rowIndex))
                        }
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 620)
    }

    @ViewBuilder
    private func pitchMarkings(in size: CGSize) -> some View {
        let stroke = Color.white.opacity(0.18)

        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(stroke, lineWidth: 1.5)

            Rectangle()
                .fill(stroke)
                .frame(width: 1.5, height: size.height - 36)

            Circle()
                .stroke(stroke, lineWidth: 1.5)
                .frame(width: min(size.width * 0.24, 96), height: min(size.width * 0.24, 96))

            Circle()
                .fill(stroke)
                .frame(width: 5, height: 5)

            VStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(stroke, lineWidth: 1.5)
                    .frame(width: size.width * 0.62, height: size.height * 0.14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(stroke.opacity(0.9), lineWidth: 1.2)
                            .frame(width: size.width * 0.30, height: size.height * 0.06)
                            .offset(y: 6)
                    )

                Spacer()

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(stroke, lineWidth: 1.5)
                    .frame(width: size.width * 0.62, height: size.height * 0.14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(stroke.opacity(0.9), lineWidth: 1.2)
                            .frame(width: size.width * 0.30, height: size.height * 0.06)
                            .offset(y: -6)
                    )
            }
            .padding(.vertical, 24)
        }
    }

    private func rowSpacerHeight(for rowIndex: Int) -> CGFloat {
        switch formationName {
        case "4-2-3-1":
            switch rowIndex {
            case 0:
                return 20
            case 1:
                return 24
            case 2:
                return 18
            default:
                return 22
            }
        case "3-5-2":
            switch rowIndex {
            case 0:
                return 20
            case 1:
                return 26
            default:
                return 24
            }
        case "3-4-3":
            switch rowIndex {
            case 0:
                return 20
            case 1:
                return 24
            default:
                return 28
            }
        case "4-3-3":
            switch rowIndex {
            case 0:
                return 18
            case 1:
                return 22
            default:
                return 26
            }
        default:
            switch rowIndex {
            case 0:
                return 18
            case rows.count - 2:
                return 24
            default:
                return 20
            }
        }
    }

    private func rowHorizontalInset(for row: [FootballFormationSlot], rowIndex: Int) -> CGFloat {
        let count = row.count

        switch formationName {
        case "3-5-2":
            switch count {
            case 1:
                return 90
            case 2:
                return 54
            case 3:
                return 44
            case 5:
                return 6
            default:
                return 20
            }
        case "4-2-3-1":
            switch count {
            case 1:
                return rowIndex == rows.count - 1 ? 94 : 90
            case 2:
                return 56
            case 3:
                return 24
            case 4:
                return 12
            default:
                return 20
            }
        case "3-4-3":
            switch count {
            case 1:
                return 90
            case 3:
                return rowIndex == rows.count - 1 ? 18 : 44
            case 4:
                return 10
            default:
                return 20
            }
        case "4-3-3":
            switch count {
            case 1:
                return 90
            case 3:
                return rowIndex == rows.count - 1 ? 18 : 34
            case 4:
                return 12
            default:
                return 20
            }
        default:
            switch count {
            case 1:
                return 90
            case 2:
                return 52
            case 4:
                return 12
            default:
                return 20
            }
        }
    }

    private func pitchSlotOffset(for slot: FootballFormationSlot, rowIndex: Int, columnIndex: Int, rowCount: Int) -> CGSize {
        let name = slot.displayName.lowercased()
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0

        if name.contains("left wing") || name.contains("left midfield") {
            xOffset -= 10
        }
        if name.contains("right wing") || name.contains("right midfield") {
            xOffset += 10
        }
        if name.contains("left back") || name.contains("right back") {
            xOffset += name.contains("left") ? -8 : 8
            yOffset += 4
        }
        if name.contains("left centre back") || name.contains("right centre back") {
            xOffset += name.contains("left") ? -4 : 4
        }
        if name.contains("attacking midfield") {
            yOffset -= 8
            if name.contains("left") { xOffset -= 8 }
            if name.contains("right") { xOffset += 8 }
        }
        if name.contains("defensive midfield") {
            yOffset += 6
            if name.contains("left") { xOffset -= 6 }
            if name.contains("right") { xOffset += 6 }
        }
        if name.contains("centre forward") || name.contains("striker") {
            yOffset -= 6
            if rowCount == 2 {
                xOffset += columnIndex == 0 ? -10 : 10
            }
        }
        if name == "goalkeeper" {
            yOffset += 8
        }

        switch formationName {
        case "3-4-3":
            if name.contains("wing") {
                xOffset += name.contains("left") ? -12 : 12
                yOffset -= 4
            }
        case "4-3-3":
            if name.contains("wing") {
                xOffset += name.contains("left") ? -14 : 14
                yOffset -= 6
            }
        case "4-2-3-1":
            if name.contains("attacking midfield") {
                yOffset -= 10
            }
        case "3-5-2":
            if name.contains("left midfield") || name.contains("right midfield") {
                xOffset += name.contains("left") ? -12 : 12
                yOffset -= 2
            }
        default:
            break
        }

        return CGSize(width: xOffset, height: yOffset)
    }

    private func pitchSlotCard(slot: FootballFormationSlot) -> some View {
        let assignedCard = viewModel.assignedCard(for: leagueName, slot: slot)
        let eligibleCards = viewModel.eligibleCards(for: leagueName, slot: slot)
        let isSelectable = assignedCard != nil || !eligibleCards.isEmpty

        return VStack(spacing: 8) {
            if let assignedCard {
                builderPhoto(for: assignedCard)

                VStack(spacing: 2) {
                    Text(viewModel.shortDisplayName(for: assignedCard))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(slot.displayName)
                        .font(.caption2)
                        .foregroundStyle(Color.kcMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let rating = assignedCard.ratingOutOfTen {
                        Text(String(format: "%.1f", rating))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.kcLime)
                    }
                }
            } else {
                ghostPlayerBadge(isSelectable: isSelectable)

                Text(slot.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(isSelectable ? "Tap to select" : "No eligible card")
                    .font(.caption2)
                    .foregroundStyle(Color.kcMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Color.kcCard.opacity(isSelectable ? 0.92 : 0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(assignedCard == nil ? Color.white.opacity(0.06) : Color.kcLime.opacity(0.55), lineWidth: 1.2)
        )
        .opacity(isSelectable ? 1 : 0.7)
    }

    private func builderPhoto(for card: FootballOwnedCard) -> some View {
        Group {
            if let photoUrl = card.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        builderPhotoFallback
                    }
                }
            } else {
                builderPhotoFallback
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var builderPhotoFallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "person.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.white.opacity(0.45))
        }
    }

    private func ghostPlayerBadge(isSelectable: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(isSelectable ? 0.06 : 0.03))
                .frame(width: 52, height: 52)

            Image(systemName: "person.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white.opacity(isSelectable ? 0.28 : 0.16))

            if isSelectable {
                Circle()
                    .strokeBorder(Color.kcLime.opacity(0.6), lineWidth: 1.2)
                    .frame(width: 52, height: 52)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.kcLime)
                    .background(Circle().fill(Color.kcNavy))
                    .offset(x: 18, y: 18)
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 52, height: 52)
            }
        }
    }
}

private struct FootballSlotSelectionSheet: View {
    let leagueName: String
    let slot: FootballFormationSlot
    @ObservedObject var viewModel: FootballCollectionViewModel

    @Environment(\.dismiss) private var dismiss

    private var assignedCard: FootballOwnedCard? {
        viewModel.assignedCard(for: leagueName, slot: slot)
    }

    private var eligibleCards: [FootballOwnedCard] {
        viewModel.eligibleCards(for: leagueName, slot: slot)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kcNavy.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(slot.displayName)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text(slot.eligibilitySummary)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.kcLime)
                        }

                        if let assignedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current Selection")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.kcMuted)
                                Text(viewModel.shortDisplayName(for: assignedCard))
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Button("Clear Slot") {
                                    viewModel.clearAssignment(for: leagueName, slot: slot)
                                }
                                .buttonStyle(.plain)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.red)
                            }
                            .padding(14)
                            .background(Color.kcCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if eligibleCards.isEmpty {
                            Text("No eligible cards in your collection for this slot yet.")
                                .font(.subheadline)
                                .foregroundStyle(Color.kcMuted)
                                .padding(16)
                                .background(Color.kcCard)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            ForEach(eligibleCards) { card in
                                Button {
                                    viewModel.assignCard(card, to: leagueName, slot: slot)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(viewModel.shortDisplayName(for: card))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                            Text(viewModel.positionDisplayName(for: card))
                                                .font(.caption)
                                                .foregroundStyle(Color.kcMuted)
                                            Text(card.clubName ?? "Unknown club")
                                                .font(.caption2)
                                                .foregroundStyle(Color.kcMuted)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 4) {
                                            if let rating = card.ratingOutOfTen {
                                                Text(String(format: "%.1f", rating))
                                                    .font(.headline.weight(.black))
                                                    .foregroundStyle(Color.kcLime)
                                            }
                                            if let appearances = card.appearances {
                                                Text("\(appearances) apps")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.kcMuted)
                                            }
                                        }
                                    }
                                    .padding(14)
                                    .background(Color.kcCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Select Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FootballPlayerCardView: View {
    let card: FootballOwnedCard
    var detailContext: FootballCardActionContext? = nil
    var onDetailActionSelected: ((FootballCardActionKind) -> Void)? = nil
    var opensDetailOnBack: Bool = false
    var showsFlipHint: Bool = false
    @State private var showDetail = false
    @State private var flipHintActive = false

    var body: some View {
        Button { showDetail = true } label: {
            cardFront
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showDetail) {
            FootballCardDetailView(
                card: card,
                actionContext: detailContext,
                onActionSelected: onDetailActionSelected,
                startsOnBack: opensDetailOnBack
            )
        }
        .onAppear {
            guard showsFlipHint else { return }
            flipHintActive = true
        }
    }

    // MARK: - Card front
    private var cardFront: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardGradient)

            VStack(alignment: .leading, spacing: 0) {
                // TOP: photo (left) + club badge & rating (right)
                HStack(alignment: .top, spacing: 12) {
                    playerPhotoContent
                        .frame(width: 90, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        // Club badge — prominent
                        if let logoUrl = card.clubLogoUrl, let url = URL(string: logoUrl) {
                            AsyncImage(url: url) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().scaledToFit()
                                } else { EmptyView() }
                            }
                            .frame(width: 52, height: 52)
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                        }

                        // Rating badge
                        if let rating = card.ratingOutOfTen {
                            VStack(spacing: 1) {
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                Text("/10")
                                    .font(.system(size: 9, weight: .bold))
                                    .opacity(0.75)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 50)
                            .background(ratingBadgeBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        if isUnscoutedCard {
                            Text("UNSCOUTED")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 14)

                Spacer()

                // BOTTOM: name + position
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .padding(.bottom, 6)

                    Text(card.playerName)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(card.clubName ?? "Unknown club")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(1)

                    HStack {
                        if isUnscoutedCard {
                            Text("Basic estimate")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.58))
                        }

                        Spacer()

                        Text((card.detailedPositionLabel ?? card.positionLabel ?? "").uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(width: 190, height: 260)
        .overlay {
            tierFinishOverlay
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tierStrokeColor, lineWidth: 1.5)
        )
        .overlay(alignment: .topTrailing) {
            if showsFlipHint {
                animatedFlipCornerHint
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }
        }
        .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
    }

    private var animatedFlipCornerHint: some View {
        ZStack(alignment: .topTrailing) {
            TriangleCorner()
                .fill(Color.white.opacity(0.22))
                .frame(width: 38, height: 38)
                .rotationEffect(.degrees(flipHintActive ? 1.5 : -1.5), anchor: .topTrailing)

            VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .black))
                    .rotationEffect(.degrees(flipHintActive ? 10 : -10))
                Text("FLIP")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .tracking(0.4)
            }
            .foregroundStyle(Color.kcNavy)
            .padding(.top, 4)
            .padding(.trailing, 4)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 6, y: 2)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: flipHintActive)
    }

    @ViewBuilder
    private var playerPhotoContent: some View {
        if let photoUrl = card.photoUrl, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFit()
                } else {
                    fallbackPhoto
                }
            }
        } else {
            fallbackPhoto
        }
    }

    private var fallbackPhoto: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "person.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var cardGradient: LinearGradient {
        switch normalizedTier {
        case "unscouted":
            return LinearGradient(colors: [Color(red: 0.21, green: 0.15, blue: 0.30), Color(red: 0.45, green: 0.34, blue: 0.58), Color(red: 0.68, green: 0.60, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "elite":
            return LinearGradient(colors: [Color(red: 0.18, green: 0.17, blue: 0.08), Color(red: 0.77, green: 0.66, blue: 0.21), Color(red: 0.95, green: 0.88, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "gold":
            return LinearGradient(colors: [Color(red: 0.34, green: 0.23, blue: 0.03), Color(red: 0.86, green: 0.62, blue: 0.06), Color(red: 0.98, green: 0.84, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "silver":
            return LinearGradient(colors: [Color(red: 0.20, green: 0.24, blue: 0.30), Color(red: 0.63, green: 0.69, blue: 0.77)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "bronze":
            return LinearGradient(colors: [Color(red: 0.22, green: 0.10, blue: 0.08), Color(red: 0.50, green: 0.23, blue: 0.12), Color(red: 0.72, green: 0.38, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            switch card.starterSlotCode {
            case "GK":
                return LinearGradient(colors: [Color(red: 0.22, green: 0.26, blue: 0.18), Color(red: 0.66, green: 0.59, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "RB", "LB", "RCB", "LCB":
                return LinearGradient(colors: [Color(red: 0.10, green: 0.22, blue: 0.36), Color(red: 0.17, green: 0.46, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case "CM", "RM", "LM":
                return LinearGradient(colors: [Color(red: 0.14, green: 0.30, blue: 0.20), Color(red: 0.30, green: 0.56, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
            default:
                return LinearGradient(colors: [Color(red: 0.33, green: 0.14, blue: 0.14), Color(red: 0.72, green: 0.27, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    @ViewBuilder
    private var tierFinishOverlay: some View {
        switch normalizedTier {
        case "gold":
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.24), Color.clear, Color.white.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.32), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 56)
                    .rotationEffect(.degrees(26))
                    .offset(x: 34, y: -18)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.20), Color.clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 84)
                    .offset(x: -16, y: -72)
            }
        case "bronze":
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.14), Color.clear, Color(red: 0.16, green: 0.08, blue: 0.05).opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(0..<7, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.035))
                        .frame(width: 260, height: 2)
                        .rotationEffect(.degrees(-18))
                        .offset(x: 0, y: CGFloat(index * 28) - 96)
                }
            }
        default:
            Color.clear
        }
    }

    private var normalizedTier: String { (card.ratingTier ?? "standard").lowercased() }


    private var tierStrokeColor: Color {
        switch normalizedTier {
        case "unscouted":
            return Color(red: 0.84, green: 0.77, blue: 0.96)
        case "elite":
            return Color(red: 0.98, green: 0.90, blue: 0.62)
        case "gold":
            return Color(red: 1.00, green: 0.88, blue: 0.36)
        case "silver":
            return Color(red: 0.84, green: 0.88, blue: 0.94)
        case "bronze":
            return Color(red: 0.78, green: 0.45, blue: 0.22)
        default:
            return Color.white.opacity(0.18)
        }
    }

    private var ratingBadgeBackground: some ShapeStyle {
        switch normalizedTier {
        case "unscouted":
            return Color(red: 0.25, green: 0.17, blue: 0.35).opacity(0.78)
        case "elite":
            return Color(red: 0.42, green: 0.34, blue: 0.06).opacity(0.74)
        case "gold":
            return Color(red: 0.69, green: 0.46, blue: 0.02).opacity(0.80)
        case "silver":
            return Color(red: 0.33, green: 0.39, blue: 0.47).opacity(0.74)
        case "bronze":
            return Color(red: 0.38, green: 0.16, blue: 0.10).opacity(0.82)
        default:
            return Color.black.opacity(0.18)
        }
    }

    private var isUnscoutedCard: Bool {
        normalizedTier == "unscouted" || (card.ratingSource ?? "").lowercased() == "fallback-basic-profile"
    }
}

private struct TriangleCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FootballStatPill: View {
    enum Tone {
        case light
    }

    let label: String
    let value: String
    let tone: Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct FootballSummaryTile: View {
    let title: String
    let value: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(String(value))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }
}
