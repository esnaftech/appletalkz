import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var playing: MediaItem?
    @State private var showImporter = false
    @State private var showAdd = false
    @State private var query = ""

    private var q: String { query.trimmingCharacters(in: .whitespaces) }

    private func matches(_ s: String) -> Bool { q.isEmpty || s.localizedCaseInsensitiveContains(q) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if store.items.isEmpty { emptyState }

                    let cont = store.continueWatching.filter { matches($0.title) }
                    if !cont.isEmpty {
                        section("Devam Et") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(cont) { MediaCard(item: $0, width: 260, onPlay: play) }
                                }.padding(.horizontal)
                            }
                        }
                    }

                    let favs = store.items.filter { $0.favorite && matches($0.title) }
                    if !favs.isEmpty {
                        section("Favoriler") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(favs) { MediaCard(item: $0, width: 200, onPlay: play) }
                                }.padding(.horizontal)
                            }
                        }
                    }

                    let movies = store.movies.filter { matches($0.title) }
                    if !movies.isEmpty {
                        section("Filmler") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 18) {
                                ForEach(movies) { MediaCard(item: $0, width: nil, onPlay: play) }
                            }.padding(.horizontal)
                        }
                    }

                    let groups = store.seriesGroups.filter { matches($0.name) }
                    if !groups.isEmpty {
                        section("Diziler") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 18) {
                                ForEach(groups) { g in
                                    NavigationLink(value: g.name) { SeriesCard(group: g) }
                                        .buttonStyle(.plain)
                                }
                            }.padding(.horizontal)
                        }
                    }

                    if !store.skippedFiles.isEmpty { skippedNote }
                }
                .padding(.vertical)
            }
            .navigationTitle("MovieShelf")
            .searchable(text: $query, prompt: "Ara")
            .navigationDestination(for: String.self) { name in
                SeriesView(name: name, onPlay: play)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showImporter = true } label: { Label("Dosya içe aktar", systemImage: "square.and.arrow.down") }
                        Button { showAdd = true } label: { Label("Bağlantı ekle", systemImage: "link") }
                        Button { store.scanDocuments() } label: { Label("Yenile", systemImage: "arrow.clockwise") }
                    } label: { Image(systemName: "plus.circle.fill") }
                }
            }
        }
        .fullScreenCover(item: $playing) { item in
            PlayerContainer(item: item) { playing = nil }
                .environmentObject(store)
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { store.importFiles(urls) }
        }
        .sheet(isPresented: $showAdd) { AddURLView() }
    }

    private func play(_ item: MediaItem) { playing = item }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.bold()).padding(.horizontal)
            content()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack").font(.system(size: 54)).foregroundStyle(.secondary)
            Text("Kitaplık boş").font(.title3.bold())
            Text("Sağ üstteki + ile dosya aktar ya da bağlantı ekle.\nBilgisayardan USB ile de dosya gönderebilirsin (Dosya Paylaşımı).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal)
    }

    private var skippedNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(store.skippedFiles.count) dosya desteklenmiyor", systemImage: "exclamationmark.triangle")
                .font(.subheadline.bold())
            Text("MKV/AVI gibi formatlar iOS'un yerleşik oynatıcısında açılmaz. Bunları MP4 (H.264/HEVC) olarak dönüştür.")
                .font(.footnote).foregroundStyle(.secondary)
            Text(store.skippedFiles.prefix(5).joined(separator: "\n"))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Kartlar

struct PosterView: View {
    let item: MediaItem
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo.opacity(0.6), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: item.kind == .movie ? "film" : "tv").font(.largeTitle).foregroundStyle(.white.opacity(0.5))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: item.id) { image = await Thumbs.image(for: item) }
    }
}

struct MediaCard: View {
    @EnvironmentObject var store: LibraryStore
    let item: MediaItem
    let width: CGFloat?
    let onPlay: (MediaItem) -> Void

    var body: some View {
        Button { onPlay(item) } label: {
            VStack(alignment: .leading, spacing: 6) {
                PosterView(item: item)
                    .overlay(alignment: .bottom) {
                        if item.progress > 0 {
                            ProgressView(value: item.progress).tint(.red).padding(8)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if item.watched {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).padding(6)
                        } else if item.favorite {
                            Image(systemName: "heart.fill").foregroundStyle(.pink).padding(6)
                        }
                    }
                Text(item.title).font(.subheadline.bold()).lineLimit(2).multilineTextAlignment(.leading)
            }
            .frame(width: width)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { store.toggleFavorite(item) } label: {
                Label(item.favorite ? "Favoriden çıkar" : "Favorile", systemImage: "heart")
            }
            Button { store.markWatched(item) } label: { Label("İzlendi işaretle", systemImage: "checkmark.circle") }
            Button { store.resetProgress(item) } label: { Label("Baştan başlat", systemImage: "arrow.counterclockwise") }
            Button(role: .destructive) { store.delete(item) } label: { Label("Sil", systemImage: "trash") }
        }
    }
}

struct SeriesCard: View {
    let group: SeriesGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterView(item: group.cover)
            Text(group.name).font(.subheadline.bold()).lineLimit(2)
            Text("\(group.episodes.count) bölüm · \(group.watchedCount) izlendi")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Dizi ekranı

struct SeriesView: View {
    @EnvironmentObject var store: LibraryStore
    let name: String
    let onPlay: (MediaItem) -> Void

    var body: some View {
        let eps = store.group(named: name)?.episodes ?? []
        let seasons = Dictionary(grouping: eps) { $0.season ?? 1 }.keys.sorted()
        List {
            if let next = eps.first(where: { $0.inProgress }) ?? eps.first(where: { !$0.watched }) {
                Button { onPlay(next) } label: {
                    Label(next.inProgress ? "Devam et · \(next.episodeLabel)" : "Oynat · \(next.episodeLabel)",
                          systemImage: "play.fill")
                        .font(.headline)
                }
            }
            ForEach(seasons, id: \.self) { s in
                Section("Sezon \(s)") {
                    ForEach(eps.filter { ($0.season ?? 1) == s }) { ep in
                        Button { onPlay(ep) } label: {
                            HStack(spacing: 12) {
                                PosterView(item: ep).frame(width: 110)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ep.episode.map { "Bölüm \($0)" } ?? ep.title).font(.subheadline.bold())
                                    if ep.progress > 0 { ProgressView(value: ep.progress).tint(.red) }
                                }
                                Spacer()
                                if ep.watched { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) { store.delete(ep) } label: { Label("Sil", systemImage: "trash") }
                            Button { store.markWatched(ep) } label: { Label("İzlendi", systemImage: "checkmark") }.tint(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bağlantı ekle

struct AddURLView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var urlText = ""
    @State private var kind: MediaKind = .movie
    @State private var series = ""

    private var url: URL? {
        let t = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: t), u.scheme?.hasPrefix("http") == true else { return nil }
        return u
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Başlık", text: $title)
                TextField("Video bağlantısı (mp4 / m3u8)", text: $urlText)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Tür", selection: $kind) {
                    ForEach(MediaKind.allCases, id: \.self) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
                if kind == .series {
                    TextField("Dizi adı", text: $series)
                    Text("Başlığa S1E3 gibi sezon/bölüm yazarsan otomatik sıralanır.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Bağlantı ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") {
                        if let url {
                            store.addRemote(title: title.isEmpty ? url.lastPathComponent : title,
                                            url: url, kind: kind, seriesName: series)
                            dismiss()
                        }
                    }.disabled(url == nil)
                }
            }
        }
    }
}
