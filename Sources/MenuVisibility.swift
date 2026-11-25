import AppKit
import ApplicationServices

enum MenuVisibility {
    static let settings = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")!
    private static let settingsID = "com.apple.systempreferences"
    private static let menuTitles = ["菜单栏", "Menu Bar", "選單列"]
    private static func windows(of app: NSRunningApplication) -> [AXUIElement]? {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        return attribute(root, kAXWindowsAttribute) as? [AXUIElement]
    }
    // Capture window ownership before opening the URL. Leave any pre-existing
    // settings window alone, even if it was previously hidden or minimized.
    static func prepare() throws -> () -> Void {
        let workspace = NSWorkspace.shared
        guard let url = workspace.urlForApplication(withBundleIdentifier: settingsID) else { throw Failure.control }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: settingsID).first
        let previous = running.flatMap { windows(of: $0) }
        if previous?.contains(where: { menuTitles.contains(attribute($0, kAXTitleAttribute) as? String ?? "") }) == true {
            return {}
        }
        let ownsWindow = running == nil || previous?.isEmpty == true
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = false
        workspace.open([settings], withApplicationAt: url, configuration: configuration)
        return {
            guard ownsWindow,
                  let app = NSRunningApplication.runningApplications(withBundleIdentifier: settingsID).first,
                  let list = windows(of: app), list.count == 1,
                  let window = list.first, menuTitles.contains(attribute(window, kAXTitleAttribute) as? String ?? ""),
                  let close = attribute(window, kAXCloseButtonAttribute), CFGetTypeID(close) == AXUIElementGetTypeID() else { return }
            AXUIElementPerformAction(close as! AXUIElement, kAXPressAction as CFString)
        }
    }
    enum Failure: LocalizedError {
        case permission, control, verification
        var errorDescription: String? {
            switch self {
            case .permission: return "请在辅助功能中允许消息板"
            case .control: return "系统菜单栏设置中未找到唯一匹配的开关"
            case .verification: return "系统未确认开关已更改"
            }
        }
    }
    private static func switches(_ node: AXUIElement, named names: Set<String>, depth: Int = 0) -> [AXUIElement] {
        if attribute(node, kAXSubroleAttribute) as? String == "AXSwitch",
           let label = attribute(node, kAXTitleUIElementAttribute),
           CFGetTypeID(label) == AXUIElementGetTypeID(),
           let name = attribute(label as! AXUIElement, kAXValueAttribute) as? String, names.contains(name) {
            return [node]
        }
        guard depth < 32 else { return [] }
        return (attribute(node, kAXChildrenAttribute) as? [AXUIElement] ?? []).flatMap {
            switches($0, named: names, depth: depth + 1)
        }
    }
    private static func lookup(_ names: Set<String>) -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first else { return nil }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.5)
        let windows = attribute(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
        let matches = windows.filter { menuTitles.contains(attribute($0, kAXTitleAttribute) as? String ?? "") }
            .flatMap { switches($0, named: names) }
        return matches.count == 1 ? matches[0] : nil
    }
    @discardableResult
    static func set(_ entry: Entry, visible: Bool) throws -> Bool {
        guard AXIsProcessTrusted() else { throw Failure.permission }
        let translations = ["com.electron.lark":"飞书","5ZSL2CJU2T.com.dingtalk.mac":"钉钉",
                            "com.tencent.xinWeChat":"微信","com.tencent.WeWorkMac":"企业微信"]
        var names = Set([entry.name,entry.url.deletingPathExtension().lastPathComponent,translations[entry.id]].compactMap { $0 })
        if let bundle = Bundle(url: entry.url) {
            for language in bundle.localizations {
                guard let path = bundle.path(forResource: "InfoPlist", ofType: "strings", inDirectory: nil, forLocalization: language),
                      let data = FileManager.default.contents(atPath: path),
                      let values = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { continue }
                for key in ["CFBundleDisplayName", "CFBundleName"] {
                    if let name = values[key] as? String, !name.isEmpty { names.insert(name) }
                }
            }
        }
        let deadline = Date().addingTimeInterval(8)
        var pressed = false
        var retriedOpen = false
        repeat {
            if let control = lookup(names), let value = attribute(control,kAXValueAttribute) as? NSNumber {
                if value.boolValue == visible { return pressed }
                if !pressed {
                    pressed = true
                    AXUIElementPerformAction(control, kAXPressAction as CFString)
                }
            }
            if !pressed && !retriedOpen && deadline.timeIntervalSinceNow < 5 {
                retriedOpen = true
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(settings)
                }
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        throw pressed ? Failure.verification : Failure.control
    }
}
