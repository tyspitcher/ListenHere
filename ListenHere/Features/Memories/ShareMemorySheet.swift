// Lets a person choose the representation to share before opening the system share sheet.

import SwiftUI

struct ShareMemorySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: MemoryShareViewModel
    @State private var preparationTask: Task<Void, Never>?

    init(viewModel: MemoryShareViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ContentUnavailableView {
                    Label(title, systemImage: systemImage)
                } description: {
                    Text(message)
                }

                if let progress = viewModel.preparationProgress, isPreparingVideo {
                    preparationStatus(progress: progress)
                } else if viewModel.options.isEmpty == false {
                    VStack(spacing: 12) {
                        ForEach(viewModel.options) { option in
                            Button {
                                preparationTask?.cancel()
                                preparationTask = Task {
                                    await viewModel.prepareShare(option)
                                }
                            } label: {
                                ShareOptionLabel(option: option)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isPreparing)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Share Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPreparing ? "Cancel" : "Done", action: dismiss.callAsFunction)
                }
            }
        }
        .sheet(item: shareBinding) { share in
            SystemShareSheet(itemURL: share.url) {
                viewModel.finishSharing(share)
                dismiss()
            }
        }
        .alert("Couldn’t Prepare Share", isPresented: failureIsPresented) {
            Button("Try Again", action: viewModel.dismissFailure)
            Button("Done", role: .cancel, action: dismiss.callAsFunction)
        } message: {
            Text("The selected media couldn’t be prepared. Please try again.")
        }
        .onDisappear {
            preparationTask?.cancel()
        }
    }

    private var title: String {
        switch viewModel.availability {
        case .photo:
            "Share Photo"
        case .audio:
            "Share Audio"
        case .photoAndAudio:
            "Share Memory"
        case .unavailable:
            "Nothing to Share"
        }
    }

    private var message: String {
        switch viewModel.availability {
        case .photo:
            "Choose how you’d like to share this photo."
        case .audio:
            "Choose how you’d like to share this ambient sound recording."
        case .photoAndAudio:
            "Choose whether to share the photo, the ambient sound, or a video that combines both."
        case .unavailable:
            "This memory does not have media available to share."
        }
    }

    private var systemImage: String {
        switch viewModel.availability {
        case .photo:
            "photo"
        case .audio:
            "waveform"
        case .photoAndAudio:
            "square.and.arrow.up"
        case .unavailable:
            "exclamationmark.triangle"
        }
    }

    private var isPreparing: Bool {
        if case .preparing = viewModel.state { return true }
        return false
    }

    private var isPreparingVideo: Bool {
        if case .preparing(.video, _) = viewModel.state { return true }
        return false
    }

    private func preparationStatus(progress: Double) -> some View {
        VStack(spacing: 12) {
            Text("Preparing Video…")
                .font(.headline)

            ProgressView(value: progress, total: 1)
                .progressViewStyle(.linear)
                .accessibilityLabel("Preparing video")
                .accessibilityValue("\(Int((progress * 100).rounded())) percent")

            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.subheadline.monospacedDigit())

            Text("Combining the photo and ambient sound may take a moment. Keep ListenHere open.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .frame(maxWidth: 420)
    }

    private var shareBinding: Binding<PreparedMemoryShare?> {
        Binding(
            get: { viewModel.preparedShare },
            set: { presentedShare in
                if presentedShare == nil, let activeShare = viewModel.preparedShare {
                    viewModel.finishSharing(activeShare)
                }
            }
        )
    }

    private var failureIsPresented: Binding<Bool> {
        Binding(
            get: {
                if case .failed = viewModel.state { return true }
                return false
            },
            set: { isPresented in
                if isPresented == false { viewModel.dismissFailure() }
            }
        )
    }
}

private struct ShareOptionLabel: View {
    let option: MemoryShareOption

    @ScaledMetric(relativeTo: .body) private var iconColumnWidth = 52
    @State private var textHeight: CGFloat = 38

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: option.systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: iconColumnWidth, height: textHeight)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                Text(option.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                textHeight = height
            }
        }
    }
}

#if DEBUG
#Preview("Ready") {
    ShareMemorySheet(
        viewModel: MemoryShareViewModel(
            availability: .photoAndAudio,
            photoURL: URL(filePath: "/tmp/photo.jpg"),
            audioURL: URL(filePath: "/tmp/audio.m4a"),
            videoExporter: AVFoundationMemoryVideoExporter()
        )
    )
        .appTheme(.listenHere)
}

#Preview("Audio") {
    ShareMemorySheet(
        viewModel: MemoryShareViewModel(
            availability: .audio,
            photoURL: nil,
            audioURL: URL(filePath: "/tmp/audio.m4a"),
            videoExporter: AVFoundationMemoryVideoExporter()
        )
    )
        .appTheme(.listenHere)
}
#endif
