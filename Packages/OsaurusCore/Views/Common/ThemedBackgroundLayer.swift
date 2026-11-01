//
//  ThemedBackgroundLayer.swift
//  osaurus
//
//  Shared background layer used by chat windows.
//  Default built-in solid themes tint native window glass. Explicit custom
//  backgrounds render as configured and may cover that material. Reduce
//  Transparency disables native translucency and supplies a solid palette
//  fallback beneath any explicitly configured custom background.
//

import SwiftUI

struct ThemedBackgroundLayer: View {
    let cachedBackgroundImage: NSImage?

    init(cachedBackgroundImage: NSImage?) {
        self.cachedBackgroundImage = cachedBackgroundImage
    }

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Tints the single window-backed material for built-in themes. ChatView
    /// clips the canvas surface; AppKit supplies the system-specific outer
    /// window mask.
    var body: some View {
        backgroundLayer
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if preservesConfiguredBackground {
            configuredBackgroundLayer
        } else if reduceTransparency {
            theme.chatWindowSolidFallback
        } else {
            // Keep the selected theme color as a light tint over the native
            // material. The stored windowBackingOpacity is mapped to a
            // glass-specific opacity instead of an almost-opaque fill.
            theme.primaryBackground.opacity(theme.chatWindowGlassTintOpacity)
        }
    }

    @ViewBuilder
    private var configuredBackgroundLayer: some View {
        if let customTheme = theme.customThemeConfig {
            switch customTheme.background.type {
            case .solid:
                Color(themeHex: customTheme.background.solidColor ?? customTheme.colors.primaryBackground)

            case .gradient:
                let colors = (customTheme.background.gradientColors ?? ["#000000", "#333333"])
                    .map { Color(themeHex: $0) }
                let points = customTheme.background.gradientUnitPoints
                LinearGradient(
                    colors: colors,
                    startPoint: points.start,
                    endPoint: points.end
                )

            case .image:
                if let image = cachedBackgroundImage {
                    ZStack {
                        backgroundImageView(
                            image: image,
                            fit: customTheme.background.imageFit ?? .fill,
                            opacity: customTheme.background.imageOpacity ?? 1.0
                        )

                        if let overlayHex = customTheme.background.overlayColor {
                            Color(themeHex: overlayHex)
                                .opacity(customTheme.background.overlayOpacity ?? 0.5)
                        }
                    }
                } else {
                    Color(themeHex: customTheme.colors.primaryBackground)
                }
            }
        } else {
            theme.primaryBackground
        }
    }

    /// The built-in Dark and Light presets use `.solid` as their default
    /// palette, which now acts as a tint over native glass. User custom themes,
    /// explicitly selected solid colors, gradients, and images retain their
    /// configured background behavior.
    private var preservesConfiguredBackground: Bool {
        guard let customTheme = theme.customThemeConfig else { return false }
        if !customTheme.isBuiltIn || customTheme.background.solidColor != nil {
            return true
        }
        switch customTheme.background.type {
        case .solid:
            return false
        case .gradient, .image:
            return true
        }
    }

    private func backgroundImageView(image: NSImage, fit: ThemeBackground.ImageFit, opacity: Double) -> some View {
        GeometryReader { geo in
            switch fit {
            case .fill:
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(opacity)
            case .fit:
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(opacity)
            case .stretch:
                Image(nsImage: image)
                    .resizable()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(opacity)
            case .tile:
                TiledImageView(image: image)
                    .opacity(opacity)
            }
        }
    }

    private struct TiledImageView: NSViewRepresentable {
        let image: NSImage

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            view.wantsLayer = true
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            nsView.layer?.backgroundColor = NSColor(patternImage: image).cgColor
        }
    }
}
