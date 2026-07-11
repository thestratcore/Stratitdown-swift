import Foundation

struct ConversionJob {
    let inputPath: URL
    let outputPath: URL
    let model: String
    let prompt: String
    let apiKey: String
}

enum ConversionError: LocalizedError {
    case inputNotFound(URL)
    case apiKeyMissing
    case markitdownBinaryMissing(String)
    case markitdownFailed(exitCode: Int32, stderr: String)
    case visionRequestFailed(status: Int, body: String)
    case invalidImageData(URL)
    case unreadablePDF(URL)

    var errorDescription: String? {
        switch self {
        case .inputNotFound(let url):
            return "Input file does not exist: \(url.path)"
        case .apiKeyMissing:
            return "OpenAI API key is not configured. Save one in Settings."
        case .markitdownBinaryMissing(let path):
            return "markitdown binary not found at \(path). Install it with `uv tool install markitdown[all]`."
        case .markitdownFailed(let exitCode, let stderr):
            return "markitdown exited with code \(exitCode): \(stderr)"
        case .visionRequestFailed(let status, let body):
            return "OpenAI vision request failed (HTTP \(status)): \(body)"
        case .invalidImageData(let url):
            return "Could not read image data from: \(url.path)"
        case .unreadablePDF(let url):
            return "Could not open PDF: \(url.path)"
        }
    }
}
