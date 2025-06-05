import SwiftUI
import Photos // Make sure this is here

struct ContentView: View {
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var photos: [PHAsset] = []
    @State private var searchText: String = "" // New state for search bar

    private let imageManager = PHCachingImageManager() 

    var body: some View {
        NavigationView {
            VStack {
                // Search bar at the top
                SearchBar(text: $searchText)
                    .padding(.top, 10) // Small padding from the navigation bar

                // Main content based on authorization status
                switch authorizationStatus {
                case .authorized, .limited:
                    if photos.isEmpty && searchText.isEmpty {
                        // Initial loading or no photos
                        ProgressView("Loading photos...")
                            .font(.headline)
                            .foregroundColor(.subtleText)
                            .padding()
                    } else if photos.isEmpty && !searchText.isEmpty {
                        // No photos found for search
                        Spacer()
                        VStack {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.accentTeal)
                            Text("No photos found for '\(searchText)'")
                                .font(.headline)
                                .foregroundColor(.subtleText)
                        }
                        Spacer()
                    } else {
                        // Display the photo grid
                        PhotoGrid(photos: filteredPhotos, imageManager: imageManager) { asset in
                            // Handle photo tap action here
                            print("Tapped photo: \(asset.localIdentifier)")
                        }
                    }
                case .denied, .restricted:
                    Spacer()
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.errorRed)
                        Text("Photo library access denied.")
                            .font(.headline)
                            .foregroundColor(.lightText)
                        Text("Please enable access in Settings to use this app.")
                            .font(.subheadline)
                            .foregroundColor(.subtleText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                case .notDetermined:
                    Spacer()
                    VStack {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.accentTeal)
                        Text("Grant photo library access to get started.")
                            .font(.headline)
                            .foregroundColor(.lightText)
                    }
                    .padding()
                    Spacer()
                @unknown default:
                    Spacer()
                    VStack {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.largeTitle)
                            .foregroundColor(.errorRed)
                        Text("An unknown error occurred.")
                            .font(.headline)
                            .foregroundColor(.lightText)
                    }
                    .padding()
                    Spacer()
                }
            }
            .background(Color.darkBackground.edgesIgnoringSafeArea(.all)) // Apply dark background
            .navigationTitle("Photo Search") // Set navigation title
            .navigationBarTitleDisplayMode(.inline) // Keep title compact
            .toolbarColorScheme(.dark, for: .navigationBar) // Ensure toolbar is dark
            .toolbarBackground(.visible, for: .navigationBar) // Make toolbar background visible
            .toolbarBackground(Color.cardBackground, for: .navigationBar) // Apply dark theme to navigation bar
            .onAppear(perform: requestPhotoAccess) // Request access when view appears
            .preferredColorScheme(.dark) // Force dark mode for the app
        }
    }

    // Computed property for filtering photos based on search text (placeholder for semantic search)
    var filteredPhotos: [PHAsset] {
        if searchText.isEmpty {
            return photos
        } else {
            // IMPORTANT: This is currently a placeholder for semantic search.
            // In future steps, this will involve using the ML model and HNSWLIB.
            // For now, it will simply return no results if anything is typed.
            return []
        }
    }

    // Function to request photo library access
    private func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
                if status == .authorized || status == .limited {
                    self.loadPhotos()
                }
            }
        }
    }

    // Function to load photos from the library
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let allPhotos = PHAsset.fetchAssets(with: fetchOptions)

        var fetchedAssets: [PHAsset] = []
        allPhotos.enumerateObjects { (asset, count, stop) in
            fetchedAssets.append(asset)
        }

        DispatchQueue.main.async {
            self.photos = fetchedAssets
        }
    }
}

// MARK: - Previews
#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
