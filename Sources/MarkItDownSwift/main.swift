import Foundation
import SwiftUI

/// Headless smoke-test entry point: `MarkItDownSwift --convert <input> [output]`.
/// Exercises the exact same ConversionRouter path the GUI's Convert button uses,
/// without needing to drive NSOpenPanel/NSSavePanel dialogs.
func runHeadlessConvert(arguments: [String]) -> Never {
    guard arguments.count >= 2 else {
        FileHandle.standardError.write(Data("Usage: --convert <input> [output]\n".utf8))
        exit(2)
    }

    let inputURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
    let outputURL = arguments.count >= 3
        ? URL(fileURLWithPath: arguments[2]).standardizedFileURL
        : inputURL.deletingPathExtension().appendingPathExtension("md")

    let apiKey = KeychainStore.read() ?? ""

    let job = ConversionJob(
        inputPath: inputURL,
        outputPath: outputURL,
        model: AppConfig.defaultModel,
        prompt: AppConfig.defaultPrompt,
        apiKey: apiKey
    )

    let semaphore = DispatchSemaphore(value: 0)
    var exitCode: Int32 = 0

    Task {
        do {
            let markdown = try await ConversionRouter.convert(job: job)
            try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
            print("OK: wrote \(markdown.count) characters to \(outputURL.path)")
        } catch {
            FileHandle.standardError.write(Data("ERROR: \(error.localizedDescription)\n".utf8))
            exitCode = 1
        }
        semaphore.signal()
    }
    semaphore.wait()
    exit(exitCode)
}

if CommandLine.arguments.count > 1, CommandLine.arguments[1] == "--convert" {
    runHeadlessConvert(arguments: Array(CommandLine.arguments.dropFirst()))
} else {
    MarkItDownSwiftApp.main()
}
