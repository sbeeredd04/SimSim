import CoreML
import Vision
import UIKit
import Photos

enum ImageEmbeddingError: Error {
    case modelInitializationFailed
    case imageConversionFailed
    case visionRequestFailed(Error)
    case invalidModelOutput
    case embeddingExtractionFailed
    case assetLoadingFailed
}

class ImageEmbedderService {
    private let model: VNCoreMLModel // Vision wrapper around our Core ML model
    private let imageEmbedder: clip_image_s2 // The auto-generated Core ML model class

    // Initialize the service with our Core ML model
    init() throws {
        do {
            // Instantiate the auto-generated Core ML model class
            // Xcode auto-generates the `clip_image_s2` class from the model file.
            self.imageEmbedder = try clip_image_s2(configuration: MLModelConfiguration())
            // Create a VNCoreMLModel from it for Vision framework
            self.model = try VNCoreMLModel(for: self.imageEmbedder.model)
        } catch {
            throw ImageEmbeddingError.modelInitializationFailed
        }
    }

    // Public method to generate embedding for a PHAsset
    func generateEmbedding(for asset: PHAsset) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = true // Ensure we get the image data right away
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                guard let data = data, let uiImage = UIImage(data: data) else {
                    continuation.resume(throwing: ImageEmbeddingError.assetLoadingFailed)
                    return
                }

                // Resize image to model's expected input size (e.g., 224x224)
                let targetSize = CGSize(width: 224, height: 224)
                guard let resizedImage = uiImage.resized(to: targetSize) else {
                    continuation.resume(throwing: ImageEmbeddingError.imageConversionFailed)
                    return
                }

                // Convert UIImage to CVPixelBuffer for Vision input
                guard let pixelBuffer = resizedImage.toCVPixelBuffer() else {
                    continuation.resume(throwing: ImageEmbeddingError.imageConversionFailed)
                    return
                }

                // Create a Vision request to run the Core ML model
                let request = VNCoreMLRequest(model: self.model) { request, error in
                    if let error = error {
                        continuation.resume(throwing: ImageEmbeddingError.visionRequestFailed(error))
                        return
                    }

                    // Process the results
                    guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
                          let featureValue = observations.first?.featureValue,
                          let multiArray = featureValue.multiArrayValue else {
                        continuation.resume(throwing: ImageEmbeddingError.invalidModelOutput)
                        return
                    }

                    // Convert MLMultiArray to Swift Array of Floats
                    let embeddingSize = multiArray.count
                    var embedding = [Float](repeating: 0, count: embeddingSize)
                    for i in 0..<embeddingSize {
                        embedding[i] = multiArray[i].floatValue
                    }
                    continuation.resume(returning: embedding)
                }

                // Specify how Vision should handle image scaling for the model
                request.imageCropAndScaleOption = .centerCrop

                // Create a Vision request handler for the pixel buffer
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: ImageEmbeddingError.visionRequestFailed(error))
                }
            }
        }
    }
}

// MARK: - UIImage Helpers

extension UIImage {
    // Resizes a UIImage to a target size without distortion
    func resized(to newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }

    // Converts a UIImage to CVPixelBuffer
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(self.size.width),
                                         Int(self.size.height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs,
                                         &pixelBuffer)

        guard status == kCVReturnSuccess, let pBuffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pBuffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(self.size.width),
                                      height: Int(self.size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }

        context.translateBy(x: 0, y: self.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return pBuffer
    }
}
