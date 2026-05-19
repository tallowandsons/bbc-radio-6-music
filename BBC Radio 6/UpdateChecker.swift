import Foundation
import Combine

class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?

    private let currentVersion: String
    private let releasesURL = URL(string: "https://api.github.com/repos/tallowandsons/bbc-radio-6-music/releases/latest")!
    private var timer: Timer?
    private var prefsCancellable: AnyCancellable?

    init() {
        currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        prefsCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if !self.checkForUpdatesEnabled { self.availableVersion = nil }
            }
    }

    private var checkForUpdatesEnabled: Bool {
        UserDefaults.standard.object(forKey: "checkForUpdates") as? Bool ?? true
    }

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    private func check() {
        guard checkForUpdatesEnabled else {
            availableVersion = nil
            return
        }
        var request = URLRequest(url: releasesURL)
        request.setValue("BBC-Radio-6-Music-App", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            DispatchQueue.main.async {
                self.availableVersion = self.isNewer(latest, than: self.currentVersion) ? latest : nil
            }
        }.resume()
    }

    private func isNewer(_ candidate: String, than current: String) -> Bool {
        let toInts = { (v: String) in v.split(separator: ".").compactMap { Int($0) } }
        let a = toInts(candidate)
        let b = toInts(current)
        let maxLen = max(a.count, b.count)
        for i in 0..<maxLen {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
