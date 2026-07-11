import AppKit
import Foundation
import SwiftUI

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published var inputPath: String = ""
    @Published var outputPath: String = ""
    @Published var model: String = AppConfig.defaultModel
    @Published var prompt: String = AppConfig.defaultPrompt
    @Published var apiKeyInput: String = ""

    @Published private(set) var state: ConversionState = .standby
    @Published private(set) var log: String = ""
    @Published private(set) var isConverting: Bool = false
    @Published private(set) var apiKeyPresent: Bool = false
    @Published private(set) var apiKeyStatus: String = "Checking Keychain…"
    @Published private(set) var markitdownFound: Bool = false
    @Published private(set) var markitdownStatus: String = ""

    private var conversionTask: Task<Void, Never>?

    init() {
        refreshConfigStatus()
    }

    func refreshConfigStatus() {
        apiKeyPresent = KeychainStore.read() != nil
        apiKeyStatus = apiKeyPresent ? "API key loaded from Keychain" : "No API key saved yet"

        markitdownFound = AppConfig.markitdownBinaryExists
        markitdownStatus = markitdownFound
            ? "markitdown CLI found"
            : "markitdown CLI not found at \(AppConfig.markitdownBinaryPath)"
    }

    func clearLog() {
        log = ""
    }

    func saveApiKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendLog("No API key entered — nothing saved.")
            return
        }
        if KeychainStore.save(trimmed) {
            apiKeyInput = ""
            appendLog("API key saved to Keychain.")
        } else {
            appendLog("ERROR: failed to save API key to Keychain.")
        }
        refreshConfigStatus()
    }

    func chooseInput(url: URL) {
        inputPath = url.path
        if outputPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            outputPath = defaultOutputPath(for: url).path
        }
    }

    func chooseOutput(url: URL) {
        outputPath = url.path
    }

    func startConversion() {
        guard !isConverting else {
            appendLog("Conversion is already running.")
            return
        }

        let trimmedInput = inputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            appendLog("ERROR: Input file is required")
            setState(.error)
            return
        }
        let inputURL = URL(fileURLWithPath: trimmedInput).standardizedFileURL

        let trimmedOutput = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputURL = trimmedOutput.isEmpty
            ? defaultOutputPath(for: inputURL)
            : URL(fileURLWithPath: trimmedOutput).standardizedFileURL
        outputPath = outputURL.path

        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            appendLog("ERROR: Model is required")
            setState(.error)
            return
        }

        guard let apiKey = KeychainStore.read(), !apiKey.isEmpty else {
            appendLog("ERROR: OpenAI API key is not configured")
            setState(.error)
            return
        }

        let job = ConversionJob(
            inputPath: inputURL,
            outputPath: outputURL,
            model: trimmedModel,
            prompt: prompt,
            apiKey: apiKey
        )

        isConverting = true
        setState(.waiting)
        appendLog("Starting conversion: \(inputURL.path)")
        appendLog("Output path: \(outputURL.path)")
        appendLog("Model: \(trimmedModel)")

        conversionTask = Task { [weak self] in
            await self?.runConversion(job: job)
        }
    }

    private func runConversion(job: ConversionJob) async {
        do {
            let markdown = try await ConversionRouter.convert(job: job)
            try markdown.write(to: job.outputPath, atomically: true, encoding: .utf8)

            appendLog("Conversion complete. Wrote \(markdown.count) characters to \(job.outputPath.path)")
            setState(.finished)
            NSWorkspace.shared.open(job.outputPath)
        } catch {
            appendLog("ERROR: \(error.localizedDescription)")
            setState(.error)
        }
        isConverting = false
    }

    private func defaultOutputPath(for inputURL: URL) -> URL {
        inputURL.deletingPathExtension().appendingPathExtension("md")
    }

    private func setState(_ newState: ConversionState) {
        state = newState
    }

    private func appendLog(_ message: String) {
        log += message + "\n"
    }
}
