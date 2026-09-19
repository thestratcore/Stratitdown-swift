import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConversionFormView: View {
    @ObservedObject var viewModel: ConversionViewModel
    @State private var showingSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                documentSection
                actionsRow
                statusSection
            }
            .padding(16)
            .frame(minWidth: 680, alignment: .topLeading)
        }
        .frame(minWidth: 680, minHeight: 520)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert("Choose PDF processing", isPresented: Binding(
            get: { viewModel.pendingPDFAnalysis != nil },
            set: { if !$0 { viewModel.cancelPDFChoice() } }
        )) {
            Button("Use local extraction") { viewModel.choosePDFEngine(.local) }
            Button("Use cloud OCR") { viewModel.choosePDFEngine(.cloud) }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let analysis = viewModel.pendingPDFAnalysis {
                Text(analysis.isMixed
                     ? "This PDF has text on \(analysis.pagesWithText) of \(analysis.pageCount) pages. Cloud OCR is recommended so scanned pages are not omitted."
                     : "All \(analysis.pageCount) pages contain text. Local extraction is recommended and keeps the document on this Mac.")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                BrandLogo(height: 40)
                Text("Convert local documents to Markdown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                supportedFormatsLines
            }
            Spacer(minLength: 24)
            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    showingSettings = true
                } label: {
                    Label("API Key", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                statusLine(ok: viewModel.apiKeyPresent, text: "API key")
                statusLine(ok: viewModel.markitdownFound, text: "markitdown CLI")
            }
        }
    }

    private var documentSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Input file").font(.headline)
                    HStack {
                        TextField("", text: $viewModel.inputPath)
                            .controlSize(.large)
                        Button("Browse") { chooseInput() }
                            .controlSize(.large)
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Output Markdown").font(.headline)
                    HStack {
                        TextField("", text: $viewModel.outputPath)
                            .controlSize(.large)
                        Button("Browse") { chooseOutput() }
                            .controlSize(.large)
                    }
                }

                Text("Drag a file onto the Input row to fill it in.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Toggle("Allow replacing an existing output", isOn: $viewModel.overwriteExistingOutput)
                    .font(.caption)
            }
            .padding(14)
        } label: {
            Text("Document")
                .font(.title3.bold())
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.08))
        )
    }

    /// Every convertible extension, written out but kept quiet: two wrapped lines in the
    /// header rather than a section of its own. Split by engine, because that's what
    /// predicts behaviour — OCR needs an API key and the network, the CLI runs offline.
    private var supportedFormatsLines: some View {
        VStack(alignment: .leading, spacing: 3) {
            formatLine("OCR", SupportedFormats.mistralOCRList)
            formatLine("CLI", SupportedFormats.markItDownCLIList)
        }
        .help("OCR formats go to Mistral (up to \(AppConfig.maxUploadBytes / 1_048_576) MB, \(AppConfig.maxPages) pages). CLI formats are converted on this Mac by markitdown.")
    }

    private func formatLine(_ engine: String, _ extensions: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(engine)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
            Text(extensions)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 16) {
            Button { viewModel.startConversion() } label: {
                HStack(spacing: 8) {
                    if viewModel.isConverting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isConverting ? "Converting…" : "Convert")
                        .font(.title3.bold())
                }
                .frame(minWidth: 140, minHeight: 20)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isConverting)

            StatusIndicatorView(state: viewModel.state)
            Spacer()
            Button("Clear all") { viewModel.clearAll() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(viewModel.isConverting)
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .help("Empty both paths and the log")
            Button("Recheck setup") { viewModel.refreshConfigStatus() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Look again for the API key and the markitdown CLI")
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Status")
                Spacer()
                Button("Copy") { copyLogToPasteboard() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button("Clear") { viewModel.clearLog() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            LogView(text: viewModel.log)
                .frame(height: 120)
        }
    }

    private func statusLine(ok: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.title = "Choose input document"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.chooseInput(url: url)
        }
    }

    private func chooseOutput() {
        let panel = NSSavePanel()
        panel.title = "Choose Markdown output"
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = URL(fileURLWithPath: viewModel.outputPath).lastPathComponent
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.chooseOutput(url: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                viewModel.chooseInput(url: url)
            }
        }
        return true
    }

    private func copyLogToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(viewModel.log, forType: .string)
    }
}
