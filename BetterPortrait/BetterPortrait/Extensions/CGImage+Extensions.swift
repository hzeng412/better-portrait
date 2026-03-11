import CoreGraphics
import AppKit

extension CGImage {
    /// Crop the image to the given rect (in pixel coordinates), clamped to image bounds.
    func cropping(toPixelRect rect: CGRect) -> CGImage? {
        let clamped = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !clamped.isEmpty else { return nil }
        // Round to integers to avoid fractional pixel issues
        let intRect = CGRect(
            x: floor(clamped.origin.x),
            y: floor(clamped.origin.y),
            width: floor(clamped.width),
            height: floor(clamped.height)
        )
        guard intRect.width > 0, intRect.height > 0 else { return nil }
        return self.cropping(to: intRect)
    }

    /// Resize image to target size.
    func resized(to size: CGSize) -> CGImage? {
        guard Int(size.width) > 0, Int(size.height) > 0 else { return nil }
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let ctx = context else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(self, in: CGRect(origin: .zero, size: size))
        return ctx.makeImage()
    }

    /// Load a CGImage from a file URL.
    static func from(url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image
    }
}
