import Foundation

enum Activity: Int, CaseIterable {
    case banana, phone, sleep, game

    var title: String { ["바나나 먹기", "폰 보기", "낮잠 자기", "게임하기"][rawValue] }
    var line: String {
        ["이거 먹고 쉴래.", "이것만 보고 잘게.", "나 쫌만 더…", "나 한 판만 하고."][rawValue]
    }
    var duration: Double {
        Double.random(in: 120...240)
    }
    func next(roll: Int, excluding previous: Activity? = nil) -> Activity {
        if self == .sleep { return .phone }
        let choices = Activity.allCases.filter { $0 != self && $0 != previous }
        return choices[roll % choices.count]
    }
}

struct Walk {
    let from: Double
    let to: Double
    let start: Double
    var pausedAt: Double?
    var pauseUntil = 0.0
    var pausedDuration = 0.0
    var frame = 0
    var duration: Double { abs(to - from) / 104 + 0.45 }
    var direction: Double { to > from ? 1 : -1 }

    static func destination(from: Double, low: Double, high: Double, across: Bool, offset: Double) -> Double {
        let high = max(low, high)
        if across { return from >= (low + high) / 2 ? low : high }
        var target = max(low, min(high, from + offset))
        if abs(target - from) < 180 { target = max(low, min(high, from - offset)) }
        return target
    }

    static func distance(at time: Double, total: Double, duration: Double) -> Double {
        let ramp = 0.45
        let speed = total / (duration - ramp)
        if time <= 0 { return 0 }
        if time >= duration { return total }
        func eased(_ t: Double) -> Double { speed * (t / 2 - ramp * sin(.pi * t / ramp) / (2 * .pi)) }
        if time < ramp { return eased(time) }
        if time > duration - ramp { return total - eased(duration - time) }
        return speed * (time - ramp / 2)
    }
}

struct PoseTransition {
    let start: Double
    let route: [Int]
    static func route(from: Activity, to: Activity) -> [Int] {
        if from == to { return [] }
        if from == .sleep && to == .phone { return [11,10,9,8,7,4,5] }
        if from == .phone && to == .sleep { return [5,6,7,8,9,10,11] }
        if from == .sleep { return [11,10,9,8,7,4,3,2,1,0] }
        if to == .sleep { return [0,1,2,3,4,7,8,9,10,11] }
        if from == .phone { return [5,6,4,3,2,1,0] }
        if to == .phone { return [0,1,2,3,4,5] }
        return []
    }
}

final class PetState {
    var activity = Activity.phone
    var previousActivity: Activity?
    var automatic = true
    var motion = true
    var roaming = true
    var visible = true
    var pressed = false
    var dragging = false
    var lifted = false
    var time = 0.0
    var nextChange = Activity.phone.duration
    var nextWalk = Double.random(in: 120...240)
    var nextRest = Double.random(in: 120...240)
    var nextExpression = Double.random(in: 120...240)
    var nextDrop = Double.random(in: 120...240)
    var nextBack = Double.random(in: 120...240)
    var quietUntil = 0.0
    var attentionEnd = 0.0
    var expressionEnd = 0.0
    var memeFaceEnd = 0.0
    var dialogue: MischiefDialogue?
    var sulkEnd = 0.0
    var walk: Walk?
    var transition: PoseTransition?
    var restStart: Double?
    var dropStart: Double?
    private var dropSpoke = false
    var backEnd: Double?
    var peekStart = -10.0
    var liftStart = 0.0
    var message = "안녕하숭~"
    var bubbleEnd = 6.0
    var classEnd: Date?
    var pendingClassEnd = false

    var busy: Bool {
        pressed || dragging || walk != nil || transition != nil || restStart != nil ||
        dropStart != nil || backEnd != nil || time < attentionEnd || time < sulkEnd || time < expressionEnd
    }

    var walkIsDue: Bool { roaming && motion && activity != .sleep && time >= nextWalk }

    func say(_ text: String, seconds: Double = 6) { message = text; bubbleEnd = time + seconds }

    func sayContext(_ context: String, fallback: String, seconds: Double = 6) {
        let line = dialogue?.pick(context: context, fallback: fallback, time: time,
                                  roll: Int.random(in: 0..<100), selection: Int.random(in: 0..<10000))
        say(line?.text ?? fallback, seconds: seconds)
        memeFaceEnd = 0
        if line?.isMeme == true && dialogue?.level == .normal && motion && activity != .sleep &&
            ["eatPoke", "phonePoke", "gamePoke", "playful", "gameCheer"].contains(context) {
            memeFaceEnd = time + 1.15
        }
    }

    func setMischiefLevel(_ level: MischiefLevel) {
        dialogue?.level = level
        memeFaceEnd = 0
        say(level.acknowledgement)
    }

    func startPhoneDrop() {
        dropStart = time
        dropSpoke = false
    }

    func setActivity(_ target: Activity, transition animate: Bool = true) {
        let route = PoseTransition.route(from: activity, to: target)
        if target != activity { previousActivity = activity }
        clearScene()
        activity = target
        nextChange = time + target.duration
        attentionEnd = 0
        sulkEnd = 0
        if motion && animate && !route.isEmpty { transition = PoseTransition(start: time, route: route) }
        quietUntil = max(quietUntil, time + (transition == nil ? 2 : Double(route.count) * 0.22 + 2.3))
    }

    func clearScene() {
        walk = nil; restStart = nil; dropStart = nil; backEnd = nil; transition = nil
        expressionEnd = 0; memeFaceEnd = 0; dropSpoke = false
    }

    func setMotion(_ enabled: Bool) {
        motion = enabled
        if !enabled { clearScene() }
    }

    func toggleVisibility() {
        pressed = false; dragging = false; lifted = false
        visible.toggle()
        if visible && pendingClassEnd {
            say("끝났다. 이제 쉬자.", seconds: 12)
            pendingClassEnd = false
        }
    }

    func poke() {
        if var scene = walk {
            if scene.pausedAt == nil { scene.pausedAt = time }
            scene.pauseUntil = time + 1
            walk = scene
            sayContext("walkPoke", fallback: "왜? 뭐? 산책하는 끼끼 처음 봐?", seconds: 1)
        } else if backEnd != nil {
            peekStart = time
            sayContext("backPoke", fallback: "왜, 뭐?", seconds: 3)
        } else {
            clearScene()
            attentionEnd = time + 2.3
            sayContext(["eatPoke", "phonePoke", "sleepPoke", "gamePoke"][activity.rawValue],
                       fallback: ["왜? 나 먹고 있잖아.", "왜애. 나 댓글 읽잖아.", "불렀으면 쓰다듬고 가…", "왜. 나도 누를 줄 알아."][activity.rawValue], seconds: 3)
        }
    }

    func startWalk(from: Double, to: Double) {
        guard motion, roaming, !busy, abs(to - from) >= 12 else { return }
        walk = Walk(from: from, to: to, start: time)
        sayContext("walk", fallback: "나 저쪽 갔다 올게.")
    }

    // Returns the horizontal position so the platform layer owns screen coordinates.
    func advance(by delta: Double, now: Date) -> Double? {
        if let end = classEnd, now >= end {
            classEnd = nil
            if visible { say("끝났다. 이제 쉬자.", seconds: 12) }
            else { pendingClassEnd = true }
        }
        guard visible else { return nil }
        time += max(0, delta)
        if let scene = transition, time - scene.start >= Double(scene.route.count) * 0.22 + 0.3 { transition = nil }
        if let start = restStart, time - start >= [4.3,25.3,90.3,4.3][activity.rawValue] { restStart = nil }
        if let start = dropStart {
            if time - start >= 1.55 && !dropSpoke {
                sayContext("phoneDrop", fallback: "못 본 척 해줘~~")
                dropSpoke = true
            }
            if time - start >= 5.6 { dropStart = nil; nextDrop = time + Double.random(in: 120...240) }
        }
        if let end = backEnd, time >= end { backEnd = nil; nextBack = time + Double.random(in: 120...240) }
        var position: Double?
        if var scene = walk {
            if let paused = scene.pausedAt {
                if pressed || time < scene.pauseUntil { return nil }
                scene.pausedDuration += max(paused, scene.pauseUntil) - paused
                scene.pausedAt = nil
            }
            let age = time - scene.start - scene.pausedDuration - 1.1
            let travel = Walk.distance(at: age, total: abs(scene.to - scene.from), duration: scene.duration)
            position = scene.from + scene.direction * travel
            scene.frame = Int((travel / 56).truncatingRemainder(dividingBy: 1) * 8)
            walk = scene
            if age >= scene.duration + 0.8 {
                walk = nil; nextWalk = time + Double.random(in: 120...240); quietUntil = max(quietUntil, time + 3)
            }
        }
        if automatic && !busy && time >= nextChange {
            let finishedGame = activity == .game
            setActivity(activity.next(roll: Int.random(in: 0..<100), excluding: previousActivity))
            sayContext(finishedGame ? "gameLoss" : activity == .game ? "gameStart" : "pose",
                       fallback: finishedGame ? "한 판 끝. 쫌 쉬자." : activity.line)
        }
        if motion && !busy && time >= quietUntil && !walkIsDue {
            // Pick the oldest eligible deadline so one kind of action cannot starve the others.
            var choices = [("rest", nextRest)]
            if activity == .phone { choices.append(("drop", nextDrop)) }
            if activity != .sleep {
                choices.append(("expression", nextExpression))
                if automatic { choices.append(("back", nextBack)) }
            }
            let next = choices.filter { $0.1 <= time }.min { $0.1 < $1.1 }?.0
            switch next {
            case "rest":
                restStart = time; nextRest = time + Double.random(in: 120...240)
                quietUntil = time + [4.3,25.3,90.3,4.3][activity.rawValue] + Double.random(in: 120...240)
            case "drop":
                startPhoneDrop()
                quietUntil = time + 5.6 + Double.random(in: 120...240)
            case "back":
                backEnd = time + Double.random(in: 35...75)
                quietUntil = backEnd! + Double.random(in: 120...240)
            case "expression":
                expressionEnd = time + 1.15; nextExpression = time + Double.random(in: 120...240)
                quietUntil = expressionEnd + Double.random(in: 120...240)
                sayContext(activity == .game ? "gameCheer" : "playful", fallback: "아 왜 웃어.")
            default: break
            }
        }
        return position
    }
}
