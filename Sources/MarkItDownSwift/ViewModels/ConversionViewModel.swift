import AppKit
import Foundation
import SwiftUI

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published var inputPath: String = ""
    @Published var outputPath: String = ""
    @Published var apiKeyInput: String = ""
    @Published var overwriteExistingOutput = false
    @Published private(set) var pendingPDFAnalysis: PDFAnalysis?

    @Published private(set) var state: ConversionState = .standby
    @Published private(set) var log: String = ""
    @Published private(set) var isConverting: Bool = false
    @Published private(set) var apiKeyPresent: Bool = false
    @Published private(set) var apiKeyStatus: String = "Checking Keychain…"
    @Published private(set) var markitdownFound: Bool = false
    @Published private(set) var markitdownStatus: String = ""

    private var conversionTask: Task<Void, Never>?

    init() {
        KeychainStore.deleteLegacyOpenAIKey()
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

    /// Resets the form back to a fresh state. Lives here rather than in the view because
    /// `state` and `log` are `private(set)`.
    func clearAll() {
        guard !isConverting else {
            appendLog("Conversion in progress — fields not cleared.")
            return
        }
        inputPath = ""
        outputPath = ""
        log = ""
        state = .standby
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
        let inputURL = URL(fileURLWithPath: trimmedInput).standardizedFileURL.resolvingSymlinksInPath()

        let trimmedOutput = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputURL = trimmedOutput.isEmpty
            ? defaultOutputPath(for: inputURL)
            : URL(fileURLWithPath: trimmedOutput).standardizedFileURL
        outputPath = outputURL.path
        guard inputURL != outputURL.resolvingSymlinksInPath() else { appendLog("ERROR: Output path must differ from input."); setState(.error); return }

        let extensionName = inputURL.pathExtension.lowercased()
        let requestedEngine = selectedPDFEngine
        selectedPDFEngine = nil
        if extensionName == "pdf", pendingPDFAnalysis == nil, requestedEngine == nil {
            do {
                let analysis = try PDFTextLayerDetector.analyze(fileURL: inputURL)
                if !analysis.isScanned {
                    pendingPDFAnalysis = analysis
                    appendLog("PDF inspected: \(analysis.pagesWithText)/\(analysis.pageCount) pages contain text. Choose an engine.")
                    return
                }
            } catch {
                appendLog("ERROR: \(error.localizedDescription)"); setState(.error); return
            }
        }
        let needsCloud = (requestedEngine == .cloud) ||
            (requestedEngine == nil && (extensionName == "pdf" || MistralOCRConverter.imageExtensions.contains(extensionName)))
        guard !needsCloud || (KeychainStore.read()?.isEmpty == false) else {
            appendLog("ERROR: Mistral API key is not configured for OCR")
            setState(.error); return
        }

        let job = ConversionJob(
            inputPath: inputURL,
            outputPath: outputURL,
            apiKey: KeychainStore.read() ?? "",
            engine: requestedEngine ?? (extensionName == "pdf" ? .cloud : (needsCloud ? .cloud : .local)),
            overwrite: overwriteExistingOutput
        )

        isConverting = true
        setState(.waiting)
        appendLog("Starting conversion: \(inputURL.path)")
        appendLog("Output path: \(outputURL.path)")

        conversionTask = Task { [weak self] in
            await self?.runConversion(job: job)
        }
    }

    func choosePDFEngine(_ engine: ConversionEngine) {
        guard pendingPDFAnalysis != nil else { return }
        pendingPDFAnalysis = nil
        startConversionWithEngine(engine)
    }

    func cancelPDFChoice() { pendingPDFAnalysis = nil }

    private func startConversionWithEngine(_ engine: ConversionEngine) {
        // The next startConversion call performs all common validation; this flag only
        // carries the explicit user choice through the single conversion entry point.
        selectedPDFEngine = engine
        startConversion()
    }

    private var selectedPDFEngine: ConversionEngine?

    private func runConversion(job: ConversionJob) async {
        do {
            let markdown = try await ConversionRouter.convert(job: job) { [weak self] message in
                Task { @MainActor in
                    self?.appendLog(message)
                }
            }
            try OutputPublisher.publish(markdown, to: job.outputPath, allowingOverwrite: job.overwrite)

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
