import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoViewModel

    var body: some View {
        switch viewModel.authorizationStatus {
        case .authorized, .limited:
            MainTabView()
        case .denied, .restricted:
            VStack(spacing: 20) {
                Text("写真へのアクセスが許可されていません")
                Text("設定アプリからアクセスを許可してください。")
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        case .notDetermined:
            VStack {
                Text("写真へのアクセス許可を確認中...")
                ProgressView()
                    .onAppear {
                        viewModel.requestAuthorization()
                    }
            }
        @unknown default:
            EmptyView()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    
    var body: some View {
        TabView {
            PhotoSwipeView()
                .tabItem {
                    Label("整理", systemImage: "photo.on.rectangle.angled")
                }

            PendingPhotosView()
                .tabItem {
                    Label("保留", systemImage: "hourglass")
                }
                .badge(viewModel.pendingPhotos.isEmpty ? nil : "\(viewModel.pendingPhotos.count)")

            DeletedPhotosView()
                .tabItem {
                    Label("削除候補", systemImage: "trash")
                }
                .badge(viewModel.deletedPhotos.isEmpty ? nil : "\(viewModel.deletedPhotos.count)")
        }
    }
}
