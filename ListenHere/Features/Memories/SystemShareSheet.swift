// Wraps UIKit's share sheet because SwiftUI has no equivalent for presenting every eligible service.

import SwiftUI
import UIKit

struct SystemShareSheet: UIViewControllerRepresentable {
    let itemURL: URL
    let completion: () -> Void

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        // UIActivityViewController asks iOS for the apps and system destinations that can accept
        // this specific file type. It keeps the available choices accurate without maintaining a
        // brittle, app-specific list of social services or cloud-storage providers.
        let controller = UIActivityViewController(
            activityItems: [itemURL],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in completion() }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
