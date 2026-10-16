import Foundation

enum UpdateSchedule {
    // Hidden pets have no periodic work. A pending class timer gets one deadline wakeup.
    static func interval(visible: Bool, motion: Bool, active: Bool) -> TimeInterval? {
        guard visible else { return nil }
        return motion ? (active ? 1.0 / 30 : 1.0 / 15) : 0.1
    }

    static func interval(for state: PetState) -> TimeInterval? {
        interval(visible: state.visible, motion: state.motion,
                 active: state.pressed || state.dragging || state.walk != nil || state.transition != nil ||
                    state.dropStart != nil || state.lifted || state.time < state.sulkEnd)
    }
}
