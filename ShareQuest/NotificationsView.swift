import SwiftUI
import Combine

// MARK: - Models

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

struct SystemAlert: Identifiable, Codable {
    let id: Int
    let symbol: String
    let content: String
    let system_urgency: String?
    let created_at: String
    let reply_count: Int

    var isUrgent: Bool { system_urgency == "high" }

    var timeAgo: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: created_at) ?? ISO8601DateFormatter().date(from: created_at) else { return "" }
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60 { return "Just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }
}

// MARK: - ViewModel

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var systemAlerts: [SystemAlert] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let readKey = "read_notification_ids"

    private var readIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: readKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: readKey) }
    }

    func load() async {
        isLoading = true
        error = nil
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadNotifications() }
            group.addTask { await self.loadAlerts() }
        }
        isLoading = false
    }

    private func loadNotifications() async {
        do {
            let fetched = try await APIService.shared.fetchNotifications()
            let ids = readIds
            // Filter to today only
            let today = Calendar.current.startOfDay(for: Date())
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            notifications = fetched
                .filter {
                    let date = fmt.date(from: $0.createdAt) ?? ISO8601DateFormatter().date(from: $0.createdAt) ?? Date.distantPast
                    return date >= today
                }
                .map { n in
                    var copy = n
                    copy.isRead = ids.contains(n.id)
                    return copy
                }
        } catch {
            self.error = "Could not load notifications."
        }
    }

    private func loadAlerts() async {
        do {
            systemAlerts = try await APIService.shared.fetchSystemAlerts()
        } catch {}
    }

    func markAllRead() async {
        var ids = readIds
        notifications.forEach { ids.insert($0.id) }
        readIds = ids
        notifications = notifications.map { var n = $0; n.isRead = true; return n }
        try? await APIService.shared.markNotificationsRead()
    }
}

// MARK: - View

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = NotificationsViewModel()
    @State private var selectedTab = 0
    @State private var navigationTarget: NavigationTarget? = nil

    enum NavigationTarget: Identifiable, Hashable {
        case stockDiscussion(symbol: String, companyName: String)
        var id: String {
            switch self { case .stockDiscussion(let s, _): return s }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab selector
                    HStack(spacing: 0) {
                        tabButton("Market Alerts", index: 0)
                        tabButton("Activity", index: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    if vm.isLoading {
                        Spacer()
                        ProgressView().tint(Theme.primaryBlue).scaleEffect(1.3)
                        Spacer()
                    } else if selectedTab == 0 {
                        alertsTab
                    } else {
                        activityTab
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
                if selectedTab == 1 && !vm.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark all read") {
                            Task { await vm.markAllRead() }
                        }
                        .font(.caption)
                        .foregroundColor(Theme.primaryBlue)
                    }
                }
            }
            .navigationDestination(item: $navigationTarget) { target in
                switch target {
                case .stockDiscussion(let symbol, let companyName):
                    StockDetailView(
                        stock: Stock(
                            id: symbol,
                            symbol: symbol,
                            companyName: companyName,
                            price: 0,
                            changeAmount: 0,
                            changePercent: 0,
                            sector: "",
                            marketCap: 0
                        ),
                        initialTab: .discussion
                    )
                }
            }
        }
        .task {
            await vm.load()
            await vm.markAllRead()
        }
    }

    // MARK: - Tab Button

    private func tabButton(_ title: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        return Button { selectedTab = index } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Theme.textSecondary)
                Rectangle()
                    .fill(isSelected ? Theme.primaryBlue : Color.clear)
                    .frame(height: 2)
                    .cornerRadius(1)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Activity Tab

    @ViewBuilder
    private var activityTab: some View {
        if vm.notifications.isEmpty {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.textSecondary.opacity(0.4))
                Text("No activity today")
                    .font(.headline).foregroundColor(.white)
                Text("XP gains, league updates, and challenge\ncompletions will appear here.")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(vm.notifications) { notif in
                        notificationRow(notif)
                    }
                }
                .padding(.top, 8)
            }
        }
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

    // MARK: - Market Alerts Tab

    @ViewBuilder
    private var alertsTab: some View {
        if vm.systemAlerts.isEmpty {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.textSecondary.opacity(0.4))
                Text("No market alerts today")
                    .font(.headline).foregroundColor(.white)
                Text("AI alerts appear when stocks move 5%+.")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.systemAlerts) { alert in
                        alertRow(alert)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private func alertRow(_ alert: SystemAlert) -> some View {
        let accentColor: Color = alert.isUrgent ? .red : Color(red: 1.0, green: 0.84, blue: 0.0)
        let bgColor: Color = alert.isUrgent
            ? Color(red: 0.28, green: 0.06, blue: 0.06)
            : Color(red: 0.18, green: 0.16, blue: 0.08)
        let borderColor: Color = alert.isUrgent ? Color.red.opacity(0.6) : Color.yellow.opacity(0.35)

        return Button {
            navigationTarget = .stockDiscussion(symbol: alert.symbol, companyName: alert.symbol)
        } label: {
            HStack(spacing: 12) {
                // Urgency icon
                Image(systemName: alert.isUrgent ? "exclamationmark.triangle.fill" : "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(alert.symbol)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(accentColor)
                        Spacer()
                        Text(alert.timeAgo)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Text(alert.content)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if alert.reply_count == 0 {
                        Label("No replies yet — be the first!", systemImage: "bubble.left")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Label("\(alert.reply_count) \(alert.reply_count == 1 ? "reply" : "replies")", systemImage: "bubble.left.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .background(bgColor)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: alert.isUrgent ? 1.5 : 1))
            .shadow(color: alert.isUrgent ? Color.red.opacity(0.25) : .clear, radius: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NotificationsView()
}
