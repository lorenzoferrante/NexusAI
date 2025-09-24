//
//  ReminderTool.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 9/24/25.
//

import Foundation

struct ReminderTool: Tool {
    let name = "manage_reminders"
    let description = "View, create, or delete reminders. Supports listing reminders, creating new reminders with optional due dates, and deleting by identifier."
    let type = ToolType.reminderTool
    
    var parameters: [String: Any] {
        [
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "description": "The reminder action to perform",
                    "enum": ["list", "create", "delete"]
                ],
                "title": [
                    "type": "string",
                    "description": "Title for the reminder (required for create) or filter when listing"
                ],
                "dueDate": [
                    "type": "string",
                    "description": "Due date and time in format yyyy-MM-dd'T'HH:mm"
                ],
                "notes": [
                    "type": "string",
                    "description": "Optional notes for the reminder"
                ],
                "identifier": [
                    "type": "string",
                    "description": "Reminder identifier for delete operations"
                ],
                "rangeInDays": [
                    "type": "integer",
                    "description": "When listing, include reminders due within this many days from today"
                ],
                "includeCompleted": [
                    "type": "boolean",
                    "description": "Whether to include completed reminders when listing"
                ]
            ],
            "required": ["action"]
        ]
    }
    
    private enum Action: String, Decodable {
        case list
        case create
        case delete
    }
    
    private struct Args: Decodable {
        let action: Action
        let title: String?
        let dueDate: String?
        let notes: String?
        let identifier: String?
        let rangeInDays: Int?
        let includeCompleted: Bool?
    }
    
    func execute(arguments: String, others: String?) async throws -> String {
        guard let data = arguments.data(using: .utf8) else {
            return "Error: Failed to read reminder arguments."
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let args = try? decoder.decode(Args.self, from: data) else {
            return "Error: Invalid reminder arguments provided."
        }
        
        let manager = await ReminderManager.shared
        let hasAccess = await manager.requestAccess()
        guard hasAccess else {
            return "Error: Reminders access denied. Please enable reminders permissions in Settings."
        }
        
        switch args.action {
        case .create:
            return await MainActor.run {
                createReminder(args: args, manager: manager)
            }
        case .list:
            return await listReminders(args: args, manager: manager)
        case .delete:
            return await MainActor.run {
                deleteReminder(args: args, manager: manager)
            }
        }
    }
    
    @MainActor private func createReminder(args: Args, manager: ReminderManager) -> String {
        guard let title = args.title, !title.isEmpty else {
            return "Error: Reminder title is required to create a reminder."
        }
        
        let dueDate: Date?
        if let dueDateString = args.dueDate {
            let formatter = Self.dateFormatter
            guard let parsed = formatter.date(from: dueDateString) else {
                return "Error: Invalid due date format. Use yyyy-MM-dd'T'HH:mm."
            }
            dueDate = parsed
        } else {
            dueDate = nil
        }
        
        let result = manager.createReminder(
            title: title,
            dueDate: dueDate,
            notes: args.notes
        )
        
        if result.success {
            var response = "✅ Reminder created successfully!\n"
            response += "📝 Title: \(title)\n"
            if let dueDate {
                response += "📅 Due: \(Self.humanDateFormatter.string(from: dueDate))\n"
            }
            if let notes = args.notes, !notes.isEmpty {
                response += "💬 Notes: \(notes)\n"
            }
            if let identifier = result.identifier {
                response += "🆔 ID: \(identifier)"
            }
            return response
        } else {
            return "Error: Failed to save reminder - \(result.message ?? "Unknown error")."
        }
    }
    
    private func listReminders(args: Args, manager: ReminderManager) async -> String {
        let summaries = await manager.fetchReminders(
            withinDays: args.rangeInDays ?? 30,
            includeCompleted: args.includeCompleted ?? false,
            matchingTitle: args.title
        )
        
        guard !summaries.isEmpty else {
            return "ℹ️ No reminders found for the requested criteria."
        }
        
        let formatter = Self.humanDateFormatter
        let formatted = summaries.map { $0.formattedDescription(dateFormatter: formatter) }
        return (["🗒️ Reminders:"] + formatted).joined(separator: "\n")
    }
    
    @MainActor private func deleteReminder(args: Args, manager: ReminderManager) -> String {
        guard let identifier = args.identifier, !identifier.isEmpty else {
            return "Error: Reminder identifier is required to delete a reminder."
        }

        let result = manager.deleteReminder(with: identifier)
        if result.success {
            return "🗑️ Reminder deleted successfully."
        } else {
            return "Error: Could not delete reminder - \(result.message ?? "Unknown error")."
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private static let humanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
