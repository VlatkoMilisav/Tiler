import AppKit

struct UpdateChecker {

    private static let releasesURL = URL(string: "https://api.github.com/repos/VlatkoMilisav/Tiler/releases/latest")!

    static func checkInBackground() {
        Task.detached(priority: .background) {
            guard let latest = await fetchLatestTag() else { return }
            guard let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return }
            guard isNewer(latest, than: current) else { return }
            await MainActor.run { showUpdateAlert(latestVersion: latest) }
        }
    }

    /// Manual check — calls `completion` on the main thread with a status string.
    static func checkManually(completion: @escaping (String) -> Void) {
        Task.detached {
            guard let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
                await MainActor.run { completion("Could not read app version") }
                return
            }
            guard let latest = await fetchLatestTag() else {
                await MainActor.run { completion("Could not reach GitHub") }
                return
            }
            await MainActor.run {
                if isNewer(latest, than: current) {
                    showUpdateAlert(latestVersion: latest)
                    completion("Tiler \(latest) available")
                } else {
                    completion("You're up to date")
                }
            }
        }
    }

    // MARK: - Private

    private static func fetchLatestTag() async -> String? {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return nil }
        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    private static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        let count = max(r.count, l.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    private static func showUpdateAlert(latestVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Tiler \(latestVersion) is available"
        alert.informativeText = "You are running version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"). Would you like to download the update?"
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/VlatkoMilisav/Tiler/releases/latest")!)
        }
    }
}
