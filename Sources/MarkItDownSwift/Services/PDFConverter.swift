import AppKit
import Foundation
import PDFKit

enum PDFConverter {
    /// Pages below this many non-whitespace characters are treated as scanned/image-only
    /// and rasterized for OCR instead of using PDFKit's extracted text.
    private static let minTextCharacters = 20
    private static let rasterScale: CGFloat = 2.0 // ~144 DPI from a 72pt PDF page

    static func convert(fileURL: URL, model: String, prompt: String, apiKey: String) async throws -> String {
        guard let document = PDFDocument(url: fileURL) else {
            throw ConversionError.unreadablePDF(fileURL)
        }

        var sections: [String] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let extractedText = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if extractedText.count >= minTextCharacters {
                sections.append(extractedText)
            } else {
                let pageImage = rasterize(page: page)
                let markdown = try await ImageOCRConverter.convert(
                    imageData: pageImage,
                    fileURL: fileURL,
                    model: model,
                    prompt: prompt,
                    apiKey: apiKey
                )
                sections.append(markdown)
            }
        }

        return sections.joined(separator: "\n\n---\n\n")
    }

    private static func rasterize(page: PDFPage) -> Data {
        let bounds = page.bounds(for: .mediaBox)
        let size = NSSize(width: bounds.width * rasterScale, height: bounds.height * rasterScale)

        let image = NSImage(size: size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.saveGState()
            context.scaleBy(x: rasterScale, y: rasterScale)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
        }
        image.unlockFocus()

        guard
            let tiffData = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiffData),
            let png = rep.representation(using: .png, properties: [:])
        else {
            return Data()
        }
        return png
    }
}
