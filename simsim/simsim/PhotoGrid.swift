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

    // For staggered animation effect
    @State private var appeared = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)], spacing: 12) {
                ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                    ImageLoader(asset: asset, imageManager: imageManager)
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 100, minHeight: 100)
                        .clipped()
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                        .onTapGesture {
                            hapticFeedback(style: .medium)
                            onPhotoTap?(asset)
                        }
                        .accessibilityLabel("Photo \(index + 1)")
                        .accessibilityAddTraits(.isImage)
                        .accessibilityHint("Double tap to select this photo")
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index % 20) * 0.03), // Staggered animation
                            value: appeared
                        )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Extra padding at bottom for the search bar
        }
        .onAppear {
            // Trigger the staggered animation when view appears
            withAnimation {
                appeared = true
            }
        }
        .onDisappear {
            // Reset the animation state
            appeared = false
        }
    }
    
    // Haptic feedback function for better user experience
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

#Preview {
    ZStack {
        Color.darkBackground.edgesIgnoringSafeArea(.all)
        Text("Photo Grid Preview (Requires actual photo data)")
            .foregroundColor(.lightText)
    }
}
