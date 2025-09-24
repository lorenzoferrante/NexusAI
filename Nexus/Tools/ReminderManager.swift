//
//  ReminderManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 9/24/25.
//

import Foundation
import EventKit

@MainActor
final class ReminderManager {
    static let shared = ReminderManager()
    
    private let eventStore = EKEventStore()
    
    private init() {}
    
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                return granted
            } catch {
                print("Reminder access error: \(error)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        print("Reminder access error: \(error)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func createReminder(
        title: String,
        dueDate: Date?,
        notes: String?
    ) -> (success: Bool, identifier: String?, message: String?) {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        
        guard let calendar = eventStore.defaultCalendarForNewReminders() ?? eventStore.calendars(for: .reminder).first else {
            return (false, nil, "No reminders calendar is configured. Open the Reminders app to create one.")
        }
        reminder.calendar = calendar
        
        if let dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
            reminder.startDateComponents = components
            let alarm = EKAlarm(absoluteDate: dueDate)
            reminder.addAlarm(alarm)
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            return (true, reminder.calendarItemIdentifier, nil)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }
    
    func fetchReminders(
        withinDays days: Int?,
        includeCompleted: Bool,
        matchingTitle titleFilter: String?
    ) async -> [ReminderSummary] {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        let upperBoundDate: Date? = {
            guard let days else { return nil }
            return Calendar.current.date(byAdding: .day, value: days, to: Date())
        }()
        
        let filtered = reminders.filter { reminder in
            if !includeCompleted && reminder.isCompleted { return false }
            if let titleFilter, !titleFilter.isEmpty {
                let matches = reminder.title?.localizedCaseInsensitiveContains(titleFilter) ?? false
                if !matches { return false }
            }
            
            guard let bound = upperBoundDate else { return true }
            guard let dueComponents = reminder.dueDateComponents,
                  let reminderDate = Calendar.current.date(from: dueComponents) else {
                return false
            }
            return reminderDate <= bound
        }
        
        return filtered
            .map { ReminderSummary(reminder: $0) }
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (lhsDate?, rhsDate?):
                    if lhsDate == rhsDate {
                        return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                    }
                    return lhsDate < rhsDate
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                }
            }
    }
    
    func deleteReminder(with identifier: String) -> (success: Bool, message: String?) {
        guard let item = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return (false, "Reminder not found.")
        }
        
        do {
            try eventStore.remove(item, commit: true)
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

struct ReminderSummary: Codable {
    let identifier: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
    let notes: String?
    
    init(reminder: EKReminder) {
        identifier = reminder.calendarItemIdentifier
        title = reminder.title ?? "(No Title)"
        notes = reminder.notes
        isCompleted = reminder.isCompleted
        if let components = reminder.dueDateComponents {
            dueDate = Calendar.current.date(from: components)
        } else {
            dueDate = nil
        }
    }
}

extension ReminderSummary {
    func formattedDescription(dateFormatter: DateFormatter) -> String {
        var lines: [String] = []
        lines.append("• " + title)
        if let dueDate {
            lines.append("   Due: " + dateFormatter.string(from: dueDate))
        }
        if isCompleted {
            lines.append("   Status: Completed")
        }
        if let notes, !notes.isEmpty {
            lines.append("   Notes: " + notes)
        }
        lines.append("   ID: " + identifier)
        return lines.joined(separator: "\n")
    }
}
