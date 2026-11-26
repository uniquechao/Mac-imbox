import SwiftUI

@MainActor
final class UpdateChecker: ObservableObject {
    struct Release: Decodable {
        struct Asset: Decodable { let name: String }
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]

        func update(over installed: String) -> (version: String, url: URL, hasDMG: Bool)? {
            func parts(_ text: String) -> [Int]? {
                let digits = text.split(separator: ".", omittingEmptySubsequences: false)
                guard (1...3).contains(digits.count) else { return nil }
                let values = digits.compactMap { part -> Int? in
                    guard !part.isEmpty, part.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
                    return Int(part)
                }
                guard values.count == digits.count else { return nil }
                return values + Array(repeating: 0, count: 3 - values.count)
            }
            let version = tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name
            guard !draft, !prerelease, let next = parts(version), let current = parts(installed),
                  current.lexicographicallyPrecedes(next) else { return nil }
            let file = "Mac-imbox-\(version)-universal.dmg"
            let dmg = assets.contains { $0.name == file }
            let path = dmg ? "download/\(tag_name)/\(file)" : "tag/\(tag_name)"
            return (version, URL(string: "https://github.com/uniquechao/Mac-imbox/releases/" + path)!, dmg)
        }
    }

    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "automaticUpdateChecks")
    @Published private(set) var available: (version: String, url: URL, hasDMG: Bool)?
    var changed: (() -> Void)?
    private var task: Task<Void, Never>?
    private var timer: Timer?

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: "automaticUpdateChecks")
        schedule()
    }

    func schedule() {
        timer?.invalidate()
        task?.cancel()
        task = nil
        guard enabled else {
            available = nil
            changed?()
            return
        }
        check()
        let timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        timer.tolerance = 300
        self.timer = timer
    }

    private func check() {
        guard enabled, task == nil else { return }
        task = Task {
            defer { if !Task.isCancelled { task = nil } }
            let endpoint = URL(string: "https://api.github.com/repos/uniquechao/Mac-imbox/releases/latest")!
            var request = URLRequest(url: endpoint, timeoutInterval: 20)
            request.setValue("Mac-imbox-UpdateChecker", forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled, (response as? HTTPURLResponse)?.statusCode == 200,
                      let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return }
                let release = try JSONDecoder().decode(Release.self, from: data)
                available = release.update(over: installed)
                changed?()
            } catch { /* A failed check is retried at the next scheduled interval. */ }
        }
    }
}
