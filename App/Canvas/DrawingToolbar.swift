import SwiftUI
import LoveWidgetCore

struct DrawingToolbar: View {

    @Bindable var viewModel: CanvasViewModel
    @State private var showBrushSizePopover = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.isColorPickerVisible.toggle()
            } label: {
                Circle()
                    .fill(Color(viewModel.selectedColor))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: Color(viewModel.selectedColor).opacity(0.5), radius: 6)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $viewModel.isColorPickerVisible) {
                ColorPickerPanel(selectedColor: $viewModel.selectedColor)
                    .padding(16)
            }

            toolbarDivider

            Button {
                showBrushSizePopover.toggle()
            } label: {
                Image(systemName: "scribble")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(ToolbarButtonStyle())
            .popover(isPresented: $showBrushSizePopover) {
                BrushSizePanel(
                    brushWidth: $viewModel.brushWidth,
                    brushOpacity: $viewModel.brushOpacity,
                    selectedColor: viewModel.selectedColor
                )
                .padding(16)
                .frame(width: 220)
            }

            toolbarDivider

            Button(action: viewModel.undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(viewModel.canUndo ? .white.opacity(0.85) : .white.opacity(0.25))
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(!viewModel.canUndo)
            .keyboardShortcut("z", modifiers: .command)

            Button(action: viewModel.redo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(viewModel.canRedo ? .white.opacity(0.85) : .white.opacity(0.25))
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(!viewModel.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])

            toolbarDivider

            Button(action: viewModel.clear) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(ToolbarButtonStyle())

            Button(action: viewModel.resetZoom) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(ToolbarButtonStyle())

            toolbarDivider

            SyncIndicator(
                status: viewModel.syncStatus,
                isPending: viewModel.isPendingUpload
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(toolbarBackground)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 22)
    }

    private var toolbarBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
    }
}

struct ColorPickerPanel: View {

    @Binding var selectedColor: StrokeColor
    @State private var customColor: Color = .red

    private let columns = Array(repeating: GridItem(.fixed(36), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(StrokeColor.presets, id: \.hexString) { color in
                    ColorSwatch(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        selectedColor = color
                    }
                }
            }

            Divider()

            HStack {
                Text("Custom")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                ColorPicker("", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: customColor) { _, newColor in
                        if let components = NSColor(newColor).usingColorSpace(.deviceRGB) {
                            selectedColor = StrokeColor(
                                red: components.redComponent,
                                green: components.greenComponent,
                                blue: components.blueComponent
                            )
                        }
                    }
            }
        }
        .frame(width: 220)
    }
}

private struct ColorSwatch: View {
    let color: StrokeColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(color))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? .white : .clear,
                            lineWidth: 2.5
                        )
                )
                .shadow(
                    color: isSelected ? Color(color).opacity(0.6) : .clear,
                    radius: 6
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct BrushSizePanel: View {

    @Binding var brushWidth: Double
    @Binding var brushOpacity: Double
    let selectedColor: StrokeColor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Size")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(brushWidth))pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $brushWidth, in: 1...40, step: 0.5)
                    .tint(Color(selectedColor))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Opacity")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(brushOpacity * 100))%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $brushOpacity, in: 0.05...1.0, step: 0.05)
                    .tint(Color(selectedColor))
            }

            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(selectedColor).opacity(brushOpacity))
                    .frame(width: 60, height: brushWidth)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

private struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(configuration.isPressed ? 0.15 : 0.0))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

private struct SyncIndicator: View {
    let status: SyncStatus
    let isPending: Bool

    var body: some View {
        Image(systemName: isPending ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(isPending ? .blue : .green)
            .frame(width: 28)
    }
}
