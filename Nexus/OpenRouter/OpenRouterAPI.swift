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
    var selectedModel: Models = DefaultsManager.shared.getModel()
    
    func stream(isWebSearch: Bool = false) async throws {
        var request = URLRequest(url: completionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messageDicts = chat.map { $0.asDictionary() }
        var payload: [String: Any] = [:]
        print(messageDicts)
        if isWebSearch {
            payload = [
                "model": selectedModel.rawValue,
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
                "model": selectedModel.rawValue,
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
        
        // Append the assistant message ONCE before streaming
        await MainActor.run {
            chat.append(Message(role: .assistant, content: ""))
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
                                if !chat.isEmpty {
                                    chat[chat.count - 1].content += content
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
    
}
