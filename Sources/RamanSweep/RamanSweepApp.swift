import SwiftUI
import AppKit

@main
struct RamanSweepApp: App {
    @StateObject private var scanner = SystemScannerService()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("RamanSweep · Adventurous M-Series Cleaner") {
            ContentView()
                .environmentObject(scanner)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
    }
}
