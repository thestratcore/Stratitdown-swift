import Foundation

/// Direct `URLSession` client for Mistral's document OCR endpoint — no SDK dependency.
///
/// The endpoint takes a whole document (not page images) and returns per-page Markdown with
/// tables and structure preserved, so there is no rasterization or prompt engineering here.
enum MistralOCRClient {
    /// How the document is handed to the API.
    enum Document {
        /// Inline base64 data URI. Retention is governed by the provider account policy.
        case inlinePDF(Data)
        case inlineImage(Data, mimeType: String)
        /// A signed URL produced by the Files API, for documents too large to inline.
        case remoteURL(URL)
    }

    // MARK: - OCR

    static func extractMarkdown(document: Document, apiKey: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversionError.apiKeyMissing
        }

        let request = OCRRequest(
            model: AppConfig.ocrModel,
            document: document.payload,
            tableFormat: nil,
            includeImageBase64: false
        )

        var urlRequest = URLRequest(url: AppConfig.ocrEndpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        // Large scanned documents legitimately take minutes.
        urlRequest.timeoutInterval = 300

        let response: OCRResponse = try await send(urlRequest)
        guard !response.pages.isEmpty else { throw ConversionError.ocrEmptyResponse }

        return response.pages
            .sorted { $0.index < $1.index }
            .map(\.markdown)
            .joined(separator: "\n\n---\n\n")
    }

    // MARK: - Files API (documents over the inline limit)

    /// Uploads a document for OCR and returns a signed URL plus the file id, so the caller
    /// can delete it once the OCR call is done rather than leaving it for Mistral's 30-day expiry.
    static func upload(fileURL: URL, data: Data, apiKey: String) async throws -> (fileID: String, signedURL: URL) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func appendField(name: String, value: String) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }

        appendField(name: "purpose", value: "ocr")
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".utf8))
        body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var uploadRequest = URLRequest(url: AppConfig.filesEndpoint)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        uploadRequest.httpBody = body
        uploadRequest.timeoutInterval = 300

        let uploaded: UploadedFile = try await send(uploadRequest)

        var signedRequest = URLRequest(
            url: AppConfig.filesEndpoint.appendingPathComponent(uploaded.id).appendingPathComponent("url")
        )
        signedRequest.httpMethod = "GET"
        signedRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        signedRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let signed: SignedURL
        do {
            signed = try await send(signedRequest)
        } catch {
            await deleteFile(id: uploaded.id, apiKey: apiKey)
            throw error
        }
        guard let url = URL(string: signed.url) else {
            await deleteFile(id: uploaded.id, apiKey: apiKey)
            throw ConversionError.mistralRequestFailed(status: 200, body: "Malformed signed URL: \(signed.url)")
        }
        return (uploaded.id, url)
    }

    static func deleteFile(id: String, apiKey: String) async {
        var request = URLRequest(url: AppConfig.filesEndpoint.appendingPathComponent(id))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) || http.statusCode == 404 else { return }
    }

    // MARK: - Transport

    private static func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ConversionError.mistralRequestFailed(status: -1, body: "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ConversionError.mistralRequestFailed(status: http.statusCode, body: "Provider rejected the request")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ConversionError.mistralRequestFailed(
                status: http.statusCode,
                body: "Unexpected response shape (\(error.localizedDescription))"
            )
        }
    }
}

// MARK: - Wire types

private struct OCRRequest: Encodable {
    let model: String
    let document: DocumentPayload
    let tableFormat: String?
    let includeImageBase64: Bool

    enum CodingKeys: String, CodingKey {
        case model, document
        case tableFormat = "table_format"
        case includeImageBase64 = "include_image_base64"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(document, forKey: .document)
        try container.encodeIfPresent(tableFormat, forKey: .tableFormat)
        try container.encode(includeImageBase64, forKey: .includeImageBase64)
    }
}

/// Mistral discriminates on `type`, with the URL living under a differently named key
/// depending on whether it's a document or an image.
struct DocumentPayload: Encodable {
    let type: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case type
        case documentURL = "document_url"
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(url, forKey: type == "image_url" ? .imageURL : .documentURL)
    }
}

private struct OCRResponse: Decodable {
    struct Page: Decodable {
        let index: Int
        let markdown: String
    }
    let pages: [Page]
}

private struct UploadedFile: Decodable {
    let id: String
}

private struct SignedURL: Decodable {
    let url: String
}

private extension MistralOCRClient.Document {
    var payload: DocumentPayload {
        switch self {
        case .inlinePDF(let data):
            return DocumentPayload(
                type: "document_url",
                url: "data:application/pdf;base64,\(data.base64EncodedString())"
            )
        case .inlineImage(let data, let mimeType):
            return DocumentPayload(
                type: "image_url",
                url: "data:\(mimeType);base64,\(data.base64EncodedString())"
            )
        case .remoteURL(let url):
            return DocumentPayload(type: "document_url", url: url.absoluteString)
        }
    }
}
