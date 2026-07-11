import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ConversionViewModel()

    var body: some View {
        ConversionFormView(viewModel: viewModel)
    }
}
