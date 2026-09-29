// Renders the theme-selected app background treatment, including solid colors and paper textures.

import SwiftUI

struct AppBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        GeometryReader { proxy in
            ZStack {
                palette.appBackground

                switch theme.backdrop(for: colorScheme) {
                case .solid:
                    EmptyView()
                case .image(let assetName, let opacity):
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .opacity(opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func appScreenBackground() -> some View {
        background {
            AppBackground()
        }
    }
}
