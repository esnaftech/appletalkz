import Foundation
import AVFoundation
import UIKit

@MainActor
final class LibraryStore: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var skippedFiles: [String] = []

    static let supported: Set<String> = ["mp4", "m4v", "mov"]
    static let unsupported: Set<String> = ["mkv", "avi", "wmv", "flv", "webm", "ts"]

    private let saveURL = Paths.support.appendingPathComponent("library.json")

    init() {
        load()
        scanDocuments()
    }

    // MARK: Gruplar

    var continueWatching: [MediaItem] {
        items.filter(\.inProgress).sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    var movies: [MediaItem] {
        items.filter { $0.kind == .movie }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var seriesGroups: [SeriesGroup] {
        let eps = items.filter { $0.kind == .series }
        let grouped = Dictionary(grouping: eps) { $0.seriesName ?? $0.title }
        return grouped.map { name, list in
            SeriesGroup(name: name, episodes: list.sorted {
                ($0.season ?? 0, $0.episode ?? 0, $0.title) < ($1.season ?? 0, $1.episode ?? 0, $1.title)
            })
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func group(named name: String) -> SeriesGroup? { seriesGroups.first { $0.name == name } }

    // MARK: Düzenleme

    func scanDocuments() {
        let fm = FileManager.default
        let base = Paths.documents.standardizedFileURL
        var found = Set<String>()
        var skipped: [String] = []

        if let en = fm.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey],
                                  options: [.skipsHiddenFiles]) {
            for case let url as URL in en {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                let full = url.standardizedFileURL.path
                guard full.count > base.path.count + 1 else { continue }
                let rel = String(full.dropFirst(base.path.count + 1))
                let ext = url.pathExtension.lowercased()
                if Self.supported.contains(ext) {
                    found.insert(rel)
                    if !items.contains(where: { $0.fileName == rel }) {
                        let p = NameParser.parse(rel)
                        items.append(MediaItem(title: p.title, kind: p.kind, seriesName: p.series,
                                               season: p.season, episode: p.episode, fileName: rel))
                    }
                } else if Self.unsupported.contains(ext) {
                    skipped.append(rel)
                }
            }
        }
        items.removeAll { $0.fileName != nil && !found.contains($0.fileName!) }
        skippedFiles = skipped
        save()
    }

    func importFiles(_ urls: [URL]) {
        let fm = FileManager.default
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            var dest = Paths.documents.appendingPathComponent(url.lastPathComponent)
            var n = 1
            while fm.fileExists(atPath: dest.path) {
                let stem = url.deletingPathExtension().lastPathComponent
                dest = Paths.documents.appendingPathComponent("\(stem) (\(n)).\(url.pathExtension)")
                n += 1
            }
            try? fm.copyItem(at: url, to: dest)
        }
        scanDocuments()
    }

    func addRemote(title: String, url: URL, kind: MediaKind, seriesName: String?) {
        let p = NameParser.parse(title)
        let useSeries = kind == .series
        items.append(MediaItem(
            title: title, kind: kind,
            seriesName: useSeries ? (seriesName?.isEmpty == false ? seriesName : (p.series ?? title)) : nil,
            season: useSeries ? p.season : nil, episode: useSeries ? p.episode : nil,
            remoteURL: url))
        save()
    }

    func delete(_ item: MediaItem) {
        if let f = item.localURL { try? FileManager.default.removeItem(at: f) }
        try? FileManager.default.removeItem(at: Paths.thumbs.appendingPathComponent("\(item.id).jpg"))
        items.removeAll { $0.id == item.id }
        save()
    }

    func toggleFavorite(_ item: MediaItem) {
        mutate(item.id) { $0.favorite.toggle() }
    }

    func markWatched(_ item: MediaItem) {
        mutate(item.id) {
            if $0.duration <= 0 { $0.duration = 1 }
            $0.position = $0.duration
        }
    }

    func resetProgress(_ item: MediaItem) {
        mutate(item.id) { $0.position = 0 }
    }

    func updateProgress(id: UUID, position: Double, duration: Double) {
        mutate(id) {
            $0.position = position
            if duration > 0 { $0.duration = duration }
            $0.lastPlayedAt = Date()
        }
    }

    private func mutate(_ id: UUID, _ change: (inout MediaItem) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        save()
    }

    // MARK: Kayıt

    private func load() {
        guard let d = try? Data(contentsOf: saveURL),
              let list = try? JSONDecoder().decode([MediaItem].self, from: d) else { return }
        items = list
    }

    private func save() {
        if let d = try? JSONEncoder().encode(items) { try? d.write(to: saveURL, options: .atomic) }
    }
}

enum Thumbs {
    static func image(for item: MediaItem) async -> UIImage? {
        let file = Paths.thumbs.appendingPathComponent("\(item.id).jpg")
        if let d = try? Data(contentsOf: file), let i = UIImage(data: d) { return i }
        guard let url = item.playbackURL else { return nil }

        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 800, height: 800)
        let dur = (try? await asset.load(.duration).seconds) ?? 0
        let secs = dur.isFinite && dur > 0 ? max(1, min(dur * 0.1, 180)) : 1
        guard let cg = try? await gen.image(at: CMTime(seconds: secs, preferredTimescale: 600)).image else { return nil }
        let img = UIImage(cgImage: cg)
        if let jpg = img.jpegData(compressionQuality: 0.8) { try? jpg.write(to: file) }
        return img
    }
}
