import SwiftUI
import Photos

struct PagedPhotoDetailView: View {
    // 親ビューから受け取るデータとコールバック
    let assets: [PHAsset]
    @Binding var currentIndex: Int
    let onUpSwipe: ((PHAsset) -> Void)?
    let onClose: () -> Void
    let upSwipeHint: String?
    
    // ジェスチャーの状態管理
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // 背景は常に黒
            Color.black.ignoresSafeArea()

            // ページングビュー
            TabView(selection: $currentIndex) {
                ForEach(assets.indices, id: \.self) { index in
                    PhotoDetailContent(asset: assets[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // ドラッグによる透明度とオフセット
            .opacity(1.0 - (dragOffset.height / 500))
            .offset(y: dragOffset.height)

            // UI要素（閉じるボタン、ページ番号、ヒント）
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.title2.weight(.medium)).foregroundColor(.white)
                    }
                    .padding()
                    Spacer()
                    if !assets.isEmpty {
                        Text("\(currentIndex + 1) / \(assets.count)").font(.headline).foregroundColor(.white).padding(.trailing)
                    }
                }
                .padding(.top)
                Spacer()
                if let hint = upSwipeHint {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                        Text(hint)
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
                    .opacity(1.0 - abs(dragOffset.height / 100))
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    // 下方向へのドラッグのみを追跡
                    if gesture.translation.height > 0 {
                        dragOffset = gesture.translation
                    }
                }
                .onEnded { gesture in
                    let verticalTranslation = gesture.translation.height
                    
                    if verticalTranslation < -150 {
                        // 上スワイプされたら、親に通知するだけ
                        handleUpSwipe()
                    } else if verticalTranslation > 150 {
                        // 下スワイプされたら、親に通知するだけ
                        onClose()
                    } else {
                        // しきい値に満たなければ元の位置に戻る
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        // ビューが表示されたらオフセットをリセット
        .onAppear {
            dragOffset = .zero
        }
    }
    
    private func handleUpSwipe() {
        // 現在表示されているアセットを特定し、親に通知
        guard currentIndex < assets.count else { return }
        let swipedAsset = assets[currentIndex]
        onUpSwipe?(swipedAsset)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
