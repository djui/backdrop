import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            currentVideo
                .padding(.horizontal, 6)
                .padding(.bottom, 8)

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

            // Keep the library inside the same block as Play so we only need
            // one separator before Settings (avoids the double-hairline look).
            if !appState.videos.isEmpty {
                MenuVideoList(
                    videos: appState.videos,
                    selected: appState.selectedVideoURL,
                    onSelect: { appState.selectVideo($0) }
                )
                .padding(.top, 4)
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
        .frame(width: 280)
    }

    @ViewBuilder
    private var currentVideo: some View {
        if let url = appState.selectedVideoURL {
            VStack(alignment: .leading, spacing: 6) {
                VideoThumbnailView(url: url)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(appState.selectedVideoName)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .padding(.horizontal, 4)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 100)
                    .overlay {
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                Text("No video selected")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// Single hairline — one only between major sections.
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

private struct MenuVideoList: View {
    let videos: [URL]
    let selected: URL?
    let onSelect: (URL) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(videos, id: \.path) { url in
                    MenuVideoRow(
                        url: url,
                        isSelected: url.path == selected?.path,
                        onSelect: onSelect
                    )
                }
            }
        }
        // Fixed height so an empty/collapsed ScrollView can't leave two separators touching.
        .frame(height: 180)
    }
}

private struct MenuVideoRow: View {
    let url: URL
    let isSelected: Bool
    let onSelect: (URL) -> Void

    @State private var isHovering = false

    private var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        Button {
            onSelect(url)
        } label: {
            HStack(spacing: 8) {
                VideoThumbnailView(url: url)
                    .frame(width: 56, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Text(name)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovering ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(isHovering ? Color.white : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
        .onHover { isHovering = $0 }
    }
}
