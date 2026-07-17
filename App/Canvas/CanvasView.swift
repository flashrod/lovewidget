import SwiftUI
import LoveWidgetCore

struct CanvasView: View {

    var viewModel: CanvasViewModel
    @State private var isDrawing: Bool = false
    @State private var showSentToast: Bool = false
    @State private var showNoPairToast: Bool = false

    private let canvasSize: CGFloat = 320

    var body: some View {
        ScrollView(.vertical) {
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

                if let error = viewModel.lastSendError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .transition(.opacity)
                }

                Divider()

                partnerSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(canvasBackground)
        .overlay(alignment: .topTrailing) {
            ConnectionStatusBadge(status: viewModel.syncStatus)
                .padding(16)
        }
        .overlay(alignment: .bottom) {
            DrawingToolbar(viewModel: viewModel)
                .padding(.bottom, 20)
        }
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
        Canvas { context, _ in
            for stroke in viewModel.drawing.strokes {
                StrokeRenderer.render(stroke, in: context)
            }
            if let active = viewModel.activeStroke, active.points.count >= 2 {
                StrokeRenderer.render(active, in: context)
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
            HStack {
                Text(viewModel.partnerName.isEmpty ? "Partner's Drawing" : "\(viewModel.partnerName)'s Drawing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.lastSyncedAt != nil {
                    Text("updated \(viewModel.lastSyncedAt?.formatted(date: .omitted, time: .shortened) ?? "")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if viewModel.partnerDrawing.strokes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.dashed")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Waiting for partner's first drawing...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: canvasSize, height: canvasSize)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.3))
                        )
                )
            } else {
                VStack(spacing: 8) {
                    Canvas { context, _ in
                        for stroke in viewModel.partnerDrawing.strokes {
                            StrokeRenderer.render(stroke, in: context)
                        }
                    }
                    .frame(width: canvasSize, height: canvasSize)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )

                    ReactionOverlay(
                        reactions: viewModel.reactions,
                        onReact: { emoji in
                            viewModel.addReaction(emoji)
                        },
                        onDismissOldest: {
                            if !viewModel.reactions.isEmpty {
                                viewModel.reactions.removeFirst()
                            }
                        }
                    )
                }
            }
        }
        .padding(.top, 8)
    }

}

struct ReactionOverlay: View {
    let reactions: [(emoji: String, date: Date)]
    let onReact: (String) -> Void
    let onDismissOldest: () -> Void

    private let emojis = ["❤️", "😊", "🔥", "✨", "🥺"]

    var body: some View {
        ZStack {
            ForEach(Array(reactions.enumerated()), id: \.offset) { index, reaction in
                Text(reaction.emoji)
                    .font(.system(size: 24))
                    .modifier(FloatingReaction(index: index, total: reactions.count))
            }

            VStack {
                Spacer()
                if reactions.count >= 10 {
                    Button("✕") { onDismissOldest() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(emoji) { onReact(emoji) }
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
}

struct FloatingReaction: ViewModifier {
    let index: Int
    let total: Int

    func body(content: Content) -> some View {
        let offsetX = CGFloat(index % 5 - 2) * 20
        let offsetY = CGFloat(index / 5) * -30 - 10

        content
            .offset(x: offsetX, y: offsetY)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: index)
    }
}
