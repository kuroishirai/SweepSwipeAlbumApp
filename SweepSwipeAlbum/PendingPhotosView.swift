import SwiftUI
import Photos

struct PendingPhotosView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    
    @State private var selectedIndex: Int?
    @State private var displayMode: GridDisplayMode = .fit
    
    // ✅ 拡大表示ビューを強制的に再生成するためのID
    @State private var detailViewId = UUID()

    private let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

    var body: some View {
        NavigationView {
            Group {
                if viewModel.pendingPhotos.isEmpty {
                    VStack { Spacer(); Text("保留中の写真はありません").foregroundColor(.gray); Spacer() }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(Array(viewModel.pendingPhotos.enumerated()), id: \.element.localIdentifier) { (index, asset) in
                                gridItem(for: asset)
                                    .onTapGesture { self.selectedIndex = index }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .navigationTitle("保留 (\(viewModel.pendingPhotos.count))")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        displayMode = (displayMode == .fit) ? .shortEdgeFill : .fit
                    }) {
                        Image(systemName: displayMode == .fit ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("すべて整理に戻す") {
                        viewModel.resetPendingPhotos()
                    }
                    .disabled(viewModel.pendingPhotos.isEmpty)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { selectedIndex != nil },
                set: { if !$0 { selectedIndex = nil } }
            )) {
                if let index = selectedIndex {
                    PagedPhotoDetailView(
                        assets: viewModel.pendingPhotos,
                        currentIndex: Binding(
                            get: { selectedIndex ?? 0 },
                            set: { selectedIndex = $0 }
                        ),
                        onUpSwipe: { asset in
                            processUpSwipeAction(for: asset)
                        },
                        onClose: {
                            selectedIndex = nil
                        },
                        upSwipeHint: "削除候補に入れる"
                    )
                    // ✅ このIDを変更することで、ビューを強制的に再生成させる
                    .id(detailViewId)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private func gridItem(for asset: PHAsset) -> some View {
        if displayMode == .fit {
            PendingFitGridItemView(asset: asset)
        } else {
            PendingShortEdgeFillGridItemView(asset: asset)
        }
    }
    
    private func processUpSwipeAction(for asset: PHAsset) {
        guard let currentIndex = self.selectedIndex else { return }

        viewModel.moveFromPendingToDelete(asset: asset)
        let newTotalCount = viewModel.pendingPhotos.count
        
        if newTotalCount == 0 {
            self.selectedIndex = nil
        } else if currentIndex >= newTotalCount {
            self.selectedIndex = newTotalCount - 1
        }

        // ✅ データの更新が終わった後、IDを更新してUIの再描画をトリガーする
        self.detailViewId = UUID()
    }
}

// (PendingFitGridItemView と PendingShortEdgeFillGridItemView は変更ありません)
// MARK: - Mode A: Fit表示（全体表示）専用のビュー
struct PendingFitGridItemView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    let asset: PHAsset
    
    @State private var image: UIImage?
    private let photoManager = PhotoManager()
    
    var body: some View {
        ZStack {
            Color(.systemGray5)
            if let image = image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottomTrailing) {
            Menu {
                Button(action: { viewModel.moveFromPendingToKeep(asset: asset) }) {
                    Label("残す", systemImage: "checkmark")
                }
                Button(role: .destructive, action: { viewModel.moveFromPendingToDelete(asset: asset) }) {
                    Label("削除候補に入れる", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .renderingMode(.original).font(.title3)
                    .background(Circle().fill(Color.black.opacity(0.3))).padding(4)
            }
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        let scale = UIScreen.main.scale
        let cellSize = (UIScreen.main.bounds.width / 3) * scale
        let size = CGSize(width: cellSize, height: cellSize)
        photoManager.fetchImage(for: asset, targetSize: size, contentMode: .aspectFit) { img in
            self.image = img
        }
    }
}

// MARK: - Mode B: ShortEdgeFill表示（短辺フィット）専用のビュー
struct PendingShortEdgeFillGridItemView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    let asset: PHAsset

    @State private var image: UIImage?
    private let photoManager = PhotoManager()

    var body: some View {
        ZStack {
            Color(.systemGray5)
            if let image = image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: calculateFrame(for: image.size, in: geometry.size).width,
                            height: calculateFrame(for: image.size, in: geometry.size).height
                        )
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            } else {
                ProgressView()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .overlay(alignment: .bottomTrailing) {
            Menu {
                Button(action: { viewModel.moveFromPendingToKeep(asset: asset) }) {
                    Label("残す", systemImage: "checkmark")
                }
                Button(role: .destructive, action: { viewModel.moveFromPendingToDelete(asset: asset) }) {
                    Label("削除候補に入れる", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .renderingMode(.original).font(.title3)
                    .background(Circle().fill(Color.black.opacity(0.3))).padding(4)
            }
        }
        .onAppear(perform: loadImage)
    }

    private func loadImage() {
        let scale = UIScreen.main.scale
        let cellSize = (UIScreen.main.bounds.width / 3) * scale
        let size = CGSize(width: cellSize, height: cellSize)
        photoManager.fetchImage(for: asset, targetSize: size, contentMode: .aspectFill) { img in
            self.image = img
        }
    }

    private func calculateFrame(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        let imageAspectRatio = imageSize.width / imageSize.height
        if imageAspectRatio > 1 {
            let newHeight = containerSize.height
            let newWidth = newHeight * imageAspectRatio
            return CGSize(width: newWidth, height: newHeight)
        } else {
            let newWidth = containerSize.width
            let newHeight = newWidth / imageAspectRatio
            return CGSize(width: newWidth, height: newHeight)
        }
    }
}
