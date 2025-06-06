import Photos
import UIKit

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
        
        let photoFetchOptions = PHFetchOptions()
        photoFetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        // --- スマートアルバムの取得 ---
        let smartAlbumOptions = PHFetchOptions()
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: smartAlbumOptions)
        
        smartAlbums.enumerateObjects { (collection, _, _) in
            let photoCount = PHAsset.fetchAssets(in: collection, options: photoFetchOptions).count
            allAlbums.append(AlbumInfo(collection: collection, count: photoCount))
        }
        
        // --- ユーザーが作成したアルバムの取得 ---
        let userAlbumOptions = PHFetchOptions()
        userAlbumOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: userAlbumOptions)
        
        userAlbums.enumerateObjects { (collection, _, _) in
            let photoCount = PHAsset.fetchAssets(in: collection, options: photoFetchOptions).count
            allAlbums.append(AlbumInfo(collection: collection, count: photoCount))
        }

        return allAlbums
    }

    func fetchPhotos(from album: PHAssetCollection?) -> [PHAsset] {
        var assets: [PHAsset] = []
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

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
