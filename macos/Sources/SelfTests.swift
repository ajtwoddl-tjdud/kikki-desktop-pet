import AppKit

private struct TestFailure: Error, CustomStringConvertible { let description: String }

func runSelfTests() throws {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(description: message) }
        checks += 1
    }
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let state = PetState()
    state.automatic = false
    state.setActivity(.sleep, transition: false)
    let originalDeadline = state.nextChange
    state.classEnd = now.addingTimeInterval(60)
    state.toggleVisibility()
    _ = state.advance(by: 120, now: now.addingTimeInterval(120))
    try check(state.time == 0 && state.nextChange == originalDeadline, "Hidden pet advanced its animation/activity clock")
    try check(state.pendingClassEnd && state.classEnd == nil, "Hidden class timer did not finish")
    state.toggleVisibility()
    try check(!state.pendingClassEnd && state.message == "끝났다. 이제 쉬자.", "Timer completion was lost on show")
    _ = state.advance(by: 1, now: now.addingTimeInterval(121))
    try check(state.activity == .sleep && state.walk == nil, "Sleeping pet spontaneously walked")

    state.setActivity(.banana, transition: false)
    state.startWalk(from: -800, to: -300)
    _ = state.advance(by: 2, now: now)
    let beforePause = state.walk!.frame
    let position = state.advance(by: 0, now: now)!
    state.poke()
    try check(state.advance(by: 0.8, now: now) == nil, "Poke did not pause walk")
    try check(state.walk?.frame == beforePause, "Walk changed its stride during glance")
    let resumed = state.advance(by: 0.2, now: now)!
    try check(abs(resumed - position) < 0.001, "Walk jumped when resuming from glance")
    let finished = state.advance(by: 20, now: now)
    try check(finished == -300 && state.walk == nil, "Walk did not settle at destination on a negative-coordinate display")
    var lastDistance = -1.0
    for step in 0...100 {
        let distance = Walk.distance(at: Double(step) * 0.06, total: 500, duration: 6)
        try check(distance >= lastDistance && distance >= 0 && distance <= 500, "Walk easing overshot or moved backwards")
        lastDistance = distance
    }
    try check(Walk.distance(at: 6, total: 500, duration: 6) == 500, "Walk endpoint is inaccurate")
    state.startWalk(from: 0, to: 500)
    state.setMotion(false)
    try check(state.walk == nil && state.transition == nil && state.restStart == nil, "Reduced motion left an active scene")
    for from in Activity.allCases {
        for to in Activity.allCases {
            let route = PoseTransition.route(from: from, to: to)
            try check(route.allSatisfy { (0..<12).contains($0) }, "Transition references missing frame")
        }
        try check((120...240).contains(from.duration), "Activity must last two to four minutes")
        for roll in 0..<12 {
            try check(from.next(roll: roll) != from, "Automatic life repeated the same activity")
            if from != .sleep {
                let previous = Activity.allCases.first { $0 != from }!
                try check(from.next(roll: roll, excluding: previous) != previous, "Automatic life bounced straight back")
            }
        }
    }
    try check(Activity.sleep.next(roll: 0) == .phone && Activity.sleep.next(roll: 99) == .phone,
              "Sleep must wake into phone activity")
    try check(Walk.destination(from: 988, low: 12, high: 988, across: true, offset: 300) == 12, "Right-edge walk stopped short")
    try check(Walk.destination(from: 12, low: 12, high: 988, across: true, offset: -300) == 988, "Left-edge walk stopped short")
    try check(Walk.destination(from: -1200, low: -1500, high: -300, across: true, offset: 300) == -300, "Negative-coordinate display crossing failed")
    try check(Walk.destination(from: 20, low: 12, high: 10, across: true, offset: 300) == 12, "Narrow display destination escaped bounds")
    let changing = PetState()
    changing.nextWalk = 121; changing.nextRest = 122; changing.nextExpression = 123; changing.nextDrop = 124; changing.nextBack = 125
    changing.setActivity(.game, transition: false)
    try check(changing.nextWalk == 121 && changing.nextRest == 122 && changing.nextExpression == 123 && changing.nextDrop == 124 && changing.nextBack == 125,
              "Activity change postponed independent scene deadlines")
    changing.motion = false
    for _ in 0..<12 {
        let previous = changing.activity
        changing.nextChange = changing.time
        _ = changing.advance(by: 0, now: now)
        try check(changing.activity != previous && (120...240).contains(changing.nextChange - changing.time), "Automatic life failed to change on a minute-scale deadline")
    }
    let details = PetState()
    details.time = 10; details.roaming = false; details.nextChange = 1000
    details.nextRest = 0; details.nextDrop = -1; details.nextExpression = -2; details.nextBack = -3
    _ = details.advance(by: 0, now: now)
    try check(details.backEnd != nil && details.restStart == nil && details.dropStart == nil, "Oldest detail was starved by fixed priority")
    try check(details.quietUntil >= details.backEnd! + 120, "Details must wait minutes between scenes")
    _ = details.advance(by: 80, now: now)
    try check(details.backEnd == nil && details.restStart == nil && details.dropStart == nil && details.expressionEnd == 0, "Overdue details ran back-to-back")

    let assets = Bundle.main.resourceURL!.appendingPathComponent("assets")
    let catalog = try MischiefCatalog(url: assets.appendingPathComponent("mischief.json"))
    let dialogue = MischiefDialogue(catalog: catalog)
    for context in ["hello", "gameStart", "gameCheer", "gameLoss", "eatPoke", "phonePoke", "gamePoke", "sleepPoke",
                    "lift", "putDown", "phoneDrop", "walk", "walkPoke", "backPoke", "playful"] {
        try check(catalog.contexts[context]?.isEmpty == false, "Missing contextual dialogue: \(context)")
    }
    for (context, lines) in catalog.contexts {
        for line in lines {
            try check(!line.contains("줴줴") || context == "gameLoss", "GG escaped the finished-game context")
            try check(!line.contains("티~원") && !line.contains("티워") || context.hasPrefix("game"), "T1 escaped the game context")
        }
    }
    dialogue.level = .off
    for context in catalog.contexts.keys.sorted() {
        let line = dialogue.pick(context: context, fallback: "plain", time: 10, roll: 0, selection: 0)
        try check(line.text == "plain" && !line.isMeme, "Off mode leaked a meme")
    }
    dialogue.level = .mild
    try check(!dialogue.pick(context: "lift", fallback: "plain", time: 10, roll: 20, selection: 0).isMeme, "Mild chance exceeded 20 percent")
    let firstMild = dialogue.pick(context: "lift", fallback: "plain", time: 10, roll: 19, selection: 0)
    try check(firstMild.isMeme && dialogue.nextAllowedAt == 130, "Mild mode lost its two-minute cooldown")
    try check(!dialogue.pick(context: "gameLoss", fallback: "plain", time: 129.9, roll: 0, selection: 0).isMeme, "Cooldown was per-context instead of global")
    let secondMild = dialogue.pick(context: "lift", fallback: "plain", time: 130, roll: 0, selection: 0)
    try check(secondMild.isMeme && secondMild.text != firstMild.text, "Contextual dialogue immediately repeated")
    dialogue.level = .normal
    try check(!dialogue.pick(context: "gameStart", fallback: "plain", time: 20, roll: 60, selection: 0).isMeme, "Normal chance exceeded 60 percent")
    try check(!dialogue.pick(context: "unknown", fallback: "plain", time: 20, roll: 0, selection: 0).isMeme && dialogue.nextAllowedAt == 0, "Unknown context consumed cooldown")
    try check(dialogue.pick(context: "gameStart", fallback: "plain", time: 20, roll: 59, selection: 0).isMeme && dialogue.nextAllowedAt == 50, "Normal mode lost its cooldown")
    try check(!dialogue.pick(context: "phoneDrop", fallback: "plain", time: 49.9, roll: 0, selection: 0).isMeme, "Normal cooldown was ignored")
    try check(dialogue.pick(context: "phoneDrop", fallback: "plain", time: 50, roll: 0, selection: 0).isMeme, "Normal cooldown did not expire")

    let gentle = PetState()
    gentle.dialogue = dialogue; gentle.automatic = false; gentle.roaming = false
    gentle.setMischiefLevel(.off)
    let gentleDeadline = gentle.nextChange, gentleWalk = gentle.nextWalk
    gentle.setMischiefLevel(.mild)
    try check(gentle.nextChange == gentleDeadline && gentle.nextWalk == gentleWalk, "Mischief setting changed autonomous cadence")
    gentle.setMischiefLevel(.off)
    gentle.poke()
    try check(gentle.message == "왜애. 나 댓글 읽잖아." && gentle.memeFaceEnd == 0, "Off-mode poke did not use the ordinary reaction")
    gentle.attentionEnd = 0
    gentle.startPhoneDrop()
    gentle.say("before impact")
    _ = gentle.advance(by: 1.5, now: now)
    try check(gentle.message == "before impact", "Phone-drop reaction fired before impact")
    _ = gentle.advance(by: 0.1, now: now)
    try check(gentle.message == "못 본 척 해줘~~", "Phone-drop impact had no reaction")
    gentle.say("after impact")
    _ = gentle.advance(by: 0.2, now: now)
    try check(gentle.message == "after impact", "Phone-drop reaction repeated every tick")

    let sprites = try Sprites(directory: assets)
    for key in sprites.sheets.keys.sorted() {
        for sprite in sprites.sheets[key]! {
            try check(sprite.silhouette.width > 0 && sprite.silhouette.height > 0, "Empty sprite: \(key)")
            try check(sprite.silhouette.minX >= 0 && sprite.silhouette.maxX <= Double(sprite.image.width), "Clipped sprite: \(key)")
        }
    }
    try check(sprites["base", 0].image.width == 627 && sprites.sheets["transition"]?.count == 12,
              "Atlas layout changed")
    let view = PetView(state: state, sprites: sprites)
    let panel = PetPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false; panel.contentView = view
    for activity in Activity.allCases {
        state.setActivity(activity, transition: false)
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw TestFailure(description: "Cannot render pet") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let body = view.bodyRect()
        try check(body.minY >= 65 && body.maxY <= 261, "Sprite escaped the pet stage")
        try check(view.containsPet(NSPoint(x: body.midX, y: body.midY)), "Pet cannot receive mouse input")
        try check(!view.containsPet(NSPoint(x: 0, y: 0)), "Transparent margin blocks mouse input")
        try check(bitmap.pixelsWide > 0, "Empty rendered view")
    }
    state.motion = true
    state.setActivity(.phone, transition: false); state.dropStart = state.time
    let dropStart = state.time
    for (age, key, index) in [(0.7,"drop",0), (1.1,"drop",2), (2.0,"drop",3), (3.3,"pickup",0), (4.3,"pickup",2), (5.0,"pickup",3)] {
        state.time = dropStart + age
        let frame = view.currentSprite()
        try check(frame.0 == key && frame.1 == index, "Phone scene skipped a hand/impact pose at \(age)")
    }
    _ = state.advance(by: 1, now: now)
    try check(state.dropStart == nil, "Phone scene did not finish")
    state.lifted = true; state.liftStart = state.time
    try check(view.currentSprite().0 == "lift", "Lift gesture does not render dangling legs")
    state.lifted = false; state.sulkEnd = state.time + 1.8
    try check(view.currentSprite().0 == "landed", "Put-down reaction missing")
    try check(UpdateSchedule.interval(visible: false, motion: true, active: true) == nil, "Hidden pet still polls")
    try check(UpdateSchedule.interval(visible: true, motion: true, active: true) == 1.0 / 30, "Active animation lost 30 FPS")
    try check(UpdateSchedule.interval(visible: true, motion: true, active: false) == 1.0 / 15, "Idle cadence is not 15 FPS")
    try check(UpdateSchedule.interval(visible: true, motion: false, active: true) == 0.1, "Reduced-motion cadence is not 10 Hz")
    state.setActivity(.phone, transition: false); state.setMotion(false); state.bubbleEnd = 0
    try check(view.invalidateIfNeeded(), "First static frame was not rendered")
    state.time += 1
    try check(!view.invalidateIfNeeded(), "Unchanged reduced-motion frame was repainted")
    state.say("테스트 메시지")
    try check(view.invalidateIfNeeded(), "Speech did not invalidate static frame")
    state.time = state.bubbleEnd
    try check(view.invalidateIfNeeded(), "Expired speech remained on screen")
    view.setFrameSize(NSSize(width: 174, height: 202.5))
    try check(view.invalidateIfNeeded(), "Resize left a stale frame")
    state.motion = true
    _ = view.invalidateIfNeeded()
    state.time += 0.1
    try check(view.invalidateIfNeeded(), "Breathing stopped updating")
    // Switching visuals must preserve the running scene and invalidate even a frozen frame.
    state.clearScene(); state.setActivity(.banana, transition: false); state.motion = false
    state.bubbleEnd = 0
    try sprites.setStyle(.twoD)
    _ = view.invalidateIfNeeded()
    let originalImage = sprites["base", 0].image
    let unchangedTime = state.time, unchangedDeadline = state.nextChange
    try sprites.setStyle(.threeD)
    try check(view.invalidateIfNeeded(), "Style switch left a stale reduced-motion frame")
    try check(state.time == unchangedTime && state.nextChange == unchangedDeadline && state.activity == .banana,
              "Style switch reset the activity clock")
    try check(sprites["base", 0].image !== originalImage, "3D bank reused the 2D image")
    try check(sprites.sheets.values.reduce(0) { $0 + $1.count } == 258, "Incomplete 3D asset coverage (257 plus landed alias)")
    for (key, frames) in sprites.sheets {
        for sprite in frames {
            try check(sprite.image.width == 627 && sprite.image.height == 627, "3D frame size: \(key)")
            try check(sprite.silhouette.minX > 0 && sprite.silhouette.minY > 0 && sprite.silhouette.maxX < 627 && sprite.silhouette.maxY < 627,
                      "3D frame clipped or empty: \(key)")
        }
    }
    state.playAsset(sheet: "hairHeart", frames: Array(0..<6))
    state.time += 1.2
    let clipBefore = view.currentSprite()
    try sprites.setStyle(.twoD)
    try check(clipBefore.0 == "heartSmooth" && view.currentSprite().0 == "hairHeart" && view.currentSprite().1 == clipBefore.1 / 4, "Style switch restarted special animation")
    try check(sprites["base", 0].image === originalImage, "2D originals were not restored")
    state.toggleVisibility()
    let hiddenClipTime = state.time
    _ = state.advance(by: 60, now: now)
    try check(state.time == hiddenClipTime && state.assetClip != nil, "Hidden special animation did not pause")
    state.toggleVisibility()
    _ = state.advance(by: 10, now: now)
    try check(state.assetClip == nil, "Special animation did not return to activity")
    state.playAsset(sheet: "reels", frames: Array(0..<4)); state.setMotion(false)
    try check(state.assetClip == nil, "Reduced motion left a special clip running")
    state.clearScene(); state.motion = true; state.automatic = false
    state.setActivity(.banana, transition: false)
    let oldNextWalk = state.nextWalk, oldNextChange = state.nextChange
    state.set3DTransitions(true)
    try check(state.nextWalk == oldNextWalk && state.nextChange == oldNextChange, "Faster transitions changed automatic activity intervals")
    state.setActivity(.sleep)
    let quick = state.transition!
    try check(quick.stepDuration == 0.14 && quick.duration < Double(quick.route.count) * 0.22, "3D transition is not faster")
    try sprites.setStyle(.threeD)
    state.time = quick.start + 0.08
    try check(view.currentSprite().0 == "transitionMid" && view.currentSprite().1 == 0, "3D transition skipped its real middle pose")
    let phaseBefore = (state.time - quick.start) / quick.stepDuration
    state.set3DTransitions(false)
    let switched = state.transition!
    try check(abs((state.time - switched.start) / switched.stepDuration - phaseBefore) < 0.00001,
              "Mode switch jumped in the middle of a transition")
    try sprites.setStyle(.twoD)
    try check(view.currentSprite().0 == "transition", "2D requested a 3D-only midpoint")
    state.clearScene(); state.motion = true
    try sprites.setStyle(.threeD)
    state.activity = .phone; state.time = 10.25
    try check(view.currentSprite().0 == "phoneSmooth", "3D phone idle did not animate")
    state.dropStart = state.time - 3.5
    try check(view.currentSprite().0 == "pickupSmooth" && view.currentSprite().1 == 2, "Pickup skipped interpolated reach")
    state.clearScene()
    var smoothWalk = Walk(from: 0, to: 400, start: state.time - 2)
    smoothWalk.frame = 2; smoothWalk.smoothFrame = 9
    state.walk = smoothWalk
    try check(view.currentSprite().0 == "walkSmooth" && view.currentSprite().1 == 9, "Walking skipped sub-stride frame")
    smoothWalk.pausedAt = state.time; state.walk = smoothWalk
    try check(view.currentSprite().0 == "glanceSmooth" && view.currentSprite().1 == 9, "Paused glance changed stride phase")
    try sprites.setStyle(.twoD)
    try check(view.currentSprite().0 == "glance" && view.currentSprite().1 == 2, "2D stride fallback changed")
    state.clearScene()
    for from in Activity.allCases {
        for to in Activity.allCases {
            let route = PoseTransition.route(from: from, to: to)
            for (a, b) in zip(route, route.dropFirst()) {
                try check(PoseTransition.midpoint(from: a, to: b) != nil, "Missing transition edge \(a)-\(b)")
            }
        }
    }
    if let output = ProcessInfo.processInfo.environment["KIKKI_PREVIEW_DIR"] {
        let folder = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        view.setFrameSize(NSSize(width: 464, height: 540))
        for style in VisualStyle.allCases {
            try sprites.setStyle(style)
            for activity in Activity.allCases {
                state.setActivity(activity, transition: false); state.bubbleEnd = 0
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw TestFailure(description: "Preview bitmap") }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw TestFailure(description: "Preview PNG") }
                try png.write(to: folder.appendingPathComponent("\(style.rawValue)-\(activity.rawValue).png"))
            }
        }
    }
    panel.close()
    print("SELF-TEST PASSED: \(checks) checks (behavior, timers, atlas loading, rendering, interaction bounds)")
}
