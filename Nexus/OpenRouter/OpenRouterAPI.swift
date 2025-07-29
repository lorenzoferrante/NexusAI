//
//  OpenRouterAPI.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
import SwiftUI

@Observable
@MainActor
class OpenRouterAPI {
    
    static let shared = OpenRouterAPI()
    
    private let API_KEY = "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"
    private let completionsURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    var output: String = ""
    var chat: [Message] = []
    var selectedModel: Models = DefaultsManager.shared.getModel()
    
    func stream(isWebSearch: Bool = false) async throws {
        var request = URLRequest(url: completionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messageDicts = chat.map { $0.asDictionary() }
        print(messageDicts)
        let payload: [String: Any] = [
            "model": selectedModel.rawValue,
            "messages": messageDicts,
            "plugins": [
                isWebSearch ? ["id": "web"] : nil
            ],
            "stream": true
        ]
        
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
    
}
