import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var videos: [URL] = []
    @Published var selectedVideoURL: URL?
    @Published var libraryFolderURL: URL?
    @Published var libraryFolderName: String = "None"
    @Published var isPlaying: Bool = false
    @Published var playbackRate: Double {
        didSet {
            defaults.set(playbackRate, forKey: Keys.playbackRate)
            engine.setRate(Float(playbackRate))
            applyPlaybackDesire()
        }
    }
    @Published var pauseOnBattery: Bool {
        didSet {
            defaults.set(pauseOnBattery, forKey: Keys.pauseOnBattery)
            applyPlaybackDesire()
        }
    }
    @Published var pauseInLowPowerMode: Bool {
        didSet {
            defaults.set(pauseInLowPowerMode, forKey: Keys.pauseInLowPowerMode)
            applyPlaybackDesire()
        }
    }
    @Published var openAtLogin: Bool {
        didSet {
            guard !isInitializing else { return }
            updateLoginItem()
        }
    }
    @Published private(set) var isOnBattery: Bool = false
    @Published private(set) var isLowPowerMode: Bool = false
    @Published private(set) var energyPaused: Bool = false
    /// Set on launch when there is no playable wallpaper; MenuBarView opens Settings.
    @Published var shouldOpenSettings = false

    /// Manual pause from the menu overrides energy auto-pause until the user resumes.
    private var manuallyPaused: Bool = false
    private var isInitializing = true

    private let defaults = UserDefaults.standard
    private let library = VideoLibrary()
    private let engine = WallpaperEngine()
    private let powerMonitor = PowerMonitor()
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let folderBookmark = "libraryFolderBookmark"
        static let selectedVideoPath = "selectedVideoPath"
        static let playbackRate = "playbackRate"
        static let pauseOnBattery = "pauseOnBattery"
        static let pauseInLowPowerMode = "pauseInLowPowerMode"
    }

    /// Menu bar glyph — pause icon when playback is stopped (manual or energy).
    var menuBarSymbolName: String {
        if selectedVideoURL == nil {
            return "photo.on.rectangle.angled"
        }
        if energyPaused || manuallyPaused || !isPlaying {
            return "pause.rectangle"
        }
        return "play.rectangle"
    }

    var selectedVideoName: String {
        selectedVideoURL?.deletingPathExtension().lastPathComponent ?? "None"
    }

    init() {
        playbackRate = defaults.object(forKey: Keys.playbackRate) as? Double ?? 1.0
        pauseOnBattery = defaults.bool(forKey: Keys.pauseOnBattery)
        pauseInLowPowerMode = defaults.bool(forKey: Keys.pauseInLowPowerMode)
        openAtLogin = SMAppService.mainApp.status == .enabled

        powerMonitor.$isOnBattery
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.isOnBattery = value
                self?.applyPlaybackDesire()
            }
            .store(in: &cancellables)

        powerMonitor.$isLowPowerMode
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.isLowPowerMode = value
                self?.applyPlaybackDesire()
            }
            .store(in: &cancellables)

        library.$videos
            .receive(on: RunLoop.main)
            .sink { [weak self] videos in
                self?.videos = videos
                self?.ensureSelectionStillValid()
            }
            .store(in: &cancellables)

        restoreLibraryFolder()
        engine.startMonitoringDisplays()
        isInitializing = false
        if selectedVideoURL == nil {
            shouldOpenSettings = true
        }
    }

    func acknowledgeSettingsOpened() {
        shouldOpenSettings = false
    }

    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Select a folder of videos to use as your wallpaper library."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        setLibraryFolder(url)
    }

    func selectVideo(_ url: URL) {
        selectedVideoURL = url
        defaults.set(url.path, forKey: Keys.selectedVideoPath)
        manuallyPaused = false
        engine.load(url: url, rate: Float(playbackRate))
        isPlaying = true
        applyPlaybackDesire()
    }

    func togglePlayPause() {
        if manuallyPaused || energyPaused || !isPlaying {
            manuallyPaused = false
            if selectedVideoURL != nil {
                isPlaying = true
                applyPlaybackDesire()
            }
        } else {
            manuallyPaused = true
            engine.pause()
            isPlaying = false
            energyPaused = false
        }
    }

    func quit() {
        engine.tearDown()
        library.stopAccessing()
        powerMonitor.stop()
        NSApp.terminate(nil)
    }

    // MARK: - Private

    private func setLibraryFolder(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: Keys.folderBookmark)
            libraryFolderURL = url
            libraryFolderName = url.lastPathComponent
            library.setFolder(url)
            if let first = library.videos.first {
                selectVideo(first)
            } else {
                selectedVideoURL = nil
                defaults.removeObject(forKey: Keys.selectedVideoPath)
                engine.tearDown()
                isPlaying = false
            }
        } catch {
            NSLog("Backdrop: failed to bookmark folder: \(error.localizedDescription)")
        }
    }

    private func restoreLibraryFolder() {
        guard let bookmark = defaults.data(forKey: Keys.folderBookmark) else { return }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                let refreshed = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                defaults.set(refreshed, forKey: Keys.folderBookmark)
            }
            libraryFolderURL = url
            libraryFolderName = url.lastPathComponent
            library.setFolder(url)

            if let path = defaults.string(forKey: Keys.selectedVideoPath) {
                let saved = URL(fileURLWithPath: path)
                if library.videos.contains(where: { $0.path == saved.path }),
                   FileManager.default.isReadableFile(atPath: saved.path) {
                    selectVideo(saved)
                } else {
                    // Previous wallpaper is missing — clear it and let launch open Settings.
                    selectedVideoURL = nil
                    defaults.removeObject(forKey: Keys.selectedVideoPath)
                    NSLog("Backdrop: saved wallpaper not found: \(path)")
                }
            }
        } catch {
            NSLog("Backdrop: failed to restore folder bookmark: \(error.localizedDescription)")
        }
    }

    private func ensureSelectionStillValid() {
        guard let selected = selectedVideoURL else { return }
        if !videos.contains(where: { $0.path == selected.path }) {
            if let first = videos.first {
                selectVideo(first)
            } else {
                selectedVideoURL = nil
                engine.tearDown()
                isPlaying = false
            }
        }
    }

    private func applyPlaybackDesire() {
        guard selectedVideoURL != nil else {
            energyPaused = false
            isPlaying = false
            return
        }

        if manuallyPaused {
            energyPaused = false
            engine.pause()
            isPlaying = false
            return
        }

        let shouldEnergyPause =
            (pauseOnBattery && isOnBattery) ||
            (pauseInLowPowerMode && isLowPowerMode)

        energyPaused = shouldEnergyPause
        if shouldEnergyPause {
            engine.pause()
            isPlaying = false
        } else {
            engine.play(rate: Float(playbackRate))
            isPlaying = true
        }
    }

    private func updateLoginItem() {
        do {
            if openAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Backdrop: login item update failed: \(error.localizedDescription)")
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
