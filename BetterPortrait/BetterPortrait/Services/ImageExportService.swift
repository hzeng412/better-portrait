import AppKit
import CoreGraphics
import UniformTypeIdentifiers

final class ImageExportService {
    enum ExportFormat {
        case png
        case jpeg(quality: CGFloat)

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            }
        }

        var utType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            }
        }
    }

    /// Check which files would be overwritten.
    func existingFiles(for photos: [(filename: String, image: CGImage)], in directory: URL, format: ExportFormat = .png) -> [String] {
        let fm = FileManager.default
        return photos.compactMap { photo in
            let url = directory.appendingPathComponent("\(photo.filename).\(format.fileExtension)")
            return fm.fileExists(atPath: url.path) ? url.lastPathComponent : nil
        }
    }

    /// Export a batch of processed images to a directory.
    func exportAll(photos: [(filename: String, image: CGImage)], to directory: URL, format: ExportFormat = .png, maxSize: Int? = nil) throws -> [URL] {
        var exportedURLs: [URL] = []

        for photo in photos {
            let url = directory.appendingPathComponent("\(photo.filename).\(format.fileExtension)")
            let imageToExport = maxSize.flatMap { resized(photo.image, maxDimension: $0) } ?? photo.image
            try export(image: imageToExport, to: url, format: format)
            exportedURLs.append(url)
        }

        return exportedURLs
    }

    private func resized(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let w = image.width
        let h = image.height
        guard max(w, h) > maxDimension else { return image }

        let scale = CGFloat(maxDimension) / CGFloat(max(w, h))
        let newW = Int((CGFloat(w) * scale).rounded())
        let newH = Int((CGFloat(h) * scale).rounded())

        guard let ctx = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return image }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage() ?? image
    }

    func export(image: CGImage, to url: URL, format: ExportFormat = .png) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, format.utType.identifier as CFString, 1, nil) else {
            throw ProcessingError.exportFailed("Could not create image destination")
        }

        var options: [CFString: Any] = [:]
        if case .jpeg(let quality) = format {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ProcessingError.exportFailed("Could not write image to \(url.lastPathComponent)")
        }
    }
}
