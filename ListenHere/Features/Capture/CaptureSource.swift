enum CaptureSource: String, CaseIterable, Identifiable {
    case camera
    case photoLibrary
    case soundOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: "Take Photo"
        case .photoLibrary: "Choose from Library"
        case .soundOnly: "Record Sound Only"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: "camera"
        case .photoLibrary: "photo.on.rectangle"
        case .soundOnly: "waveform"
        }
    }
}
