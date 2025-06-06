import SwiftUI
import Photos

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
                        Text("\(viewModel.currentIndex) / \(viewModel.filteredPhotoAssets.count) (\(viewModel.totalPhotoCount))")
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
    @State private var image: UIImage? = nil
    private let photoManager = PhotoManager()
    
    var body: some View {
        ZStack {
            Color(.systemGray4)
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        let targetSize = CGSize(width: 1024, height: 1024)
        photoManager.fetchImage(for: asset, targetSize: targetSize, contentMode: .aspectFit) { downloadedImage in
            self.image = downloadedImage
        }
    }
}
