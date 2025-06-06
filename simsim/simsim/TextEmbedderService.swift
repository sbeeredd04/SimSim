import CoreML
import Foundation

enum TextEmbeddingError: Error {
    case modelInitializationFailed
    case textEncodingFailed
    case invalidModelOutput
    case tokenizationFailed
}

class TextEmbedderService {
    private let textEncoder: clip_text_s2
    private let tokenizer = SimpleTokenizer()
    private let sequenceLength = 77 // Standard for CLIP models

    init() throws {
        do {
            self.textEncoder = try clip_text_s2(configuration: MLModelConfiguration())
        } catch {
            throw TextEmbeddingError.modelInitializationFailed
        }
    }

    func generateEmbedding(for text: String) async throws -> [Float] {
        // 1. Tokenize text
        let tokenIds = tokenizer.tokenize(text: text)
        
        // 2. Pad or truncate tokens to the required sequence length
        var paddedTokenIds = tokenIds + Array(repeating: 0, count: max(0, sequenceLength - tokenIds.count))
        if paddedTokenIds.count > sequenceLength {
            paddedTokenIds = Array(paddedTokenIds.prefix(sequenceLength))
        }

        do {
            // 3. Create MLMultiArray from token IDs
            let inputMultiArray = try MLMultiArray(shape: [1, NSNumber(value: sequenceLength)], dataType: .int32)
            for (index, token) in paddedTokenIds.enumerated() {
                inputMultiArray[index] = NSNumber(value: token)
            }
            
            // 4. Make prediction
            // Note: The input parameter name 'input' must match the one in the auto-generated 'clip_text_s2' class.
            let modelInput = clip_text_s2Input(input_text: inputMultiArray)
            let prediction = try await self.textEncoder.prediction(input: modelInput)
            
            // 5. Extract and convert output
            // Try to access the output using featureValue(for:)
            guard let embeddingMultiArray = prediction.featureValue(for: "output")?.multiArrayValue else {
                throw TextEmbeddingError.invalidModelOutput
            }

            let embeddingSize = embeddingMultiArray.count
            var embedding = [Float](repeating: 0, count: embeddingSize)
            let ptr = embeddingMultiArray.dataPointer.bindMemory(to: Float.self, capacity: embeddingSize)
            for i in 0..<embeddingSize {
                embedding[i] = ptr[i]
            }
            return embedding

        } catch {
            print("Error generating text embedding: \(error)")
            throw TextEmbeddingError.textEncodingFailed
        }
    }
}

// A very basic tokenizer for demonstration purposes.
// A real CLIP implementation requires a specific BPE (Byte-Pair Encoding) tokenizer.
class SimpleTokenizer {
    func tokenize(text: String) -> [Int] {
        let text = text.lowercased()
        let tokens = text.components(separatedBy: .whitespacesAndNewlines)
        // A dummy conversion of string to some integer hash. Not a real vocabulary.
        return tokens.map { abs($0.hashValue % 49408) } // 49408 is vocab size for CLIP
    }
} 
