// Wraps Apple's standard still-camera interface and returns private image bytes to capture.

import SwiftUI
import UniformTypeIdentifiers

struct CapturedPhoto: Sendable {
    let data: Data
    let preferredFileExtension: String
}

struct SystemCameraPicker: UIViewControllerRepresentable {
    let onPhotoCaptured: (CapturedPhoto) -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        // UIImagePickerController supplies Apple's familiar capture and retake experience.
        // It is wrapped narrowly because SwiftUI doesn't provide an equivalent still-camera picker.
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.mediaTypes = [UTType.image.identifier]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: SystemCameraPicker

        init(parent: SystemCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let imageURL = info[.imageURL] as? URL,
               let data = try? Data(contentsOf: imageURL) {
                parent.onPhotoCaptured(
                    CapturedPhoto(
                        data: data,
                        preferredFileExtension: imageURL.pathExtension.isEmpty ? "jpeg" : imageURL.pathExtension
                    )
                )
                return
            }

            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.92) else {
                parent.onFailure()
                return
            }
            parent.onPhotoCaptured(CapturedPhoto(data: data, preferredFileExtension: "jpeg"))
        }
    }
}
