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

    let positional = arguments.dropFirst().filter { $0 != "--overwrite" }
    let inputURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
    let outputURL = positional.count >= 2
        ? URL(fileURLWithPath: positional[1]).standardizedFileURL
        : inputURL.deletingPathExtension().appendingPathExtension("md")
    let ext = inputURL.pathExtension.lowercased()

    let apiKey = KeychainStore.read() ?? ""

    let job = ConversionJob(
        inputPath: inputURL,
        outputPath: outputURL,
        apiKey: apiKey,
        engine: ext == "pdf" || MistralOCRConverter.imageExtensions.contains(ext) ? .cloud : .local,
        overwrite: arguments.contains("--overwrite")
    )

    let semaphore = DispatchSemaphore(value: 0)
    let result = HeadlessResult()

    Task.detached {
        do {
            let markdown = try await ConversionRouter.convert(job: job) { message in
                print("ROUTE: \(message)")
            }
            try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
            print("OK: wrote \(markdown.count) characters to \(outputURL.path)")
        } catch {
            FileHandle.standardError.write(Data("ERROR: \(error.localizedDescription)\n".utf8))
            result.code = 1
        }
        semaphore.signal()
    }
    semaphore.wait()
    exit(result.code)
}

private final class HeadlessResult: @unchecked Sendable {
    var code: Int32 = 0
}

if CommandLine.arguments.count > 1, CommandLine.arguments[1] == "--convert" {
    runHeadlessConvert(arguments: Array(CommandLine.arguments.dropFirst()))
} else {
    MarkItDownSwiftApp.main()
}
