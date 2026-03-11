import SwiftUI
import UniformTypeIdentifiers

struct ImportDropZone: View {
    @ObservedObject var viewModel: PortraitViewModel
    @State private var isTargeted = false
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon with glass backing
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("BetterPortrait")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Batch-process portrait photos with automatic face detection, uniform cropping, and background replacement.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            VStack(spacing: 4) {
                Text("Drop portrait photos here")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text("or")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                viewModel.importFiles()
            } label: {
                Label("Choose Files", systemImage: "folder.badge.plus")
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Supports JPEG, PNG, HEIC")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isTargeted ? Color.accentColor.opacity(0.06) : .clear)
                .padding(12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.15),
                    style: StrokeStyle(lineWidth: 1.5, dash: isTargeted ? [] : [10, 6])
                )
                .padding(12)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
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
