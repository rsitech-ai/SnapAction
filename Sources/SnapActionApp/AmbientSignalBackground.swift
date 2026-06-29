import SwiftUI

struct AmbientSignalBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 34

            var linePath = Path()
            var x = -size.height * 0.4
            while x < size.width {
                linePath.move(to: CGPoint(x: x, y: size.height))
                linePath.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(linePath, with: .color(.primary.opacity(0.035)), lineWidth: 1)

            let rect = CGRect(x: size.width * 0.62, y: size.height * 0.12, width: size.width * 0.26, height: size.height * 0.72)
            let rounded = Path(roundedRect: rect, cornerRadius: 28)
            context.stroke(rounded, with: .color(.green.opacity(0.09)), lineWidth: 1.5)

            let amberRect = CGRect(x: size.width * 0.08, y: size.height * 0.68, width: size.width * 0.28, height: size.height * 0.20)
            context.stroke(
                Path(roundedRect: amberRect, cornerRadius: 22),
                with: .color(.orange.opacity(0.06)),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
    }
}

struct ProcessingHalo: View {
    let isActive: Bool
    @State private var rotation = Angle.zero

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.08), lineWidth: 1)
            Circle()
                .trim(from: 0, to: isActive ? 0.72 : 0.32)
                .stroke(
                    AngularGradient(colors: [.green, .orange, .primary.opacity(0.25), .green], center: .center),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(rotation)
        }
        .frame(width: 34, height: 34)
        .onAppear { updateRotation() }
        .onChange(of: isActive) { _, _ in updateRotation() }
        .opacity(isActive ? 1 : 0.72)
        .scaleEffect(isActive ? 1.04 : 1)
        .animation(.smooth(duration: 0.25), value: isActive)
    }

    private func updateRotation() {
        if isActive {
            rotation = .zero
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                rotation = .degrees(360)
            }
        } else {
            withAnimation(.smooth(duration: 0.2)) {
                rotation = .degrees(32)
            }
        }
    }
}

struct ConfidenceGauge: View {
    let value: Double
    let tone: Color

    var body: some View {
        Gauge(value: min(max(value, 0), 1)) {
            EmptyView()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(tone)
        .frame(width: 44, height: 44)
    }
}
