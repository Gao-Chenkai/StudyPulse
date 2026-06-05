//
//  CalendarManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation
import EventKit

/// 日历事件管理器 - 处理考试事件的创建和管理
class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    
    /// 请求日历访问权限
    func requestAccess() async throws -> Bool {
        try await eventStore.requestWriteOnlyAccessToEvents()
    }
    
    /// 将考试添加到系统日历
    /// - Parameters:
    ///   - examName: 考试名称
    ///   - subject: 科目名称
    ///   - examDate: 考试日期
    ///   - note: 备注（可选）
    /// - Returns: 是否添加成功
    func addExamToCalendar(
        examName: String,
        subject: String,
        examDate: Date,
        note: String? = nil
    ) async throws -> Bool {
        // 请求权限
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }
        
        // 创建事件
        let event = EKEvent(eventStore: eventStore)
        event.title = "考试: \(examName)"
        event.notes = note ?? "科目: \(subject)\n来自 StudyPulse"
        event.startDate = examDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: examDate) ?? examDate
        event.isAllDay = true
        
        // 设置提醒
        let alarm = EKAlarm(relativeOffset: -86400) // 提前一天提醒
        event.alarms = [alarm]
        
        // 获取默认日历
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // 保存事件
        try eventStore.save(event, span: .thisEvent)
        return true
    }
    
    /// 移除之前添加的考试事件
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

/// 日历错误类型
enum CalendarError: LocalizedError {
    case accessDenied
    case saveFailed
    case eventNotFound
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "StudyPulse 没有日历访问权限，请在设置中开启"
        case .saveFailed:
            return "保存日历事件失败"
        case .eventNotFound:
            return "未找到对应的日历事件"
        }
    }
}
