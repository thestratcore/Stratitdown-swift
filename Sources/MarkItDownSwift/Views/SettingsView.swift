import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ConversionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OpenAI API Key")
                .font(.title2.bold())

            Text("Saved once to the macOS Keychain — you shouldn't need to touch this again unless the key changes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                SecureField("sk-...", text: $viewModel.apiKeyInput)
                Button("Save to Keychain") { viewModel.saveApiKey() }
            }

            VStack(alignment: .leading, spacing: 6) {
                statusLine(ok: viewModel.apiKeyPresent, text: viewModel.apiKeyStatus)
                statusLine(ok: viewModel.markitdownFound, text: viewModel.markitdownStatus)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 460, height: 280)
        .onAppear { viewModel.refreshConfigStatus() }
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
}
