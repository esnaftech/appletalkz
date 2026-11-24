import SwiftUI
import AVKit

struct PlayerContainer: View {
    let item: MediaItem
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            PlayerScreen(item: item).ignoresSafeArea()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
    }
}

struct PlayerScreen: UIViewControllerRepresentable {
    let item: MediaItem
    @EnvironmentObject var store: LibraryStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store, item: item) }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.player = context.coordinator.player
        context.coordinator.begin()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        let store: LibraryStore
        let item: MediaItem
        let player: AVPlayer
        private var timeObserver: Any?
        private var endObserver: NSObjectProtocol?

        init(store: LibraryStore, item: MediaItem) {
            self.store = store
            self.item = item
            self.player = AVPlayer(url: item.playbackURL ?? URL(fileURLWithPath: "/dev/null"))
        }

        func begin() {
            if item.position > 3 && item.progress < 0.95 {
                player.seek(to: CMTime(seconds: item.position, preferredTimescale: 600))
            }
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.save() }
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.finished() }
            }
            player.play()
        }

        func save() {
            guard let cur = player.currentItem else { return }
            let pos = player.currentTime().seconds
            let dur = cur.duration.seconds
            guard pos.isFinite else { return }
            store.updateProgress(id: item.id, position: pos, duration: dur.isFinite ? dur : item.duration)
        }

        func finished() {
            let dur = player.currentItem?.duration.seconds ?? 0
            if dur.isFinite && dur > 0 {
                store.updateProgress(id: item.id, position: dur, duration: dur)
            }
        }

        func stop() {
            save()
            player.pause()
            if let t = timeObserver { player.removeTimeObserver(t); timeObserver = nil }
            if let e = endObserver { NotificationCenter.default.removeObserver(e); endObserver = nil }
        }
    }
}
