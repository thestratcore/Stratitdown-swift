import Foundation

enum AppConfig {
    /// Mistral's rolling OCR alias. OCR output can change when the provider updates this alias.
    static let ocrModel = "mistral-ocr-latest"

    static let keychainService = "local.personal.markitdown-swift"
    static let keychainAccount = "mistral-api-key"
    /// Account used before the migration to Mistral; cleaned up once on launch.
    static let legacyKeychainAccount = "openai-api-key"

    static let ocrEndpoint = URL(string: "https://api.mistral.ai/v1/ocr")!
    static let filesEndpoint = URL(string: "https://api.mistral.ai/v1/files")!

    /// Below this, the document is sent inline as a base64 data URI. Larger files use the
    /// Files API and are deleted after processing on a best-effort basis.
    static let inlineBase64Limit = 20 * 1024 * 1024
    /// Mistral's hard limits, checked before any network call.
    static let maxUploadBytes = 50 * 1024 * 1024
    static let maxPages = 1000

    /// A PDF counts as having a real text layer once this many non-whitespace characters have
    /// been found across its pages — enough to rule out incidental embedded/metadata text in an
    /// otherwise scanned document, low enough to catch anything genuinely text-based.
    static let pdfTextLayerMinimumCharacters = 50

    /// Installed via `uv tool install markitdown[all]`, or via Homebrew / a shell PATH entry.
    /// Resolved per-user at runtime rather than hardcoded, since the uv tool directory lives under
    /// each user's home directory.
    static var markitdownBinaryPath: String {
        resolvedMarkitdownPath ?? "~/.local/share/uv/tools/markitdown/bin/markitdown (not found)"
    }

    static var markitdownBinaryExists: Bool {
        resolvedMarkitdownPath != nil
    }

    private static var resolvedMarkitdownPath: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/share/uv/tools/markitdown/bin/markitdown",
            "/opt/homebrew/bin/markitdown",
            "/usr/local/bin/markitdown",
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }

        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
        return (pathEntries.map { "\($0)/markitdown" })
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
