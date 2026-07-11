import SwiftUI

enum ConversionState: Equatable {
    case standby
    case waiting
    case finished
    case error

    var label: String {
        switch self {
        case .standby: return "Stand-by"
        case .waiting: return "Waiting for AI"
        case .finished: return "Finished"
        case .error: return "Error"
        }
    }

    var color: Color {
        switch self {
        case .standby: return Color(red: 0.604, green: 0.604, blue: 0.604) // #9a9a9a
        case .waiting: return Color(red: 0.847, green: 0.608, blue: 0.0)   // #d89b00
        case .finished: return Color(red: 0.184, green: 0.620, blue: 0.267) // #2f9e44
        case .error: return Color(red: 0.788, green: 0.165, blue: 0.165)  // #c92a2a
        }
    }
}
