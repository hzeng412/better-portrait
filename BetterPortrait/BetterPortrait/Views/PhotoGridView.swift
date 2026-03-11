import SwiftUI
import UniformTypeIdentifiers

struct PhotoGridView: View {
    @ObservedObject var viewModel: PortraitViewModel
    @State private var isTargeted = false

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button(action: { viewModel.importFiles() }) {
                    Label("Add Photos", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderless)

                Spacer()

                if viewModel.isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                } else if viewModel.processedCount > 0 {
                    Text("\(viewModel.processedCount)/\(viewModel.photos.count) processed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                Button(role: .destructive, action: { viewModel.clearAll() }) {
                    Label("Clear All", systemImage: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.photos) { photo in
                        PhotoThumbnailView(photo: photo) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                viewModel.removePhoto(photo)
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(isTargeted ? Color.accentColor.opacity(0.04) : Color.clear)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
                return true
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                defer { group.leave() }
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                let imageTypes: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp"]
                if imageTypes.contains(url.pathExtension.lowercased()) {
                    urls.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            viewModel.addFiles(urls: urls)
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: PortraitPhoto
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: photo.displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(borderColor, lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)

                // Status badge
                statusBadge
                    .padding(6)
            }

            Text(photo.filename)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button { onRemove() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch photo.status {
        case .processing:
            ProgressView()
                .controlSize(.mini)
                .padding(5)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .help("Processing...")
        case .completed where !photo.faceDetected:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.caption2)
                .padding(5)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .help("No face detected — center crop was used instead")
        case .failed(let message):
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption2)
                .padding(5)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .help(message)
        default:
            EmptyView()
        }
    }

    private var borderColor: Color {
        switch photo.status {
        case .completed where photo.faceDetected: return .green.opacity(0.4)
        case .completed: return .yellow.opacity(0.4)
        case .failed: return .red.opacity(0.4)
        default: return .clear
        }
    }
}
