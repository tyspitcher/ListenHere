// Provides the Places browsing entry point and its current empty-state presentation.
import SwiftUI

struct PlacesView: View {
    var body: some View {
        ContentUnavailableView(
            "No Places Yet",
            systemImage: "map",
            description: Text("Places will appear after memories are saved with location information.")
        )
        .navigationTitle("Places")
        .appScreenBackground()
    }
}
