import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""

    private var filteredVideos: [URL] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.videos }
        return appState.videos.filter {
            $0.deletingPathExtension().lastPathComponent
                .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            library
            Divider()
            playback
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: - Library

    private var library: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Library")

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(appState.libraryFolderName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Button("Change Folder…") {
                    appState.chooseLibraryFolder()
                }
                .controlSize(.small)
            }

            if appState.videos.isEmpty {
                Text("No videos found. Choose a folder containing mp4, mov, or m4v files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Wallpaper")
                        Text(appState.selectedVideoName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                    .font(.callout)

                    TextField("Search videos", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)

                    if filteredVideos.isEmpty {
                        Text("No videos match “\(searchText)”.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                    } else {
                        VideoPickerGrid(
                            videos: filteredVideos,
                            selected: appState.selectedVideoURL,
                            onSelect: { appState.selectVideo($0) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Playback

    private var playback: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Playback")

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Pause on battery", isOn: $appState.pauseOnBattery)
                Toggle("Pause in Low Power Mode", isOn: $appState.pauseInLowPowerMode)
                Toggle("Open at Login", isOn: $appState.openAtLogin)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text(String(format: "%g×", appState.playbackRate))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("0.25×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $appState.playbackRate, in: 0.25...2.0, step: 0.25)
                    Text("2×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Pausing keeps the current frame on your desktop.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }
}
