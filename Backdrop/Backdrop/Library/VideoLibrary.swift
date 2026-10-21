import Foundation

/// Scans a user-selected folder for video files. Selection of which video to play
/// is owned by AppState — this type only maintains the library list.
@MainActor
final class VideoLibrary: ObservableObject {
    @Published private(set) var videos: [URL] = []

    private var folderURL: URL?
    private var isAccessing = false
    private var directorySource: DispatchSourceFileSystemObject?
    private let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "mpeg", "mpg", "avi"]

    func setFolder(_ url: URL) {
        stopAccessing()
        folderURL = url
        isAccessing = url.startAccessingSecurityScopedResource()
        rescan()
        startWatching(url)
    }

    func stopAccessing() {
        directorySource?.cancel()
        directorySource = nil
        if isAccessing, let folderURL {
            folderURL.stopAccessingSecurityScopedResource()
        }
        isAccessing = false
    }

    func rescan() {
        guard let folderURL else {
            videos = []
            return
        }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        videos = contents
            .filter { url in
                videoExtensions.contains(url.pathExtension.lowercased())
            }
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    private func startWatching(_ url: URL) {
        directorySource?.cancel()
        directorySource = nil

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            self?.rescan()
        }
        source.setCancelHandler {
            close(fd)
        }
        directorySource = source
        source.resume()
    }
}
