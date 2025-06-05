//
//  ImageLoader.swift
//  simsim
//
//  Created by Sri Ujjwal Reddy B on 6/5/25.
//

import SwiftUI
import Photos // Required for PHAsset and PHCachingImageManager

struct ImageLoader: View {
    let asset: PHAsset // The photo asset to load
    let imageManager: PHCachingImageManager // Manager for efficient image loading
    @State private var image: UIImage? = nil // State to hold the loaded image

    var body: some View {
        Group {
            if let image = image {
                // Display the loaded image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Placeholder while image is loading
                Rectangle()
                    .fill(Color.cardBackground)
                    .overlay(ProgressView().tint(.lightText))
            }
        }
        .onAppear {
            // Request a thumbnail image when the view appears
            imageManager.requestImage(for: asset,
                                     targetSize: CGSize(width: 200, height: 200),
                                     contentMode: .aspectFill,
                                     options: nil) { image, _ in
                self.image = image
            }
        }
        .onDisappear {
            self.image = nil
        }
    }
}

#Preview {
    Rectangle()
        .fill(Color.gray.opacity(0.4))
        .frame(width: 100, height: 100)
        .cornerRadius(8)
        .overlay(Text("Image Placeholder").font(.caption).foregroundColor(.white))
        .previewLayout(.sizeThatFits)
}
