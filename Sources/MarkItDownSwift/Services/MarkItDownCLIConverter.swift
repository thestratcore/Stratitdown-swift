import Foundation

/// Shells out to the already-installed `markitdown` CLI (`uv tool install markitdown[all]`)
/// for every format it handles natively (docx, pptx, xlsx, eml, csv, html, ...).
enum MarkItDownCLIConverter {
    static func convert(fileURL: URL) throws -> String {
        guard AppConfig.markitdownBinaryExists else {
            throw ConversionError.markitdownBinaryMissing(AppConfig.markitdownBinaryPath)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: AppConfig.markitdownBinaryPath)
        process.arguments = [fileURL.path, "-o", outputURL.path]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe() // markitdown writes to -o, keep stdout quiet

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
            throw ConversionError.markitdownFailed(exitCode: process.terminationStatus, stderr: stderrText)
        }

        return try String(contentsOf: outputURL, encoding: .utf8)
    }
}
