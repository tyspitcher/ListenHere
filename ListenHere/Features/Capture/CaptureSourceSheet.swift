import SwiftUI

struct CaptureSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSource: CaptureSource?

    var body: some View {
        NavigationStack {
            Group {
                if let selectedSource {
                    ContentUnavailableView(
                        selectedSource.title,
                        systemImage: selectedSource.systemImage,
                        description: Text("The capture service will connect to this native entry point in the next feature slice.")
                    )
                } else {
                    List(CaptureSource.allCases) { source in
                        Button {
                            selectedSource = source
                        } label: {
                            Label(source.title, systemImage: source.systemImage)
                        }
                    }
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
