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

    /// 当前显示月份（动画过程中已提前切为目标月）
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    /// 正在滑出的旧月份（nil 表示无动画中）
    @State private var outgoingMonth: Date? = nil
    /// 新网格滑入进度（1 → 0，使用弹簧）
    @State private var incomingProgress: CGFloat = 0
    /// 旧网格滑出进度（1 → 0，使用 easeOut 防止回弹）
    @State private var outgoingProgress: CGFloat = 0
    /// 滑动方向：1 表示下一个月从底部滑入，-1 表示上一个月从顶部滑入
    @State private var slideDirection: Int = 0
    /// 用户当前选中的日期
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    /// 点击单科考试行的回调
    var onSelectExam: ((Exam) -> Void)?
    /// 点击综合考试行的回调
    var onSelectComprehensive: ((comprehensiveExam) -> Void)?

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

    /// 当天（selectedDate）所在的考试
    private var examsOnSelectedDate: [CalendarExam] {
        let day = Calendar.current.startOfDay(for: selectedDate)
        return allExams
            .filter { $0.contains(day: day) }
            .sorted { $0.start < $1.start }
    }

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
        ZStack(alignment: .top) {
            Color(.systemBackground)
                .ignoresSafeArea()

            monthGridContainer

            VStack(spacing: 0) {
                glassHeaderLayer
                Spacer(minLength: 200)
                glassBottomPanel
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 月份网格背景层

    private var monthGridContainer: some View {
        GeometryReader { geo in
            let clampedIncoming = max(0, min(1, incomingProgress))
            let clampedOutgoing = max(0, min(1, outgoingProgress))
            ZStack {
                monthGrid(for: displayedMonth)
                    .offset(y: CGFloat(slideDirection) * clampedIncoming * geo.size.height)

                if let outgoingMonth {
                    monthGrid(for: outgoingMonth)
                        .offset(y: -CGFloat(slideDirection) * (1 - clampedOutgoing) * geo.size.height)
                        .opacity(clampedOutgoing < 0.05 ? 0 : 1)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture)
        }
        .padding(.top, headerTotalFixedHeight)
        .padding(.bottom, 190)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                let vertical = value.translation.height
                if vertical < -50 {
                    shiftMonth(by: 1)
                } else if vertical > 50 {
                    shiftMonth(by: -1)
                }
            }
    }

    private func monthGrid(for month: Date) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let days = Calendar.current.monthGridDays(for: month)
        let today = Calendar.current.startOfDay(for: Date())

        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                let day = Calendar.current.startOfDay(for: date)
                let inMonth = Calendar.current.isDate(date, equalTo: month, toGranularity: .month)
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
        .padding(.horizontal, 4)
    }

    // MARK: - 顶部玻璃层

    /// 玻璃背景与屏幕左右边缘之间的内缩量
    private let glassEdgeInset: CGFloat = 16
    /// 顶部玻璃层固定总高度（与 monthGridContainer 的 .padding(.top) 对齐）
    private let headerTotalFixedHeight: CGFloat = 88

    private var glassHeaderLayer: some View {
        ZStack(alignment: .top) {
            // Independent glass background layer, sizing & inset controlled separately
            Group {
                if #available(iOS 26, *) {
                    Color.clear.glassEffect(.regular, in: headerGlassShape)
                } else {
                    headerGlassShape.fill(.regularMaterial)
                }
            }
            // Constrain glass height first to prevent vertical overflow into date rows
            .frame(height: headerTotalFixedHeight)
            // Lock horizontal inset on glass itself to avoid full-width stretch
            .padding(.horizontal, glassEdgeInset)
            // Only extend top edge to status bar, no vertical expansion
            .ignoresSafeArea(edges: .top)

            // Foreground header content, matching horizontal inset of glass background
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
            }
            .padding(.bottom, 8)
            .padding(.horizontal, glassEdgeInset)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var headerGlassShape: some Shape {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

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
                let direction = todayMonth > displayedMonth ? 1 : -1
                animateToMonth(todayMonth, direction: direction)
                selectedDate = Calendar.current.startOfDay(for: today)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

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

    private var weekdayHeader: some View {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
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

    // MARK: - 底部玻璃详情面板

    private var glassBottomPanel: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: glassEdgeInset)
            selectedDayPanel
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background {
                    if #available(iOS 26, *) {
                        Color.clear.glassEffect(.regular, in: bottomGlassShape)
                    } else {
                        bottomGlassShape.fill(.regularMaterial)
                    }
                }
            Color.clear.frame(width: glassEdgeInset)
        }
        .alignmentGuide(.bottom) { $0[.bottom] }
        .ignoresSafeArea(edges: .bottom)
    }

    private var bottomGlassShape: some Shape {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

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
                ScrollView(.vertical, showsIndicators: false) {
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
                .frame(maxHeight: 124)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 跳转

    private func shiftMonth(by offset: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        animateToMonth(Calendar.current.startOfMonth(for: next), direction: offset)
    }

    private func animateToMonth(_ target: Date, direction: Int) {
        guard outgoingMonth == nil else { return }

        outgoingMonth = displayedMonth
        displayedMonth = target
        slideDirection = direction
        incomingProgress = 1
        outgoingProgress = 1

        withAnimation(.interpolatingSpring(stiffness: 140, damping: 24)) {
            incomingProgress = 0
        }
        withAnimation(.easeOut(duration: 0.32)) {
            outgoingProgress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            outgoingMonth = nil
            slideDirection = 0
            incomingProgress = 0
            outgoingProgress = 0
        }
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
        for exam in exams where !exam.isSingleDay {
            let isStart = Calendar.current.isDate(date, inSameDayAs: exam.start)
            let isEnd = Calendar.current.isDate(date, inSameDayAs: exam.end)
            if isStart || isEnd {
                return (exam.isComprehensive ? Color(.systemPurple) : Color(.systemBlue), isStart, isEnd)
            }
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
        .background {
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.tertiarySystemGroupedBackground))
            }
        }
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
    func startOfMonth(for date: Date) -> Date {
        var components = dateComponents([.year, .month], from: date)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return self.date(from: components) ?? date
    }

    func monthGridDays(for monthAnchor: Date) -> [Date] {
        let monthStart = startOfMonth(for: monthAnchor)
        let weekdayIndex = component(.weekday, from: monthStart) - 1
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

@MainActor
private enum PreviewSupport {
    static func makeSampleDataManager() -> DataManager {
        let manager = DataManager()
        manager.examSets = sampleExams
        manager.comprehensiveExamSets = sampleComprehensiveExams
        return manager
    }

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
