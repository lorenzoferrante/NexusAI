//
//  OpenRouterAPI.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
import SwiftUI
import PhotosUI

@Observable
@MainActor
class OpenRouterAPI {
    
    static let shared = OpenRouterAPI()
    
    private let API_KEY = "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"
    private let completionsURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    var selectedFileURL: URL?
    var selectedImage: UIImage? = nil
    var photoPickerItems: PhotosPickerItem? = nil {
        didSet {
            Task {
                await loadImage()
            }
        }
    }
    var output: String = ""
    var chat: [Message] = []
    var selectedModel: OpenRouterModel = DefaultsManager.shared.getModel()
    
    func stream(isWebSearch: Bool = false) async throws {
        // Append the assistant message ONCE before streaming
        let newAssistantMessage: Message = .init(
            chatId: SupabaseManager.shared.currentChat!.id,
            role: .assistant,
            content: "",
            createdAt: Date()
        )
        try await SupabaseManager.shared.addMessageToChat(newAssistantMessage)        
        
        var request = URLRequest(url: completionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messageDicts = SupabaseManager.shared.currentMessages.map { $0.asDictionary() }
        var payload: [String: Any] = [:]
        print(messageDicts)
        if isWebSearch {
            payload = [
                "model": selectedModel.code,
                "messages": messageDicts,
                "plugins": [["id": "web"]],
                "stream": true,
                "reasoning": [
                    "effort": "medium",
                    "enabled": true,
                    "exclude": true,
                ]
            ]
        } else {
            payload = [
                "model": selectedModel.code,
                "messages": messageDicts,
                "stream": true,
                "reasoning": [
                    "effort": "medium",
                    "enabled": true,
                    "exclude": true,
                ]
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        print(String(data: try! JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted), encoding: .utf8)!)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[DEBUG] Error: invalid response")
            return
        }
        
        if httpResponse.statusCode != 200 {
            print("[DEBUG] Error: invalid code (\(httpResponse.statusCode))")
            // Optional: print body for debugging
            var debugData = Data()
            for try await byte in bytes {
                debugData.append(byte)
            }
            if let body = String(data: debugData, encoding: .utf8) {
                print("[DEBUG] Body: \(body)")
            }
            return
        }
        
        var buffer = Data()
        for try await byte in bytes {
            buffer.append(byte)
            
            while let range = buffer.range(of: Data([0x0A])) { // 0x0A = \n
                let lineData = buffer.prefix(upTo: range.lowerBound)
                buffer.removeSubrange(..<range.upperBound)
                
                guard let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      line.hasPrefix("data: ") else {
                    continue
                }
                
                let dataString = String(line.dropFirst("data: ".count))
                if dataString == "[DONE]" {
                    return
                }
                
                if let data = dataString.data(using: .utf8) {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            
                            // Append to last assistant message
                            await MainActor.run {
                                if !SupabaseManager.shared.currentMessages.isEmpty {
                                    let lastIndex = SupabaseManager.shared.currentMessages.lastIndex(where: {$0.role == .assistant})!
                                    SupabaseManager.shared.currentMessages[lastIndex].content += content
                                }
                            }
                            fflush(stdout)
                        }

                    } catch {
                        print("[DEBUG] Parsing error...")
                    }
                }
            }
        }
    }
    
    private func loadImage() async {
        guard let item = photoPickerItems else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            await MainActor.run {
                self.selectedImage = uiImage
            }
        }
    }
    
    public func base64FromSwiftUIImage() -> String? {
        guard let image = selectedImage else {
            return nil
        }
        guard let imageData = image.pngData() else { return nil }
        return "data:image/jpeg;base64,\(imageData.base64EncodedString())"
    }
    
    public func fileContent() -> String? {
        guard let fileURL = selectedFileURL else {
            return nil
        }
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    public func base64FromFileURL() -> String? {
        guard let fileURL = selectedFileURL else {
            return nil
        }
        
        let fileExtension = fileURL.pathExtension
        let dataURI = dataURIPrefix(for: fileExtension)
        
        do {
            let encodedFile = try Data(contentsOf: fileURL).base64EncodedString()
            return "\(dataURI)\(encodedFile)"
        } catch {
            print("[DEBUG] Error encoding file: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func dataURIPrefix(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf":
            return "data:application/pdf;base64,"
        case "txt":
            return "data:text/plain;base64,"
        case "csv":
            return "data:text/csv;base64,"
        case "json":
            return "data:application/json;base64,"
        case "xml":
            return "data:application/xml;base64,"
        case "html", "htm":
            return "data:text/html;base64,"
        case "md":
            return "data:text/markdown;base64,"
        case "rtf":
            return "data:application/rtf;base64,"
        case "yaml", "yml":
            return "data:text/yaml;base64,"
        default:
            return "data:application/octet-stream;base64,"
        }
    }
    
    public func generateChatTitle(from query: String) async throws -> String? {
        let url = URL(string: "https://openrouter.ai/api/v1/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Use the selected model's code, or fallback to a default string if needed
        let prompt = """
            Given the user prompt, generate a short, concise yet effective title for a chat. \
            RESPOND ONLY WITH THE TITLE. \
            QUERY: \(query.trimmingCharacters(in: .whitespacesAndNewlines))
            """
        let modelCode = "google/gemini-2.5-flash-lite"
        let payload: [String: Any] = [
            "model": modelCode,
            "prompt": prompt
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[DEBUG - generateChatTitle()] Failed to generate chat title: Invalid response")
            return nil
        }
        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        debugPrint("[DEBUG - generateChatTitle()] Title: \(decoded)")
        return decoded.choices.first?.text
    }
    
}
