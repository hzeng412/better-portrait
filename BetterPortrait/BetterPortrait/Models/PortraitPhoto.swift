import AppKit
import CoreGraphics

enum ProcessingStatus: Equatable {
    case pending
    case processing
    case completed
    case failed(String)

    static func == (lhs: ProcessingStatus, rhs: ProcessingStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.processing, .processing), (.completed, .completed):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

enum ProcessingStep: String {
    case waiting = "Waiting"
    case detectingFace = "Detecting face"
    case faceDetected = "Face detected"
    case noFaceFound = "No face found"
    case cropping = "Cropping"
    case removingBackground = "Removing background"
    case complete = "Processed"
    case error = "Error"
}

enum AspectRatioPreset: String, CaseIterable, Identifiable {
    case square = "1:1"
    case portrait3x4 = "3:4"
    case portrait9x16 = "9:16"
    case landscape4x3 = "4:3"
    case landscape16x9 = "16:9"

    var id: String { rawValue }

    var ratio: CGFloat {
        switch self {
        case .square: return 1.0
        case .portrait3x4: return 3.0 / 4.0
        case .portrait9x16: return 9.0 / 16.0
        case .landscape4x3: return 4.0 / 3.0
        case .landscape16x9: return 16.0 / 9.0
        }
    }

    var label: String {
        switch self {
        case .square: return "1:1"
        case .portrait3x4: return "3:4 ↕"
        case .portrait9x16: return "9:16 ↕"
        case .landscape4x3: return "4:3 ↔"
        case .landscape16x9: return "16:9 ↔"
        }
    }
}

enum SizingMode: String, CaseIterable, Identifiable {
    case bestFit = "Best Fit"
    case matchLargest = "Match Largest"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .matchLargest:
            return "All faces exactly the same size (driven by the largest face)"
        case .bestFit:
            return "Faces approximately similar, better framing for most photos"
        }
    }
}

enum BackgroundMode: Equatable {
    case solidColor
    case transparent
    case image(URL)
}

struct PortraitPhoto: Identifiable {
    let id = UUID()
    let originalURL: URL
    let originalImage: CGImage
    var processedImage: CGImage?
    var status: ProcessingStatus = .pending
    var faceDetected: Bool = true
    var processingStep: ProcessingStep = .waiting
    /// Vision-normalized face bounding box (bottom-left origin), nil if no face found
    var detectedFaceRect: CGRect?

    var displayImage: NSImage {
        let cgImage = processedImage ?? originalImage
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    var filename: String {
        originalURL.deletingPathExtension().lastPathComponent
    }
}
