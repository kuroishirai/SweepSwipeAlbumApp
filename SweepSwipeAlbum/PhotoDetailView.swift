//
//  PhotoDetailView.swift
//  SweepSwipeAlbum
//
//  Created by 白井 達也 on 2025/06/06.
//

import SwiftUI
import Photos

struct PhotoDetailView: View {
    // 表示する写真アセット
    let asset: PHAsset
    
    // このビューを閉じるための仕組み
    @Environment(\.presentationMode) var presentationMode
    
    @State private var image: UIImage? = nil
    private let photoManager = PhotoManager()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 背景は黒
            Color.black
                .ignoresSafeArea()

            // 写真の表示エリア
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // 画像読み込み中
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            // 閉じるボタン
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title2.weight(.medium))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .padding()
        }
        .onAppear(perform: loadFullImage)
    }
    
    /// フル解像度の画像を読み込む
    private func loadFullImage() {
        // PHImageManagerMaximumSize で可能な限り高解像度の画像を取得
        let targetSize = PHImageManagerMaximumSize
        photoManager.fetchImage(for: asset, targetSize: targetSize, contentMode: .aspectFit) { downloadedImage in
            self.image = downloadedImage
        }
    }
}
