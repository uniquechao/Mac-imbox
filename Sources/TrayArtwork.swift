import AppKit

// Read only named image entries from the installed Electron application's ASAR.
private func bundledTrayImage(_ app: URL, path: String) -> NSImage? {
    guard let file = try? FileHandle(forReadingFrom: app.appendingPathComponent("Contents/Resources/app.asar")) else { return nil }
    defer { try? file.close() }
    guard let header = try? file.read(upToCount: 16), header.count == 16 else { return nil }
    func uint32(_ offset: Int) -> Int {
        (0..<4).reduce(0) { $0 | Int(header[offset + $1]) << (8 * $1) }
    }
    let length = uint32(12)
    guard length > 0, length <= 16_777_216, uint32(4) >= length + 8,
          let data = try? file.read(upToCount: length),
          var node = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
    for component in path.split(separator: "/") {
        guard let files = node["files"] as? [String: Any], let child = files[String(component)] as? [String: Any] else { return nil }
        node = child
    }
    guard let size = node["size"] as? Int, (1...4_194_304).contains(size),
          let offset = node["offset"] as? String, let start = UInt64(offset),
          start < UInt64.max - UInt64(uint32(4)) - 8 else { return nil }
    do {
        try file.seek(toOffset: UInt64(uint32(4)) + 8 + start)
        guard let bytes = try file.read(upToCount: size), bytes.count == size else { return nil }
        return NSImage(data: bytes)
    } catch { return nil }
}

enum TrayArtwork {
    private static let cache = NSCache<NSString, NSImage>()
    static func image(for entry: Entry, clash: String?) -> NSImage? {
        let path: String
        switch entry.id {
        case "com.volcengine.corplink": path = "static/img/tray-default-Template@2x.png"
        case "party.mihomo.app":
            guard let clash else { return nil }
            path = "resources/" + clash
        default: return nil
        }
        let url = entry.url
        let key = (url.path + "/" + path) as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let image = bundledTrayImage(url, path: path) else { return nil }
        image.isTemplate = path.contains("Template")
        cache.setObject(image, forKey: key)
        return image
    }

    static func clashIcon(app: String, core: String) -> String? {
        // Clash Party serializes its settings as block YAML with two-space indentation.
        func flag(_ text: String, section: String) -> Bool? {
            var inside = false
            for raw in text.components(separatedBy: .newlines) {
                let line = String(raw.prefix(while: { $0 != "#" })).trimmingCharacters(in: .newlines)
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                if line.first != " " { inside = line.trimmingCharacters(in: .whitespaces) == section + ":" }
                else if inside, line.hasPrefix("  enable:") {
                    return Bool(line.dropFirst("  enable:".count).trimmingCharacters(in: .whitespaces))
                }
            }
            return false
        }
        guard let proxy = flag(app, section: "sysProxy"), let tun = flag(core, section: "tun") else { return nil }
        if app.components(separatedBy: .newlines).contains("disableTrayIconColor: true") { return "iconTemplate.png" }
        switch (proxy, tun) {
        case (true, true): return "icon_red.png"
        case (true, false): return "icon_blue.png"
        case (false, true): return "icon_green.png"
        default: return "iconTemplate.png"
        }
    }

    static func currentClashIcon() -> String? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "party.mihomo.app").isEmpty else { return nil }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/mihomo-party")
        guard let app = try? String(contentsOf: dir.appendingPathComponent("config.yaml"), encoding: .utf8),
              let core = try? String(contentsOf: dir.appendingPathComponent("mihomo.yaml"), encoding: .utf8) else { return nil }
        return clashIcon(app: app, core: core)
    }
}
