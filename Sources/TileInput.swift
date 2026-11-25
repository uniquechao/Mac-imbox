import SwiftUI
import AppKit

struct TileInput: NSViewRepresentable {
    let click: () -> Void
    let makeMenu: () -> NSMenu
    let hold: () -> Void

    final class Surface: NSView {
        var click: (() -> Void)?
        var makeMenu: (() -> NSMenu)?
        override func rightMouseDown(with event: NSEvent) { showMenu(event) }
        private func showMenu(_ event: NSEvent) {
            cancel()
            if let menu = makeMenu?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
        }
        var hold: (() -> Void)?
        private var timer: Timer?
        private var armed = false
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            cancel()
            if event.modifierFlags.contains(.control) { showMenu(event); return }
            armed = true
            let timer = Timer(timeInterval: 0.48, repeats: false) { [weak self] _ in
                guard let self, self.armed else { return }
                self.cancel()
                self.hold?()
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        override func mouseDragged(with event: NSEvent) {
            if !bounds.contains(convert(event.locationInWindow, from: nil)) { cancel() }
        }
        override func mouseUp(with event: NSEvent) {
            let shouldOpen = armed && bounds.contains(convert(event.locationInWindow, from: nil))
            cancel()
            if shouldOpen { click?() }
        }
        override func viewDidMoveToWindow() {
            if window == nil { cancel() }
        }
        private func cancel() { timer?.invalidate(); timer = nil; armed = false }
    }
    func makeNSView(context: Context) -> Surface { Surface() }
    func updateNSView(_ view: Surface, context: Context) {
        view.click = click
        view.makeMenu = makeMenu
        view.hold = hold
    }
}
