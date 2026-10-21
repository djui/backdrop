import AppKit
import AVFoundation
import SwiftUI

/// Generates and caches a still frame for each video so the user can see what they are picking.
@MainActor
final class VideoThumbnailCache {
    static let shared = VideoThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    func thumbnail(for url: URL) async -> NSImage? {
        let key = cacheKey(for: url)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task.detached(priority: .utility) { await Self.generate(url: url) }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            cache.setObject(image, forKey: key as NSString)
        }
        return image
    }

    /// Path + modification date, so a replaced file gets a fresh thumbnail.
    private func cacheKey(for url: URL) -> String {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        return "\(url.path)#\(modified)"
    }

    private nonisolated static func generate(url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        // Sample ~10% in (capped at 3s) to skip black intro frames.
        var time = CMTime(seconds: 1, preferredTimescale: 600)
        if let duration = try? await asset.load(.duration), duration.isNumeric, duration.seconds > 0 {
            time = CMTime(seconds: min(duration.seconds * 0.1, 3), preferredTimescale: 600)
        }

        do {
            let result = try await generator.image(at: time)
            return NSImage(cgImage: result.image, size: .zero)
        } catch {
            NSLog("Backdrop: thumbnail failed for \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
}

/// A single thumbnail image that loads asynchronously.
struct VideoThumbnailView: View {
    let url: URL
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipped()
        .task(id: url) {
            image = nil
            failed = false
            let result = await VideoThumbnailCache.shared.thumbnail(for: url)
            image = result
            failed = result == nil
        }
    }
}

/// Narrow two-column thumbnail grid; scrolls when there are many videos.
struct VideoPickerGrid: View {
    let videos: [URL]
    let selected: URL?
    let onSelect: (URL) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(videos, id: \.path) { url in
                    tile(for: url)
                }
            }
            .padding(8)
        }
        .frame(height: 200)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private func tile(for url: URL) -> some View {
        let isSelected = url.path == selected?.path
        let name = url.deletingPathExtension().lastPathComponent

        return Button {
            onSelect(url)
        } label: {
            VStack(spacing: 2) {
                VideoThumbnailView(url: url)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(5)
                        }
                    }
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
