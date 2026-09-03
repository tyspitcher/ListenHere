// Renders the state-dependent All Memories content while its parent owns navigation and presentation state.

import Foundation
import SwiftUI

struct AllMemoriesContentView: View {
    let viewModel: AllMemoriesViewModel
    let openMemory: (UUID) -> Void
    let presentCapture: () -> Void
    let requestDeletion: (MemorySummary) -> Void
    let presentEdit: (MemorySummary) -> Void
    let presentJournalAssignment: (MemorySummary) -> Void

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading Memories")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let memories) where memories.isEmpty:
                ContentUnavailableView {
                    Label("No Memories Yet", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Capture a photo, a sound, or both to hold on to this moment.")
                } actions: {
                    Button("Create Memory", systemImage: "plus", action: presentCapture)
                        .buttonStyle(.borderedProminent)
                }
            case .loaded(let memories):
                ScrollView {
                    LazyVStack(spacing: 22) {
                        ForEach(memories) { memory in
                            MemoryCardRowView(
                                memory: memory,
                                managedPhotoURL: viewModel.managedPhotoURL(for: memory),
                                open: { openMemory(memory.id) },
                                edit: { presentEdit(memory) },
                                chooseJournals: { presentJournalAssignment(memory) },
                                delete: { requestDeletion(memory) }
                            )
                        }
                    }
                    .padding()
                }
                .refreshable { viewModel.load() }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Memories Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: viewModel.load)
                }
            }
        }
        .task { viewModel.load() }
        .appScreenBackground()
    }
}
