import SwiftUI

struct ProcessingProgressView: View {
    @ObservedObject var viewModel: PortraitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                Text("Progress")
                    .font(.subheadline.weight(.semibold))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Phase indicator
            phaseHeader
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 12)

            // Per-photo list (unprocessed/warnings on top, completed at bottom)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sortedPhotos) { photo in
                        photoStepRow(photo)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Export notification
            if let message = viewModel.exportMessage {
                Divider()
                    .padding(.horizontal, 12)

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: message.contains("error")
                              ? "xmark.circle.fill"
                              : "checkmark.circle.fill")
                            .foregroundStyle(message.contains("error") ? .red : .green)
                            .font(.caption)

                        Text(message)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let directory = viewModel.exportedDirectory {
                        Button {
                            NSWorkspace.shared.open(directory)
                        } label: {
                            Label("Open in Finder", systemImage: "folder")
                                .font(.caption.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()
                .padding(.horizontal, 12)

            // Action buttons
            HStack(spacing: 8) {
                Button(action: { viewModel.processAll() }) {
                    Label(
                        viewModel.hasProcessedPhotos ? "Reprocess" : "Process",
                        systemImage: "wand.and.stars"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(viewModel.isProcessing)

                Menu {
                    Button(action: { viewModel.exportAll() }) {
                        Label("Export All", systemImage: "square.and.arrow.up.on.square")
                    }
                    Button(action: { viewModel.exportProcessedOnly() }) {
                        Label("Export Processed Only", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderedButton)
                .controlSize(.large)
                .disabled(!viewModel.hasProcessedPhotos || viewModel.isProcessing)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 250)
        .background(.ultraThinMaterial)
    }

    private var sortedPhotos: [PortraitPhoto] {
        if viewModel.currentPhase == .done {
            return viewModel.photos.sorted { a, b in
                sortOrder(a) < sortOrder(b)
            }
        }
        return viewModel.photos
    }

    private func sortOrder(_ photo: PortraitPhoto) -> Int {
        switch photo.processingStep {
        case .error: return 0
        case .noFaceFound: return 1
        case .waiting: return 2
        case .complete where !photo.faceDetected: return 3
        case .complete: return 4
        default: return 2
        }
    }

    @ViewBuilder
    private var phaseHeader: some View {
        HStack(spacing: 8) {
            switch viewModel.currentPhase {
            case .idle:
                phaseContent(icon: "photo.on.rectangle", text: "\(viewModel.photos.count) photo\(viewModel.photos.count == 1 ? "" : "s") loaded", color: .secondary, active: false)
            case .detectingFaces(let current, let total):
                phaseContent(icon: "eye.fill", text: "Detecting Faces \(current)/\(total)", color: .blue, active: true)
            case .normalizingFaces:
                phaseContent(icon: "arrow.left.and.right", text: "Normalizing", color: .orange, active: true)
            case .croppingAndCompositing(let current, let total):
                phaseContent(icon: "scissors", text: "Processing \(current)/\(total)", color: .purple, active: true)
            case .done:
                phaseContent(icon: "checkmark.circle.fill", text: "All Processed", color: .green, active: false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func phaseContent(icon: String, text: String, color: Color, active: Bool) -> some View {
        HStack(spacing: 8) {
            if active {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
            }
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(active ? .primary : .secondary)
        }
    }

    private func photoStepRow(_ photo: PortraitPhoto) -> some View {
        let hasWarning = photo.processingStep == .complete && !photo.faceDetected

        return HStack(spacing: 8) {
            stepIcon(for: photo.processingStep, noFace: !photo.faceDetected)
                .frame(width: 14, height: 14)

            Text(photo.filename)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)

            Spacer()

            Text(hasWarning ? "No face found" : photo.processingStep.rawValue)
                .font(.caption2)
                .foregroundStyle(hasWarning ? .yellow : stepColor(for: photo.processingStep))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            photo.processingStep == .complete && photo.faceDetected
                ? Color.green.opacity(0.06)
                : hasWarning
                    ? Color.yellow.opacity(0.06)
                    : photo.processingStep == .error
                        ? Color.red.opacity(0.06)
                        : Color.clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
    }

    @ViewBuilder
    private func stepIcon(for step: ProcessingStep, noFace: Bool = false) -> some View {
        switch step {
        case .waiting:
            Image(systemName: "circle")
                .font(.system(size: 8))
                .foregroundStyle(.quaternary)
        case .detectingFace, .cropping, .removingBackground:
            ProgressView()
                .controlSize(.mini)
        case .faceDetected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .noFaceFound:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
        case .complete:
            if noFace {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        }
    }

    private func stepColor(for step: ProcessingStep) -> Color {
        switch step {
        case .waiting: return .secondary
        case .detectingFace, .cropping, .removingBackground: return .blue
        case .faceDetected, .complete: return .green
        case .noFaceFound: return .yellow
        case .error: return .red
        }
    }
}
