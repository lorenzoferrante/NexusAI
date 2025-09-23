//
//  ImageGenTool.swift
//  Nexus
//
//  Created by Codex on 09/23/25.
//

import Foundation

/// A tool that generates images via OpenRouter using Google Gemini 2.5 Flash Image Preview.
/// - The LLM calls this tool when the user asks to create/edit an image.
/// - It sends the user's prompt (and, if present, an attached image URL) to the image model.
/// - Returns a JSON string containing `content` (assistant text) and `images` (array of base64 data URLs).
struct ImageGenTool: Tool {
    let name: String = "generate_image"
    let description: String = "Generate or edit an image using the user's prompt. Optionally uses an attached image as input. Returns a single base64 image."
    let type: ToolType = .imageTool

    // JSON schema advertised to the model
    var parameters: [String: Any] {
        [
            "type": "object",
            "properties": [
                "prompt": [
                    "type": "string",
                    "description": "Text prompt describing the image to generate or edit."
                ]
            ],
            "required": ["prompt"],
            "additionalProperties": false
        ]
    }

    private struct Args: Decodable {
        let prompt: String
    }

    /// `others` may contain a JSON object like: { "image_urls": ["https://...", "data:image/png;base64,..."] }
    struct OthersEnvelope: Decodable {
        let image_urls: [String]?
    }

    func execute(arguments: String, others: String?) async throws -> String {
        // 1) Decode primary arguments
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(Args.self, from: data) else {
            return "{\"error\":\"generate_image: Invalid or missing arguments. Provide JSON with at least 'prompt'.\"}"
        }

        // 2) Decode optional input images from `others`
        var inputImageURLs: [String] = []
        if let others, let odata = others.data(using: .utf8) {
            if let env = try? JSONDecoder().decode(OthersEnvelope.self, from: odata),
               let urls = env.image_urls {
                inputImageURLs = urls
            } else {
                // Fallback: accept a raw string or pipe-separated URLs
                let raw = others.trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.hasPrefix("[") || raw.hasPrefix("{") {
                    // try decode as [String]
                    if let arr = try? JSONDecoder().decode([String].self, from: odata) { inputImageURLs = arr }
                } else if !raw.isEmpty {
                    inputImageURLs = raw.split(separator: "|").map { String($0) }
                }
            }
        }

        // 3) Build OpenRouter request
        let apiKey = try await SupabaseManager.shared.ensureOpenRouterKey()
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Compose message content: prompt text + optional input image(s)
        var contentItems: [[String: Any]] = [[
            "type": "text",
            "text": args.prompt
        ]]
        for u in inputImageURLs where !u.isEmpty {
            contentItems.append([
                "type": "image_url",
                "image_url": ["url": u]
            ])
        }

        let payload: [String: Any] = [
            "model": "google/gemini-2.5-flash-image-preview",
            "messages": [[
                "role": "user",
                "content": contentItems
            ]],
            // Request both text and image output modalities as per OpenRouter docs
            "modalities": ["image", "text"],
            "stream": false
        ]

        // 4) Execute
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (respData, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: respData, encoding: .utf8) ?? ""
            return "{\"error\":\"generate_image: HTTP error. Body: \(snippet.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        }

        // 5) Parse response
        struct ChoiceMessage: Decodable {
            let role: String?
            let content: String?
            let images: [ImageStruct]?
        }
        struct Choice: Decodable { let message: ChoiceMessage }
        struct CompletionResponse: Decodable { let choices: [Choice] }

        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: respData)
        let message = decoded.choices.first?.message
        let text = (message?.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let images = message?.images ?? []

        // 6) Return a compact JSON string with text + base64 image for the caller to display
        // Enforce single-image result: only keep the first image if present.
        let base64s: [String] = images.first.map { [$0.imageURL.url] } ?? []
        let resultDict: [String: Any] = [
            "content": text.isEmpty ? "" : text,
            "images": base64s
        ]
        let resultData = try JSONSerialization.data(withJSONObject: resultDict)
        return String(data: resultData, encoding: .utf8) ?? "{}"
    }

    private func buildPromptText(args: Args) -> String { args.prompt }
}
