import AppKit
import Foundation
import SnapActionCore
import Vision

struct VisionOCRService: Sendable {
    func recognizeText(in url: URL) async throws -> OCRDocument {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try await recognizeText(in: cgImage)
    }

    func recognizeText(in image: CGImage) async throws -> OCRDocument {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: image)
            try handler.perform([request])

            let blocks = (request.results ?? []).compactMap { observation -> OCRBlock? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let box = observation.boundingBox
                return OCRBlock(
                    text: candidate.string,
                    boundingBox: OCRRect(
                        x: box.origin.x,
                        y: 1 - box.origin.y - box.height,
                        width: box.width,
                        height: box.height
                    ),
                    confidence: Double(candidate.confidence)
                )
            }
            return OCRDocument(blocks: blocks)
        }.value
    }
}
