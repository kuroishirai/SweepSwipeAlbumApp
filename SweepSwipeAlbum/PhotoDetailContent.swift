import SwiftUI
import Photos
import AVKit
import PhotosUI

struct PhotoDetailContent: View {
    let asset: PHAsset
    
    @State private var image: UIImage? = nil
    @State private var playerItem: AVPlayerItem? = nil
    @State private var livePhoto: PHLivePhoto? = nil
    
    // ✅ 動画スライダー操作の状態を管理する変数を追加
    @State private var isSliderEditing = false
    
    private let photoManager = PhotoManager()

    var body: some View {
        Group {
            switch asset.mediaType {
            case .image:
                if asset.mediaSubtypes.contains(.photoLive) {
                    if let livePhoto = livePhoto {
                        LivePhotoView(livePhoto: livePhoto)
                    } else {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                } else {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            case .video:
                if let playerItem = playerItem {
                    // ✅ isForegroundとisSliderEditingの引数を渡すように修正
                    VideoPlayerView(playerItem: playerItem, isForeground: true, isSliderEditing: $isSliderEditing)
                } else {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            default:
                Text("Unsupported Media Type").foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: loadMedia)
    }
    
    private func loadMedia() {
        switch asset.mediaType {
        case .image:
            let targetSize = PHImageManagerMaximumSize
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
