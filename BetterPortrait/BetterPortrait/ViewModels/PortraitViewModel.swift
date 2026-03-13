import SwiftUI
import AppKit

enum ProcessingPhase: Equatable {
    case idle
    case detectingFaces(current: Int, total: Int)
    case normalizingFaces
    case croppingAndCompositing(current: Int, total: Int)
    case done
}

@MainActor
final class PortraitViewModel: ObservableObject {
    @Published var photos: [PortraitPhoto] = []
    @Published var backgroundColor: Color = .white
    @Published var backgroundMode: BackgroundMode = .solidColor
    @Published var backgroundImageURL: URL?
    @Published var selectedAspectRatio: AspectRatioPreset = .square
    @Published var selectedSizingMode: SizingMode = .bestFit
    @Published var isProcessing = false
    @Published var exportMessage: String?
    @Published var exportedDirectory: URL?
    @Published var currentPhase: ProcessingPhase = .idle

    private let faceDetection = FaceDetectionService()
    private let backgroundRemoval = BackgroundRemovalService()
    private let exportService = ImageExportService()

    var processedCount: Int {
        photos.filter { $0.status == .completed }.count
    }

    var hasPhotos: Bool {
        !photos.isEmpty
    }

    var hasProcessedPhotos: Bool {
        processedCount > 0
    }

    // MARK: - Import (no auto-processing)

    func importFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK else { return }
        addFiles(urls: panel.urls)
    }

    func addFiles(urls: [URL]) {
        for url in urls {
            guard let image = CGImage.from(url: url) else { continue }
            let photo = PortraitPhoto(originalURL: url, originalImage: image)
            photos.append(photo)
        }
    }

    // MARK: - Processing (manual, serial with UI updates)

    func processAll() {
        guard !isProcessing else { return }
        isProcessing = true
        exportMessage = nil

        let bgColor = NSColor(backgroundColor).cgColor
        let bgMode = backgroundMode
        let bgImageCG: CGImage? = {
            if case .image(let url) = bgMode {
                return CGImage.from(url: url)
            }
            return nil
        }()
        let ratio = selectedAspectRatio.ratio
        let sizingMode = selectedSizingMode
        let total = photos.count

        // Reset all photos
        for i in photos.indices {
            photos[i].status = .processing
            photos[i].processedImage = nil
            photos[i].processingStep = .waiting
            photos[i].detectedFaceRect = nil
        }

        Task {
            // ── Phase 1: Face Detection ──
            var faceInfos: [(index: Int, faceRect: CGRect, imgW: Int, imgH: Int)] = []

            for i in photos.indices {
                currentPhase = .detectingFaces(current: i + 1, total: total)
                photos[i].processingStep = .detectingFace

                let image = photos[i].originalImage
                let faceRect: CGRect? = await Task.detached {
                    try? self.faceDetection.detectFace(in: image)
                }.value

                photos[i].detectedFaceRect = faceRect
                photos[i].faceDetected = faceRect != nil
                photos[i].processingStep = faceRect != nil ? .faceDetected : .noFaceFound

                if let rect = faceRect {
                    faceInfos.append((i, rect, image.width, image.height))
                }
            }

            // ── Phase 2: Compute face fraction based on sizing mode ──
            currentPhase = .normalizingFaces

            let targetFraction: CGFloat
            if faceInfos.isEmpty {
                targetFraction = 0.28
            } else {
                let inputs = faceInfos.map {
                    (faceRect: $0.faceRect, imageWidth: $0.imgW, imageHeight: $0.imgH)
                }
                switch sizingMode {
                case .matchLargest:
                    targetFraction = faceDetection.computeMatchLargestFraction(
                        photos: inputs, aspectRatio: ratio
                    )
                case .bestFit:
                    targetFraction = faceDetection.computeBestFitFraction(
                        photos: inputs, aspectRatio: ratio
                    )
                }
            }

            // ── Phase 3: Crop + Background Removal (skip photos with no face) ──
            for i in photos.indices {
                currentPhase = .croppingAndCompositing(current: i + 1, total: total)

                // No face found — keep original image untouched
                guard let faceRect = photos[i].detectedFaceRect else {
                    photos[i].status = .completed
                    continue
                }

                let image = photos[i].originalImage
                let imgW = image.width
                let imgH = image.height

                photos[i].processingStep = .cropping

                let cropRect = faceDetection.computeCrop(
                    faceRect: faceRect,
                    imageWidth: imgW,
                    imageHeight: imgH,
                    aspectRatio: ratio,
                    targetFaceFraction: targetFraction
                )

                guard let cropped = image.cropping(toPixelRect: cropRect) else {
                    photos[i].status = .failed("Crop failed")
                    photos[i].processingStep = .error
                    continue
                }

                photos[i].processingStep = .removingBackground

                let result: Result<CGImage, Error> = await Task.detached {
                    do {
                        let composited: CGImage
                        switch bgMode {
                        case .transparent:
                            composited = try self.backgroundRemoval.removeAndCompositeTransparent(image: cropped)
                        case .image(_):
                            if let bgImg = bgImageCG {
                                composited = try self.backgroundRemoval.removeAndComposite(image: cropped, backgroundImage: bgImg)
                            } else {
                                composited = try self.backgroundRemoval.removeAndComposite(image: cropped, backgroundColor: bgColor)
                            }
                        case .solidColor:
                            composited = try self.backgroundRemoval.removeAndComposite(image: cropped, backgroundColor: bgColor)
                        }
                        return .success(composited)
                    } catch {
                        return .failure(error)
                    }
                }.value

                switch result {
                case .success(let composited):
                    photos[i].processedImage = composited
                    photos[i].status = .completed
                    photos[i].processingStep = .complete
                case .failure(let error):
                    photos[i].status = .failed(error.localizedDescription)
                    photos[i].processingStep = .error
                }
            }

            currentPhase = .done
            isProcessing = false
        }
    }

    // MARK: - Export

    func exportAll() {
        exportPhotos(processedOnly: false)
    }

    func exportProcessedOnly() {
        exportPhotos(processedOnly: true)
    }

    private func exportPhotos(processedOnly: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"

        guard panel.runModal() == .OK, let directory = panel.url else { return }

        let toExport: [(filename: String, image: CGImage)]
        if processedOnly {
            toExport = photos.compactMap { photo -> (filename: String, image: CGImage)? in
                guard let processed = photo.processedImage else { return nil }
                return (photo.filename, processed)
            }
        } else {
            toExport = photos.map { photo in
                (photo.filename, photo.processedImage ?? photo.originalImage)
            }
        }

        // Check for existing files and confirm overwrite
        let existing = exportService.existingFiles(for: toExport, in: directory)
        if !existing.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Overwrite existing files?"
            alert.informativeText = "\(existing.count) file\(existing.count == 1 ? "" : "s") already exist\(existing.count == 1 ? "s" : "") in this folder and will be replaced."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            let urls = try exportService.exportAll(photos: toExport, to: directory)
            exportMessage = "Exported \(urls.count) photos"
            exportedDirectory = directory
        } catch {
            exportMessage = "Export error: \(error.localizedDescription)"
            exportedDirectory = nil
        }
    }

    func pickBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "Choose a background image"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        backgroundImageURL = url
        backgroundMode = .image(url)
    }

    func removePhoto(_ photo: PortraitPhoto) {
        photos.removeAll { $0.id == photo.id }
    }

    func clearAll() {
        photos.removeAll()
        exportMessage = nil
        currentPhase = .idle
    }
}
