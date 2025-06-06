import SwiftUI
import Photos
import CoreML
import Vision
import CoreData
import hnswlib_swift

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // UI State
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var searchText: String = ""
    @State private var statusMessage: String? = nil
    @State private var isIndexing: Bool = false
    @State private var isSearching: Bool = false
    @State private var indexedPhotoCount: Int = 0
    @State private var totalPhotoCount: Int = 0

    // Data
    @State private var allPhotos: [PHAsset] = [] // All photos loaded from library
    @State private var displayedPhotos: [PHAsset] = [] // Photos currently on screen

    // Services
    private let imageManager = PHCachingImageManager()
    @State private var imageEmbedderService: ImageEmbedderService?
    @State private var textEmbedderService: TextEmbedderService?
    @State private var photoIndexManager: PhotoIndexManager?
    @State private var photoSearchService: PhotoSearchService?

    var body: some View {
        ZStack {
            Color.darkBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
                .frame(height: 50)
                .background(Color.darkBackground.opacity(0.8))
                
                // Content Area
                ZStack {
                    if isIndexing {
                        ProgressView("Indexing photos... \(indexedPhotoCount) / \(totalPhotoCount)")
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentTeal))
                            .foregroundColor(.subtleText)
                    } else if isSearching {
                        ProgressView("Searching...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentTeal))
                            .foregroundColor(.subtleText)
                    } else if let message = statusMessage {
                        StatusMessageView(message: message, isError: message.contains("denied") || message.contains("Failed"))
                    } else if displayedPhotos.isEmpty && !searchText.isEmpty {
                        StatusMessageView(message: "No photos found for \"\(searchText)\"", isError: false)
                    } else {
                        PhotoGrid(photos: displayedPhotos, imageManager: imageManager) { asset in
                            print("Tapped photo: \(asset.localIdentifier)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: setupServicesAndRequestAccess)
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
    }
    
    // MARK: - Setup
    private func setupServicesAndRequestAccess() {
        if photoIndexManager == nil {
            photoIndexManager = PhotoIndexManager(context: viewContext)
        }
        if imageEmbedderService == nil {
            do {
                imageEmbedderService = try ImageEmbedderService()
                textEmbedderService = try TextEmbedderService()
                photoSearchService = PhotoSearchService(
                    embeddingDimension: 512, // Correct dimension for MobileCLIP
                    photoIndexManager: photoIndexManager!,
                    textEmbedderService: textEmbedderService!
                )
            } catch {
                statusMessage = "Failed to initialize ML services: \(error.localizedDescription)"
            }
        }
        requestPhotoAccess()
    }
    
    // MARK: - Photo Loading & Permissions
    private func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
                switch status {
                case .authorized, .limited:
                    self.statusMessage = "Loading photos..."
                    self.loadPhotos()
                case .denied, .restricted:
                    self.statusMessage = "Photo access denied. Please enable in Settings."
                case .notDetermined:
                    self.statusMessage = "Welcome! Please grant photo access to begin."
                @unknown default:
                    self.statusMessage = "An unknown error occurred."
                }
            }
        }
    }
    
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        var fetchedPhotos: [PHAsset] = []
        assets.enumerateObjects { (asset, _, _) in fetchedPhotos.append(asset) }
        
        DispatchQueue.main.async {
            self.allPhotos = fetchedPhotos
            self.displayedPhotos = fetchedPhotos
            self.totalPhotoCount = fetchedPhotos.count
            self.statusMessage = nil
            Task { await startIndexing() }
        }
    }
    
    // MARK: - Indexing
    private func startIndexing() async {
        guard !isIndexing, let manager = photoIndexManager, let embedder = imageEmbedderService else { return }

        isIndexing = true
        indexedPhotoCount = 0
        
        let assetsToIndex = await manager.filterUnindexedAssets(assets: allPhotos)
        let alreadyIndexedCount = allPhotos.count - assetsToIndex.count
        
        DispatchQueue.main.async {
            self.indexedPhotoCount = alreadyIndexedCount
        }
        
        guard !assetsToIndex.isEmpty else {
            isIndexing = false
            print("All photos already indexed.")
            Task { await buildSearchIndex() }
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for asset in assetsToIndex {
                group.addTask {
                    do {
                        let embedding = try await embedder.generateEmbedding(for: asset)
                        try await manager.saveEmbedding(id: asset.localIdentifier, embedding: embedding)
                        DispatchQueue.main.async { self.indexedPhotoCount += 1 }
                    } catch {
                        print("Failed to index asset \(asset.localIdentifier): \(error)")
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.isIndexing = false
            print("Indexing complete.")
            Task { await buildSearchIndex() }
        }
    }
    
    // MARK: - Search
    private func buildSearchIndex() async {
        guard let searchService = photoSearchService else { return }
        if searchService.hnswIndex != nil { return }

        DispatchQueue.main.async { statusMessage = "Building search index..." }
        do {
            try await searchService.buildIndex()
            DispatchQueue.main.async { statusMessage = "Search index ready." }
        } catch {
            DispatchQueue.main.async { statusMessage = "Failed to build search index: \(error.localizedDescription)" }
        }
    }
    
    private func performSearch(query: String) {
        guard let searchService = photoSearchService else { return }
        guard !isIndexing else { return }

        if query.isEmpty {
            displayedPhotos = allPhotos
            return
        }
        
        guard searchService.hnswIndex != nil else {
            statusMessage = "Search index is not ready yet."
            return
        }

        isSearching = true
        Task {
            do {
                let resultIDs = try await searchService.performSemanticSearch(query: query, topK: 50)
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: resultIDs, options: nil)
                var foundPhotos: [PHAsset] = []
                fetchResult.enumerateObjects { (asset, _, _) in foundPhotos.append(asset) }
                
                DispatchQueue.main.async {
                    self.displayedPhotos = foundPhotos
                    self.isSearching = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Search failed: \(error.localizedDescription)"
                    self.isSearching = false
                }
            }
        }
    }
}

// MARK: - Subviews
struct StatusMessageView: View {
    let message: String
    let isError: Bool
    
    var body: some View {
        VStack {
            Image(systemName: isError ? "xmark.octagon.fill" : "info.circle.fill")
                .font(.largeTitle)
                .foregroundColor(isError ? .errorRed : .accentTeal)
            Text(message)
                .font(.headline)
                .foregroundColor(.subtleText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - Previews
#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
