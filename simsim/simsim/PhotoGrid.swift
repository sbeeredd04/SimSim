//
//  PhotoGrid.swift
//  simsim
//
//  Created by Sri Ujjwal Reddy B on 6/5/25.
//

import SwiftUI
import Photos // Required for PHAsset and PHCachingImageManager

struct PhotoGrid: View {
    let photos: [PHAsset]
    let imageManager: PHCachingImageManager
    var onPhotoTap: ((PHAsset) -> Void)? = nil

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)], spacing: 8) {
                ForEach(photos, id: \.localIdentifier) { asset in
                    ImageLoader(asset: asset, imageManager: imageManager)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        .onTapGesture {
                            onPhotoTap?(asset)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    ZStack {
        Color.darkBackground.edgesIgnoringSafeArea(.all)
        Text("Photo Grid Preview (Requires actual photo data)")
            .foregroundColor(.lightText)
    }
}
