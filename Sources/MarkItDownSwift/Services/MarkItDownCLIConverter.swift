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

        let diagnosticsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: diagnosticsURL.path, contents: nil)
        let diagnosticsHandle = try FileHandle(forWritingTo: diagnosticsURL)
        defer {
            try? diagnosticsHandle.close()
            try? FileManager.default.removeItem(at: diagnosticsURL)
        }
        process.standardError = diagnosticsHandle
        process.standardOutput = diagnosticsHandle

        try process.run()
        let deadline = Date().addingTimeInterval(300)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if process.isRunning { process.terminate(); throw ConversionError.markitdownFailed(exitCode: 124, stderr: "Conversion timed out after 300 seconds") }

        if process.terminationStatus != 0 {
            try? diagnosticsHandle.synchronize()
            let stderrData = (try? Data(contentsOf: diagnosticsURL)) ?? Data()
            let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
            throw ConversionError.markitdownFailed(exitCode: process.terminationStatus, stderr: String(stderrText.prefix(4_096)))
        }

        return try String(contentsOf: outputURL, encoding: .utf8)
    }
}
