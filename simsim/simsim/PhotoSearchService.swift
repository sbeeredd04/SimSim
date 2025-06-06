import Foundation
import hnswlib_swift

enum PhotoSearchError: Error {
    case indexNotInitialized
    case indexBuildingFailed(Error)
    case searchFailed(Error)
    case invalidEmbeddingDimension
}

class PhotoSearchService {
    // This property needs to be accessible from ContentView to check its status
    private(set) var hnswIndex: HNSWIndex?
    private let embeddingDimension: Int
    private let photoIndexManager: PhotoIndexManager
    private let textEmbedderService: TextEmbedderService
    
    // This will map the HNSW internal UInt32 labels back to our PHAsset string identifiers
    private var labelToLocalIdentifier: [UInt32: String] = [:]
    private var localIdentifierToLabel: [String: UInt32] = [:]

    init(embeddingDimension: Int, photoIndexManager: PhotoIndexManager, textEmbedderService: TextEmbedderService) {
        self.embeddingDimension = embeddingDimension
        self.photoIndexManager = photoIndexManager
        self.textEmbedderService = textEmbedderService
    }

    // MARK: - Index Management

    func buildIndex() async throws {
        guard hnswIndex == nil else {
            print("HNSW Index already built.")
            return
        }

        print("Starting HNSW index build...")
        let allEmbeddings = try await photoIndexManager.fetchAllEmbeddings()

        guard !allEmbeddings.isEmpty else {
            print("No embeddings found to build HNSW index.")
            return
        }
        
        // Populate the mapping between string IDs and UInt32 labels
        var currentLabel: UInt32 = 0
        for embedding in allEmbeddings {
            if localIdentifierToLabel[embedding.id] == nil {
                labelToLocalIdentifier[currentLabel] = embedding.id
                localIdentifierToLabel[embedding.id] = currentLabel
                currentLabel += 1
            }
        }

        let maxElements = allEmbeddings.count + 1000

        hnswIndex = try HNSWIndex(spaceType: .cosine,
                                  dim: embeddingDimension)

        let embeddingVectors = allEmbeddings.map { $0.embedding }
        let labels = allEmbeddings.map { UInt32(localIdentifierToLabel[$0.id]!) }

        // Debug logging for embeddings
        print("Embedding count: \(embeddingVectors.count)")
        if let first = embeddingVectors.first {
            print("Embedding dimension (first): \(first.count)")
            print("Type of first embedding element: \(type(of: first.first))")
        }
        for (i, emb) in embeddingVectors.enumerated() {
            if emb.count != embeddingDimension {
                print("[HNSWIndex Debug] Embedding at index \(i) has wrong dimension: \(emb.count), expected: \(embeddingDimension)")
            }
            if emb.contains(where: { !$0.isFinite }) {
                print("[HNSWIndex Debug] Embedding at index \(i) contains non-finite values!")
            }
        }
        if embeddingVectors.isEmpty {
            print("[HNSWIndex Debug] No embeddings to add to HNSW index!")
        }

        if !embeddingVectors.isEmpty {
            try hnswIndex?.addItems(data: embeddingVectors)
            print("HNSW Index built with \(allEmbeddings.count) elements.")
        } else {
            print("No embeddings to add to HNSW index.")
        }
    }

    // MARK: - Search

    func performSemanticSearch(query: String, topK: Int) async throws -> [String] {
        guard let index = hnswIndex else {
            throw PhotoSearchError.indexNotInitialized
        }

        let queryEmbedding = try await textEmbedderService.generateEmbedding(for: query)

        guard queryEmbedding.count == embeddingDimension else {
            throw PhotoSearchError.invalidEmbeddingDimension
        }

        let searchResults = try index.searchKnn(query: [queryEmbedding], k: topK)
        
        let resultLabels = searchResults.labels.first ?? []
        
        // Map the UInt32 labels back to the original photo localIdentifiers
        let photoIds = resultLabels.compactMap { labelToLocalIdentifier[UInt32($0)] }
        return photoIds
    }
} 