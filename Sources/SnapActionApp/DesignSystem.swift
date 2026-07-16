import SnapActionCore
import SwiftUI

enum SnapActionDesign {
    static let spacingXS: CGFloat = 6
    static let spacingS: CGFloat = 10
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let workspaceRadius: CGFloat = 22
    static let groupRadius: CGFloat = 14
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
    func snapSurface(
        tone: DisplayTone = .neutral,
        cornerRadius: CGFloat = SnapActionDesign.workspaceRadius
    ) -> some View {
        modifier(SnapSurfaceModifier(tone: tone, cornerRadius: cornerRadius))
    }
}

private struct SnapSurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let tone: DisplayTone
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        if reduceTransparency {
            content
                .background(.background, in: shape)
                .overlay { boundary(shape) }
        } else if #available(macOS 26.0, *) {
            if tone == .neutral {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                    .overlay { boundary(shape) }
            } else {
                content
                    .glassEffect(.regular.tint(tone.softColor), in: .rect(cornerRadius: cornerRadius))
                    .overlay { boundary(shape) }
            }
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay { boundary(shape) }
        }
    }

    private var boundaryColor: Color {
        if colorSchemeContrast == .increased {
            return .primary.opacity(0.28)
        }

        return tone == .neutral ? .primary.opacity(0.08) : tone.color.opacity(0.18)
    }

    private func boundary(_ shape: RoundedRectangle) -> some View {
        shape.stroke(boundaryColor, lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
    }
}
