import AppKit
import Foundation
import UniformTypeIdentifiers

enum ImageOCRConverter {
    static func convert(fileURL: URL, model: String, prompt: String, apiKey: String) async throws -> String {
        try await convert(imageData: try loadData(from: fileURL), fileURL: fileURL, model: model, prompt: prompt, apiKey: apiKey)
    }

    /// OpenAI's vision endpoint only accepts PNG/JPEG/WEBP/GIF, so TIFF (and anything
    /// else AppKit can decode) is re-encoded to PNG before it's sent.
    static func convert(imageData: Data, fileURL: URL, model: String, prompt: String, apiKey: String) async throws -> String {
        let (payload, mimeType) = try normalizedForVisionAPI(imageData: imageData, fileURL: fileURL)
        return try await OpenAIVisionClient.extractMarkdown(
            imageData: payload,
            mimeType: mimeType,
            model: model,
            prompt: prompt,
            apiKey: apiKey
        )
    }

    private static func normalizedForVisionAPI(imageData: Data, fileURL: URL) throws -> (Data, String) {
        let ext = fileURL.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg"].contains(ext) else {
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

    private static func loadData(from fileURL: URL) throws -> Data {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            throw ConversionError.invalidImageData(fileURL)
        }
        return data
    }

    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "tif", "tiff": return "image/tiff"
        default:
            if let type = UTType(filenameExtension: url.pathExtension), let mime = type.preferredMIMEType {
                return mime
            }
            return "application/octet-stream"
        }
    }
}
