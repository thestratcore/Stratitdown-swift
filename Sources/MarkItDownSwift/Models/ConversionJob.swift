import Foundation

struct ConversionJob: Sendable {
    let inputPath: URL
    let outputPath: URL
    let apiKey: String
    let engine: ConversionEngine
    let overwrite: Bool
}

enum ConversionEngine: String, CaseIterable, Sendable {
    case local
    case cloud
}

struct PDFAnalysis: Equatable, Sendable {
    let pageCount: Int
    let pagesWithText: Int

    var isTextOnly: Bool { pageCount > 0 && pagesWithText == pageCount }
    var isScanned: Bool { pagesWithText == 0 }
    var isMixed: Bool { !isTextOnly && !isScanned }
}

enum ConversionError: LocalizedError {
    case inputNotFound(URL)
    case apiKeyMissing
    case markitdownBinaryMissing(String)
    case markitdownFailed(exitCode: Int32, stderr: String)
    case mistralRequestFailed(status: Int, body: String)
    case invalidImageData(URL)
    case fileTooLarge(bytes: Int)
    case tooManyPages(Int)
    case ocrEmptyResponse
    case outputExists(URL)
    case outputIsInput
    case invalidOutput(URL)
    case routeRequiresConfirmation
    case localEngineCannotProcessScannedPDF
    case cancelled
    case cloudEngineUnsupported

    var errorDescription: String? {
        switch self {
        case .inputNotFound(let url):
            return "Input file does not exist: \(url.path)"
        case .apiKeyMissing:
            return "Mistral API key is not configured. Save one in Settings."
        case .markitdownBinaryMissing(let path):
            return "markitdown binary not found at \(path). Install it with `uv tool install markitdown[all]`."
        case .markitdownFailed(let exitCode, let stderr):
            return "markitdown exited with code \(exitCode): \(stderr)"
        case .mistralRequestFailed(let status, let body):
            return "Mistral OCR request failed (HTTP \(status)): \(body)"
        case .invalidImageData(let url):
            return "Could not read image data from: \(url.path)"
        case .fileTooLarge(let bytes):
            let megabytes = Double(bytes) / 1_048_576
            return String(
                format: "File is %.1f MB — Mistral OCR accepts at most %d MB.",
                megabytes,
                AppConfig.maxUploadBytes / 1_048_576
            )
        case .tooManyPages(let pages):
            return "PDF has \(pages) pages — Mistral OCR accepts at most \(AppConfig.maxPages)."
        case .ocrEmptyResponse:
            return "Mistral OCR returned no pages for this document."
        case .outputExists(let url):
            return "Output already exists: \(url.path). Choose another path or enable overwrite."
        case .outputIsInput:
            return "The output path must differ from the input file."
        case .invalidOutput(let url):
            return "Output is not a writable regular file location: \(url.path)"
        case .routeRequiresConfirmation:
            return "Choose whether this PDF should use local extraction or cloud OCR."
        case .localEngineCannotProcessScannedPDF:
            return "This PDF has pages without a text layer; local extraction may omit them. Choose cloud OCR."
        case .cancelled:
            return "Conversion cancelled."
        case .cloudEngineUnsupported:
            return "Cloud OCR supports PDF and image inputs only."
        }
    }
}
