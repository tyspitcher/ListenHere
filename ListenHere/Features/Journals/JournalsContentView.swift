// Renders the state-dependent journal list while JournalsView owns its presentation flows.

import SwiftUI

struct JournalsContentView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: JournalsViewModel

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading Journals")
            case .loaded(let journals) where journals.isEmpty:
                ContentUnavailableView(
                    "No Journals Yet",
                    systemImage: "book.closed",
                    description: Text("Your first journal will be created when you save a memory.")
                )
            case .loaded(let journals):
                List(journals) { journal in
                    HStack {
                        NavigationLink(value: AppRoute.journal(journal.id)) {
                            Label {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(journal.name)
                                        if journal.isDefault {
                                            Text("Default Journal")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(journal.memoryCount, format: .number)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: journal.isSystemUnassigned ? "tray" : "book.closed")
                                    .foregroundStyle(
                                        journal.isDefault ? palette.accent : palette.secondaryAccent
                                    )
                            }
                        }
                        .buttonStyle(.plain)

                        if journal.isSystemUnassigned == false {
                            Menu("Journal Actions", systemImage: "ellipsis") {
                                Button("Rename", systemImage: "pencil") {
                                    viewModel.requestRename(of: journal)
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    viewModel.requestDeletion(of: journal)
                                }
                            }
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if journal.isSystemUnassigned == false {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                viewModel.requestDeletion(of: journal)
                            }
                        }
                    }
                }
            case .failed(let message):
                ContentUnavailableView(
                    "Journals Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .task { await viewModel.load() }
    }
}
