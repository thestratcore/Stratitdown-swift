import Foundation

enum AppConfig {
    static let defaultModel = "gpt-4o"
    static let defaultPrompt = ""
    static let commonModels = ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "o4-mini"]

    static let keychainService = "local.personal.markitdown-swift"
    static let keychainAccount = "openai-api-key"

    static let visionEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

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

        // Fall back to a login-shell PATH lookup, in case markitdown lives somewhere
        // shell-specific (pyenv, asdf, a custom PATH entry, etc).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v markitdown"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              FileManager.default.isExecutableFile(atPath: path)
        else { return nil }
        return path
    }
}
