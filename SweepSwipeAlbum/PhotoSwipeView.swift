import SwiftUI
import Photos
import AVKit
import PhotosUI
import Combine // MARK: - 新規追加

struct PhotoSwipeView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    
    @State private var cardOffset: CGSize = .zero
    @State private var showAlbumList = false
    @State private var showResetAlert = false

    var body: some View {
        NavigationView {
            VStack {
                swipeArea
                
                Spacer()

                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .padding()
                }
                .disabled(!viewModel.canUndo)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text(viewModel.navigationTitle).font(.headline)
                        Text(viewModel.filteredPhotoAssets.isEmpty ? "0 / 0" : "\(viewModel.currentIndex + 1) / \(viewModel.filteredPhotoAssets.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("アルバム") { showAlbumList.toggle() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showResetAlert = true }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .sheet(isPresented: $showAlbumList) {
                AlbumListView()
            }
            .alert("「残す」をリセット", isPresented: $showResetAlert) {
                Button("リセットする", role: .destructive) {
                    self.viewModel.resetKeptPhotos()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("「残す」に保存した写真をリセットし、再度整理対象にしますか？この操作は元に戻せません。")
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var swipeArea: some View {
        ZStack {
            if viewModel.currentIndex + 1 < viewModel.filteredPhotoAssets.count {
                PhotoCardView(asset: viewModel.filteredPhotoAssets[viewModel.currentIndex + 1])
                    .scaleEffect(0.95)
                    .offset(y: -20)
                    .id("background_\(viewModel.filteredPhotoAssets[viewModel.currentIndex + 1].localIdentifier)")
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .cornerRadius(10)
                    .scaleEffect(0.95)
                    .offset(y: -20)
            }
            
            if viewModel.currentIndex < viewModel.filteredPhotoAssets.count {
                PhotoCardView(asset: viewModel.filteredPhotoAssets[viewModel.currentIndex])
                    .offset(cardOffset)
                    .rotationEffect(.degrees(Double(cardOffset.width / 25)))
                    .id("foreground_\(viewModel.filteredPhotoAssets[viewModel.currentIndex].localIdentifier)")
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in self.cardOffset = gesture.translation }
                            .onEnded { gesture in handleSwipe(translation: gesture.translation) }
                    )
            } else {
                VStack {
                    Text("このアルバムの整理は完了しました！")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func handleSwipe(translation: CGSize) {
        let swipeThreshold: CGFloat = 100
        
        if translation.width < -swipeThreshold {
            swipeCard(direction: .delete)
        } else if translation.width > swipeThreshold {
            swipeCard(direction: .keep)
        } else if translation.height < -swipeThreshold {
            swipeCard(direction: .pending)
        } else {
            withAnimation(.spring()) {
                self.cardOffset = .zero
            }
        }
    }

    private func swipeCard(direction: SwipeAction) {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        withAnimation(.easeOut(duration: 0.3)) {
            switch direction {
            case .delete:
                self.cardOffset = CGSize(width: -screenWidth, height: 0)
            case .keep:
                self.cardOffset = CGSize(width: screenWidth, height: 0)
            case .pending:
                self.cardOffset = CGSize(width: 0, height: -screenHeight * 1.5)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let swipedAsset = self.viewModel.filteredPhotoAssets[self.viewModel.currentIndex]
            self.viewModel.swipe(asset: swipedAsset, direction: direction)
            self.cardOffset = .zero
        }
    }
}


struct PhotoCardView: View {
    let asset: PHAsset
    private let photoManager = PhotoManager()
    
    @State private var image: UIImage? = nil
    @State private var playerItem: AVPlayerItem? = nil
    @State private var livePhoto: PHLivePhoto? = nil

    var body: some View {
        ZStack {
            Color(.systemGray4)
            
            switch asset.mediaType {
            case .image:
                if asset.mediaSubtypes.contains(.photoLive) {
                    if let livePhoto = livePhoto {
                        LivePhotoView(livePhoto: livePhoto, isMuted: true)
                    } else {
                        ProgressView()
                    }
                } else {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
            case .video:
                if let playerItem = playerItem {
                    VideoPlayerView(playerItem: playerItem)
                } else {
                    ProgressView()
                }
            default:
                Text("Unsupported Media Type")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
        .onAppear(perform: loadMedia)
    }
    
    private func loadMedia() {
        let targetSize = CGSize(width: 1024, height: 1024)
        
        switch asset.mediaType {
        case .image:
            if asset.mediaSubtypes.contains(.photoLive) {
                photoManager.fetchLivePhoto(for: asset, targetSize: targetSize) { fetchedLivePhoto in
                    self.livePhoto = fetchedLivePhoto
                }
            } else {
                photoManager.fetchImage(for: asset, targetSize: targetSize, contentMode: .aspectFit) { fetchedImage in
                    self.image = fetchedImage
                }
            }
        case .video:
            photoManager.fetchVideo(for: asset) { fetchedPlayerItem in
                self.playerItem = fetchedPlayerItem
            }
        default:
            break
        }
    }
}

// MARK: - 変更点
// AVPlayerの状態を管理するObservableObjectを作成
class PlayerViewModel: ObservableObject {
    let player: AVPlayer
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var totalTime: Double = 0
    
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    init(playerItem: AVPlayerItem) {
        self.player = AVPlayer(playerItem: playerItem)
        setupObservers()
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }
    
    private func setupObservers() {
        // 再生状態の監視
        player.publisher(for: \.timeControlStatus)
            .map { $0 == .playing }
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)

        // 再生時間の監視
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        // 総再生時間の取得
        if let duration = player.currentItem?.duration, duration.isNumeric {
            totalTime = duration.seconds
        }
        
        // ループ再生の設定
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            .sink { [weak self] _ in
                self?.player.seek(to: .zero)
                self?.player.play()
            }
            .store(in: &cancellables)
    }
    
    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
}

struct VideoPlayerView: View {
    // MARK: - 変更点
    // StateObjectとしてPlayerViewModelを保持
    @StateObject private var playerViewModel: PlayerViewModel
    
    @State private var showControls: Bool = true
    @State private var longPressActive: Bool = false
    
    init(playerItem: AVPlayerItem) {
        // StateObjectを初期化
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(playerItem: playerItem))
    }

    var body: some View {
        ZStack {
            CustomVideoPlayer(player: playerViewModel.player)
                .onAppear { playerViewModel.player.play() }
                .onDisappear { playerViewModel.player.pause() }

            VStack {
                Spacer()
                // MARK: - 変更点
                // ViewModelを渡すように変更
                VideoControlsView(playerViewModel: playerViewModel)
                    .padding(.bottom, 20)
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut, value: showControls)
            }
        }
        .onTapGesture {
            withAnimation { showControls.toggle() }
            if showControls { startControlsTimer() }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.2)
                .onChanged { pressing in
                    longPressActive = pressing
                    playerViewModel.player.rate = pressing ? 2.5 : (playerViewModel.isPlaying ? 1.0 : 0.0)
                }
                .onEnded { _ in
                    longPressActive = false
                    playerViewModel.player.rate = playerViewModel.isPlaying ? 1.0 : 0.0
                }
        )
    }
    
    private func startControlsTimer() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            if !longPressActive {
                withAnimation { showControls = false }
            }
        }
    }
}

struct CustomVideoPlayer: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

struct VideoControlsView: View {
    // MARK: - 変更点
    // ViewModelをObservedObjectとして受け取る
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text(formatTime(playerViewModel.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)
                // MARK: - 変更点
                // ViewModelのプロパティと直接バインディング
                Slider(value: $playerViewModel.currentTime, in: 0...playerViewModel.totalTime, onEditingChanged: { editing in
                    if !editing {
                        playerViewModel.seek(to: playerViewModel.currentTime)
                    }
                })
                Text(formatTime(playerViewModel.totalTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            
            Button(action: {
                playerViewModel.togglePlayPause()
            }) {
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN, !time.isInfinite else { return "0:00" }
        let seconds = Int(time)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct LivePhotoView: UIViewRepresentable {
    var livePhoto: PHLivePhoto
    var isMuted: Bool = false

    func makeUIView(context: Context) -> PHLivePhotoView {
        let livePhotoView = PHLivePhotoView()
        livePhotoView.livePhoto = self.livePhoto
        livePhotoView.isMuted = self.isMuted
        livePhotoView.startPlayback(with: .full)
        return livePhotoView
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = self.livePhoto
        uiView.isMuted = self.isMuted
    }
}
