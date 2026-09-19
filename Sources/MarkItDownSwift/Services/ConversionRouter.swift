import Foundation

enum ConversionRouter {
    static func convert(
        job: ConversionJob,
        onRouteDecision: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        guard FileManager.default.fileExists(atPath: job.inputPath.path) else {
            throw ConversionError.inputNotFound(job.inputPath)
        }

        let ext = job.inputPath.pathExtension.lowercased()

        if MistralOCRConverter.imageExtensions.contains(ext) {
            guard job.engine == .cloud else { throw ConversionError.cloudEngineUnsupported }
            return try await MistralOCRConverter.convertImage(
                fileURL: job.inputPath,
                apiKey: job.apiKey
            )
        }

        if ext == "pdf" {
            let analysis = try PDFTextLayerDetector.analyze(fileURL: job.inputPath)
            if job.engine == .local {
                guard analysis.isTextOnly else { throw ConversionError.localEngineCannotProcessScannedPDF }
                onRouteDecision?("PDF is text-only — converting locally via markitdown CLI.")
                return try MarkItDownCLIConverter.convert(fileURL: job.inputPath)
            }
            onRouteDecision?("Converting PDF via cloud OCR (\(analysis.pagesWithText)/\(analysis.pageCount) pages have text).")
            return try await MistralOCRConverter.convertPDF(
                fileURL: job.inputPath,
                apiKey: job.apiKey
            )
        }

        guard job.engine == .local else { throw ConversionError.cloudEngineUnsupported }
        return try MarkItDownCLIConverter.convert(fileURL: job.inputPath)
    }
}
