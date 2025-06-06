import SwiftUI
import Photos

struct PhotoDetailContent: View {
    let asset: PHAsset
    
    @State private var image: UIImage? = nil
    private let photoManager = PhotoManager()

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: loadFullImage)
    }
    
    private func loadFullImage() {
        let targetSize = PHImageManagerMaximumSize
        photoManager.fetchImage(for: asset, targetSize: targetSize, contentMode: .aspectFit) { downloadedImage in
            self.image = downloadedImage
        }
    }
}
