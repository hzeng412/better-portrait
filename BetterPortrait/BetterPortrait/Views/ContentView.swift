import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PortraitViewModel()

    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                // Left panel: settings
                ExportSettingsView(viewModel: viewModel)

                // Main content area
                if viewModel.hasPhotos {
                    PhotoGridView(viewModel: viewModel)
                } else {
                    ImportDropZone(viewModel: viewModel)
                }

                // Right panel: processing progress
                if viewModel.hasPhotos {
                    ProcessingProgressView(viewModel: viewModel)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.hasPhotos)
        }
        .frame(minWidth: 900, minHeight: 550)
    }
}
