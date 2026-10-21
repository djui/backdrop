import AVFoundation
import AppKit
import CoreGraphics

/// Owns one looping muted AVQueuePlayer and one desktop-level window per display.
@MainActor
final class WallpaperEngine {
    private struct Session {
        let window: NSWindow
        let view: VideoPlayerView
    }

    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var sessions: [CGDirectDisplayID: Session] = [:]
    private var currentURL: URL?
    private var currentRate: Float = 1.0
    private var screenObserver: NSObjectProtocol?

    func startMonitoringDisplays() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildWindowsPreservingPlayback()
            }
        }
    }

    func load(url: URL, rate: Float) {
        currentURL = url
        currentRate = rate

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        let looper = AVPlayerLooper(player: player, templateItem: item)

        self.looper = looper
        self.queuePlayer = player

        ensureWindows()
        for session in sessions.values {
            session.view.attach(player: player)
        }

        player.playImmediately(atRate: rate)
    }

    func play(rate: Float) {
        currentRate = rate
        guard let player = queuePlayer else { return }
        player.playImmediately(atRate: rate)
    }

    func pause() {
        queuePlayer?.pause()
    }

    func setRate(_ rate: Float) {
        currentRate = rate
        guard let player = queuePlayer, player.rate > 0 else { return }
        player.rate = rate
    }

    func tearDown() {
        pause()
        looper?.disableLooping()
        looper = nil
        queuePlayer?.removeAllItems()
        queuePlayer = nil
        currentURL = nil

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }

        for session in sessions.values {
            session.window.contentView = nil
            session.window.orderOut(nil)
            session.window.close()
        }
        sessions.removeAll()
    }

    private func rebuildWindowsPreservingPlayback() {
        let rate = currentRate
        let wasPlaying = (queuePlayer?.rate ?? 0) > 0

        for session in sessions.values {
            session.window.contentView = nil
            session.window.orderOut(nil)
            session.window.close()
        }
        sessions.removeAll()

        ensureWindows()
        if let player = queuePlayer {
            for session in sessions.values {
                session.view.attach(player: player)
            }
            if wasPlaying, currentURL != nil {
                player.playImmediately(atRate: rate)
            }
        }
    }

    private func ensureWindows() {
        let screens = NSScreen.screens
        var seen = Set<CGDirectDisplayID>()

        for screen in screens {
            let displayID = screen.displayID
            seen.insert(displayID)
            if sessions[displayID] != nil {
                sessions[displayID]?.window.setFrame(screen.frame, display: false)
                continue
            }

            let window = DesktopWindow.make(for: screen)
            let view = VideoPlayerView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.autoresizingMask = [.width, .height]
            if let player = queuePlayer {
                view.attach(player: player)
            }
            window.contentView = view
            sessions[displayID] = Session(window: window, view: view)
        }

        for id in sessions.keys where !seen.contains(id) {
            if let session = sessions.removeValue(forKey: id) {
                session.window.contentView = nil
                session.window.orderOut(nil)
                session.window.close()
            }
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        if let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return CGDirectDisplayID(number.uint32Value)
        }
        return CGMainDisplayID()
    }
}
