import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Notifications")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("You have no new notifications.")
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NotificationsView()
}
