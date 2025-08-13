//
//  CalendarTool.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/13/25.
//

import Foundation

struct CalendarTool: Tool {
    let name = "manage_calendar"
    let description = "Create, edit, or delete calendar events. Can add events with title, date/time, duration, location, and notes."
    let type = ToolType.genericTool
    
    var parameters: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "Title of the event"
                ],
                "startDate": [
                    "type": "string",
                    "description": "Start date and time in format yyyy-MM-dd'T'HH:mm"
                ],
                "endDate": [
                    "type": "string",
                    "description": "End date and time in format yyyy-MM-dd'T'HH:mm"
                ],
                "location": [
                    "type": "string",
                    "description": "Location of the event"
                ],
                "notes": [
                    "type": "string",
                    "description": "Additional notes or description for the event"
                ],
                "allDay": [
                    "type": "boolean",
                    "description": "Whether this is an all-day event"
                ],
                "eventId": [
                    "type": "string",
                    "description": "Event identifier for edit/delete operations"
                ],
                "reminder": [
                    "type": "integer",
                    "description": "Minutes before the event to set a reminder (e.g., 15, 30, 60)"
                ]
            ],
            "required": ["title", "startDate"]
        ]
    }
    
    struct Args: Decodable {
        let title: String?
        let startDate: String?
        let endDate: String?
        let location: String?
        let notes: String?
        let allDay: Bool?
        let eventId: String?
        let reminder: Int?
    }
    
    func execute(arguments: String, others: String?) async throws -> String {
        
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(Args.self, from: data) else {
            return "Error: Invalid arguments provided for calendar operation"
        }
        
        // Get calendar manager instance
        let calendarManager = await CalendarManager.shared
        
        // Request permission if needed
        let hasAccess = await calendarManager.requestAccess()
        guard hasAccess else {
            return "Error: Calendar access denied. Please enable calendar permissions in Settings."
        }
        
        // Handle different actions
        return try await createEvent(args: args)
    }
    
    private func createEvent(args: Args) async throws -> String {
        guard let title = args.title else {
            return "Error: Event title is required for creating an event"
        }
        
        guard let startDateStr = args.startDate else {
            return "Error: Start date is required for creating an event"
        }
        
        // Parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let startDate = dateFormatter.date(from: startDateStr) else {
            return "Error: Invalid start date format. Use this format: yyyy-MM-dd'T'HH:mm"
        }
        
        let endDate: Date
        if let endDateStr = args.endDate {
            guard let parsedEndDate = dateFormatter.date(from: endDateStr) else {
                return "Error: Invalid end date format. Use this format: yyyy-MM-dd'T'HH:mm"
            }
            endDate = parsedEndDate
        } else {
            // Default to 1 hour duration if no end date specified
            endDate = startDate.addingTimeInterval(3600)
        }
        
        // Create the event
        let result = try await CalendarManager.shared.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: args.location,
            notes: args.notes,
            isAllDay: args.allDay ?? false,
            reminderMinutes: args.reminder
        )
        
        if result.success {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            var response = "✅ Event created successfully!\n"
            response += "📅 **\(title)**\n"
            response += "🕐 \(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))\n"
            
            if let location = args.location {
                response += "📍 Location: \(location)\n"
            }
            
            if let notes = args.notes {
                response += "📝 Notes: \(notes)\n"
            }
            
            if let reminder = args.reminder {
                response += "⏰ Reminder: \(reminder) minutes before\n"
            }
            
            if let eventId = result.eventId {
                response += "🔖 Event ID: \(eventId)"
            }
            
            return response
        } else {
            return "Error: Failed to create event - \(result.message ?? "Unknown error")"
        }
    }

}
