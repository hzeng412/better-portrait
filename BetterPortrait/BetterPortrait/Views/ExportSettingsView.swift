import SwiftUI

struct ExportSettingsView: View {
    @ObservedObject var viewModel: PortraitViewModel

    private let presetColors: [(String, Color)] = [
        ("White", .white),
        ("Light Gray", Color(nsColor: .init(white: 0.93, alpha: 1))),
        ("Black", .black),
        ("Blue", Color(red: 0.2, green: 0.4, blue: 0.7)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                Text("Settings")
                    .font(.subheadline.weight(.semibold))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Crop ratio
                    settingsSection(title: "Crop", icon: "crop") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(AspectRatioPreset.allCases) { preset in
                                radioRow(
                                    label: preset.label,
                                    selected: viewModel.selectedAspectRatio == preset
                                ) {
                                    viewModel.selectedAspectRatio = preset
                                }
                            }
                        }
                    }

                    // Background color
                    settingsSection(title: "Fill", icon: "paintbrush.fill") {
                        HStack(spacing: 8) {
                            ForEach(presetColors, id: \.0) { name, color in
                                colorButton(name: name, color: color)
                            }

                            Spacer()

                            ColorPicker("", selection: $viewModel.backgroundColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 30)
                                .help("Custom Color")
                        }
                    }

                    // Sizing mode
                    settingsSection(title: "Sizing", icon: "person.2.crop.square.stack.fill") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(SizingMode.allCases) { mode in
                                radioRow(
                                    label: mode.rawValue,
                                    selected: viewModel.selectedSizingMode == mode
                                ) {
                                    viewModel.selectedSizingMode = mode
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func radioRow(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .blue : .secondary)
                    .font(.system(size: 14))

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(selected ? .primary : .secondary)

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                selected ? Color.blue.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private func colorButton(name: String, color: Color) -> some View {
        Button {
            viewModel.backgroundColor = color
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)

                Circle()
                    .strokeBorder(
                        viewModel.backgroundColor == color
                            ? Color.accentColor
                            : Color.primary.opacity(0.12),
                        lineWidth: viewModel.backgroundColor == color ? 2.5 : 1
                    )
                    .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(.plain)
        .help(name)
    }
}
