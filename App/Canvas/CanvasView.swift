import SwiftUI
import LoveWidgetCore

struct CanvasView: View {

    var viewModel: CanvasViewModel
    @State private var isDrawing: Bool = false
    @State private var showSentToast: Bool = false

    private let canvasSize: CGFloat = 320

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                canvasBackground

                VStack(spacing: 16) {
                    Text("Your Canvas")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    drawingSurface
                        .frame(width: canvasSize, height: canvasSize)

                    HStack(spacing: 12) {
                        Button("Clear") {
                            viewModel.clear()
                        }
                        .buttonStyle(.bordered)

                        Button("Send") {
                            viewModel.sendDrawing()
                            showSentToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showSentToast = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if showSentToast {
                        Text("Sent!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }

                    if !viewModel.partnerDrawing.strokes.isEmpty {
                        Divider()
                        partnerSection
                    }
                }

                VStack {
                    Spacer()
                    DrawingToolbar(viewModel: viewModel)
                        .padding(.bottom, 20)
                }

                VStack {
                    HStack {
                        Spacer()
                        ConnectionStatusBadge(status: viewModel.syncStatus)
                            .padding(16)
                    }
                    Spacer()
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var canvasBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.04, green: 0.04, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                let spacing: CGFloat = 24
                var point = CGPoint(x: 0, y: 0)
                while point.y < size.height {
                    point.x = 0
                    while point.x < size.width {
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 1.5, height: 1.5)),
                            with: .color(.white.opacity(0.06))
                        )
                        point.x += spacing
                    }
                    point.y += spacing
                }
            }
        }
        .ignoresSafeArea()
    }

    private var drawingSurface: some View {
        Canvas { context, canvasSize in
            for stroke in viewModel.drawing.strokes {
                renderStroke(stroke, in: context)
            }
            if let active = viewModel.activeStroke, active.points.count >= 2 {
                renderStroke(active, in: context, isActive: true)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if !isDrawing {
                        isDrawing = true
                        viewModel.beginStroke(at: value.location)
                    } else {
                        viewModel.continueStroke(to: value.location)
                    }
                }
                .onEnded { _ in
                    isDrawing = false
                    viewModel.endStroke()
                }
        )
    }

    private var partnerSection: some View {
        VStack(spacing: 12) {
            Text("Partner's Drawing")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            ZStack {
                Canvas { context, size in
                    for stroke in viewModel.partnerDrawing.strokes {
                        renderStroke(stroke, in: context)
                    }
                }
                .frame(width: canvasSize * 0.6, height: canvasSize * 0.6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                )

                ReactionOverlay(
                    reactions: viewModel.reactions,
                    onReact: { emoji in
                        viewModel.addReaction(emoji)
                    }
                )
            }
        }
    }

    private func renderStroke(_ stroke: Stroke, in context: GraphicsContext, isActive: Bool = false) {
        guard stroke.points.count >= 2 else {
            if let point = stroke.points.first {
                let dotRect = CGRect(
                    x: point.x - stroke.width / 2,
                    y: point.y - stroke.width / 2,
                    width: stroke.width,
                    height: stroke.width
                )
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(Color(stroke.color).opacity(stroke.opacity))
                )
            }
            return
        }

        let cgPath = SplineSmoothing.path(from: stroke.points)
        let path = Path(cgPath)

        var copy = context
        copy.opacity = stroke.opacity
        copy.stroke(
            path,
            with: .color(Color(stroke.color)),
            style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
        )

        if isActive {
            copy.stroke(
                path,
                with: .color(Color(stroke.color).opacity(0.15)),
                style: StrokeStyle(lineWidth: stroke.width * 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

extension Color {
    init(_ strokeColor: StrokeColor) {
        self.init(
            red: strokeColor.red,
            green: strokeColor.green,
            blue: strokeColor.blue,
            opacity: strokeColor.alpha
        )
    }
}

struct ReactionOverlay: View {
    let reactions: [(String, Date)]
    let onReact: (String) -> Void

    private let emojis = ["❤️", "😊", "🔥", "✨", "🥺"]

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) {
                        onReact(emoji)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 18))
                    .padding(4)
                    .background(Circle().fill(.ultraThinMaterial))
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        }
    }
}
