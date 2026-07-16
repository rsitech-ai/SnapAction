import Foundation
import Testing
@testable import SnapActionCore

@Test
func actionCandidateDecodesHistoryWrittenBeforeExtractionProvenanceExisted() throws {
    let currentCandidate = ActionCandidate(
        id: UUID(uuidString: "3B82A4F7-A8E3-44E3-A87B-6195DFD89D40")!,
        kind: .textTable,
        title: "Extract text",
        confidence: 0.65,
        sourceText: "Fixture text",
        fields: [.extractedText: "Fixture text"],
        validationState: .valid,
        extractionProvenance: .foundationModels
    )
    let currentData = try JSONEncoder().encode(currentCandidate)
    var legacyObject = try #require(JSONSerialization.jsonObject(with: currentData) as? [String: Any])
    legacyObject.removeValue(forKey: "extractionProvenance")
    let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

    let candidate = try JSONDecoder().decode(ActionCandidate.self, from: legacyData)

    #expect(candidate.extractionProvenance == nil)
    #expect(candidate.title == "Extract text")
}

@Test
func validatorPreservesDeterministicFallbackProvenance() {
    let candidate = ActionCandidate(
        kind: .textTable,
        title: "Extract text",
        confidence: 0.65,
        sourceText: "Fixture text",
        fields: [.extractedText: "Fixture text"],
        validationState: .warning("Model timed out"),
        extractionProvenance: .deterministicFallback(.modelTimedOut)
    )

    let validated = ActionValidator().validated(candidate)

    #expect(validated.validationState == .valid)
    #expect(validated.extractionProvenance == .deterministicFallback(.modelTimedOut))
}

@Test
func deterministicFallbackProvenanceHasTruthfulPresentationCopy() {
    #expect(
        ExtractionProvenance.deterministicFallback(.modelTimedOut).fallbackStatusText
            == "Deterministic fallback active — Apple Intelligence timed out."
    )
    #expect(ExtractionProvenance.foundationModels.fallbackStatusText == nil)
}
