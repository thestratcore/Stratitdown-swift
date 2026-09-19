import Foundation
import PDFKit

/// Inspects every page so mixed PDFs cannot be mistaken for fully text-based documents.
enum PDFTextLayerDetector {
    static func analyze(fileURL: URL) throws -> PDFAnalysis {
        guard let document = PDFDocument(url: fileURL) else {
            throw ConversionError.invalidImageData(fileURL)
        }
        var pagesWithText = 0
        for pageIndex in 0..<document.pageCount {
            if let text = document.page(at: pageIndex)?.string,
               text.contains(where: { !$0.isWhitespace }) { pagesWithText += 1 }
        }
        return PDFAnalysis(pageCount: document.pageCount, pagesWithText: pagesWithText)
    }
}
