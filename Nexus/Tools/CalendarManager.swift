//
//  CalendarManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/13/25.
//

import Foundation
import EventKit

// MARK: - Calendar Manager Helper Class
@MainActor
class CalendarManager {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestWriteOnlyAccessToEvents()
                return granted
            } catch {
                print("Calendar access error: \(error)")
                return false
            }
        } else {
            // iOS 16 and earlier
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        print("Calendar access error: \(error)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        isAllDay: Bool = false,
        reminderMinutes: Int? = nil
    ) throws -> (success: Bool, eventId: String?, message: String?) {
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        if let location = location {
            event.location = location
        }
        
        if let notes = notes {
            event.notes = notes
        }
        
        // Add reminder if specified
        if let reminderMinutes = reminderMinutes {
            let alarm = EKAlarm(relativeOffset: TimeInterval(-reminderMinutes * 60))
            event.addAlarm(alarm)
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return (true, event.eventIdentifier, nil)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

}
