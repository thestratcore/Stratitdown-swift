import SwiftUI

struct StatusIndicatorView: View {
    let state: ConversionState

    var body: some View {
        HStack(spacing: 6) {
            if state == .waiting {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            } else {
                Circle()
                    .fill(state.color)
                    .frame(width: 14, height: 14)
            }
            Text(state.label)
                .foregroundStyle(.secondary)
        }
    }
}
