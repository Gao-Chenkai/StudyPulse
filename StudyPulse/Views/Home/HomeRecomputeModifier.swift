//
//  HomeRecomputeModifier.swift
//  StudyPulse
//
//  把 HomeView 的多个 onChange / onAppear 重算触发器抽出来,避免主 body
//  的 View 表达式过长导致 Swift 编译器超时。
//  Extract the multiple onChange / onAppear recompute triggers from HomeView to avoid the main body
//  expression becoming too long, which would cause the Swift compiler to time out.
//
//  Created for Plans & Routines spec (2026-07-09).
//

import SwiftUI

/// 把单一的 recompute 触发器挂到 content 上(每个 modifier 只加一个 onChange,
/// 避免 SwiftUI body 表达式嵌套过深导致类型检查器超时)。
/// Attach a single recompute trigger to `content` (each modifier adds only one onChange,
/// avoiding the SwiftUI body expression nesting too deep and timing out the type checker).
struct RecomputeOnAppearModifier: ViewModifier {
    let viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content.onAppear { viewModel.recompute() }
    }
}

/// 成绩集合变化时触发 `HomeViewModel` 重算。
/// Trigger `HomeViewModel` recompute when the grade collection changes.
struct RecomputeOnGradesChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let grades: [Grade]

    func body(content: Content) -> some View {
        content.onChange(of: grades) { _, _ in viewModel.recompute() }
    }
}

/// 考试集合变化时触发 `HomeViewModel` 重算。
/// Trigger `HomeViewModel` recompute when the exam collection changes.
struct RecomputeOnExamsChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let examSets: [Exam]

    func body(content: Content) -> some View {
        content.onChange(of: examSets) { _, _ in viewModel.recompute() }
    }
}

/// 错题集变化时触发 `HomeViewModel` 重算。
/// Trigger `HomeViewModel` recompute when the mistake-note collection changes.
struct RecomputeOnMistakesChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let mistakeSets: [MistakeNote]

    func body(content: Content) -> some View {
        content.onChange(of: mistakeSets) { _, _ in viewModel.recompute() }
    }
}

/// 任务集合变化时触发 `HomeViewModel` 重算。
/// Trigger `HomeViewModel` recompute when the task collection changes.
struct RecomputeOnTasksChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let taskItems: [TaskItem]

    func body(content: Content) -> some View {
        content.onChange(of: taskItems) { _, _ in viewModel.recompute() }
    }
}

/// 日常计划(Routine)定义变化时触发重算。
/// Trigger recompute when the routine definitions change.
struct RecomputeOnRoutinesChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let routines: [Routine]

    func body(content: Content) -> some View {
        content.onChange(of: routines) { _, _ in viewModel.recompute() }
    }
}

/// 日常计划实例(完成/跳过)变化时触发重算。
/// Trigger recompute when routine instances (done/skipped) change.
struct RecomputeOnRoutineInstancesChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let instances: [RoutineInstance]

    func body(content: Content) -> some View {
        content.onChange(of: instances) { _, _ in viewModel.recompute() }
    }
}

/// HRV 健康读数变化时触发重算(影响主页上的「恢复雷达」等卡片)。
/// Trigger recompute when the HRV health reading changes (affects the "Recovery Radar" card on Home).
struct RecomputeOnHRVChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let readiness: HRVReadiness

    func body(content: Content) -> some View {
        content.onChange(of: readiness) { _, _ in viewModel.recompute() }
    }
}

/// 身体状态或恢复历史变化时触发重算，覆盖 HRV 以外的睡眠、心率与锻炼更新。
/// Recompute when body status or its persisted daily snapshot changes.
struct RecomputeOnBodyStatusChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let bodyStatus: BodyStatus
    let healthHistory: [DailyHealthSnapshot]

    func body(content: Content) -> some View {
        content
            .onChange(of: bodyStatus) { _, _ in viewModel.recompute() }
            .onChange(of: healthHistory) { _, _ in viewModel.recompute() }
    }
}

extension View {
    /// 触发 Home 数据聚合 + 计划重算 — onAppear 版本
    /// Trigger Home data aggregation + plan recompute — onAppear variant.
    func recomputeOnAppear(viewModel: HomeViewModel) -> some View {
        modifier(RecomputeOnAppearModifier(viewModel: viewModel))
    }

    /// 成绩集合变化时触发 Home 重算
    /// Trigger Home recompute when the grade collection changes.
    func recomputeOnGradesChange(
        viewModel: HomeViewModel,
        grades: [Grade]
    ) -> some View {
        modifier(RecomputeOnGradesChangeModifier(viewModel: viewModel, grades: grades))
    }

    /// 考试集合变化时触发 Home 重算
    /// Trigger Home recompute when the exam collection changes.
    func recomputeOnExamsChange(
        viewModel: HomeViewModel,
        examSets: [Exam]
    ) -> some View {
        modifier(RecomputeOnExamsChangeModifier(viewModel: viewModel, examSets: examSets))
    }

    /// 错题集变化时触发 Home 重算
    /// Trigger Home recompute when the mistake-note collection changes.
    func recomputeOnMistakesChange(
        viewModel: HomeViewModel,
        mistakeSets: [MistakeNote]
    ) -> some View {
        modifier(RecomputeOnMistakesChangeModifier(viewModel: viewModel, mistakeSets: mistakeSets))
    }

    /// 任务集合变化时触发 Home 重算
    /// Trigger Home recompute when the task collection changes.
    func recomputeOnTasksChange(
        viewModel: HomeViewModel,
        taskItems: [TaskItem]
    ) -> some View {
        modifier(RecomputeOnTasksChangeModifier(viewModel: viewModel, taskItems: taskItems))
    }

    /// 日常计划定义变化时触发 Home 重算
    /// Trigger Home recompute when the routine definitions change.
    func recomputeOnRoutinesChange(
        viewModel: HomeViewModel,
        routines: [Routine]
    ) -> some View {
        modifier(RecomputeOnRoutinesChangeModifier(viewModel: viewModel, routines: routines))
    }

    /// 日常计划实例(完成/跳过)变化时触发 Home 重算
    /// Trigger Home recompute when routine instances (done/skipped) change.
    func recomputeOnRoutineInstancesChange(
        viewModel: HomeViewModel,
        instances: [RoutineInstance]
    ) -> some View {
        modifier(RecomputeOnRoutineInstancesChangeModifier(
            viewModel: viewModel,
            instances: instances
        ))
    }

    /// HRV 读数变化时触发 Home 重算
    /// Trigger Home recompute when the HRV reading changes.
    func recomputeOnHRVChange(
        viewModel: HomeViewModel,
        readiness: HRVReadiness
    ) -> some View {
        modifier(RecomputeOnHRVChangeModifier(viewModel: viewModel, readiness: readiness))
    }

    /// 身体状态/健康历史变化时触发 Home 重算。
    func recomputeOnBodyStatusChange(
        viewModel: HomeViewModel,
        bodyStatus: BodyStatus,
        healthHistory: [DailyHealthSnapshot]
    ) -> some View {
        modifier(RecomputeOnBodyStatusChangeModifier(
            viewModel: viewModel,
            bodyStatus: bodyStatus,
            healthHistory: healthHistory
        ))
    }
}
