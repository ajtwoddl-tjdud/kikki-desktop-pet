import AppKit
import Carbon
import OSLog

final class ActionItem: NSMenuItem {
    private let handler: () -> Void
    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func invoke() { handler() }
}

final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    func register() -> OSStatus {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetEventDispatcherTarget(), { _, event, context in
            guard let context = context, let event = event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x4B494B49, identifier.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().onPress?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return installed }
        return RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(controlKey),
                                   EventHotKeyID(signature: 0x4B494B49, id: 1), GetEventDispatcherTarget(), 0, &reference)
    }
    deinit {
        if let reference = reference { UnregisterEventHotKey(reference) }
        if let handler = handler { RemoveEventHandler(handler) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let state = PetState()
    private var panel: PetPanel!
    private var petView: PetView!
    private var statusItem: NSStatusItem!
    private let hotKey = HotKey()
    private var timer: Timer?
    private var classTimer: Timer?
    private var scheduledClassEnd: Date?
    private var previousTick = ProcessInfo.processInfo.systemUptime
    private var menuOpen = false
    private var hotKeyStatus = noErr
    private var screenObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "io.github.ajtwoddl-tjdud.kikki", category: "Runtime")

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            guard let resources = Bundle.main.resourceURL else { throw PetError.asset("Resources") }
            let sprites = try Sprites(directory: resources.appendingPathComponent("assets"))
            state.dialogue = MischiefDialogue(catalog: try MischiefCatalog(url: resources.appendingPathComponent("assets/mischief.json")))
            state.dialogue?.level = MischiefLevel(rawValue: UserDefaults.standard.string(forKey: "mischiefLevel") ?? "") ?? .normal
            state.sayContext("hello", fallback: "야르. 끼끼 왔어.")
            panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 232, height: 270),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "끼끼"
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.isMovableByWindowBackground = false
            petView = PetView(state: state, sprites: sprites); panel.contentView = petView
            petView.showMenu = { [weak self] event in
                guard let self = self else { return }
                NSMenu.popUpContextMenu(self.makeMenu(), with: event, for: self.petView)
            }
            petView.didMove = { [weak self] in self?.keepOnScreen() }
            if let area = NSScreen.main?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: area.maxX - 256, y: area.minY + 12))
            }
            panel.orderFrontRegardless()
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem.button?.title = "🐒"
            statusItem.button?.toolTip = "끼끼 · Control+M으로 보이기/숨기기"
            statusItem.menu = makeMenu()
            hotKey.onPress = { [weak self] in self?.toggleVisibility() }
            hotKeyStatus = hotKey.register()
            if hotKeyStatus != noErr {
                statusItem.button?.toolTip = "Control+M을 등록하지 못했습니다 (\(hotKeyStatus)). 메뉴에서 보이기/숨기기를 사용하세요."
                logger.error("Control+M registration failed: \(self.hotKeyStatus)")
            }
            statusItem.menu = makeMenu()
            screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                     object: nil, queue: .main) { [weak self] _ in
                self?.state.walk = nil; self?.keepOnScreen()
            }
            previousTick = ProcessInfo.processInfo.systemUptime
            updateTimers()
            petView.invalidateIfNeeded()
            logger.info("App ready")
        } catch {
            let alert = NSAlert(error: error); alert.runModal(); NSApp.terminate(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !state.visible { toggleVisibility() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        classTimer?.invalidate()
        if let observer = screenObserver { NotificationCenter.default.removeObserver(observer) }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime, delta = min(0.25, max(0, now - previousTick))
        previousTick = now
        guard !menuOpen else { return }
        if let x = state.advance(by: delta, now: Date()) { panel.setFrameOrigin(NSPoint(x: x, y: panel.frame.minY)) }
        guard state.visible else { return }
        if state.walkIsDue && !state.busy {
            startWalk(across: true)
        }
        // Transparent margins should let clicks reach the app underneath.
        let local = petView.convert(panel.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        panel.ignoresMouseEvents = !state.pressed && !petView.containsPet(local)
        petView.invalidateIfNeeded()
        updateTimers()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        updateTimers()
    }

    func menuDidClose(_ menu: NSMenu) {
        menuOpen = false
        previousTick = ProcessInfo.processInfo.systemUptime
        petView.invalidateIfNeeded()
        updateTimers()
    }

    private func updateTimers() {
        let interval = menuOpen ? nil : UpdateSchedule.interval(for: state)
        if timer?.timeInterval != interval {
            timer?.invalidate(); timer = nil
            logger.info("Animation interval ms: \(interval.map { Int(($0 * 1000).rounded()) } ?? 0)")
            if let interval = interval {
                let next = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
                next.tolerance = interval * 0.1
                timer = next; RunLoop.main.add(next, forMode: .common)
            }
        }
        if scheduledClassEnd != state.classEnd {
            classTimer?.invalidate(); classTimer = nil
            scheduledClassEnd = state.classEnd
            if let deadline = state.classEnd {
                let next = Timer(timeInterval: max(0.001, deadline.timeIntervalSinceNow), repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    self.scheduledClassEnd = nil
                    self.classTimer = nil
                    _ = self.state.advance(by: 0, now: Date())
                    self.petView.invalidateIfNeeded()
                    self.updateTimers()
                }
                next.tolerance = 0.05
                classTimer = next; RunLoop.main.add(next, forMode: .common)
            }
        }
    }

    private func toggleVisibility() {
        if state.pressed { return }
        state.toggleVisibility()
        if state.visible { keepOnScreen(); panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        logger.info("Visibility: \(self.state.visible ? "shown" : "hidden", privacy: .public)")
        previousTick = ProcessInfo.processInfo.systemUptime
        statusItem.menu = makeMenu()
        petView.invalidateIfNeeded()
        updateTimers()
    }

    private func screenArea() -> CGRect {
        let frame = panel.frame
        return NSScreen.screens.max { a, b in
            let aRect = a.frame.intersection(frame), bRect = b.frame.intersection(frame)
            return aRect.width * aRect.height < bRect.width * bRect.height
        }?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func keepOnScreen() {
        let area = screenArea(), frame = panel.frame
        panel.setFrameOrigin(NSPoint(x: max(area.minX, min(frame.minX, area.maxX - frame.width)),
                                     y: max(area.minY, min(frame.minY, area.maxY - frame.height))))
    }

    private func startWalk(across: Bool) {
        let area = screenArea(), low = area.minX + 12, high = max(low, area.maxX - panel.frame.width - 12)
        let current = panel.frame.minX
        let offset = (Bool.random() ? 1.0 : -1) * Double.random(in: 260...560)
        let target = Walk.destination(from: current, low: low, high: high, across: across, offset: offset)
        state.startWalk(from: current, to: target)
        if state.walk == nil { state.nextWalk = state.time + Double.random(in: 120...240) }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "끼끼")
        menu.delegate = self
        func add(_ title: String, _ action: @escaping () -> Void) {
            menu.addItem(ActionItem(title) { [weak self] in
                action()
                self?.petView.invalidateIfNeeded()
                self?.updateTimers()
            })
        }
        add(state.visible ? "끼끼 숨기기 · Control+M" : "끼끼 보이기 · Control+M") { [weak self] in self?.toggleVisibility() }
        if hotKeyStatus != noErr {
            let item = NSMenuItem(title: "Control+M 사용 불가 (\(hotKeyStatus))", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        menu.addItem(.separator())
        add("알아서 놀기") { [self] in state.automatic = true; state.say("너 할 거 해. 나 여기 있을게.") }
        for activity in Activity.allCases {
            add(activity.title) { [self] in
                state.automatic = false; state.setActivity(activity)
                state.sayContext(activity == .game ? "gameStart" : "pose", fallback: activity.line)
            }
        }
        add("폰 보다가 꾸벅…") { [self] in
            state.automatic = false; state.motion = true; state.setActivity(.phone, transition: false)
            state.startPhoneDrop()
        }
        add("누워서 자세 고치기") { [self] in
            state.automatic = false; state.motion = true; state.setActivity(.sleep, transition: false); state.restStart = state.time
        }
        add("바나나 한 입 먹기") { [self] in
            state.motion = true; state.setActivity(.banana, transition: false); state.restStart = state.time
        }
        add("등 돌리고 쉬기") { [self] in state.clearScene(); state.backEnd = state.time + 60; state.peekStart = -10 }
        add("윙크 한 번 해봐") { [self] in
            state.setActivity(.banana, transition: false); state.expressionEnd = state.time + 1.15; state.say("윙크. 너한테 해준 거야. 헤헤.")
        }
        add("메롱 해봐") { [self] in
            state.setActivity(.game, transition: false); state.expressionEnd = state.time + 1.15; state.say("메롱. 쪼끔 킹받지? 헤헤.")
        }
        add("움직임 줄이기 / 다시 신나게") { [self] in state.setMotion(!state.motion); state.say("이 정도 텐션 어때.") }
        let mischiefMenu = NSMenu(title: "킹받기 조절")
        for level in MischiefLevel.allCases {
            let item = ActionItem(level.title) { [self] in
                state.setMischiefLevel(level)
                UserDefaults.standard.set(level.rawValue, forKey: "mischiefLevel")
                statusItem.menu = makeMenu()
                petView.invalidateIfNeeded()
                updateTimers()
            }
            item.state = state.dialogue?.level == level ? .on : .off
            mischiefMenu.addItem(item)
        }
        let mischiefItem = NSMenuItem(title: "킹받기 조절", action: nil, keyEquivalent: "")
        mischiefItem.submenu = mischiefMenu
        menu.addItem(mischiefItem)
        add("근처로 산책 가봐") { [self] in state.motion = true; state.roaming = true; state.clearScene(); startWalk(across: false) }
        add("반대쪽 끝까지 산책 가봐") { [self] in state.motion = true; state.roaming = true; state.clearScene(); startWalk(across: true) }
        add("자동 산책 켜기 / 끄기") { [self] in state.roaming.toggle(); state.walk = nil; state.nextWalk = state.time + Double.random(in: 120...240) }
        menu.addItem(.separator())
        add("크기 바꾸기 · 작게 / 크게") { [self] in
            state.walk = nil
            let scale = panel.frame.width > 200 ? 0.75 : 1.0
            panel.setContentSize(NSSize(width: 232 * scale, height: 270 * scale)); keepOnScreen()
        }
        add("끼끼 퇴근") { NSApp.terminate(nil) }
        return menu
    }
}
