import SnapActionCore
import SwiftUI

struct SidebarView: View {
    let appState: AppState

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedCandidateID) {
            modelSection
            suggestionsSection
            historySection
        }
        .listStyle(.sidebar)
        .searchable(text: $appState.historySearchText, prompt: "Search history")
        .navigationTitle("SnapAction")
    }

    private var modelSection: some View {
        Section("Model") {
            Label {
                Text(appState.modelStatus)
                    .lineLimit(2)
            } icon: {
                Image(systemName: "apple.intelligence")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var suggestionsSection: some View {
        Section("Suggested Actions") {
            if appState.candidates.isEmpty {
                Text("No suggestions")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.candidates) { candidate in
                    CandidateSidebarRow(candidate: candidate)
                        .tag(candidate.id)
                }
            }
        }
    }

    private var historySection: some View {
        Section("History") {
            if appState.filteredHistory.isEmpty {
                Text("No history")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.filteredHistory) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.candidates.first?.title ?? "Captured text")
                            .lineLimit(1)
                        Text(entry.result?.displayMessage ?? entry.capturedAt.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .selectionDisabled()
                }
            }
        }
    }
}

private struct CandidateSidebarRow: View {
    let candidate: ActionCandidate

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: candidate.kind.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.title.isEmpty ? candidate.kind.displayName : candidate.title)
                    .lineLimit(1)
                Text(candidate.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: candidate.validationState.symbolName)
                .foregroundStyle(candidate.validationState.displayTone.color)
                .accessibilityLabel(candidate.validationState.message)
        }
        .padding(.vertical, 2)
    }
}
