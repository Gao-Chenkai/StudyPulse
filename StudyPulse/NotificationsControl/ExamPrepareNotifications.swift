//
//  ExamPrepareNotifications.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/4.
//

import Foundation
@preconcurrency import UserNotifications

class ExamPrepareNotifications {
    static let shared = ExamPrepareNotifications()
    
    private init() {}
    
    // 1. 请求权限（建议在 App 启动时调用一次）
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ 通知权限请求失败: \(error.localizedDescription)")
            } else {
                print("✅ 通知权限状态: \(granted ? "已允许" : "已拒绝")")
            }
        }
    }
    
    // 2. 添加考试倒计时通知
    // 参数: examName - 考试名称, examDate - 考试日期
    func scheduleNotifications(for examName: String, date: Date) {
        let center = UNUserNotificationCenter.current()
        
        // 定义需要提醒的天数
        let daysToNotify = [1, 3, 5, 10, 30]
        
        for day in daysToNotify {
            // 计算触发通知的具体时间 = 考试日期 - N天
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -day, to: date) else { continue }
            
            // 如果计算出的时间已经过去（例如考试就在明天，那么“30天前”的通知就不需要了），直接跳过
            if triggerDate < Date() { continue }
            
            // 配置通知内容
            let content = UNMutableNotificationContent()
            content.title = "📅 考试倒计时"
            content.body = "距离 **\(examName)** 还有 **\(day)** 天，请做好准备！"
            content.sound = .default
            
            // 配置触发器
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                repeats: false
            )
            
            // 生成唯一标识符 (格式: Exam_名字_天数)
            // 这样方便以后通过名字查找并删除特定的通知
            let identifier = "Exam_\(examName)_\(day)Days"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // 添加到系统
            center.add(request) { error in
                if let error = error {
                    print("❌ 添加通知失败 (\(day)天前): \(error.localizedDescription)")
                } else {
                    print("✅ 成功安排通知: \(day)天前 (\(triggerDate))")
                }
            }
        }
    }
    
    // 3. (可选) 取消特定考试的所有通知
    // 比如用户删除了考试，或者修改了考试时间，可以先调用这个清除旧的
    func cancelNotifications(for examName: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            // 找出所有包含该考试名称的通知 ID
            let toRemove = requests.filter { $0.identifier.contains(examName) }
            let ids = toRemove.map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                print("✅ 已取消 \(examName) 的 \(ids.count) 个待办通知")
            }
        }
    }
}
