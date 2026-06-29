import Foundation

public struct OCRRect: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct OCRBlock: Codable, Equatable, Hashable, Sendable {
    public var text: String
    public var boundingBox: OCRRect
    public var confidence: Double

    public init(text: String, boundingBox: OCRRect, confidence: Double) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

public struct OCRDocument: Codable, Equatable, Sendable {
    public var blocks: [OCRBlock]
    public var capturedAt: Date

    public init(blocks: [OCRBlock], capturedAt: Date = Date()) {
        self.blocks = blocks
            .filter { !$0.text.isEmpty }
            .sorted { lhs, rhs in
                if abs(lhs.boundingBox.y - rhs.boundingBox.y) > 0.02 {
                    return lhs.boundingBox.y < rhs.boundingBox.y
                }
                return lhs.boundingBox.x < rhs.boundingBox.x
            }
        self.capturedAt = capturedAt
    }

    public var normalizedText: String {
        blocks.map(\.text).joined(separator: "\n")
    }

    public static func singleBlock(_ text: String, capturedAt: Date = Date()) -> OCRDocument {
        OCRDocument(
            blocks: [
                OCRBlock(
                    text: text,
                    boundingBox: OCRRect(x: 0, y: 0, width: 1, height: 1),
                    confidence: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1
                )
            ],
            capturedAt: capturedAt
        )
    }
}
