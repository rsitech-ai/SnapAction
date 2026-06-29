import SnapActionCore
import SwiftUI

enum SnapActionDesign {
    static let panelRadius: CGFloat = 18
    static let compactRadius: CGFloat = 12
}

extension DisplayTone {
    var color: Color {
        switch self {
        case .neutral:
            .secondary
        case .success:
            .green
        case .warning:
            .orange
        case .danger:
            .red
        }
    }

    var softColor: Color {
        color.opacity(0.14)
    }
}

extension ConfidenceBand {
    var label: String {
        switch self {
        case .low:
            "Low"
        case .medium:
            "Medium"
        case .high:
            "High"
        }
    }
}

extension View {
    func snapGlassPanel(
        tone: DisplayTone = .neutral,
        interactive: Bool = false,
        cornerRadius: CGFloat = SnapActionDesign.panelRadius
    ) -> some View {
        modifier(SnapGlassPanelModifier(tone: tone, interactive: interactive, cornerRadius: cornerRadius))
    }
}

private struct SnapGlassPanelModifier: ViewModifier {
    let tone: DisplayTone
    let interactive: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    interactive
                        ? .regular.tint(tone.softColor).interactive()
                        : .regular.tint(tone.softColor),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(tone.color.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

struct SnapMetricPill: View {
    let icon: String
    let text: String
    let tone: DisplayTone

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .snapGlassPanel(tone: tone, interactive: true, cornerRadius: 20)
            .lineLimit(1)
    }
}
