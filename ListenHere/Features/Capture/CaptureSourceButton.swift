// Presents one immediately available media-source action in the capture composer.

import SwiftUI

struct CaptureSourceButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
