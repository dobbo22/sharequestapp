//
//  ShareQuestApp.swift
//  ShareQuest
//
//  Created by MartinD on 11/03/2026.
//

import SwiftUI

@main
struct ShareQuestApp: App {

    init() {
        migrateBaseURLIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Force any stored remote base URL that points at the non-www host to the
/// canonical www host. URLSession strips custom headers on redirects, so
/// requests sent to sharequest.co.uk (which 307s to www) would lose their
/// Authorization / x-user-id headers and silently fail.
private func migrateBaseURLIfNeeded() {
    let key = "api_remote_base_url"
    if let stored = UserDefaults.standard.string(forKey: key),
       stored.contains("sharequest.co.uk"),
       !stored.contains("www.sharequest.co.uk") {
        let fixed = stored.replacingOccurrences(of: "://sharequest.co.uk", with: "://www.sharequest.co.uk")
        UserDefaults.standard.set(fixed, forKey: key)
    }
}
