//
//  TextFileTool.swift
//  Nexus
//
//  Created by Codex on 08/31/25.
//

import Foundation

struct TextFileTool: Tool {
    let name: String = "create_text_file"
    let description: String = "Create a text file (e.g., .txt, .md, .swift, .c, .cpp, .json, etc.), upload it, and return a downloadable link along with a preview."
    let type = ToolType.fileTool

    // JSON schema for function parameters
    var parameters: [String: Any] {
        [
            "type": "object",
            "properties": [
                "fileName": [
                    "type": "string",
                    "description": "File name including extension (e.g., notes.txt, Main.swift, program.c)."
                ],
                "content": [
                    "type": "string",
                    "description": "UTF-8 text content for the file."
                ]
            ],
            "required": ["fileName", "content"],
            "additionalProperties": false
        ]
    }

    private struct Args: Decodable {
        let fileName: String
        let content: String
    }

    func execute(arguments: String, others: String?) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(Args.self, from: data) else {
            return "{\"error\":\"create_text_file: Invalid or missing arguments. Provide JSON with fileName and content.\"}"
        }

        let trimmedName = args.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = args.content

        if trimmedName.isEmpty {
            return "{\"error\":\"create_text_file: 'fileName' cannot be empty.\"}"
        }
        if trimmedContent.isEmpty {
            return "{\"error\":\"create_text_file: 'content' cannot be empty.\"}"
        }

        // Basic filename sanitization: remove path separators and control characters
        let safeName = sanitizeFilename(trimmedName)

        // Namespace the file path using the current chat id when available to avoid collisions
        let namespacedPath: String = await {
            if let chatId = await SupabaseManager.shared.currentChat?.id.uuidString.lowercased() {
                return "\(chatId)/\(safeName)"
            }
            return safeName
        }()

        // Upload file to Supabase Storage
        await SupabaseManager.shared.uploadFileToBucket(trimmedContent, fileName: namespacedPath)
        let publicURL = await SupabaseManager.shared.retrieveFileURLFrom(namespacedPath)

        // Build a Markdown response including a download link and a preview code block
        let language = languageHint(for: safeName)
        let header = "✅ File created: \(safeName)"
        let linkLine = publicURL.isEmpty ? "" : "\n🔗 Download: [\(safeName)](\(publicURL))"
        let preview = "\n\n```\(language)\n\(trimmedContent)\n```"
        return header + linkLine + preview
    }

    // MARK: - Helpers
    private func sanitizeFilename(_ name: String) -> String {
        var result = name
        let forbidden: CharacterSet = {
            var set = CharacterSet(charactersIn: "/\\:\"|?*\n\r\t\0")
            set.formUnion(.illegalCharacters)
            set.formUnion(.controlCharacters)
            return set
        }()
        result.unicodeScalars.removeAll { forbidden.contains($0) }
        // Avoid leading/trailing spaces and dots which can cause issues
        result = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        if result.isEmpty { result = "file.txt" }
        // Ensure it remains a text-like name; if no extension, default to .txt
        if !result.contains(".") { result += ".txt" }
        return result
    }

    private func languageHint(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "c": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "h": return "c"
        case "m": return "objectivec"
        case "mm": return "objectivecpp"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "py": return "python"
        case "js", "mjs", "cjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "jsx": return "jsx"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "php": return "php"
        case "sh", "bash", "zsh": return "bash"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "md", "markdown": return "markdown"
        case "txt": return ""
        default: return ""
        }
    }
}

