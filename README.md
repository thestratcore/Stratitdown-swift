# MarkItDown Swift

Native macOS 14+ SwiftUI front end for converting local documents to Markdown.

The app routes office, mail, text, archive, and audio formats to the locally installed [Microsoft MarkItDown](https://github.com/microsoft/markitdown) CLI. PDFs and images use Mistral OCR when cloud processing is selected. Text-only PDFs default to local extraction; mixed PDFs prompt with cloud OCR recommended; PDFs without a text layer use cloud OCR automatically. Status: internal.

## Stack

| Component | Technology | Pinned in |
|---|---|---|
| Platform | macOS, SwiftUI, Swift Package Manager | `Package.swift` (`swift-tools-version`, `platforms`) |
| Dependencies | none (no Swift packages) | `Package.swift` |
| Converters | Microsoft MarkItDown CLI (installed with `uv tool`), Mistral OCR (cloud, optional) | README "Build" |
| CI | GitHub Actions | `.github/workflows/ci.yml` |

## Features

- Converts office, mail, text, archive and audio files to Markdown through the local MarkItDown CLI.
- PDFs and images: local text extraction, or Mistral OCR when cloud processing is chosen.
- CLI mode: `MarkItDownSwift --convert input output.md`.

### Privacy and limits

Cloud OCR sends document contents to Mistral over HTTPS and may incur usage charges. API keys are stored in the macOS Keychain. Files uploaded through Mistral’s Files API are deleted after conversion when possible; cleanup failures are reported. Review Mistral’s retention and privacy terms before processing sensitive documents. The application does not claim zero retention.

Mistral OCR accepts files up to 50 MiB and 1,000 PDF pages. OCR output is probabilistic and the `mistral-ocr-latest` alias may change over time. Returned table content is inserted into the Markdown output; a table reference without its content causes conversion to fail. Embedded OCR image assets are not downloaded into the Markdown output.

## Run and test

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

## Deploy

n/a: a local app. `./build_app.sh` builds an ad-hoc-signed bundle for the host; there is no notarised download.

## Links

- Vault: `Company/Stratcore/Projects/MarkItDownSwift/PROJECT_KNOWLEDGE.md`
- Agent rules: `AGENTS.md`

### License

Code is Apache-2.0 licensed. The bundled icon and wordmark are owned by the project author. MarkItDown and Mistral are separate projects and services with their own terms.
