//
//  HomeRecomputeModifier.swift
//  StudyPulse
//
//  把 HomeView 的多个 onChange / onAppear 重算触发器抽出来,避免主 body
//  的 View 表达式过长导致 Swift 编译器超时。
//
//  Created for Plans & Routines spec (2026-07-09).
//

import SwiftUI

/// 把单一的 recompute 触发器挂到 content 上(每个 modifier 只加一个 onChange,
/// 避免 SwiftUI body 表达式嵌套过深导致类型检查器超时)。
struct RecomputeOnAppearModifier: ViewModifier {
    let viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content.onAppear { viewModel.recompute() }
    }
}

struct RecomputeOnGradesChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let grades: [Grade]

    func body(content: Content) -> some View {
        content.onChange(of: grades) { _, _ in viewModel.recompute() }
    }
}

struct RecomputeOnExamsChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let examSets: [Exam]

    func body(content: Content) -> some View {
        content.onChange(of: examSets) { _, _ in viewModel.recompute() }
    }
}

struct RecomputeOnMistakesChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let mistakeSets: [MistakeNote]

    func body(content: Content) -> some View {
        content.onChange(of: mistakeSets) { _, _ in viewModel.recompute() }
    }
}

struct RecomputeOnTasksChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let taskItems: [TaskItem]

    func body(content: Content) -> some View {
        content.onChange(of: taskItems) { _, _ in viewModel.recompute() }
    }
}

struct RecomputeOnRoutinesChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let routines: [Routine]

    func body(content: Content) -> some View {
        content.onChange(of: routines) { _, _ in viewModel.recompute() }
    }
}

struct RecomputeOnRoutineInstancesChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let instances: [RoutineInstance]

    func body(content: Content) -> some View {
        content.onChange(of: instances) { _, _ in viewModel.recompute() }
    }
}

struct RecomputeOnHRVChangeModifier: ViewModifier {
    let viewModel: HomeViewModel
    let readiness: HRVReadiness

    func body(content: Content) -> some View {
        content.onChange(of: readiness) { _, _ in viewModel.recompute() }
    }
}

extension View {
    /// 触发 Home 数据聚合 + 计划重算 — onAppear 版本
    func recomputeOnAppear(viewModel: HomeViewModel) -> some View {
        modifier(RecomputeOnAppearModifier(viewModel: viewModel))
    }

    func recomputeOnGradesChange(
        viewModel: HomeViewModel,
        grades: [Grade]
    ) -> some View {
        modifier(RecomputeOnGradesChangeModifier(viewModel: viewModel, grades: grades))
    }

    func recomputeOnExamsChange(
        viewModel: HomeViewModel,
        examSets: [Exam]
    ) -> some View {
        modifier(RecomputeOnExamsChangeModifier(viewModel: viewModel, examSets: examSets))
    }

    func recomputeOnMistakesChange(
        viewModel: HomeViewModel,
        mistakeSets: [MistakeNote]
    ) -> some View {
        modifier(RecomputeOnMistakesChangeModifier(viewModel: viewModel, mistakeSets: mistakeSets))
    }

    func recomputeOnTasksChange(
        viewModel: HomeViewModel,
        taskItems: [TaskItem]
    ) -> some View {
        modifier(RecomputeOnTasksChangeModifier(viewModel: viewModel, taskItems: taskItems))
    }

    func recomputeOnRoutinesChange(
        viewModel: HomeViewModel,
        routines: [Routine]
    ) -> some View {
        modifier(RecomputeOnRoutinesChangeModifier(viewModel: viewModel, routines: routines))
    }

    func recomputeOnRoutineInstancesChange(
        viewModel: HomeViewModel,
        instances: [RoutineInstance]
    ) -> some View {
        modifier(RecomputeOnRoutineInstancesChangeModifier(
            viewModel: viewModel,
            instances: instances
        ))
    }

    func recomputeOnHRVChange(
        viewModel: HomeViewModel,
        readiness: HRVReadiness
    ) -> some View {
        modifier(RecomputeOnHRVChangeModifier(viewModel: viewModel, readiness: readiness))
    }
}
