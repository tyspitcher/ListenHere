// Keeps save discoverable at the bottom of the composer while communicating disabled and saving states.

import SwiftUI

struct CaptureSaveBar: View {
    let canSave: Bool
    let isSaving: Bool
    let save: () -> Void

    var body: some View {
        Button(action: save) {
            HStack {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isSaving ? "Saving Memory" : "Save Memory")
                    .bold()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(canSave == false || isSaving)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
