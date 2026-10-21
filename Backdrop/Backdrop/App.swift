import AppKit
import SwiftUI

@main
struct BackdropApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.menuBarSymbolName)
        }
        // Window style so the popover can show thumbnail previews (plain menus cannot).
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 340, height: 520)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar agent: stay out of the Dock, but allow Settings to become key.
        NSApp.setActivationPolicy(.accessory)
    }
}
