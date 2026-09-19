import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers
import ImageIO

/// Turns a local PDF or image into Markdown via Mistral OCR.
///
/// Whole documents are sent in one call — Mistral handles page splitting, layout and tables
/// itself, which is why there is no PDFKit rasterization here. PDFKit is used only to count
/// pages so an over-limit document fails before any bytes go over the network.
enum MistralOCRConverter {
    /// Extensions Mistral's OCR endpoint documents as directly acceptable. Everything else
    /// AppKit can decode is re-encoded to PNG first.
    static let nativeImageExtensions: Set<String> = ["png", "jpg", "jpeg", "avif"]
    static let imageExtensions: Set<String> = nativeImageExtensions
        .union(["tif", "tiff", "bmp", "gif", "webp"])

    // MARK: - PDF

    static func convertPDF(fileURL: URL, apiKey: String) async throws -> String {
        let data = try loadData(from: fileURL)
        try checkSize(data)

        if let pageCount = PDFDocument(url: fileURL)?.pageCount, pageCount > AppConfig.maxPages {
            throw ConversionError.tooManyPages(pageCount)
        }

        if data.count <= AppConfig.inlineBase64Limit {
            return try await MistralOCRClient.extractMarkdown(document: .inlinePDF(data), apiKey: apiKey)
        }
        return try await convertViaUpload(fileURL: fileURL, data: data, apiKey: apiKey)
    }

    // MARK: - Images

    static func convertImage(fileURL: URL, apiKey: String) async throws -> String {
        let (payload, mimeType) = try normalizedForOCR(imageData: try loadData(from: fileURL), fileURL: fileURL)
        try checkSize(payload)
        return try await MistralOCRClient.extractMarkdown(
            document: .inlineImage(payload, mimeType: mimeType),
            apiKey: apiKey
        )
    }

    /// Mistral documents PNG/JPEG/AVIF support, so TIFF (and anything else AppKit can
    /// decode) is re-encoded to PNG before it's sent.
    private static func normalizedForOCR(imageData: Data, fileURL: URL) throws -> (Data, String) {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 40_000_000 / height else {
            throw ConversionError.invalidImageData(fileURL)
        }
        let ext = fileURL.pathExtension.lowercased()
        guard nativeImageExtensions.contains(ext) else {
            guard
                let rep = NSBitmapImageRep(data: imageData),
                let png = rep.representation(using: .png, properties: [:])
            else {
                throw ConversionError.invalidImageData(fileURL)
            }
            return (png, "image/png")
        }
        return (imageData, mimeType(for: fileURL))
    }

    // MARK: - Helpers

    /// Files past the inline limit go through the Files API. The upload is deleted afterwards
    /// rather than left to Mistral's 30-day expiry.
    private static func convertViaUpload(fileURL: URL, data: Data, apiKey: String) async throws -> String {
        let (fileID, signedURL) = try await MistralOCRClient.upload(
            fileURL: fileURL,
            data: data,
            apiKey: apiKey
        )
        do {
            let markdown = try await MistralOCRClient.extractMarkdown(document: .remoteURL(signedURL), apiKey: apiKey)
            await MistralOCRClient.deleteFile(id: fileID, apiKey: apiKey)
            return markdown
        } catch {
            await MistralOCRClient.deleteFile(id: fileID, apiKey: apiKey)
            throw error
        }
    }

    private static func checkSize(_ data: Data) throws {
        guard data.count <= AppConfig.maxUploadBytes else {
            throw ConversionError.fileTooLarge(bytes: data.count)
        }
    }

    private static func loadData(from fileURL: URL) throws -> Data {
        if let size = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber,
           size.intValue > AppConfig.maxUploadBytes {
            throw ConversionError.fileTooLarge(bytes: size.intValue)
        }
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            throw ConversionError.invalidImageData(fileURL)
        }
        return data
    }

    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "avif": return "image/avif"
        default:
            if let type = UTType(filenameExtension: url.pathExtension), let mime = type.preferredMIMEType {
                return mime
            }
            return "application/octet-stream"
        }
    }
}
