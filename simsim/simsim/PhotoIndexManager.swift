import CoreData
import Foundation
import Photos
import Combine

class PhotoIndexManager {
    let context: NSManagedObjectContext // Core Data managed object context
    private let backgroundContext: NSManagedObjectContext
    private let imageEmbedderService: ImageEmbedderService
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    @Published var indexingProgress: Float = 0.0
    @Published var indexedPhotoCount: Int = 0
    @Published var isIndexingComplete: Bool = false
    
    init(context: NSManagedObjectContext, persistenceController: PersistenceController = .shared) {
        self.context = context
        self.backgroundContext = PersistenceController.shared.backgroundContext()
        self.imageEmbedderService = try! ImageEmbedderService()
        self.persistenceController = persistenceController
        self.indexedPhotoCount = countIndexedPhotos()
    }
    
    // MARK: - Save Embedding
    
    func saveEmbedding(id: String, embedding: [Float]) async throws {
        try await context.perform { // Perform on the context's private queue
            let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)

            // Check if embedding already exists
            if let existingEmbedding = try self.context.fetch(fetchRequest).first {
                // Update existing
                existingEmbedding.embeddingData = Data(fromArray: embedding)
            } else {
                // Create new
                let newEmbedding = PhotoEmbedding(context: self.context)
                newEmbedding.id = id
                newEmbedding.embeddingData = Data(fromArray: embedding)
            }

            try self.context.save() // Save changes to the persistent store
        }
    }
    
    // MARK: - Fetch Embedding
    
    func fetchEmbedding(for id: String) async throws -> [Float]? {
        return try await context.perform {
            let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            fetchRequest.fetchLimit = 1

            let results = try self.context.fetch(fetchRequest)
            guard let photoEmbedding = results.first,
                  let embeddingData = photoEmbedding.embeddingData else {
                return nil
            }
            return embeddingData.toArray(type: Float.self)
        }
    }
    
    // MARK: - Fetch All Embeddings (for search)
    
    func fetchAllEmbeddings() async throws -> [(id: String, embedding: [Float])] {
        return try await context.perform {
            let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
            let results = try self.context.fetch(fetchRequest)
            return results.compactMap { photoEmbedding in
                guard let id = photoEmbedding.id,
                      let embeddingData = photoEmbedding.embeddingData else {
                    return nil
                }
                let embedding = embeddingData.toArray(type: Float.self)
                return (id: id, embedding: embedding ?? [])
            }
        }
    }
    
    // MARK: - Delete Embedding
    
    func deleteEmbedding(for id: String) async throws {
        try await context.perform {
            let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            fetchRequest.fetchLimit = 1

            if let objectToDelete = try self.context.fetch(fetchRequest).first {
                self.context.delete(objectToDelete)
                try self.context.save()
            }
        }
    }
    
    // MARK: - Check if embedding exists
    
    func embeddingExists(for id: String) async throws -> Bool {
        return try await context.perform {
            let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            // fetchRequest.fetchLimit = 1 // Not needed for count
            let count = try self.context.count(for: fetchRequest)
            return count > 0
        }
    }
    
    // MARK: - Get indexing stats
    
    func getIndexingStats() async throws -> (indexed: Int, total: Int) {
        return try await context.perform {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest<NSManagedObject>(entityName: "PhotoEmbedding")
            let indexedCount = try self.context.count(for: fetchRequest)
            
            // For total, we need to check the photo library
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let totalCount = PHAsset.fetchAssets(with: options).count
            
            return (indexed: indexedCount, total: totalCount)
        }
    }

    func startIndexing() {
        Task {
            let allPhotos = await fetchAllPhotos()
            let alreadyIndexed = await fetchIndexedPhotoIDs()
            let photosToIndex = allPhotos.filter { !alreadyIndexed.contains($0.localIdentifier) }

            guard !photosToIndex.isEmpty else {
                DispatchQueue.main.async {
                    self.isIndexingComplete = true
                    self.indexingProgress = 1.0
                }
                return
            }
            
            let total = photosToIndex.count
            var processedCount = 0

            for asset in photosToIndex {
                do {
                    let embedding = try await imageEmbedderService.generateEmbedding(for: asset)
                    try await saveEmbedding(id: asset.localIdentifier, embedding: embedding)
                    
                    processedCount += 1
                    DispatchQueue.main.async {
                        self.indexedPhotoCount += 1
                        self.indexingProgress = Float(processedCount) / Float(total)
                    }
                } catch {
                    print("Failed to generate or save embedding for asset \(asset.localIdentifier): \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.isIndexingComplete = true
            }
        }
    }
    
    private func fetchAllPhotos() async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            var fetchedAssets: [PHAsset] = []
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            
            let allPhotos = PHAsset.fetchAssets(with: fetchOptions)
            allPhotos.enumerateObjects { (asset, _, _) in
                fetchedAssets.append(asset)
            }
            continuation.resume(returning: fetchedAssets)
        }
    }

    private func fetchIndexedPhotoIDs() async -> Set<String> {
        await withCheckedContinuation { continuation in
            let context = persistenceController.container.newBackgroundContext()
            context.perform {
                let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
                fetchRequest.propertiesToFetch = ["id"]
                
                do {
                    let results = try context.fetch(fetchRequest)
                    let ids = Set(results.compactMap { $0.id })
                    continuation.resume(returning: ids)
                } catch {
                    print("Failed to fetch indexed photo IDs: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    func countIndexedPhotos() -> Int {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            return count
        } catch {
            print("Failed to count indexed photos: \(error)")
            return 0
        }
    }

    func hasIndexedPhotos() -> Bool {
        return countIndexedPhotos() > 0
    }

    func filterUnindexedAssets(assets: [PHAsset]) async -> [PHAsset] {
        let allIDs = Set(assets.map { $0.localIdentifier })
        let indexedIDs = await fetchIndexedPhotoIDs()
        let unindexedIDs = allIDs.subtracting(indexedIDs)
        
        return assets.filter { unindexedIDs.contains($0.localIdentifier) }
    }
}

// MARK: - Data Conversion Helpers

extension Data {
    // Converts Data to an Array of a specific type (e.g., Float)
    func toArray<T>(type: T.Type) -> [T]? where T: ExpressibleByFloatLiteral {
        guard self.count % MemoryLayout<T>.stride == 0 else { return nil }
        var array = [T](repeating: 0.0, count: self.count / MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { copyBytes(to: $0) }
        return array
    }

    // Converts an Array of a specific type to Data
    init<T>(fromArray array: [T]) {
        self = array.withUnsafeBytes { Data($0) }
    }
}