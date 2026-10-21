import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.energyPaused {
                Text("Paused to save energy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
            }

            MenuItemRow(
                title: appState.isPlaying ? "Pause" : "Play",
                enabled: appState.selectedVideoURL != nil
            ) {
                appState.togglePlayPause()
            }

            MenuSeparator()

            MenuItemRow(title: "Settings…", shortcut: "⌘,") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }

            MenuItemRow(title: "Quit Backdrop", shortcut: "⌘Q") {
                appState.quit()
            }
        }
        .padding(5)
        .frame(width: 220)
        .onAppear {
            openSettingsIfNeeded()
        }
        .onChange(of: appState.shouldOpenSettings) { _, needed in
            if needed { openSettingsIfNeeded() }
        }
    }

    private func openSettingsIfNeeded() {
        guard appState.shouldOpenSettings else { return }
        // Defer so the menu-bar agent is ready to present the Settings scene.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard appState.shouldOpenSettings else { return }
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
            appState.acknowledgeSettingsOpened()
        }
    }
}

private struct MenuSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

private struct MenuItemRow: View {
    let title: String
    var shortcut: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Spacer(minLength: 12)
                if let shortcut {
                    Text(shortcut)
                        .foregroundStyle(isHovering && enabled ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovering && enabled ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(
                !enabled
                    ? Color.secondary
                    : (isHovering ? Color.white : Color.primary)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering in
            isHovering = enabled && hovering
        }
    }
}
