import AppKit
import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers

struct Entry: Identifiable, Codable, Equatable {
    var id: String
    var path: String
    var url: URL { NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) ?? URL(fileURLWithPath: path) }
    var name: String { FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "") }
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

// Only inspect Dock application items. No chat windows or message content are read.
func dockBadges(_ selected: [Entry]) -> [String: String]? {
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
    let root = AXUIElementCreateApplication(dock.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 0.4)
    guard let groups = attribute(root, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
    var result: [String: String] = [:]
    let paths = Dictionary(selected.map { ($0.url.resolvingSymlinksInPath().path, $0.id) }, uniquingKeysWith: { a,_ in a })
    var foundList = false
    for group in groups where attribute(group, kAXRoleAttribute) as? String == "AXList" {
        guard let items = attribute(group, kAXChildrenAttribute) as? [AXUIElement] else { continue }
        foundList = true
        for item in items {
            guard let url = attribute(item, kAXURLAttribute) as? URL,
                  let id = paths[url.resolvingSymlinksInPath().path] else { continue }
            let label = (attribute(item, "AXStatusLabel") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            result[id] = label == "0" ? "" : label
        }
    }
    return foundList ? result : nil
}

func unreadCount(_ raw: String?) -> String? {
        guard let label = raw,
              label.range(of: #"^[0-9]+[+]?$"#, options: .regularExpression) != nil,
              label.contains(where: { ("1"..."9").contains(String($0)) }) else { return nil }
        return label
    }

// Some clients publish their numeric count on a status item instead of the Dock.
func readableBadges(_ entries: [Entry]) -> [String: String]? {
    guard AXIsProcessTrusted() else { return nil }
    var result = dockBadges(entries) ?? [:]
    for entry in entries where unreadCount(result[entry.id]) == nil && MessagingApps.identifiers.contains(entry.id) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: entry.id).first else { continue }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.25)
        guard let bar = attribute(root, "AXExtrasMenuBar"), CFGetTypeID(bar) == AXUIElementGetTypeID(),
              let items = attribute(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement], items.count == 1 else { continue }
        for key in [kAXTitleAttribute, kAXValueAttribute] {
            if let label = attribute(items[0], key) as? String,
               let count = unreadCount(label.trimmingCharacters(in: .whitespacesAndNewlines)) {
                result[entry.id] = count
                break
            }
        }
    }
    return result
}

func menuCount(in entries: [Entry], badges: [String: String]) -> String {
    var total = 0
    var lowerBound = false
    for entry in entries {
        guard let label = unreadCount(badges[entry.id]) else { continue }
        lowerBound = lowerBound || label.hasSuffix("+")
        let digits = label.prefix { $0.isNumber }
        guard let n = Int(digits), n <= 999 - total else { return "999+" }
        total += n
    }
    return total == 0 ? "" : String(total) + (lowerBound ? "+" : "")
}

func firstUnread(in entries: [Entry], badges: [String: String]) -> Entry? {
    entries.first { unreadCount(badges[$0.id]) != nil }
}

final class Board: ObservableObject {
    @Published var entries: [Entry] = [] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: "entries"); refresh() }
    }
    @Published var badges: [String: String] = [:]
    @Published var trusted = AXIsProcessTrusted()
    @Published var clashIcon: String?
    @Published var available = false
    @Published var editing = false
    @Published var error = ""
    var changed: (() -> Void)?
    var scanning = false
    var resumePending = true
    var pending: [String: Bool] {
        get { UserDefaults.standard.dictionary(forKey: "pendingVisibility") as? [String: Bool] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "pendingVisibility") }
    }
    init() {
        if let data = UserDefaults.standard.data(forKey: "entries"),
           let stored = try? JSONDecoder().decode([Entry].self, from: data) { entries = stored }
    }
    @Published private(set) var runningEntries: [Entry] = []
    func refresh() {
        let runningIDs = Set(NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }.compactMap(\.bundleIdentifier))
        let visible = entries.filter { runningIDs.contains($0.id) }
        if visible != runningEntries {
            runningEntries = visible
            badges = badges.filter { runningIDs.contains($0.key) }
            changed?()
        }
        let previouslyTrusted = trusted
        trusted = AXIsProcessTrusted()
        if !trusted && previouslyTrusted { badges = [:]; available = false; changed?() }
        if trusted && (resumePending || !previouslyTrusted) && !syncing {
            resumePending = false
            resume()
        }
        let selection = runningEntries
        guard !selection.isEmpty else { badges = [:]; clashIcon = nil; available = false; changed?(); return }
        let canReadDock = trusted
        guard !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .utility).async {
            let result = canReadDock ? readableBadges(selection) : nil
            let clash = selection.contains { $0.id == "party.mihomo.app" } ? TrayArtwork.currentClashIcon() : nil
            DispatchQueue.main.async {
                self.scanning = false
                guard self.runningEntries == selection, canReadDock == AXIsProcessTrusted() else { self.refresh(); return }
                self.clashIcon = clash
                self.available = result != nil
                self.badges = result ?? [:]
                self.changed?()
            }
        }
    }
    func allow() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @Published var syncing = false
    func resume() {
        guard let entry = entries.first(where: { pending[$0.id] != nil }) else { return }
        sync([entry], removing: pending[entry.id] == true)
    }
    func sync(_ selection: [Entry], removing: Bool = false) {
        guard !syncing, !selection.isEmpty else { return }
        syncing = true
        for entry in selection { pending[entry.id] = removing }
        if !removing { entries.append(contentsOf: selection.filter { !entries.contains($0) }) }
        guard AXIsProcessTrusted() else {
            error = "操作已保存，等待「设备控制和数据访问」授权。如果开关已打开，请移除旧记录并重新添加当前消息板。"
            syncing = false
            return
        }
        error = ""
        let finish: () -> Void
        do { finish = try MenuVisibility.prepare() }
        catch {
            self.error = error.localizedDescription
            syncing = false
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var failed = [Entry]()
            var reasons = [String]()
            for entry in selection {
                do { _ = try MenuVisibility.set(entry, visible: removing) }
                catch { failed.append(entry); reasons.append(entry.name + " · " + error.localizedDescription) }
            }
            DispatchQueue.main.async {
                finish()
                for entry in selection where !failed.contains(entry) { self.pending.removeValue(forKey: entry.id) }
                if removing, failed.isEmpty {
                    self.entries.removeAll { $0.id == selection[0].id }

                }
                if !failed.isEmpty {
                    self.error = "未能确认菜单栏开关：" + reasons.joined(separator: "、")
                    NSLog("%@", self.error)
                }
                self.syncing = false
                if failed.isEmpty { self.resume() }
            }
        }
    }
    @Published var showingGuide = !UserDefaults.standard.bool(forKey: "guideSeen")
    @Published var importNote = ""
    func closeGuide() {
        showingGuide = false
        UserDefaults.standard.set(true, forKey: "guideSeen")
    }
    func importMessagingApps() {
        let urls = MessagingApps.installed()
        let before = entries.count
        addURLs(urls)
        let count = entries.count - before
        importNote = urls.isEmpty ? "未找到支持的 IM，可点 ＋ 手动添加。" :
            (count == 0 ? "检测到的 IM 都已加入。" : "已加入 \(count) 个 IM。")
    }
    func add() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "选择要收纳的应用（可多选）"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        addURLs(panel.urls)
    }
    func addURLs(_ urls: [URL]) {
        var next = entries
        for url in urls where url.pathExtension.lowercased() == "app" {
            if let id = Bundle(url: url)?.bundleIdentifier, !next.contains(where: { $0.id == id }) {
                next.append(Entry(id: id, path: url.path))
            }
        }
        let added = next.filter { !entries.contains($0) }
        sync(added)
    }
    var dismissPanel: (() -> Void)?
    func open(_ entry: Entry) {
        dismissPanel?()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: entry.url, configuration: configuration) { app, error in
            if let app { app.unhide(); app.activate(options: []) }
            if let error { DispatchQueue.main.async { self.error = error.localizedDescription } }
        }
    }
}

private struct TileWiggle: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([false, true]) { icon, phase in
                icon.rotationEffect(.degrees(phase ? 3 : -3))
            } animation: { _ in .easeInOut(duration: 0.13) }
        } else {
            content
        }
    }
}

struct AppTile: View {
    let entry: Entry
    @ObservedObject var board: Board
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var badge: String? { unreadCount(board.badges[entry.id]) }

    var body: some View {
        ZStack {
            Image(nsImage: TrayArtwork.image(for: entry, clash: board.clashIcon) ?? NSWorkspace.shared.icon(forFile: entry.url.path))
                .resizable().scaledToFit().frame(width: 48, height: 48)
                .modifier(TileWiggle(active: board.editing && !reduceMotion))
                .frame(width: 56, height: 56).contentShape(Rectangle())
                .overlay {
                    TileInput(click: { if !board.editing { board.open(entry) } },
                              makeMenu: { board.contextMenu(for: entry) },
                              hold: { board.editing = true })
                }
                .accessibilityLabel(entry.name)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { if !board.editing { board.open(entry) } }
                .accessibilityAction(named: "编辑应用") { board.editing = true }
            if let badge {
                Text(badge).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 4).frame(minWidth: 16, minHeight: 16)
                    .background(.red, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(false)
            }
            if board.editing {
                Button { board.sync([entry], removing: true) } label: {
                    Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(white: 0.28))
                        .font(.system(size: 17)).frame(width: 22, height: 22)
                }.buttonStyle(.plain).accessibilityLabel("移除" + entry.name)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }.frame(width: 58, height: 58)
    }
}

struct Panel: View {
    @ObservedObject var board: Board
    @State private var showingAbout = false
    private let columns = Array(repeating: GridItem(.fixed(58), spacing: 8), count: 4)
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if showingAbout {
                VStack(alignment: .leading, spacing: 10) {
                    Button { showingAbout = false } label: { Label("返回", systemImage: "chevron.left") }
                        .buttonStyle(.borderless)
                    HStack {
                        Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 44, height: 44)
                        VStack(alignment: .leading) {
                            Text("消息板 · Mac-imbox").font(.headline)
                            Text("版本 " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("开发者  xschao")
                    Link("GitHub · Mac-imbox", destination: URL(string: "https://github.com/uniquechao/Mac-imbox")!)
                    Link("inboxbar.chaoa.xyz", destination: URL(string: "https://inboxbar.chaoa.xyz")!)
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
            HStack(spacing: 12) {
                if board.syncing { ProgressView().controlSize(.small) }
                Button("导入 IM") { board.closeGuide(); board.importMessagingApps() }.help("导入已安装的常用聊天软件")
                Spacer()
                Button { if board.showingGuide { board.closeGuide() } else { board.showingGuide = true } } label: { Image(systemName: "questionmark.circle") }.help("使用指引")
                if board.editing {
                    Button { board.editing = false } label: { Image(systemName: "checkmark") }.help("完成编辑")
                }
                Button { board.add() } label: { Image(systemName: "plus") }.help("添加应用")
                Menu {
                    Button("重新同步菜单栏") { board.sync(board.entries) }.disabled(board.entries.isEmpty)
                    Button("关于消息板…") { showingAbout = true }
                    Divider()
                    Button("退出消息板") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
            }.buttonStyle(.borderless)
            if !board.trusted {
                VStack(alignment: .leading, spacing: 5) {
                    Label("无法读取未读数", systemImage: "lock.fill").font(.headline)
                    Text("请允许消息板使用「设备控制和数据访问」。开启后，所有已收纳应用的角标和顶部总数会自动刷新。")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                    Button("打开权限设置…") { board.allow() }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            if board.showingGuide {
                GettingStarted { board.closeGuide() }
            } else if !board.runningEntries.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(board.runningEntries) { entry in AppTile(entry: entry, board: board) }
                    }
                }.frame(height: min(4, CGFloat((board.runningEntries.count + 3) / 4)) * 66 - 8)
            }
            if !board.importNote.isEmpty { Text(board.importNote).font(.caption).foregroundStyle(.secondary) }
            if !board.error.isEmpty { Text(board.error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            }
        }.disabled(board.syncing).padding(12).frame(width: 280)
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    let board = Board()
    let pop = NSPopover()
    var item: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(rootView: Panel(board: board))
        board.dismissPanel = { [weak self] in self?.pop.close() }
        board.changed = { [weak self] in self?.update() }
        board.refresh()
        for event in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                self?.board.refresh()
            }
        }
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.board.refresh() }
        update()
        if board.showingGuide { toggle() }
    }
    func update() {
        let count = menuCount(in: board.runningEntries, badges: board.badges)
        let hasBadge = !count.isEmpty
        item.button?.title = count
        item.button?.imagePosition = hasBadge ? .imageLeading : .imageOnly
        item.button?.setAccessibilityLabel(hasBadge ? "消息板，未读 " + count : "消息板")
        item.button?.image = hasBadge ? MenuGlyph.attention : MenuGlyph.quiet
        item.button?.toolTip = !board.trusted ? "消息板无法读取未读数，请打开面板授权" : hasBadge ? "左键展开 · 右键打开首个未读应用" : "消息板 · 点击展开"
    }
    @objc func statusClicked() {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp ||
            (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        guard secondary else { toggle(); return }
        board.refresh()
        let entries = board.runningEntries
        DispatchQueue.global(qos: .userInitiated).async {
            let latest = AXIsProcessTrusted() ? readableBadges(entries) ?? [:] : [:]
            DispatchQueue.main.async {
                self.board.refresh()
                if let target = firstUnread(in: self.board.runningEntries, badges: latest) {
                    self.board.open(target)
                } else if !self.pop.isShown {
                    self.toggle()
                }
            }
        }
    }
    @objc func toggle() {
        if pop.isShown { pop.close() }
        else if let button = item.button {
            board.refresh()
            board.editing = false
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    func application(_ application: NSApplication, open urls: [URL]) { board.addURLs(urls) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !pop.isShown { toggle() }
        return true
    }
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
