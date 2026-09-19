# MarkItDown Swift

Native macOS 14+ SwiftUI front end for converting local documents to Markdown.

The app routes office, mail, text, archive, and audio formats to the locally installed [Microsoft MarkItDown](https://github.com/microsoft/markitdown) CLI. PDFs and images use Mistral OCR when cloud processing is selected. Text-only PDFs default to local extraction; mixed PDFs prompt with cloud OCR recommended; PDFs without a text layer use cloud OCR automatically.

## Privacy and limits

Cloud OCR sends document contents to Mistral over HTTPS and may incur usage charges. API keys are stored in the macOS Keychain. Files uploaded through Mistral’s Files API are deleted after conversion when possible; cleanup failures are reported. Review Mistral’s retention and privacy terms before processing sensitive documents. The application does not claim zero retention.

Mistral OCR accepts files up to 50 MiB and 1,000 PDF pages. OCR output is probabilistic and the `mistral-ocr-latest` alias may change over time. Embedded OCR image assets are not downloaded into the Markdown output.

## Build

Install Swift 5.9+ and macOS 14+. Install MarkItDown 0.1.6 (or a compatible version):

```sh
uv tool install 'markitdown[all]==0.1.6'
./build_app.sh
```

The bundle is ad-hoc signed for local use and targets the host architecture. No Developer ID signing or notarized download is provided by this repository.

The CLI smoke path is:

```sh
.build/release/MarkItDownSwift --convert input.pdf output.md
# Add --overwrite to explicitly replace an existing output.
```

Use the GUI for PDF engine selection. Never commit API keys, private documents, build products, or local Keychain exports.

## License

Code is Apache-2.0 licensed. The bundled icon and wordmark are owned by the project author. MarkItDown and Mistral are separate projects and services with their own terms.
