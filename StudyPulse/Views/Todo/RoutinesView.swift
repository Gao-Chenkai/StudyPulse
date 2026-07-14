//
//  RoutinesView.swift
//  StudyPulse
//
//  Todo Tab 内的"例程"子页签。
//  展示一周 × 时间槽的周计划模板;支持新建 / 编辑 / 启停 / 删除。
//
//  Created for Plans & Routines spec (2026-07-09).
//

import SwiftUI

/// 例程视图(列表 + 编辑器)
struct RoutinesView: View {
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject private var envManager: AppEnvironmentManager
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 由 TodoRootView 传入的页签绑定(Tasks / Routines)
    @Binding var segment: TodoRootView.Segment

    @State private var editorMode: EditorMode? = nil

    enum EditorMode: Identifiable {
        case create
        case edit(Routine)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let r): return "edit-\(r.id.uuidString)"
            }
        }
    }

    private var routines: [Routine] {
        container.routineRepo.filteredRoutines
    }

    var body: some View {
        ZStack {
            if routines.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .background(Color(.systemGroupedBackground).opacity(DesignToken.Opacity.rootBackground))
        .containerBackground(.clear, for: .navigation)
        .navigationTitle("Routines".localized())
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                .accessibilityLabel("New routine".localized())
            }
        }
        .sheet(item: $editorMode) { mode in
            RoutineEditorSheet(
                container: container,
                editing: existingRoutine(for: mode)
            )
        }
    }

    // MARK: - Segment Picker

    /// Tasks / Routines 页签选择器,作为滚动内容的一部分
    private var segmentPicker: some View {
        Picker("", selection: $segment) {
            ForEach(TodoRootView.Segment.allCases) { s in
                Label(s.title, systemImage: s.icon).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignToken.Spacing.mainHorizontal(for: sizeClass))
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            segmentPicker
            Image(systemName: "repeat.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.indigo.opacity(0.7))
            Text("No routines yet".localized())
                .font(.title3.bold())
            Text("Schedule recurring study blocks like\n\"Mon 19:00-21:00 Math mistake review\".".localized())
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundColor(.secondary)
            Button {
                editorMode = .create
            } label: {
                Label("Add your first routine".localized(), systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(40)
    }

    // MARK: - List

    private var listContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignToken.Spacing.cardSpacing) {
                segmentPicker
                gridCard
                Text("All routines".localized())
                    .font(.headline)
                    .padding(.horizontal, 4)
                ForEach(groupedByWeekday(), id: \.weekday) { group in
                    weekdaySection(group: group)
                }
            }
            .padding(.horizontal, DesignToken.Spacing.mainHorizontal(for: sizeClass))
            .padding(.vertical, DesignToken.Spacing.large)
        }
    }

    // MARK: - Grid Card

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week".localized())
                    .font(.headline)
                Spacer()
            }
            WeekGridView(routines: routines)
                .frame(height: 120)
        }
        .padding(DesignToken.Spacing.cardPadding)
        .cardSkin()
    }

    private func weekdaySection(group: WeekdayGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(weekdayName(group.weekday))
                    .font(.subheadline.bold())
                Spacer()
                Text("\(group.routines.count)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            ForEach(group.routines) { routine in
                routineRow(routine)
            }
        }
        .padding(DesignToken.Spacing.cardPadding)
        .cardSkin()
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: routine.type.colorHex).opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: routine.type.icon)
                    .foregroundColor(Color(hex: routine.type.colorHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(routine.startTimeLabel) - \(routine.endTimeLabel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let s = routine.subject {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(s.localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            if !routine.enabled {
                Text("Off".localized())
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.secondary.opacity(0.2))
                    )
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            editorMode = .edit(routine)
        }
    }

    // MARK: - Helpers

    private func existingRoutine(for mode: EditorMode) -> Routine? {
        if case .edit(let r) = mode { return r }
        return nil
    }

    private struct WeekdayGroup: Identifiable {
        let weekday: Int
        let routines: [Routine]
        var id: Int { weekday }
    }

    private func groupedByWeekday() -> [WeekdayGroup] {
        // weekday 1=Sun ... 7=Sat
        let byWeekday: [Int: [Routine]] = Dictionary(grouping: routines) { r in
            // 简化:取第一个 weekday(用户每条 routine 至少选 1 天)
            r.weekdays.min() ?? 1
        }
        return (1...7).compactMap { wd in
            guard let arr = byWeekday[wd], !arr.isEmpty else { return nil }
            return WeekdayGroup(weekday: wd, routines: arr.sorted { $0.startTime < $1.startTime })
        }
    }

    private func weekdayName(_ wd: Int) -> String {
        let names = ["Sun".localized(), "Mon".localized(), "Tue".localized(),
                     "Wed".localized(), "Thu".localized(), "Fri".localized(),
                     "Sat".localized()]
        return names[(wd - 1) % 7]
    }
}

// MARK: - 一周网格

private struct WeekGridView: View {
    let routines: [Routine]
    private let weekdays = 7
    private let hours: [Int] = Array(0...23)
    private let pixelsPerHour: CGFloat = 4.5

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 星期头
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 28)
                ForEach(1...weekdays, id: \.self) { wd in
                    Text(weekdayShortName(wd))
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            // 行:每个 weekday 一行
            HStack(alignment: .top, spacing: 0) {
                // 时刻尺
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(hours, id: \.self) { h in
                        Text(h % 6 == 0 ? "\(h)" : "")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: pixelsPerHour, alignment: .top)
                    }
                }
                .frame(width: 28)
                ForEach(1...weekdays, id: \.self) { wd in
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                        ForEach(routinesForWeekday(wd), id: \.id) { r in
                            routineBlock(r)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: CGFloat(hours.count) * pixelsPerHour)
                    .border(Color.secondary.opacity(0.15), width: 0.5)
                }
            }
        }
    }

    private func weekdayShortName(_ wd: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[(wd - 1) % 7]
    }

    private func routinesForWeekday(_ wd: Int) -> [Routine] {
        routines.filter { $0.weekdays.contains(wd) }
    }

    private func routineBlock(_ r: Routine) -> some View {
        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: r.startTime)
        let eComps = cal.dateComponents([.hour, .minute], from: r.endTime)
        let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
        let eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
        let topY = CGFloat(sMin) / 60.0 * pixelsPerHour
        let heightY = max(8, CGFloat(eMin - sMin) / 60.0 * pixelsPerHour)
        return RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: r.type.colorHex).opacity(0.75))
            .overlay(
                Text(r.type.shortTitle)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 2),
                alignment: .leading
            )
            .frame(height: heightY)
            .offset(y: topY)
            .padding(.horizontal, 1)
    }
}
