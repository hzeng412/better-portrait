import Vision
import CoreGraphics

final class FaceDetectionService: Sendable {

    // MARK: - Phase 1: Detect face in a single image

    func detectFace(in image: CGImage) throws -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let results = request.results, !results.isEmpty else {
            return nil
        }

        let largest = results.max(by: {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        })
        return largest?.boundingBox
    }

    // MARK: - Phase 2: Compute uniform face fraction

    // Reference proportions (from the user's ideal portrait):
    //   Head (Vision face box * 1.4) = ~48% of frame height
    //   Head top margin = ~7% from frame top
    // These constants define the "ideal headshot" look.
    private let idealHeadFraction: CGFloat = 0.48
    private let headTopMarginFraction: CGFloat = 0.07

    /// "Match Largest" mode: the image with the largest face sets the fraction.
    /// Minimum is the ideal headshot fraction (0.48), so even if all faces are
    /// small, we still get the tight headshot look from the reference.
    func computeMatchLargestFraction(
        photos: [(faceRect: CGRect, imageWidth: Int, imageHeight: Int)],
        aspectRatio: CGFloat
    ) -> CGFloat {
        var maxRequired: CGFloat = idealHeadFraction

        for photo in photos {
            let headH = photo.faceRect.height * CGFloat(photo.imageHeight) * 1.4
            let imgH = CGFloat(photo.imageHeight)
            let imgW = CGFloat(photo.imageWidth)

            let reqByH = headH / imgH
            let reqByW = headH * aspectRatio / imgW
            let required = max(reqByH, reqByW)

            if required > maxRequired {
                maxRequired = required
            }
        }

        return maxRequired * 1.05
    }

    /// "Best Fit" mode: targets the ideal headshot fraction (0.48), capped at 0.55.
    /// Gives most images the reference look. Tightly-cropped originals may have
    /// slightly larger faces but nothing extreme.
    func computeBestFitFraction(
        photos: [(faceRect: CGRect, imageWidth: Int, imageHeight: Int)],
        aspectRatio: CGFloat
    ) -> CGFloat {
        let matchLargest = computeMatchLargestFraction(photos: photos, aspectRatio: aspectRatio)
        return min(matchLargest, 0.55)
    }

    // MARK: - Phase 3: Compute crop rect for one image

    /// All math in CG pixel coordinates (origin top-left, y increases downward).
    /// Matches the reference portrait: head top at ~7% from frame top.
    func computeCrop(
        faceRect: CGRect,
        imageWidth: Int,
        imageHeight: Int,
        aspectRatio: CGFloat,
        targetFaceFraction: CGFloat
    ) -> CGRect {
        let imgW = CGFloat(imageWidth)
        let imgH = CGFloat(imageHeight)

        // Convert Vision face rect (bottom-left) to CG (top-left) pixel coords
        let faceW = faceRect.width * imgW
        let faceH = faceRect.height * imgH
        let faceX_cg = faceRect.origin.x * imgW
        let faceY_cg = imgH - (faceRect.origin.y + faceRect.height) * imgH

        let faceCenterX = faceX_cg + faceW / 2.0

        // Head top: Vision face box top minus ~40% face height for hair/crown
        let headTopY = faceY_cg - faceH * 0.4
        let headH = faceH * 1.4

        // Crop dimensions from target fraction
        var cropH = headH / targetFaceFraction
        var cropW = cropH * aspectRatio

        // Clamp to image bounds while keeping aspect ratio
        if cropW > imgW {
            cropW = imgW
            cropH = cropW / aspectRatio
        }
        if cropH > imgH {
            cropH = imgH
            cropW = cropH * aspectRatio
        }

        // Position: head top at 7% from crop top (matches reference portrait)
        var cropX = faceCenterX - cropW / 2.0
        var cropY = headTopY - cropH * headTopMarginFraction

        // Shift into image bounds
        cropX = max(0, min(cropX, imgW - cropW))
        cropY = max(0, min(cropY, imgH - cropH))

        return CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
    }

    func centerCrop(imageWidth: Int, imageHeight: Int, aspectRatio: CGFloat) -> CGRect {
        let imgW = CGFloat(imageWidth)
        let imgH = CGFloat(imageHeight)
        let imageAspect = imgW / imgH

        var cropW: CGFloat
        var cropH: CGFloat

        if imageAspect > aspectRatio {
            cropH = imgH
            cropW = imgH * aspectRatio
        } else {
            cropW = imgW
            cropH = imgW / aspectRatio
        }

        let cropX = (imgW - cropW) / 2.0
        let cropY = (imgH - cropH) / 2.0

        return CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
    }
}
