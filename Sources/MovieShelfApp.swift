import SwiftUI
import AVFoundation

@main
struct MovieShelfApp: App {
    @StateObject private var store = LibraryStore()
    @Environment(\.scenePhase) private var phase

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onChange(of: phase) { _, new in
                    if new == .active { store.scanDocuments() }
                }
        }
    }
}
