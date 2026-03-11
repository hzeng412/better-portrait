import Vision
import CoreGraphics
import CoreImage

final class BackgroundRemovalService: Sendable {
    private let ciContext = CIContext()

    /// Generate a person segmentation mask, then composite onto a background color.
    /// Runs synchronously — call from a background thread.
    func removeAndComposite(image: CGImage, backgroundColor: CGColor) throws -> CGImage {
        let mask = try generateMask(for: image)

        let ciSource = CIImage(cgImage: image)
        let maskCI = CIImage(cgImage: mask)
        let ciMask = maskCI.transformed(by: CGAffineTransform(
            scaleX: ciSource.extent.width / maskCI.extent.width,
            y: ciSource.extent.height / maskCI.extent.height
        ))

        let bgImage = CIImage(color: CIColor(cgColor: backgroundColor))
            .cropped(to: ciSource.extent)

        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            throw ProcessingError.compositingFailed
        }
        blendFilter.setValue(ciSource, forKey: kCIInputImageKey)
        blendFilter.setValue(bgImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(ciMask, forKey: "inputMaskImage")

        guard let outputImage = blendFilter.outputImage,
              let result = ciContext.createCGImage(outputImage, from: ciSource.extent) else {
            throw ProcessingError.compositingFailed
        }

        return result
    }

    private func generateMask(for image: CGImage) throws -> CGImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            throw ProcessingError.segmentationFailed
        }

        let maskBuffer = result.pixelBuffer
        let ciImage = CIImage(cvPixelBuffer: maskBuffer)

        guard let cgMask = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw ProcessingError.segmentationFailed
        }

        return cgMask
    }
}

enum ProcessingError: LocalizedError {
    case segmentationFailed
    case compositingFailed
    case faceDetectionFailed
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .segmentationFailed:
            return "Person segmentation failed"
        case .compositingFailed:
            return "Image compositing failed"
        case .faceDetectionFailed:
            return "Face detection failed"
        case .exportFailed(let msg):
            return "Export failed: \(msg)"
        }
    }
}
