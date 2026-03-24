import SwiftUI

struct AppNotification: Identifiable, Codable {
    let id: String
    let type: String
    let title: String
    let body: String
    let createdAt: String
    var isRead: Bool

    var icon: String {
        switch type {
        case "xp":          return "bolt.fill"
        case "league":      return "trophy.fill"
        case "challenge":   return "checkmark.seal.fill"
        case "trade":       return "chart.line.uptrend.xyaxis"
        case "level_up":    return "star.fill"
        default:            return "bell.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case "xp":          return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "league":      return Theme.accentPurple
        case "challenge":   return .green
        case "trade":       return Theme.primaryBlue
        case "level_up":    return .orange
        default:            return Theme.textSecondary
        }
    }

    var timeAgo: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) else { return "" }
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60 { return "Just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }
}

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    func load() async {
        isLoading = true
        error = nil
        do {
            notifications = try await APIService.shared.fetchNotifications()
        } catch {
            self.error = "Could not load notifications."
        }
        isLoading = false
    }

    func markAllRead() async {
        notifications = notifications.map { var n = $0; n.isRead = true; return n }
        try? await APIService.shared.markNotificationsRead()
    }
}

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = NotificationsViewModel()

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    var notifications: [AppNotification] { vm.notifications }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryBlue))
                        .scaleEffect(1.3)
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.accentYellow)
                        Text(err)
                            .foregroundColor(Theme.textSecondary)
                        Button("Retry") { Task { await vm.load() } }
                            .foregroundColor(Theme.primaryBlue)
                    }
                } else if notifications.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textSecondary.opacity(0.4))
                        Text("No notifications yet")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Activity like XP gains, league updates\nand challenge completions will appear here.")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(notifications) { notif in
                                notificationRow(notif)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.primaryBlue)
                }
                if !notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark all read") {
                            Task { await vm.markAllRead() }
                        }
                        .font(.caption)
                        .foregroundColor(Theme.primaryBlue)
                    }
                }
            }
        }
        .task { await vm.load() }
    }

    private func notificationRow(_ notif: AppNotification) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(notif.iconColor.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: notif.icon)
                    .font(.system(size: 18))
                    .foregroundColor(notif.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(notif.title)
                    .font(.system(size: 14, weight: notif.isRead ? .regular : .semibold))
                    .foregroundColor(.white)
                Text(notif.body)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(notif.timeAgo)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                if !notif.isRead {
                    Circle()
                        .fill(Theme.primaryBlue)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(notif.isRead ? Color.clear : Theme.primaryBlue.opacity(0.05))
    }
}

#Preview {
    NotificationsView()
}
