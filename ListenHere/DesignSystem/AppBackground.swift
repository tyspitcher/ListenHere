import SwiftUI

struct AppBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        ZStack {
            palette.appBackground

            switch theme.backdrop(for: colorScheme) {
            case .solid:
                EmptyView()
            case .image(let assetName, let opacity):
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .opacity(opacity)
            }
        }
        .ignoresSafeArea()
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func appScreenBackground() -> some View {
        background { AppBackground() }
    }
}
