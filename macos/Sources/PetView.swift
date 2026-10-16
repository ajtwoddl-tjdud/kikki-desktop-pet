import AppKit

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    let state: PetState
    let sprites: Sprites
    var showMenu: ((NSEvent) -> Void)?
    var didMove: (() -> Void)?
    private var pressPoint = NSPoint.zero
    private var pressOrigin = NSPoint.zero
    private var lastRender: RenderKey?
    private var lastAccessibilityValue: String?
    private var cachedMessage = ""
    private var cachedTextHeight = 22.0
    private lazy var textAttributes: [NSAttributedString.Key: Any] = {
        let style = NSMutableParagraphStyle(); style.alignment = .center
        return [.font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor(calibratedRed: 0.29, green: 0.19, blue: 0.12, alpha: 1), .paragraphStyle: style]
    }()
    private struct RenderKey: Equatable {
        let sheet: String
        let index: Int
        let flipped: Bool
        let breath: Double
        let phoneAge: Double?
        let sleepMark: Bool
        let message: String?
        let size: CGSize
    }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }

    init(state: PetState, sprites: Sprites) {
        self.state = state; self.sprites = sprites
        super.init(frame: NSRect(x: 0, y: 0, width: 232, height: 270))
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("끼끼")
        setAccessibilityHelp("클릭하면 반응하고, 드래그하면 이동합니다. 우클릭하면 메뉴를 엽니다.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Repaint only when something drawn actually changed. Pointer hit testing stays independent.
    @discardableResult func invalidateIfNeeded() -> Bool {
        let (sheet, index, flipped) = currentSprite()
        let key = RenderKey(sheet: sheet, index: index, flipped: flipped,
                            breath: state.motion && sheet == "base" ? sin(state.time * 1.2) : 0,
                            phoneAge: state.dropStart.map { state.time - $0 },
                            sleepMark: state.activity == .sleep && state.motion && sheet == "base",
                            message: state.time < state.bubbleEnd ? state.message : nil, size: bounds.size)
        guard key != lastRender else { return false }
        lastRender = key
        let accessibilityValue = key.message ?? state.activity.title
        if accessibilityValue != lastAccessibilityValue {
            lastAccessibilityValue = accessibilityValue
            setAccessibilityValue(accessibilityValue)
        }
        needsDisplay = true
        return true
    }

    func currentSprite() -> (String, Int, Bool) {
        let t = state.time, mode = state.activity.rawValue
        if state.lifted { return ("lift", state.motion ? Int((t - state.liftStart) / 1.35 * 8) % 8 : 0, false) }
        if t < state.sulkEnd { return ("landed", 0, false) }
        if let scene = state.transition {
            let i = min(scene.route.count - 1, Int((t - scene.start) / 0.22))
            return ("transition", scene.route[i], false)
        }
        if let scene = state.walk {
            let age = t - scene.start - scene.pausedDuration - 1.1
            if scene.pausedAt != nil { return ("glance", scene.frame, scene.direction > 0) }
            if age < 0 { return ("walkPose", 0, false) }
            if age >= scene.duration { return ("walkPose", 3, false) }
            return ("walk", scene.frame, scene.direction > 0)
        }
        if state.backEnd != nil {
            let age = t - state.peekStart
            let frame = age >= 0 && age < 2.6 ? (age < 0.14 || age > 2.42 ? 1 : (age > 1.2 && age < 1.34 ? 3 : 2)) : 0
            return ("back", frame, false)
        }
        if t < state.attentionEnd {
            let cheeky = state.motion && state.dialogue?.level == .normal && t < state.memeFaceEnd
            return (cheeky ? "playful" : "look", mode, false)
        }
        if let start = state.dropStart {
            let age = t - start
            if age < 0.65 { return ("blink", 1, false) }
            if age < 1.02 { return ("drop", 0, false) }
            if age < 1.55 { return ("drop", 2, false) }
            if age < 3.2 { return ("drop", 3, false) }
            return ("pickup", age < 3.75 ? 0 : (age < 4.2 ? 1 : (age < 4.9 ? 2 : 3)), false)
        }
        if let start = state.restStart {
            if state.activity == .game { return ("playful", 3, false) }
            return ("rest", [4,2,0,0][mode] + (t - start >= 0.9 ? 1 : 0), false)
        }
        if t < state.expressionEnd { return ("playful", mode, false) }
        if state.motion && state.activity != .sleep && t.truncatingRemainder(dividingBy: 4.7) < 0.14 { return ("blink", mode, false) }
        return ("base", mode, false)
    }

    func imageRect(for sprite: Sprite) -> CGRect {
        let factor = min(220 / Double(sprite.image.width), 195 / Double(sprite.image.height))
        let width = Double(sprite.image.width) * factor, height = Double(sprite.image.height) * factor
        return CGRect(x: 6 + (220 - width) / 2, y: 65 + (195 - height) / 2, width: width, height: height)
    }

    func bodyRect() -> CGRect {
        let (key, index, flipped) = currentSprite(), sprite: Sprite
        sprite = sprites[key, index]
        let rect = imageRect(for: sprite), factor = rect.width / Double(sprite.image.width)
        let x = flipped ? Double(sprite.image.width) - sprite.silhouette.maxX : sprite.silhouette.minX
        return CGRect(x: rect.minX + x * factor, y: rect.minY + sprite.silhouette.minY * factor,
                      width: sprite.silhouette.width * factor, height: sprite.silhouette.height * factor)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let scale = bounds.width / 232
        context.saveGState(); context.scaleBy(x: scale, y: scale)
        let (key, index, flipped) = currentSprite(), sprite: Sprite
        sprite = sprites[key, index]
        let body = bodyRect()
        if !state.lifted {
            NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.13, alpha: 0.12).setFill()
            NSBezierPath(ovalIn: NSRect(x: 54, y: body.maxY - 5, width: 124, height: 8)).fill()
        }
        let rect = imageRect(for: sprite)
        context.saveGState()
        if flipped { context.translateBy(x: 232, y: 0); context.scaleBy(x: -1, y: 1) }
        if state.motion && key == "base" {
            let breath = sin(state.time * 1.2) * (state.activity == .sleep ? 0.006 : 0.003)
            context.translateBy(x: 116, y: rect.maxY); context.scaleBy(x: 1, y: 1 + breath)
            context.translateBy(x: -116, y: -rect.maxY)
        }
        drawSprite(sprite, in: rect, context: context)
        context.restoreGState()
        if let start = state.dropStart {
            let age = state.time - start
            if (age >= 0.65 && age < 1.02) || (age >= 1.55 && age < 3.2) {
                let p = (age - 0.65) / 0.37
                let offset = age < 1.02 ? NSPoint(x: -15 * p * p, y: 12 * p * p) : NSPoint(x: 47, y: 68)
                drawSprite(sprites["drop", 1], in: rect.offsetBy(dx: offset.x, dy: offset.y), context: context)
            }
        }
        if state.activity == .sleep && state.motion && key == "base" {
            ("z z" as NSString).draw(at: NSPoint(x: body.maxX - 20, y: body.minY - 14), withAttributes: [
                .font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.brown])
        }
        if state.time < state.bubbleEnd {
            let text = state.message as NSString
            if cachedMessage != state.message {
                cachedMessage = state.message
                cachedTextHeight = max(22, ceil(text.boundingRect(with: NSSize(width: 186, height: 100),
                                                               options: [.usesLineFragmentOrigin], attributes: textAttributes).height))
            }
            let height = cachedTextHeight
            let bubble = NSRect(x: 10, y: max(4, body.minY - height - 34), width: 212, height: height + 18)
            let tail = NSBezierPath(); tail.move(to: NSPoint(x: 92, y: bubble.maxY - 1))
            tail.line(to: NSPoint(x: 102, y: bubble.maxY + 11)); tail.line(to: NSPoint(x: 112, y: bubble.maxY - 1))
            NSColor(calibratedRed: 1, green: 0.996, blue: 0.973, alpha: 1).setFill()
            NSBezierPath(roundedRect: bubble, xRadius: 18, yRadius: 18).fill(); tail.fill()
            NSColor.brown.setStroke()
            let border = NSBezierPath(roundedRect: bubble, xRadius: 18, yRadius: 18); border.lineWidth = 1.5; border.stroke()
            text.draw(in: bubble.insetBy(dx: 13, dy: 9), withAttributes: textAttributes)
        }
        context.restoreGState()
    }

    private func drawSprite(_ sprite: Sprite, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(sprite.image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    func containsPet(_ point: NSPoint) -> Bool {
        let scale = bounds.width / 232
        return bodyRect().insetBy(dx: -5, dy: -5).contains(NSPoint(x: point.x / scale, y: point.y / scale))
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { showMenu?(event); return }
        pressPoint = NSEvent.mouseLocation; pressOrigin = window?.frame.origin ?? .zero
        state.pressed = true; state.dragging = false; state.lifted = false
        state.transition = nil; state.restStart = nil; state.sulkEnd = 0
        if state.walk != nil { state.walk?.pausedAt = state.time }
    }
    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation, dx = point.x - pressPoint.x, dy = point.y - pressPoint.y
        guard state.dragging || abs(dx) + abs(dy) > 6 else { return }
        if !state.dragging { state.clearScene(); state.attentionEnd = 0 }
        state.dragging = true
        window?.setFrameOrigin(NSPoint(x: pressOrigin.x + dx, y: pressOrigin.y + dy))
        if !state.lifted && dy >= 14 {
            state.lifted = true; state.liftStart = state.time
            state.sayContext("lift", fallback: "아 왜 들어… 쪼끔만 낮춰주라.")
        }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        let moved = state.dragging, lifted = state.lifted
        state.pressed = false; state.dragging = false; state.lifted = false
        if moved {
            state.nextWalk = state.time + Double.random(in: 120...240)
            if lifted { state.sulkEnd = state.time + 1.8 }
            if lifted { state.sayContext("putDown", fallback: "휴. 바닥이 좋긴 하네.") }
            else { state.say("아자스~ 여기 있을게.") }
            didMove?()
        } else { state.poke() }
        needsDisplay = true
    }
    override func rightMouseDown(with event: NSEvent) { showMenu?(event) }
    override func otherMouseDown(with event: NSEvent) { showMenu?(event) }
}
