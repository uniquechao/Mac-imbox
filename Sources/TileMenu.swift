import AppKit
import ApplicationServices

// Offer preferences only if this running app exposes an enabled native command.
func preferencesCommand(for entry: Entry) -> AXUIElement? {
    guard AXIsProcessTrusted(),
          let app = NSRunningApplication.runningApplications(withBundleIdentifier: entry.id).first else { return nil }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 0.2)
    guard let bar = attribute(root, kAXMenuBarAttribute), CFGetTypeID(bar) == AXUIElementGetTypeID(),
          let menus = attribute(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
    let names = ["设置", "偏好设置", "設定", "偏好設定", "Settings", "Preferences"]
    for header in menus.prefix(2) {
        for menu in attribute(header, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
            for item in attribute(menu, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                guard let title = attribute(item, kAXTitleAttribute) as? String,
                      names.contains(title.trimmingCharacters(in: CharacterSet(charactersIn: "…. "))),
                      (attribute(item, kAXEnabledAttribute) as? NSNumber)?.boolValue == true else { continue }
                var actions: CFArray?
                AXUIElementCopyActionNames(item, &actions)
                if (actions as? [String])?.contains(kAXPressAction) == true { return item }
            }
        }
    }
    return nil
}

private final class CommandItem: NSMenuItem {
    let performCommand: () -> Void
    init(_ label: String, perform: @escaping () -> Void) {
        performCommand = perform
        super.init(title: label, action: #selector(invoke), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError("CommandItem is created in code") }
    @objc private func invoke() { performCommand() }
}

extension Board {
    func contextMenu(for entry: Entry) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(CommandItem("打开" + entry.name) { self.open(entry) })
        if let settings = preferencesCommand(for: entry) {
            menu.addItem(CommandItem(entry.name + " 设置…") {
                if AXUIElementPerformAction(settings, kAXPressAction as CFString) == .success {
                    self.dismissPanel?()
                    NSRunningApplication.runningApplications(withBundleIdentifier: entry.id).first?.activate(options: [])
                } else { self.error = "应用未能打开设置。" }
            })
        }
        menu.addItem(.separator())
        menu.addItem(CommandItem("从消息板移除") { self.sync([entry], removing: true) })
        return menu
    }
}
