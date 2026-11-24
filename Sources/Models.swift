import Foundation

enum Paths {
    static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    static let support: URL = {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    static let thumbs: URL = {
        let u = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("thumbs")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()
}

enum MediaKind: String, Codable, CaseIterable {
    case movie, series
    var label: String { self == .movie ? "Film" : "Dizi" }
}

struct MediaItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var kind: MediaKind
    var seriesName: String?
    var season: Int?
    var episode: Int?
    var fileName: String?      // Documents klasörüne göre göreli yol
    var remoteURL: URL?
    var position: Double = 0
    var duration: Double = 0
    var favorite = false
    var addedAt = Date()
    var lastPlayedAt: Date?

    var progress: Double { duration > 0 ? min(position / duration, 1) : 0 }
    var watched: Bool { progress > 0.95 }
    var inProgress: Bool { position > 5 && !watched }
    var localURL: URL? { fileName.map { Paths.documents.appendingPathComponent($0) } }
    var playbackURL: URL? { localURL ?? remoteURL }

    var episodeLabel: String {
        guard let e = episode else { return title }
        return "S\(season ?? 1)·B\(e)"
    }
}

struct SeriesGroup: Identifiable {
    var id: String { name }
    let name: String
    let episodes: [MediaItem]
    var cover: MediaItem { episodes.first! }
    var watchedCount: Int { episodes.filter(\.watched).count }
}

enum NameParser {
    struct Result {
        var title: String
        var kind: MediaKind
        var series: String?
        var season: Int?
        var episode: Int?
    }

    static func parse(_ fileName: String) -> Result {
        let base = (fileName as NSString).lastPathComponent
        let stem = (base as NSString).deletingPathExtension
        let ns = stem as NSString

        let patterns = [#"[Ss](\d{1,2})[ ._-]?[Ee](\d{1,3})"#, #"\b(\d{1,2})x(\d{2,3})\b"#]
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p),
                  let m = re.firstMatch(in: stem, range: NSRange(location: 0, length: ns.length)),
                  let s = Int(ns.substring(with: m.range(at: 1))),
                  let e = Int(ns.substring(with: m.range(at: 2))) else { continue }
            let prefix = ns.substring(to: m.range.location)
            var series = clean(prefix)
            if series.isEmpty { series = clean((fileName as NSString).deletingLastPathComponent) }
            if series.isEmpty { series = "Dizi" }
            return Result(title: "\(series) S\(s)B\(e)", kind: .series, series: series, season: s, episode: e)
        }
        return Result(title: clean(stem), kind: .movie, series: nil, season: nil, episode: nil)
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -"))
    }
}
