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
    try check(!state.pendingClassEnd && state.message.contains("고생했어"), "Timer completion was lost on show")
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
    try check(gentle.message == "응? 너 보고 있어." && gentle.memeFaceEnd == 0, "Off-mode poke did not use the ordinary reaction")
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
    panel.close()
    print("SELF-TEST PASSED: \(checks) checks (behavior, timers, atlas loading, rendering, interaction bounds)")
}
