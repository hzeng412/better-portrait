import Vision
import CoreGraphics
import CoreImage

final class BackgroundRemovalService: Sendable {
    private let ciContext = CIContext()

    /// Composite person onto a solid background color.
    func removeAndComposite(image: CGImage, backgroundColor: CGColor) throws -> CGImage {
        let mask = try generateMask(for: image)
        let ciSource = CIImage(cgImage: image)
        let ciMask = scaledMask(mask, to: ciSource)

        let bgImage = CIImage(color: CIColor(cgColor: backgroundColor))
            .cropped(to: ciSource.extent)

        return try blend(source: ciSource, background: bgImage, mask: ciMask)
    }

    /// Composite person onto a transparent background (PNG with alpha).
    func removeAndCompositeTransparent(image: CGImage) throws -> CGImage {
        let mask = try generateMask(for: image)
        let ciSource = CIImage(cgImage: image)
        let ciMask = scaledMask(mask, to: ciSource)

        // Transparent background
        let bgImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: ciSource.extent)

        return try blend(source: ciSource, background: bgImage, mask: ciMask)
    }

    /// Composite person onto a custom image background.
    func removeAndComposite(image: CGImage, backgroundImage: CGImage) throws -> CGImage {
        let mask = try generateMask(for: image)
        let ciSource = CIImage(cgImage: image)
        let ciMask = scaledMask(mask, to: ciSource)

        // Scale background image to match source dimensions
        let ciBg = CIImage(cgImage: backgroundImage)
        let scaleX = ciSource.extent.width / ciBg.extent.width
        let scaleY = ciSource.extent.height / ciBg.extent.height
        let scale = max(scaleX, scaleY) // fill (cover) mode
        let scaledBg = ciBg.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        // Center crop the scaled background
        let cropX = (scaledBg.extent.width - ciSource.extent.width) / 2
        let cropY = (scaledBg.extent.height - ciSource.extent.height) / 2
        let croppedBg = scaledBg.cropped(to: CGRect(
            x: scaledBg.extent.origin.x + cropX,
            y: scaledBg.extent.origin.y + cropY,
            width: ciSource.extent.width,
            height: ciSource.extent.height
        )).transformed(by: CGAffineTransform(
            translationX: -scaledBg.extent.origin.x - cropX,
            y: -scaledBg.extent.origin.y - cropY
        ))

        return try blend(source: ciSource, background: croppedBg, mask: ciMask)
    }

    // MARK: - Private

    private func scaledMask(_ mask: CGImage, to source: CIImage) -> CIImage {
        let maskCI = CIImage(cgImage: mask)
        return maskCI.transformed(by: CGAffineTransform(
            scaleX: source.extent.width / maskCI.extent.width,
            y: source.extent.height / maskCI.extent.height
        ))
    }

    private func blend(source: CIImage, background: CIImage, mask: CIImage) throws -> CGImage {
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            throw ProcessingError.compositingFailed
        }
        blendFilter.setValue(source, forKey: kCIInputImageKey)
        blendFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(mask, forKey: "inputMaskImage")

        guard let outputImage = blendFilter.outputImage,
              let result = ciContext.createCGImage(outputImage, from: source.extent) else {
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
