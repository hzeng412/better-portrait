import SwiftUI

struct ExportSettingsView: View {
    @ObservedObject var viewModel: PortraitViewModel

    private let presetColors: [(String, Color)] = [
        ("White", .white),
        ("Light Gray", Color(nsColor: .init(white: 0.93, alpha: 1))),
        ("Black", .black),
        ("Blue", Color(red: 0.2, green: 0.4, blue: 0.7)),
    ]

    private var isCustomColor: Bool {
        !presetColors.contains { $0.1 == viewModel.backgroundColor }
    }

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

                    // Background mode
                    settingsSection(title: "Background", icon: "paintbrush.fill") {
                        VStack(alignment: .leading, spacing: 4) {
                            // Solid color option
                            radioRow(
                                label: "Solid Color",
                                selected: viewModel.backgroundMode == .solidColor
                            ) {
                                viewModel.backgroundMode = .solidColor
                            }

                            HStack(spacing: 8) {
                                ForEach(presetColors, id: \.0) { name, color in
                                    colorButton(name: name, color: color)
                                }

                                ColorPicker("", selection: $viewModel.backgroundColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .fixedSize()
                                    .scaleEffect(24.0 / 38.0)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .overlay(
                                        ZStack {
                                            if isCustomColor {
                                                Circle()
                                                    .fill(viewModel.backgroundColor)
                                                Circle()
                                                    .strokeBorder(
                                                        viewModel.backgroundMode == .solidColor ? Color.accentColor : Color.primary.opacity(0.12),
                                                        lineWidth: viewModel.backgroundMode == .solidColor ? 2.5 : 1
                                                    )
                                            } else {
                                                Circle()
                                                    .fill(
                                                        AngularGradient(
                                                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                                            center: .center
                                                        )
                                                    )
                                                Circle()
                                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                            }
                                        }
                                        .allowsHitTesting(false)
                                    )
                                    .help("Custom Color")
                                    .onChange(of: viewModel.backgroundColor) {
                                        viewModel.backgroundMode = .solidColor
                                    }
                            }
                            .padding(.leading, 30)
                            .padding(.trailing, 8)
                            .padding(.top, 2)

                            // Transparent option
                            radioRow(
                                label: "Transparent",
                                selected: viewModel.backgroundMode == .transparent
                            ) {
                                viewModel.backgroundMode = .transparent
                            }

                            // Custom image option
                            radioRow(
                                label: "Custom Image",
                                selected: {
                                    if case .image = viewModel.backgroundMode { return true }
                                    return false
                                }()
                            ) {
                                if viewModel.backgroundImageURL != nil {
                                    viewModel.backgroundMode = .image(viewModel.backgroundImageURL!)
                                } else {
                                    viewModel.pickBackgroundImage()
                                }
                            }

                            if viewModel.backgroundImageURL == nil {
                                // No image selected yet — show "Choose Image" button
                                Button {
                                    viewModel.pickBackgroundImage()
                                } label: {
                                    Label("Choose Image", systemImage: "plus.square")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                                .padding(.leading, 30)
                                .padding(.top, 2)
                            } else if let url = viewModel.backgroundImageURL {
                                // Image selected — click anywhere on row to change
                                Button {
                                    viewModel.pickBackgroundImage()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(url.lastPathComponent)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        Spacer()

                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Change image")
                                .padding(.leading, 30)
                                .padding(.top, 2)
                            }
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

            Spacer()

            Divider()
                .padding(.horizontal, 12)

            // About
            VStack(alignment: .leading, spacing: 4) {
                Text("BetterPortrait v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)

                Text("Made by Haochen Zeng")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    if let url = URL(string: "https://x.com/hzeng412") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("@hzeng412")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        let isSelected = viewModel.backgroundMode == .solidColor && viewModel.backgroundColor == color
        return Button {
            viewModel.backgroundColor = color
            viewModel.backgroundMode = .solidColor
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)

                Circle()
                    .strokeBorder(
                        isSelected
                            ? Color.accentColor
                            : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 2.5 : 1
                    )
                    .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(.plain)
        .help(name)
    }
}
