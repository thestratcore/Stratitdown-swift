import Foundation

/// The file types the app can convert, grouped by which engine handles them — that split is
/// what actually predicts behaviour for the user (a Mistral route needs an API key and the
/// network; a markitdown route runs offline but needs the CLI installed).
///
/// The OCR groups are derived from `MistralOCRConverter`'s own extension sets so this list
/// can't drift away from what `ConversionRouter` really does.
enum SupportedFormats {
    struct Group {
        let title: String
        let extensions: [String]
    }

    static let viaMistralOCR: [Group] = [
        Group(title: "Documents", extensions: ["pdf"]),
        Group(title: "Images", extensions: MistralOCRConverter.nativeImageExtensions.sorted()),
        Group(
            title: "Images, re-encoded to PNG first",
            extensions: MistralOCRConverter.imageExtensions
                .subtracting(MistralOCRConverter.nativeImageExtensions)
                .sorted()
        ),
    ]

    static let viaMarkItDownCLI: [Group] = [
        Group(title: "Office and mail", extensions: ["docx", "pptx", "xlsx", "xls", "msg", "eml"]),
        Group(title: "Text and data", extensions: ["csv", "tsv", "json", "xml", "html", "htm", "txt", "md", "rss", "atom"]),
        Group(title: "Books and notebooks", extensions: ["epub", "ipynb"]),
        Group(title: "Audio, transcribed", extensions: ["wav", "mp3", "m4a"]),
        Group(title: "Archives, expanded in place", extensions: ["zip"]),
    ]

    /// Flattened for the header, where the groups are collapsed into one line per engine —
    /// the engine split is the part worth keeping at a glance.
    static var mistralOCRList: String { flatten(viaMistralOCR) }
    static var markItDownCLIList: String { flatten(viaMarkItDownCLI) }

    private static func flatten(_ groups: [Group]) -> String {
        groups.flatMap(\.extensions).map { ".\($0)" }.joined(separator: " ")
    }
}
