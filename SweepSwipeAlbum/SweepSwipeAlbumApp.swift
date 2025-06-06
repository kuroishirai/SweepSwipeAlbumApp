import SwiftUI

@main
struct SweepSwipeAlbumApp: App {
    @StateObject private var photoViewModel = PhotoViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoViewModel)
        }
    }
}
