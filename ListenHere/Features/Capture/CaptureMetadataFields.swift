// Presents optional text metadata without owning the capture draft.

import SwiftUI

struct CaptureMetadataFields: View {
    @Binding var title: String
    @Binding var description: String
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            TextField("Title (Optional)", text: $title)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.next)

            TextField("Description (Optional)", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .disabled(isEnabled == false)
    }
}
