//
//  DateUtils.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/5/25.
//

import Foundation

extension NumberFormatter {
    static let tokenCount: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal // Adds grouping separators
        return formatter
    }()
}

class DateUtils {
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, yyyy"
        return formatter.string(from: date)
    }
    
    /// Given a date, returns a time difference like:
    /// 1 day ago
    /// 8 days ago
    /// 1 month ago
    static func daySince(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
