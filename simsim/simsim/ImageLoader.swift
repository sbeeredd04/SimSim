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
    @State private var isLoading = true // Track loading state
    @State private var fadeIn = false // For fade-in animation
    
    var body: some View {
        Group {
            if let image = image {
                // Display the loaded image with fade-in animation
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(fadeIn ? 1.0 : 0.0)
                    .transition(.opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.3)) {
                            fadeIn = true
                        }
                    }
            } else {
                // Improved placeholder with shimmer effect
                Rectangle()
                    .fill(Color.cardBackground)
                    .overlay(
                        Group {
                            if isLoading {
                                ShimmerView()
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 30))
                                    .foregroundColor(.subtleText.opacity(0.5))
                            }
                        }
                    )
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // Clean up resources when view disappears
            self.image = nil
            self.fadeIn = false
        }
        .accessibilityLabel("Photo")
    }
    
    private func loadImage() {
        // Request image with options for better performance
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300), // Higher resolution
            contentMode: .aspectFill,
            options: options
        ) { loadedImage, info in
            // Handle error case
            if info?[PHImageErrorKey] != nil {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // Update image on main thread if we got a valid result
            if let image = loadedImage {
                DispatchQueue.main.async {
                    self.image = image
                    self.isLoading = false
                }
            }
        }
    }
}

// Shimmer loading effect for a more polished UI
struct ShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(
                colors: [
                    Color.cardBackground.opacity(0.4),
                    Color.subtleText.opacity(0.2),
                    Color.cardBackground.opacity(0.4)
                ]
            ),
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Rectangle())
        .offset(x: isAnimating ? 300 : -300)
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
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
