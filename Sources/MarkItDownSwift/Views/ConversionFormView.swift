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
                modelSection
                actionsRow
                statusSection
            }
            .padding(16)
            .frame(minWidth: 680, alignment: .topLeading)
        }
        .frame(minWidth: 680, minHeight: 620)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            Text("Convert local documents to Markdown with MarkItDown Swift and OpenAI vision.")
                .foregroundStyle(.secondary)
            Spacer()
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

    private var modelSection: some View {
        GroupBox("Model") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model").font(.subheadline)
                    HStack {
                        TextField("", text: $viewModel.model)
                            .frame(width: 220)
                        Menu {
                            ForEach(AppConfig.commonModels, id: \.self) { name in
                                Button {
                                    viewModel.model = name
                                } label: {
                                    if name == viewModel.model {
                                        Label(name, systemImage: "checkmark")
                                    } else {
                                        Text(name)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 24)
                        .help("Choose a common model preset")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt override (optional)").font(.subheadline)
                    TextField("Leave empty to use default OCR prompt", text: $viewModel.prompt)
                }
            }
            .padding(8)
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
            Button("Refresh status") { viewModel.refreshConfigStatus() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
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
                .frame(minHeight: 220)
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
