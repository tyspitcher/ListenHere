// Renders the capture draft's optional canonical location and forwards editing to the location sheet.

import SwiftUI

struct CaptureLocationField: View {
    let location: MemoryLocation?
    let isEnabled: Bool
    let chooseLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
            Button(action: chooseLocation) {
                LabeledContent("Place") {
                    if let location {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(location.displayName)
                            Text(location.coordinateDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .multilineTextAlignment(.trailing)
                    } else {
                        Text("Add Location")
                    }
                }
            }
            .foregroundStyle(.primary)
            .disabled(isEnabled == false)
        }
    }
}
