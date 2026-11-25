import AppKit

enum MenuGlyph {
    static let quiet = draw(unread: false)
    static let attention = draw(unread: true)

    private static func draw(unread: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 23, height: 18), flipped: true) { _ in
            NSColor.black.set()
            // A raised back edge echoes the stack on the application tile.
            let back = NSBezierPath()
            back.move(to: NSPoint(x: 5, y: 2.5))
            back.line(to: NSPoint(x: 16, y: 2.5))
            back.lineWidth = 1.6
            back.lineCapStyle = .round
            back.stroke()

            let card = NSBezierPath(roundedRect: NSRect(x: 2, y: 5, width: 17, height: 10), xRadius: 3, yRadius: 3)
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: 5, y: 13))
            tail.line(to: NSPoint(x: 5, y: 17.5))
            tail.line(to: NSPoint(x: 11, y: 13))
            tail.close()
            if unread {
                card.fill()
                tail.fill()
                let context = NSGraphicsContext.current!.cgContext
                context.saveGState()
                context.setBlendMode(.clear)
                context.fillEllipse(in: CGRect(x: 14, y: 0, width: 9, height: 9))
                context.restoreGState()
                NSBezierPath(ovalIn: NSRect(x: 15.5, y: 1.5, width: 6, height: 6)).fill()
            } else {
                card.fill()
                tail.fill()
                let context = NSGraphicsContext.current!.cgContext
                context.saveGState()
                context.setBlendMode(.clear)
                context.addPath(CGPath(roundedRect: CGRect(x: 3.6, y: 6.6, width: 13.8, height: 6.8),
                                       cornerWidth: 1.6, cornerHeight: 1.6, transform: nil))
                context.fillPath()
                context.restoreGState()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = unread ? "消息板，有未读" : "消息板"
        return image
    }
}
