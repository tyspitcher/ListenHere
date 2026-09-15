// Presents optional text metadata without owning the capture draft.

import SwiftUI

struct CaptureMetadataFields: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding var title: String
    @Binding var description: String
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            TextField("Title (Optional)", text: $title)
                .textFieldStyle(CaptureMetadataTextFieldStyle())
                .submitLabel(.next)

            TextField("Description (Optional)", text: $description, axis: .vertical)
                .textFieldStyle(CaptureMetadataTextFieldStyle())
                .lineLimit(3...6)
        }
        .disabled(isEnabled == false)
    }
}

private struct CaptureMetadataTextFieldStyle: TextFieldStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    func _body(configuration: TextField<Self._Label>) -> some View {
        let palette = theme.palette(for: colorScheme)

        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(palette.primaryText)
            .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.separator)
            }
            .tint(palette.accent)
    }
}
