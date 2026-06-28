//
//  ExamCalendarView.swift
//  StudyPulse
//
//  考试月历视图：按日期标点，多日考试跨日高亮。
//

import SwiftUI

/// 考试月历视图
struct ExamCalendarView: View {
    @EnvironmentObject var dataManager: DataManager

    /// 当前显示月份的第一天（用于网格计算）
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    /// 用户当前选中的日期
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    /// 月份切换方向：1 表示下一个月（向上滑入），-1 表示上一个月（向下滑入）
    @State private var monthShiftDirection: Int = 0

    /// 点击单科考试行的回调
    var onSelectExam: ((Exam) -> Void)?
    /// 点击综合考试行的回调
    var onSelectComprehensive: ((comprehensiveExam) -> Void)?

    /// 单日考（Exam）按 examDate 归一化为当天
    /// 多日考（comprehensiveExam）跨 examDate ~ examEndDate 区间
    private var allExams: [CalendarExam] {
        var items: [CalendarExam] = []
        for exam in dataManager.examSets {
            items.append(CalendarExam(
                id: exam.id,
                name: exam.name,
                subject: exam.subject,
                importance: exam.importance,
                start: Calendar.current.startOfDay(for: exam.examDate),
                end: Calendar.current.startOfDay(for: exam.examEndDate ?? exam.examDate),
                isComprehensive: false,
                exam: exam,
                comprehensiveExam: nil
            ))
        }
        for exam in dataManager.comprehensiveExamSets {
            let subjectText = exam.subject.joined(separator: ", ")
            items.append(CalendarExam(
                id: exam.id,
                name: exam.name,
                subject: subjectText,
                importance: exam.importance,
                start: Calendar.current.startOfDay(for: exam.examDate),
                end: Calendar.current.startOfDay(for: exam.examEndDate ?? exam.examDate),
                isComprehensive: true,
                exam: nil,
                comprehensiveExam: exam
            ))
        }
        return items
    }

    /// 当前显示月份中，所有出现的格子
    private var monthDays: [Date] {
        Calendar.current.monthGridDays(for: displayedMonth)
    }

    /// 当天（selectedDate）所在的考试
    private var examsOnSelectedDate: [CalendarExam] {
        let day = Calendar.current.startOfDay(for: selectedDate)
        return allExams
            .filter { $0.contains(day: day) }
            .sorted { $0.start < $1.start }
    }

    /// 当月所有考试（按日期升序）
    private var monthExams: [CalendarExam] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }
        let monthStart = Calendar.current.startOfDay(for: monthInterval.start)
        let monthEnd = Calendar.current.startOfDay(for: monthInterval.end)
        return allExams
            .filter { $0.end >= monthStart && $0.start < monthEnd }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayHeader
            slidingMonthGrid
                .padding(.horizontal, 4)
            Divider()
                .padding(.top, 12)
            selectedDayPanel
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var slidingMonthGrid: some View {
        monthGrid
            .id(displayedMonth)
            .transition(slideTransition)
            .animation(.easeInOut(duration: 0.25), value: displayedMonth)
            .clipped()
    }

    private var slideTransition: AnyTransition {
        let edge: Edge = monthShiftDirection > 0 ? .bottom : .top
        return .asymmetric(
            insertion: .move(edge: edge),
            removal: .move(edge: edge == .bottom ? .top : .bottom)
        )
    }

    // MARK: - 月份头

    private var monthHeader: some View {
        HStack(spacing: 8) {
            glassCircleButton(systemName: "chevron.left") {
                shiftMonth(by: -1)
            }
            .accessibilityLabel(Text("Previous Month".localized()))

            Spacer()

            Text(displayedMonth, format: .dateTime.year().month(.wide))
                .font(.headline)
                .foregroundColor(Color(.label))

            Spacer()

            glassCircleButton(systemName: "chevron.right") {
                shiftMonth(by: 1)
            }
            .accessibilityLabel(Text("Next Month".localized()))

            glassPillButton(title: "Today".localized()) {
                let today = Date()
                let todayMonth = Calendar.current.startOfMonth(for: today)
                monthShiftDirection = todayMonth > displayedMonth ? 1 : -1
                displayedMonth = todayMonth
                selectedDate = Calendar.current.startOfDay(for: today)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 液态玻璃按钮

    /// iOS 26+ 用系统 `glassEffect` 渲染液态玻璃；老版本回退到 `.regularMaterial`。
    /// `glassEffect(_:in:)` 必须作用在透明画布（`Color.clear`）上，再通过 `in:` 把形状传进去。
    @ViewBuilder
    private func glassCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(.label))
                .frame(width: 32, height: 32)
                .background {
                    if #available(iOS 26, *) {
                        Color.clear.glassEffect(.regular, in: Circle())
                    } else {
                        Circle().fill(.regularMaterial)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func glassPillButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(Color(.systemBlue))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    if #available(iOS 26, *) {
                        Color.clear.glassEffect(.regular, in: Capsule())
                    } else {
                        Capsule().fill(Color(.systemBlue).opacity(0.12))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 星期头

    private var weekdayHeader: some View {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        // veryShortStandaloneWeekdaySymbols 始终以 Sunday 开头；保持与系统日历一致
        return HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    // MARK: - 月份网格

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let days = monthDays
        let today = Calendar.current.startOfDay(for: Date())

        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                let day = Calendar.current.startOfDay(for: date)
                let inMonth = Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                let isToday = Calendar.current.isDate(day, inSameDayAs: today)
                let dayExams = allExams.filter { $0.contains(day: day) }

                DayCell(
                    date: day,
                    inMonth: inMonth,
                    isSelected: isSelected,
                    isToday: isToday,
                    exams: dayExams
                )
                .frame(height: 52)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDate = day
                    }
                }
            }
        }
    }

    // MARK: - 选中日面板

    @ViewBuilder
    private var selectedDayPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedDate, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(.label))
                Spacer()
                if !examsOnSelectedDate.isEmpty {
                    Text("\(examsOnSelectedDate.count) " + "exams".localized())
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color(.systemBlue).opacity(0.15))
                        )
                        .foregroundColor(Color(.systemBlue))
                }
            }

            if examsOnSelectedDate.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(Color(.tertiaryLabel))
                        Text("No exams on this day".localized())
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .padding(.vertical, 18)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(examsOnSelectedDate) { exam in
                        CalendarExamRow(exam: exam, referenceDate: selectedDate)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let underlying = exam.exam {
                                    onSelectExam?(underlying)
                                } else if let underlying = exam.comprehensiveExam {
                                    onSelectComprehensive?(underlying)
                                }
                            }
                    }
                }
            }
        }
        .padding(14)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: - 跳转

    private func shiftMonth(by offset: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        monthShiftDirection = offset
        displayedMonth = Calendar.current.startOfMonth(for: next)
    }
}

// MARK: - 单日格子

private struct DayCell: View {
    let date: Date
    let inMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let exams: [CalendarExam]

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isSelected {
                    Circle().fill(Color(.systemBlue))
                } else if isToday {
                    Circle()
                        .stroke(Color(.systemBlue), lineWidth: 1.5)
                }
                Text(Calendar.current.component(.day, from: date), format: .number)
                    .font(.system(size: 14, weight: isToday ? .bold : .medium))
                    .foregroundColor(numberColor)
            }
            .frame(width: 26, height: 26)
            dotsRow
        }
        .frame(maxWidth: .infinity)
        .opacity(inMonth ? 1.0 : 0.32)
    }

    @ViewBuilder
    private var dotsRow: some View {
        ZStack {
            // 多日考试背景横条（横条填满 cell 宽度；grid spacing 0 保证跨格像素级拼接）
            if let span = multiDaySpanInfo {
                GeometryReader { proxy in
                    spanBar(width: proxy.size.width, color: span.color,
                            isStart: span.isStart, isEnd: span.isEnd)
                }
                .frame(height: 6)
            }
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { idx in
                    Circle()
                        .fill(dotColor(at: idx))
                        .frame(width: 4, height: 4)
                        .opacity(idx < singleDayDotCount ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func spanBar(width: CGFloat, color: Color, isStart: Bool, isEnd: Bool) -> some View {
        let height: CGFloat = 6
        let radius = height / 2
        UnevenRoundedRectangle(cornerRadii: cornerRadii(radius: radius, isStart: isStart, isEnd: isEnd))
            .fill(color.opacity(0.22))
            .frame(width: width, height: height)
    }

    private func cornerRadii(radius: CGFloat, isStart: Bool, isEnd: Bool) -> RectangleCornerRadii {
        if isStart {
            return .init(topLeading: radius, bottomLeading: radius, bottomTrailing: 0, topTrailing: 0)
        } else if isEnd {
            return .init(topLeading: 0, bottomLeading: 0, bottomTrailing: radius, topTrailing: radius)
        }
        return .init(topLeading: 0, bottomLeading: 0, bottomTrailing: 0, topTrailing: 0)
    }

    private var singleDayDotCount: Int {
        // 单日或多日：最多展示 3 个点（优先综合 + 重要单科）
        let allSorted = sortedExamsForDisplay
        if allSorted.isEmpty { return 0 }
        return min(3, allSorted.count)
    }

    private var sortedExamsForDisplay: [CalendarExam] {
        exams.sorted { lhs, rhs in
            if lhs.isComprehensive != rhs.isComprehensive {
                return lhs.isComprehensive && !rhs.isComprehensive
            }
            return lhs.importance > rhs.importance
        }
    }

    private func dotColor(at index: Int) -> Color {
        let sorted = sortedExamsForDisplay
        guard index < sorted.count else { return .clear }
        return sorted[index].isComprehensive ? Color(.systemPurple) : Color(.systemBlue)
    }

    private var multiDaySpanInfo: (color: Color, isStart: Bool, isEnd: Bool)? {
        // 找出跨多天的考试，并判断当前格子是起点 / 中间 / 终点
        for exam in exams where !exam.isSingleDay {
            let isStart = Calendar.current.isDate(date, inSameDayAs: exam.start)
            let isEnd = Calendar.current.isDate(date, inSameDayAs: exam.end)
            if isStart || isEnd {
                return (exam.isComprehensive ? Color(.systemPurple) : Color(.systemBlue), isStart, isEnd)
            }
            // 介于 start 与 end 之间
            if exam.start < date && date < exam.end {
                return (exam.isComprehensive ? Color(.systemPurple) : Color(.systemBlue), false, false)
            }
        }
        return nil
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return Color(.systemBlue) }
        if Calendar.current.isDateInWeekend(date) { return Color(.systemRed).opacity(0.85) }
        return Color(.label)
    }
}

// MARK: - 选中日行

private struct CalendarExamRow: View {
    let exam: CalendarExam
    /// 用于计算多日考试「第几天」的参考日期（通常就是选中的那一天）
    let referenceDate: Date

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exam.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color(.label))
                        .lineLimit(1)
                    if !exam.isSingleDay {
                        Text(multiDayLabel)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(accentColor.opacity(0.15))
                            )
                            .foregroundColor(accentColor)
                    }
                }
                Text(exam.subject)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                ForEach(0..<exam.importance, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.yellow)
                }
                if exam.importance < 5 {
                    ForEach(0..<(5 - exam.importance), id: \.self) { _ in
                        Image(systemName: "star")
                            .font(.system(size: 6))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private var accentColor: Color {
        exam.isComprehensive ? Color(.systemPurple) : Color(.systemBlue)
    }

    private var multiDayLabel: String {
        if exam.isSingleDay { return "" }
        let calendar = Calendar.current
        let totalDays = (calendar.dateComponents([.day], from: exam.start, to: exam.end).day ?? 0) + 1
        let dayIndex = (calendar.dateComponents([.day], from: exam.start, to: referenceDate).day ?? 0) + 1
        let clamped = min(max(dayIndex, 1), totalDays)
        let template = "Day %d/%d".localized()
        return String(format: template, clamped, totalDays)
    }
}

// MARK: - 数据模型

/// 统一单科 / 综合考试在日历中的展示形态
struct CalendarExam: Identifiable, Hashable {
    let id: UUID
    let name: String
    let subject: String
    let importance: Int
    let start: Date
    let end: Date
    let isComprehensive: Bool
    let exam: Exam?
    let comprehensiveExam: comprehensiveExam?

    var isSingleDay: Bool {
        Calendar.current.isDate(start, inSameDayAs: end)
    }

    /// 该日是否落在考试区间内（含首尾）
    func contains(day: Date) -> Bool {
        let target = Calendar.current.startOfDay(for: day)
        return target >= start && target <= end
    }

    static func == (lhs: CalendarExam, rhs: CalendarExam) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Calendar 扩展

private extension Calendar {
    /// 返回月份第一天（00:00:00）
    func startOfMonth(for date: Date) -> Date {
        var components = dateComponents([.year, .month], from: date)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return self.date(from: components) ?? date
    }

    /// 返回当前显示月份对应的 6×7 = 42 个日期（前导补上月首之前的几天 + 月尾之后的几天）
    func monthGridDays(for monthAnchor: Date) -> [Date] {
        let monthStart = startOfMonth(for: monthAnchor)
        let weekdayIndex = component(.weekday, from: monthStart) - 1 // 0 = Sunday
        guard let gridStart = self.date(byAdding: .day, value: -weekdayIndex, to: monthStart) else {
            return []
        }
        return (0..<42).compactMap { offset in
            self.date(byAdding: .day, value: offset, to: gridStart)
        }
    }
}

// MARK: - Preview

#Preview("With Sample Data") {
    ExamCalendarView()
        .environmentObject(PreviewSupport.makeSampleDataManager())
}

#Preview("Empty") {
    ExamCalendarView()
        .environmentObject(DataManager())
}

#Preview("Dark Mode") {
    ExamCalendarView()
        .environmentObject(PreviewSupport.makeSampleDataManager())
        .preferredColorScheme(.dark)
}

/// 预览用示例数据
@MainActor
private enum PreviewSupport {
    static func makeSampleDataManager() -> DataManager {
        let manager = DataManager()
        manager.examSets = sampleExams
        manager.comprehensiveExamSets = sampleComprehensiveExams
        return manager
    }

    /// 当前月份内：单日考 / 多日考
    private static var sampleExams: [Exam] {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.startOfMonth(for: now)
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        func date(day: Int, hour: Int = 9) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            return calendar.date(from: components) ?? monthStart
        }

        return [
            Exam(
                name: "Math Quiz",
                date: date(day: 5, hour: 10),
                importance: 3,
                subject: "Mathematics",
                examName: "Chapter 3 Quiz",
                masteryDegree: 60
            ),
            Exam(
                name: "Physics Midterm",
                date: date(day: 12, hour: 8),
                importance: 5,
                subject: "Physics",
                examName: "Midterm",
                masteryDegree: 45
            ),
            Exam(
                name: "Final Week — 3 Day Block",
                date: date(day: 18, hour: 9),
                importance: 5,
                subject: "Chemistry",
                examName: "Final Block",
                masteryDegree: 30
            ).withExamEndDate(date(day: 20, hour: 17)),
            Exam(
                name: "English Oral",
                date: date(day: 22, hour: 14),
                importance: 2,
                subject: "English",
                examName: "Speaking Test",
                masteryDegree: 75
            ),
            Exam(
                name: "History Pop Quiz",
                date: date(day: 26, hour: 11),
                importance: 1,
                subject: "History",
                examName: "Surprise Quiz",
                masteryDegree: 80
            )
        ]
    }

    /// 综合考试：含跨日
    private static var sampleComprehensiveExams: [comprehensiveExam] {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        func date(day: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = 9
            return calendar.date(from: components) ?? now
        }

        return [
            comprehensiveExam(
                name: "Midterm Week",
                date: date(day: 8),
                importance: 4,
                subject: ["Mathematics", "Physics", "Chemistry"],
                examName: "Midterm",
                masteryDegree: 55
            ).withExamEndDate(date(day: 10)),
            comprehensiveExam(
                name: "Liberal Arts Final",
                date: date(day: 28),
                importance: 5,
                subject: ["History", "Politics", "Geography"],
                examName: "Final",
                masteryDegree: 40
            )
        ]
    }
}

// Exam 构造完成后追加 examEndDate 的便捷方法（不影响线上逻辑）
private extension Exam {
    func withExamEndDate(_ end: Date) -> Exam {
        var copy = self
        copy.examEndDate = end
        return copy
    }
}

private extension comprehensiveExam {
    func withExamEndDate(_ end: Date) -> comprehensiveExam {
        var copy = self
        copy.examEndDate = end
        return copy
    }
}
