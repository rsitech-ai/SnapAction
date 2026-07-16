import SwiftUI

struct WarmSignalBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)

            if !reduceTransparency {
                RadialGradient(
                    colors: [.orange.opacity(0.07), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 520
                )

                RadialGradient(
                    colors: [.green.opacity(0.06), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 560
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
