import SwiftUI
import AppKit

@main
struct MainCleanMacApp: App {
    @StateObject private var scanner = SystemScannerService()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("MainCleanMac") {
            ContentView()
                .environmentObject(scanner)
                .frame(minWidth: 1020, minHeight: 660)
        }
        .windowResizability(.contentMinSize)
    }
}
