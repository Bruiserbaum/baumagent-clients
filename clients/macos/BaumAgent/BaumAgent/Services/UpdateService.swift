import Foundation
import AppKit

struct UpdateInfo {
    let version: String
    let notes: String
    let releaseUrl: URL
}

@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    private let apiUrl = URL(string:
        "https://api.github.com/repos/Bruiserbaum/baumagent-clients/releases/latest")!

    @Published var availableUpdate: UpdateInfo?
    @Published var isChecking = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func checkForUpdate() async {
        isChecking = true
        defer { isChecking = false }

        do {
            var req = URLRequest(url: apiUrl)
            req.setValue("BaumAgentMac/1.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard
                let tag = json?["tag_name"] as? String,
                let htmlUrl = json?["html_url"] as? String,
                let releaseUrl = URL(string: htmlUrl)
            else { return }

            let latestVersion = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard isNewerVersion(latestVersion, than: currentVersion) else { return }

            let notes = json?["body"] as? String ?? ""
            availableUpdate = UpdateInfo(
                version: latestVersion,
                notes: notes,
                releaseUrl: releaseUrl
            )
        } catch {}
    }

    func openReleasePage() {
        guard let url = availableUpdate?.releaseUrl else { return }
        NSWorkspace.shared.open(url)
    }

    private func isNewerVersion(_ candidate: String, than current: String) -> Bool {
        let parse: (String) -> [Int] = { v in
            v.split(separator: ".").compactMap { Int($0) }
        }
        let lhs = parse(candidate)
        let rhs = parse(current)
        let len = max(lhs.count, rhs.count)
        for i in 0..<len {
            let a = i < lhs.count ? lhs[i] : 0
            let b = i < rhs.count ? rhs[i] : 0
            if a != b { return a > b }
        }
        return false
    }
}
