// Renders deleted journals and memories with native recovery and permanent-deletion actions.
import SwiftUI

struct RecentlyDeletedView: View {
    @State private var viewModel: RecentlyDeletedViewModel

    private let openMemory: (UUID) -> Void
    private let openJournal: (UUID) -> Void

    init(
        viewModel: RecentlyDeletedViewModel,
        openMemory: @escaping (UUID) -> Void = { _ in },
        openJournal: @escaping (UUID) -> Void = { _ in }
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.openMemory = openMemory
        self.openJournal = openJournal
    }

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Recently Deleted Items",
                    systemImage: "trash",
                    description: Text("Deleted memories and journals remain here for 30 days.")
                )
            } else {
                List(viewModel.items) { item in
                    RecentlyDeletedRow(
                        item: item,
                        recover: { viewModel.recover(item) },
                        permanentlyDelete: { viewModel.permanentlyDelete(item) },
                        openMemory: { openMemory(item.id.modelID) },
                        openJournal: { openJournal(item.id.modelID) },
                        thumbnailURL: { viewModel.thumbnailURL(for: item) }
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Recently Deleted")
        .onAppear {
            viewModel.load()
        }
        .alert("Something Went Wrong", isPresented: errorIsPresented) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.dismissError()
                }
            }
        )
    }
}

private struct RecentlyDeletedRow: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var areActionsPresented = false

    let item: RecentlyDeletedItem
    let recover: () -> Void
    let permanentlyDelete: () -> Void
    let openMemory: () -> Void
    let openJournal: () -> Void
    let thumbnailURL: () -> URL?

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        HStack(spacing: 12) {
            Button(action: openItem) {
                HStack(spacing: 12) {
                    thumbnail(palette: palette)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        Text("Deletes \(item.expiresAt, style: .relative)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this item in read-only mode")

            Button {
                areActionsPresented = true
            } label: {
                Label("Actions for \(item.title)", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
                    .frame(width: 56, height: 56)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Recover or permanently delete this item")
            // Anchor the native confirmation dialog to the selected row's action control.
            // This keeps it within reach on iPhone and beside the relevant item on iPad.
            .confirmationDialog(
                item.title,
                isPresented: $areActionsPresented,
                titleVisibility: .visible
            ) {
                Button("Recover", action: recover)
                Button("Delete Permanently", role: .destructive, action: permanentlyDelete)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose whether to recover this item or delete it permanently.")
            }
        }
    }

    private func openItem() {
        switch item.kind {
        case .memory:
            openMemory()
        case .journal:
            openJournal()
        }
    }

    @ViewBuilder
    private func thumbnail(palette: AppPalette) -> some View {
        if item.kind == .memory, let photoURL = thumbnailURL() {
            ManagedPhotoImageView(photoURL: photoURL, contentMode: .fill, maximumPixelSize: 160)
                .frame(width: 64, height: 64)
                .clipped()
        } else {
            Image(systemName: item.kind == .memory ? "photo.on.rectangle" : "book.closed")
                .font(.title3)
                .foregroundStyle(palette.tertiaryAccent)
                .frame(width: 64, height: 64)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    let now = Date()
    let repository = PreviewRecentlyDeletedRepository(items: [
        RecentlyDeletedItem(
            id: .init(kind: .memory, modelID: UUID()),
            title: "A Day at the Park",
            deletedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            expiresAt: now.addingTimeInterval(28 * 24 * 60 * 60)
        ),
        RecentlyDeletedItem(
            id: .init(kind: .journal, modelID: UUID()),
            title: "Summer Trip",
            deletedAt: now.addingTimeInterval(-5 * 24 * 60 * 60),
            expiresAt: now.addingTimeInterval(25 * 24 * 60 * 60)
        ),
    ])

    NavigationStack {
        RecentlyDeletedView(
            viewModel: RecentlyDeletedViewModel(repository: repository)
        )
    }
}

@MainActor
private final class PreviewRecentlyDeletedRepository: RecentlyDeletedRepository {
    private var items: [RecentlyDeletedItem]

    init(items: [RecentlyDeletedItem]) {
        self.items = items
    }

    func fetchItems() throws -> [RecentlyDeletedItem] {
        items
    }

    func recover(_ itemID: RecentlyDeletedItem.ID, at date: Date) throws {
        items.removeAll { $0.id == itemID }
    }

    func permanentlyDelete(_ itemID: RecentlyDeletedItem.ID) throws {
        items.removeAll { $0.id == itemID }
    }

    func purgeExpiredItems(at referenceDate: Date) throws {
        items.removeAll { $0.expiresAt <= referenceDate }
    }
}
