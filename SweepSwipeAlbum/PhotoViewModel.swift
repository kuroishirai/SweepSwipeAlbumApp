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

// MARK: - 変更点
// 年単位の絞り込みを追加
enum SelectionType {
    case allPhotos
    case album(PHAssetCollection)
    case month(Date)
    case year(Date)
}

@MainActor
class PhotoViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var filteredPhotoAssets: [PHAsset] = []
    
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
    
    // MARK: - 変更点
    // 年単位のデータを保持するプロパティを追加
    @Published var yearlyGroupedAssets: [Date: [PHAsset]] = [:]
    @Published var sortedYears: [Date] = []

    private var allPhotoAssets: [PHAsset] = []
    private var keptPhotoIdentifiers: Set<String> = []
    private var history: [(action: SwipeAction, asset: PHAsset)] = []
    private let photoManager = PhotoManager()
    
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
        // MARK: - 変更点
        // 年単位のタイトル表示を追加
        case .year(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年"
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: date)
        }
    }

    init() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
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
        // MARK: - 変更点
        // 年単位のグルーピング処理を追加
        let allPhotos = photoManager.fetchPhotos(from: nil)
        groupPhotosByMonth(allPhotos: allPhotos)
        groupPhotosByYear(allPhotos: allPhotos)
        loadPhotosForSelection()
    }

    func loadAlbums() {
        self.albums = photoManager.fetchAlbums()
    }
    
    // MARK: - 変更点
    // 全写真アセットを引数で受け取るように変更
    func groupPhotosByMonth(allPhotos: [PHAsset]) {
        let grouped = Dictionary(grouping: allPhotos) { asset -> Date in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: asset.creationDate ?? Date())
            return calendar.date(from: components) ?? Date()
        }
        self.monthlyGroupedAssets = grouped
        self.sortedMonths = grouped.keys.sorted(by: >)
    }

    // MARK: - 変更点
    // 年単位で写真をグループ化するメソッドを追加
    func groupPhotosByYear(allPhotos: [PHAsset]) {
        let grouped = Dictionary(grouping: allPhotos) { asset -> Date in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year], from: asset.creationDate ?? Date())
            return calendar.date(from: components) ?? Date()
        }
        self.yearlyGroupedAssets = grouped
        self.sortedYears = grouped.keys.sorted(by: >)
    }

    func loadPhotosForSelection() {
        switch selection {
        case .allPhotos:
            allPhotoAssets = photoManager.fetchPhotos(from: nil)
        case .album(let collection):
            allPhotoAssets = photoManager.fetchPhotos(from: collection)
        case .month(let date):
            allPhotoAssets = monthlyGroupedAssets[date] ?? []
        // MARK: - 変更点
        // 年単位のデータソースを指定
        case .year(let date):
            allPhotoAssets = yearlyGroupedAssets[date] ?? []
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
