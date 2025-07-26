import Photos
import UIKit
import AVKit

// 複数のビューで共有する表示モードの定義
enum GridDisplayMode {
    case fit          // 長辺フィット (全体表示)
    case shortEdgeFill // 短辺フィット (クロップあり)
}

// PHAssetをIdentifiableに準拠させる
extension PHAsset: Identifiable {
    public var id: String {
        localIdentifier
    }
}

class PhotoManager {

    func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: completion)
    }

    func fetchAlbums() -> [AlbumInfo] {
        var allAlbums: [AlbumInfo] = []
        
        // MARK: - 変更点
        // 動画やライブフォトもカウントに含めるため、mediaTypeの絞り込みを解除
        let photoFetchOptions = PHFetchOptions()

        // --- スマートアルバムの取得 ---
        let smartAlbumOptions = PHFetchOptions()
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: smartAlbumOptions)
        
        smartAlbums.enumerateObjects { (collection, _, _) in
            // MARK: - 変更点
            // ここでのPredicateを削除し、すべてのメディアタイプをカウントするように変更
            let photoCount = PHAsset.fetchAssets(in: collection, options: nil).count
            if photoCount > 0 {
                allAlbums.append(AlbumInfo(collection: collection, count: photoCount))
            }
        }
        
        // --- ユーザーが作成したアルバムの取得 ---
        let userAlbumOptions = PHFetchOptions()
        userAlbumOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: userAlbumOptions)
        
        userAlbums.enumerateObjects { (collection, _, _) in
            // MARK: - 変更点
            // ここでのPredicateを削除し、すべてのメディアタイプをカウントするように変更
            let photoCount = PHAsset.fetchAssets(in: collection, options: nil).count
            if photoCount > 0 {
                allAlbums.append(AlbumInfo(collection: collection, count: photoCount))
            }
        }

        return allAlbums
    }

    // MARK: - 変更点
    // predicateを削除し、すべてのメディアタイプ（画像、動画、ライブフォト）を取得するように修正
    func fetchPhotos(from album: PHAssetCollection?) -> [PHAsset] {
        var assets: [PHAsset] = []
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult: PHFetchResult<PHAsset>
        if let album = album {
             fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
        } else {
            fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        }

        fetchResult.enumerateObjects { (asset, _, _) in
            assets.append(asset)
        }
        return assets
    }

    func fetchImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact

        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { (image, _) in
            completion(image)
        }
    }
    
    // MARK: - 変更点
    // 動画再生のためにAVPlayerItemを取得するメソッドを追加
    func fetchVideo(for asset: PHAsset, completion: @escaping (AVPlayerItem?) -> Void) {
        guard asset.mediaType == .video else {
            completion(nil)
            return
        }
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
            DispatchQueue.main.async {
                completion(playerItem)
            }
        }
    }

    // MARK: - 変更点
    // ライブフォト表示のためにPHLivePhotoを取得するメソッドを追加
    func fetchLivePhoto(for asset: PHAsset, targetSize: CGSize, completion: @escaping (PHLivePhoto?) -> Void) {
        guard asset.mediaSubtypes.contains(.photoLive) else {
            completion(nil)
            return
        }

        let options = PHLivePhotoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic

        PHImageManager.default().requestLivePhoto(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { livePhoto, _ in
            DispatchQueue.main.async {
                completion(livePhoto)
            }
        }
    }

    func deletePhotos(assets: [PHAsset], completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }) { success, error in
            if let error = error {
                print("Error deleting assets: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
