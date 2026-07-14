//
//  BulkOperationOrchestrator.swift
//  StudyPulse
//
//  批量清空:从设置页"清空数据"面板触发,按类别调用对应 repo 的
//  `clearAll()`,并返回 (category, deleted count) 列表。
//
//  设计:持有 7 个 repo 的引用,做一次性的多 repo 协同删除;
//  与 RepositoryContainer 解耦(只依赖 repo 协议),便于单测和未来替换。
//
//  从原 `RepositoryContainer.bulkClearData` 拆出 (Phase 3, 2026-07-14)。
//

import Foundation
import os

/// 批量清空选项(用于设置页"清空数据"面板)
/// Bulk-clear option (used in Settings → "Clear Data" panel).
enum BulkClearCategory: String, CaseIterable, Identifiable, Hashable {
    case grades
    case mistakes
    case exams
    case tasks
    case profileReset
    case routines

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grades:       return "成绩"
        case .mistakes:     return "错题"
        case .exams:        return "考试"
        case .tasks:        return "待办"
        case .profileReset: return "重置个人资料"
        case .routines:     return "例程"
        }
    }

    var systemImage: String {
        switch self {
        case .grades:       return "chart.bar.fill"
        case .mistakes:     return "book.fill"
        case .exams:        return "calendar"
        case .tasks:        return "checklist"
        case .profileReset: return "person.crop.circle.badge.exclamationmark"
        case .routines:     return "repeat.circle.fill"
        }
    }
}

/// 批量清空编排器
/// Bulk-clear orchestrator.
///
/// - 7 个 repo 协同删除(例程 + 关联 instance 一起清,profile reset 同时删头像)
/// - `RepositoryContainer` 通过 `bulkOps` 字段持有实例,保持调用方式不变
@MainActor
final class BulkOperationOrchestrator {
    private let gradeRepo: any GradeRepository
    private let mistakeRepo: any MistakeRepository
    private let examRepo: any ExamRepository
    private let taskRepo: any TaskRepository
    private let routineRepo: any RoutineRepository
    private let routineInstanceRepo: any RoutineInstanceRepository
    private let profileRepo: any ProfileRepository

    init(
        gradeRepo: any GradeRepository,
        mistakeRepo: any MistakeRepository,
        examRepo: any ExamRepository,
        taskRepo: any TaskRepository,
        routineRepo: any RoutineRepository,
        routineInstanceRepo: any RoutineInstanceRepository,
        profileRepo: any ProfileRepository
    ) {
        self.gradeRepo = gradeRepo
        self.mistakeRepo = mistakeRepo
        self.examRepo = examRepo
        self.taskRepo = taskRepo
        self.routineRepo = routineRepo
        self.routineInstanceRepo = routineInstanceRepo
        self.profileRepo = profileRepo
    }

    /// 批量清空数据(category → 删除条数)
    /// Bulk-clear data. Returns `(category, deleted count)` pairs.
    @discardableResult
    func clear(categories: Set<BulkClearCategory>) -> [(category: BulkClearCategory, count: Int)] {
        var results: [(BulkClearCategory, Int)] = []
        for cat in categories {
            let count: Int
            switch cat {
            case .grades:       count = gradeRepo.clearAll()
            case .mistakes:     count = mistakeRepo.clearAll()
            case .exams:        count = examRepo.clearAll()
            case .tasks:        count = taskRepo.clearAll()
            case .routines:
                // 例程 + 关联 instance 一起清
                let instCount = routineInstanceRepo.allInstances.count
                for inst in routineInstanceRepo.allInstances {
                    routineInstanceRepo.delete(inst.id)
                }
                let routineCount = routineRepo.clearAll()
                count = routineCount + instCount
            case .profileReset:
                // 重置 profile 到默认 + 删头像
                if let filename = profileRepo.profile.avatarFileName {
                    profileRepo.deleteAvatar(filename: filename)
                }
                profileRepo.profile = UserProfile()
                profileRepo.saveProfile()
                count = 1
            }
            results.append((cat, count))
        }
        Log.data.info("BulkOperationOrchestrator clear: \(results.map { "\($0.0)=\($0.1)" }.joined(separator: ","), privacy: .public)")
        return results
    }
}
