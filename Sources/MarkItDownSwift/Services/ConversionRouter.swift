import Foundation

enum ConversionRouter {
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tif", "tiff"]

    static func convert(job: ConversionJob) async throws -> String {
        guard FileManager.default.fileExists(atPath: job.inputPath.path) else {
            throw ConversionError.inputNotFound(job.inputPath)
        }

        let ext = job.inputPath.pathExtension.lowercased()

        if imageExtensions.contains(ext) {
            return try await ImageOCRConverter.convert(
                fileURL: job.inputPath,
                model: job.model,
                prompt: job.prompt,
                apiKey: job.apiKey
            )
        }

        if ext == "pdf" {
            return try await PDFConverter.convert(
                fileURL: job.inputPath,
                model: job.model,
                prompt: job.prompt,
                apiKey: job.apiKey
            )
        }

        return try MarkItDownCLIConverter.convert(fileURL: job.inputPath)
    }
}
