import AppKit

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
if CommandLine.arguments.contains("--self-test") {
    do { try runSelfTests(); exit(0) }
    catch { fputs("SELF-TEST FAILED: \(error)\n", stderr); exit(1) }
}
// Launch Services usually reuses the running app. Also guard direct executable launches.
if let identifier = Bundle.main.bundleIdentifier,
   let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
    .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
    NSWorkspace.shared.openApplication(at: existing.bundleURL!, configuration: NSWorkspace.OpenConfiguration())
    exit(0)
}
let delegate = AppDelegate()
application.delegate = delegate
application.run()
