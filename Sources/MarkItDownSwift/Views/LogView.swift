import SwiftUI

struct LogView: View {
    let text: String

    private var lines: [String] {
        text.isEmpty ? [" "] : text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .foregroundStyle(line.hasPrefix("ERROR") ? Color.red : Color.primary)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .id("logEnd")
            }
            .background(Color(nsColor: .textBackgroundColor))
            .border(Color(nsColor: .separatorColor))
            .onChange(of: text) { _, _ in
                proxy.scrollTo("logEnd", anchor: .bottom)
            }
        }
    }
}
