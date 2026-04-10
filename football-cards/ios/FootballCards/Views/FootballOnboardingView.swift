import SwiftUI

// MARK: - Brand colours (mirrors FootballLoginView)
private extension Color {
    static let kcNavy  = Color(red: 0.051, green: 0.106, blue: 0.165)
    static let kcLime  = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let kcCard  = Color(red: 0.118, green: 0.176, blue: 0.239)
    static let kcMuted = Color(red: 0.541, green: 0.608, blue: 0.690)
}

// MARK: - Club badge image
private struct ClubBadge: View {
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        Image(systemName: "shield.fill")
            .font(.system(size: size * 0.5))
            .foregroundStyle(Color.kcMuted)
    }
}

// MARK: - Club row
private struct ClubRow: View {
    let club: FootballClub
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ClubBadge(url: club.logoUrl, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(club.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(club.leagueName ?? "Unknown league")
                    .font(.caption)
                    .foregroundStyle(Color.kcMuted)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.kcLime)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? Color.kcCard.opacity(0.8) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.kcLime.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Onboarding view
struct FootballOnboardingView: View {
    @ObservedObject var profileViewModel: FootballProfileViewModel
    let suggestedDisplayName: String

    @State private var displayName = ""
    @State private var teamName = ""
    @State private var searchText = ""
    @State private var selectedClubId: String?

    var filteredClubs: [FootballClub] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return profileViewModel.clubs }
        return profileViewModel.clubs.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            ($0.leagueName?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var selectedClub: FootballClub? {
        profileViewModel.clubs.first { $0.id == selectedClubId }
    }

    var body: some View {
        ZStack {
            Color.kcNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Footy")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Cards")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(Color.kcLime)
                    }
                    Text("Pick your club")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Choose the team you support and we'll build your 22-card starter squad.")
                        .font(.subheadline)
                        .foregroundStyle(Color.kcMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Clubs with no players who have made an appearance are excluded.")
                        .font(.caption)
                        .foregroundStyle(Color.kcMuted.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Display name + team name fields
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.kcMuted)
                        TextField("Display name", text: $displayName)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.kcCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .tint(Color.kcLime)
                            .environment(\.colorScheme, .dark)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Team name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.kcMuted)
                        TextField("e.g. FC Bina", text: $teamName)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.kcCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .tint(Color.kcLime)
                            .environment(\.colorScheme, .dark)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.kcMuted)
                    TextField("Search clubs or leagues", text: $searchText)
                        .foregroundStyle(.white)
                        .tint(Color.kcLime)
                        .environment(\.colorScheme, .dark)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.kcCard)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Club list
                Group {
                    if profileViewModel.isLoadingClubs && profileViewModel.clubs.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color.kcLime)
                            Text("Loading clubs…")
                                .font(.subheadline)
                                .foregroundStyle(Color.kcMuted)
                        }
                        Spacer()
                    } else if filteredClubs.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "shield.slash")
                                .font(.largeTitle)
                                .foregroundStyle(Color.kcMuted)
                            Text("No clubs found")
                                .foregroundStyle(Color.kcMuted)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredClubs) { club in
                                    ClubRow(club: club, isSelected: selectedClubId == club.id)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                selectedClubId = club.id
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        }
                    }
                }

                // Error
                if let error = profileViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }

                // CTA
                VStack(spacing: 0) {
                    if let club = selectedClub {
                        HStack(spacing: 10) {
                            ClubBadge(url: club.logoUrl, size: 28)
                            Text(club.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Button {
                        Task {
                            guard let selectedClubId else { return }
                            _ = await profileViewModel.completeOnboarding(
                                displayName: displayName.isEmpty ? suggestedDisplayName : displayName,
                                teamName: teamName.isEmpty ? nil : teamName,
                                supportedClubId: selectedClubId
                            )
                        }
                    } label: {
                        if profileViewModel.isSaving {
                            ProgressView("Creating starter pack")
                                .tint(Color.kcNavy)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Starter Pack")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 50)
                    .background(selectedClubId != nil ? Color.kcLime : Color.kcMuted.opacity(0.3))
                    .foregroundStyle(selectedClubId != nil ? Color.kcNavy : Color.kcMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(selectedClubId == nil || profileViewModel.isSaving)
                    .animation(.easeInOut(duration: 0.2), value: selectedClubId)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color.kcNavy)
            }
        }
        .navigationBarHidden(true)
        .task {
            displayName = suggestedDisplayName
            if profileViewModel.clubs.isEmpty && !profileViewModel.isLoadingClubs {
                await profileViewModel.loadClubs()
            }
        }
    }
}
