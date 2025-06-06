import SwiftUI
import Photos
import Combine

struct AlbumInfo {
    let collection: PHAssetCollection
    let count: Int
}

enum SwipeAction {
    case delete, keep, pending
}

enum SelectionType {
    case allPhotos
    case album(PHAssetCollection)
    case month(Date)
}

@MainActor
class PhotoViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var filteredPhotoAssets: [PHAsset] = []
    
    // ✅ didSetを追加して、配列が変更されるたびに保存処理を呼ぶ
    @Published var deletedPhotos: [PHAsset] = [] {
        didSet {
            saveDeletedPhotos()
        }
    }
    @Published var pendingPhotos: [PHAsset] = [] {
        didSet {
            savePendingPhotos()
        }
    }
    
    @Published var currentIndex: Int = 0
    @Published var albums: [AlbumInfo] = []
    
    @Published var selection: SelectionType = .allPhotos {
        didSet {
            loadPhotosForSelection()
        }
    }
    
    @Published var monthlyGroupedAssets: [Date: [PHAsset]] = [:]
    @Published var sortedMonths: [Date] = []

    private var allPhotoAssets: [PHAsset] = []
    private var keptPhotoIdentifiers: Set<String> = []
    private var history: [(action: SwipeAction, asset: PHAsset)] = []
    private let photoManager = PhotoManager()
    
    // ✅ UserDefaultsのキーを追加
    private let keptPhotosKey = "keptPhotoIdentifiers"
    private let deletedPhotosKey = "deletedPhotoIdentifiers"
    private let pendingPhotosKey = "pendingPhotoIdentifiers"

    var canUndo: Bool { !history.isEmpty }
    var totalPhotoCount: Int { allPhotoAssets.count }
    
    var navigationTitle: String {
        switch selection {
        case .allPhotos:
            return "すべての写真"
        case .album(let collection):
            return collection.japaneseLocalizedTitle
        case .month(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月"
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: date)
        }
    }

    init() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        // ✅ 最初に全ての状態を読み込む
        loadKeptPhotos()
        loadDeletedPhotos()
        loadPendingPhotos()
        
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            loadInitialData()
        }
    }

    func requestAuthorization() {
        photoManager.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status == .authorized || status == .limited {
                    self?.loadInitialData()
                }
            }
        }
    }

    func loadInitialData() {
        loadAlbums()
        groupPhotosByMonth()
        loadPhotosForSelection()
    }

    func loadAlbums() {
        self.albums = photoManager.fetchAlbums()
    }
    
    func groupPhotosByMonth() {
        let allPhotos = photoManager.fetchPhotos(from: nil)
        let grouped = Dictionary(grouping: allPhotos) { asset -> Date in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: asset.creationDate ?? Date())
            return calendar.date(from: components) ?? Date()
        }
        self.monthlyGroupedAssets = grouped
        self.sortedMonths = grouped.keys.sorted(by: >)
    }
    
    func loadPhotosForSelection() {
        switch selection {
        case .allPhotos:
            allPhotoAssets = photoManager.fetchPhotos(from: nil)
        case .album(let collection):
            allPhotoAssets = photoManager.fetchPhotos(from: collection)
        case .month(let date):
            allPhotoAssets = monthlyGroupedAssets[date] ?? []
        }
        filterPhotos()
        resetSwipeState()
    }
    
    private func filterPhotos() {
        let deletedIdentifiers = Set(deletedPhotos.map { $0.localIdentifier })
        let pendingIdentifiers = Set(pendingPhotos.map { $0.localIdentifier })
        
        let allExcludedIdentifiers = keptPhotoIdentifiers
            .union(deletedIdentifiers)
            .union(pendingIdentifiers)
            
        filteredPhotoAssets = allPhotoAssets.filter { !allExcludedIdentifiers.contains($0.localIdentifier) }
    }
    
    private func resetSwipeState() {
        currentIndex = 0
        history = []
    }

    func swipe(asset: PHAsset, direction: SwipeAction) {
        switch direction {
        case .delete:
            deletedPhotos.append(asset)
        case .keep:
            keptPhotoIdentifiers.insert(asset.localIdentifier)
            saveKeptPhotos()
        case .pending:
            pendingPhotos.append(asset)
        }
        history.append((action: direction, asset: asset))
        
        if currentIndex < filteredPhotoAssets.count {
            currentIndex += 1
        }
    }

    func undo() {
        guard let lastAction = history.popLast() else { return }

        if currentIndex > 0 {
            currentIndex -= 1
        }
       
        switch lastAction.action {
        case .delete:
            _ = deletedPhotos.popLast()
        case .keep:
            keptPhotoIdentifiers.remove(lastAction.asset.localIdentifier)
            saveKeptPhotos()
        case .pending:
            _ = pendingPhotos.popLast()
        }
    }
    
    // MARK: - Persistence (データの永続化)
    
    private func saveKeptPhotos() {
        UserDefaults.standard.set(Array(keptPhotoIdentifiers), forKey: keptPhotosKey)
    }
    
    private func loadKeptPhotos() {
        if let identifiers = UserDefaults.standard.array(forKey: keptPhotosKey) as? [String] {
            keptPhotoIdentifiers = Set(identifiers)
        }
    }
    
    // ✅ 新しい保存・読み込みメソッド
    private func saveDeletedPhotos() {
        let identifiers = deletedPhotos.map { $0.localIdentifier }
        UserDefaults.standard.set(identifiers, forKey: deletedPhotosKey)
    }
    
    private func loadDeletedPhotos() {
        guard let identifiers = UserDefaults.standard.array(forKey: deletedPhotosKey) as? [String], !identifiers.isEmpty else { return }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { (asset, _, _) in
            assets.append(asset)
        }
        self.deletedPhotos = assets
    }
    
    private func savePendingPhotos() {
        let identifiers = pendingPhotos.map { $0.localIdentifier }
        UserDefaults.standard.set(identifiers, forKey: pendingPhotosKey)
    }

    private func loadPendingPhotos() {
        guard let identifiers = UserDefaults.standard.array(forKey: pendingPhotosKey) as? [String], !identifiers.isEmpty else { return }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { (asset, _, _) in
            assets.append(asset)
        }
        self.pendingPhotos = assets
    }
    
    func resetKeptPhotos() {
        keptPhotoIdentifiers.removeAll()
        UserDefaults.standard.removeObject(forKey: keptPhotosKey)
        filterPhotos()
        resetSwipeState()
    }
    
    // (以降のメソッドは変更なし)
    func confirmDelete(assetsToDelete: [PHAsset], completion: @escaping (Bool) -> Void) {
        photoManager.deletePhotos(assets: assetsToDelete) { [weak self] success in
            if success {
                self?.deletedPhotos.removeAll { assetsToDelete.contains($0) }
            }
            completion(success)
        }
    }

    func cancelDelete(assetToCancel: PHAsset) {
        deletedPhotos.removeAll { $0 == assetToCancel }
        filterPhotos()
        resetSwipeState()
    }
    
    func moveFromPendingToKeep(asset: PHAsset) {
        pendingPhotos.removeAll { $0 == asset }
        keptPhotoIdentifiers.insert(asset.localIdentifier)
        saveKeptPhotos()
    }
    
    func moveFromPendingToDelete(asset: PHAsset) {
        pendingPhotos.removeAll { $0 == asset }
        deletedPhotos.append(asset)
    }
    
    func resetPendingPhotos() {
        pendingPhotos.removeAll()
        filterPhotos()
        resetSwipeState()
    }
}
