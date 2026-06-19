//
//  CalendarManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation
import EventKit

// MARK: - Calendar Manager (日历管理器)

/// 日历事件管理器 - 处理考试事件的创建和管理
/// 使用 EventKit 框架将考试添加到系统日历
class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    
    /// Request calendar access
    /// - Returns: Whether the user granted access
    func requestAccess() async throws -> Bool {
        try await eventStore.requestWriteOnlyAccessToEvents()
    }
    
    /// Add an exam to the system calendar
    /// - Parameters:
    ///   - examName: Exam name
    ///   - subject: Subject name
    ///   - examDate: Exam date
    ///   - note: Additional notes (optional)
    /// - Returns: Whether the event was added successfully
    func addExamToCalendar(
        examName: String,
        subject: String,
        examDate: Date,
        note: String? = nil
    ) async throws -> Bool {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "Exam: \(examName)"
        event.notes = note ?? "Subject: \(subject)\nFrom StudyPulse"
        event.startDate = examDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: examDate) ?? examDate
        event.isAllDay = true
        
        let alarm = EKAlarm(relativeOffset: -86400)
        event.alarms = [alarm]
        
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        try eventStore.save(event, span: .thisEvent)
        return true
    }
    
    /// Remove a previously added exam event
    /// - Parameter eventIdentifier: Event unique identifier
    /// - Returns: Whether the event was removed successfully
    func removeExamFromCalendar(eventIdentifier: String) async throws -> Bool {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }
        
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            return false
        }
        
        try eventStore.remove(event, span: .thisEvent)
        return true
    }
}

enum CalendarError: LocalizedError {
    case accessDenied
    case saveFailed
    case eventNotFound
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return NSLocalizedString("StudyPulse does not have calendar access. Please enable it in Settings.", comment: "Calendar error: no permission")
        case .saveFailed:
            return NSLocalizedString("Failed to save calendar event.", comment: "Calendar error: save failed")
        case .eventNotFound:
            return NSLocalizedString("Calendar event not found.", comment: "Calendar error: event not found")
        }
    }
}
