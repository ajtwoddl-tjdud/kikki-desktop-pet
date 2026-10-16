import AppKit
import CryptoKit

// Offscreen CPU benchmark, not a battery/GPU measurement. Build with -D OPTIMIZED
// for change-driven invalidation, or without it to reproduce repaint-every-tick behavior.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let sprites = try Sprites(directory: URL(fileURLWithPath: CommandLine.arguments[1]))
let frameCount = 600
for scenario in ["phone-bubble", "reduced-motion", "walk"] {
    let state = PetState()
    state.automatic = false; state.time = 20
    state.motion = scenario != "reduced-motion"
    state.bubbleEnd = scenario == "phone-bubble" ? 1000 : 0
    if scenario == "walk" { state.walk = Walk(from: 0, to: 100_000, start: 0) }
    let view = PetView(state: state, sprites: sprites)
    let panel = PetPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false; panel.contentView = view
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    var draws = 0
    let start = clock()
    for frame in 0..<frameCount {
        autoreleasepool {
            state.time = 20 + Double(frame) / 30
            if state.walk != nil { state.walk?.frame = (frame / 4) % 8 }
            #if OPTIMIZED
            let changed = view.invalidateIfNeeded()
            #else
            let changed = true
            #endif
            if changed {
                memset(bitmap.bitmapData!, 0, bitmap.bytesPerRow * bitmap.pixelsHigh)
                view.cacheDisplay(in: view.bounds, to: bitmap); draws += 1
            }
        }
    }
    let milliseconds = Double(clock() - start) / Double(CLOCKS_PER_SEC) * 1000
    let pixels = Data(bytes: bitmap.bitmapData!, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    let hash = SHA256.hash(data: pixels).map { String(format: "%02x", $0) }.joined()
    let result: [String: Any] = ["scenario": scenario, "frames": frameCount, "draws": draws,
                               "cpu_ms": milliseconds, "pixels_sha256": hash]
    print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
    panel.close()
}
