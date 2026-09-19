import AppKit
import SwiftUI

/// The MarkItDown wordmark. Two fixed-colour PNGs ship in the target's resources rather than
/// an asset catalog (SwiftPM executables have no `.xcassets` support), so the appearance
/// variant is picked by hand.
struct BrandLogo: View {
    @Environment(\.colorScheme) private var colorScheme

    var height: CGFloat = 26

    var body: some View {
        Group {
            if let image = Self.image(for: colorScheme) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // If the resource bundle didn't make it into the .app, fall back to type
                // rather than an empty header.
                Text("MARKITDOWN")
                    .font(.system(size: height * 0.62, weight: .medium, design: .monospaced))
                    .tracking(height * 0.18)
            }
        }
        .frame(height: height)
        .accessibilityLabel("MarkItDown")
    }

    private static func image(for colorScheme: ColorScheme) -> NSImage? {
        let name = colorScheme == .dark ? "markitdown_logo_w" : "markitdown_logo_b"
        guard let url = resourceBundle?.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Resolved by hand rather than via `Bundle.module`, whose generated accessor calls
    /// `fatalError` when the resource bundle is missing — a missing logo should degrade to
    /// the text fallback above, not take the app down.
    private static let resourceBundle: Bundle? = {
        let bundleName = "MarkItDownSwift_MarkItDownSwift.bundle"
        let candidates = [
            Bundle.main.resourceURL,          // Contents/Resources in the assembled .app
            Bundle.main.bundleURL,            // alongside the binary under `swift run`
            Bundle.main.executableURL?.deletingLastPathComponent(),
        ]
        for case let directory? in candidates {
            let url = directory.appendingPathComponent(bundleName)
            if let bundle = Bundle(url: url) { return bundle }
        }
        return nil
    }()
}
