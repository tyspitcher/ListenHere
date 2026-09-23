// Presents the memory's current video-sharing readiness without performing export work.

import SwiftUI

struct ShareMemorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let availability: MemorySharingAvailability

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text(message)
            }
            .navigationTitle("Share Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
    }

    private var title: String {
        switch availability {
        case .photo:
            "Share Photo"
        case .video:
            "Share Video"
        case .needsBackground:
            "Create a Background First"
        case .unavailable:
            "Nothing to Share"
        }
    }

    private var message: String {
        switch availability {
        case .photo:
            "This memory’s photo will be shared as an image. It won’t be converted into a video."
        case .video:
            "This memory’s photo and sound will be combined into a shareable video."
        case .needsBackground:
            "This recording needs a saved title background before it can be shared as a video."
        case .unavailable:
            "This memory does not have media available to share."
        }
    }

    private var systemImage: String {
        switch availability {
        case .photo:
            "photo"
        case .video:
            "square.and.arrow.up"
        case .needsBackground:
            "rectangle.3.group.fill"
        case .unavailable:
            "exclamationmark.triangle"
        }
    }
}

#if DEBUG
#Preview("Ready") {
    ShareMemorySheet(availability: .video)
        .appTheme(.listenHere)
}

#Preview("Needs Background") {
    ShareMemorySheet(availability: .needsBackground)
        .appTheme(.listenHere)
}
#endif
