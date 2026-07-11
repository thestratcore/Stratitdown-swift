import Foundation

/// Direct port of what `MarkItDown(llm_client=OpenAI(...), llm_model=..., llm_prompt=...)`
/// did under the hood for images: a single Chat Completions call with an inline base64 image.
enum OpenAIVisionClient {
    private static let defaultPrompt = """
    Convert this document image to Markdown. Preserve headings, tables, and lists \
    as faithfully as possible. Respond with Markdown only, no commentary.
    """

    static func extractMarkdown(
        imageData: Data,
        mimeType: String,
        model: String,
        prompt: String,
        apiKey: String
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversionError.apiKeyMissing
        }

        let effectivePrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultPrompt
            : prompt

        let base64 = imageData.base64EncodedString()
        let dataURI = "data:\(mimeType);base64,\(base64)"

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": effectivePrompt],
                        ["type": "image_url", "image_url": ["url": dataURI]],
                    ],
                ]
            ],
        ]

        var request = URLRequest(url: AppConfig.visionEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversionError.visionRequestFailed(status: -1, body: "No HTTP response")
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<unreadable body>"
            throw ConversionError.visionRequestFailed(status: httpResponse.statusCode, body: body)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            let body = String(data: data, encoding: .utf8) ?? "<unreadable body>"
            throw ConversionError.visionRequestFailed(status: httpResponse.statusCode, body: "Unexpected response shape: \(body)")
        }

        return content
    }
}
