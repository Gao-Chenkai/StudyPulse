//
//  TodoView.swift
//  StudyPulse
//
//  「待办」页：统一展示日常作业、阅读材料与考试日程。
//  与原「考试」页相比,本页同时承担三类条目的列表/筛选/分组/详情/编辑。
//
//  The Todo page unifies daily homework, reading materials, and exam schedules in a single
//  list with type-based filtering and time-based grouping.
//

import SwiftUI

// MARK: - 类型筛选

/// 列表顶部的类型筛选 chip
enum TodoTypeFilter: Hashable, CaseIterable {
    case all
    case exam
    case homework
    case reading

    var label: String {
        switch self {
        case .all: return "All".localized()
        case .exam: return "Exams".localized()
        case .homework: return "Homework".localized()
        case .reading: return "Reading".localized()
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .exam: return "calendar"
        case .homework: return "pencil.and.list.clipboard"
        case .reading: return "book.fill"
        }
    }
}

// MARK: - TodoView

struct TodoView: View {
    @EnvironmentObject var dataManager: DataManager

    // 列表 vs 日历视图模式
    @State private var viewMode: ExamViewMode = ExamViewMode.loadFromDefaults()
    // 类型筛选
    @State private var typeFilter: TodoTypeFilter = .all
    // 是否显示已完成（默认隐藏，主列表更干净）
    @State private var showCompleted: Bool = false

    // 新增菜单控制
    @State private var showingNewExam: Bool = false
    @State private var showingNewTask: TaskType? = nil

    // 详情导航
    @State private var selectedExam: Exam? = nil
    @State private var selectedComprehensive: comprehensiveExam? = nil
    @State private var selectedTask: TaskItem? = nil

    // 已过期面板
    @State private var showingPastSheet: Bool = false

    // MARK: - 派生数据

    /// 应用类型筛选 + 已完成筛选后的统一条目
    private var allEntries: [TodoEntry] {
        let includeCompleted = showCompleted
        let all = dataManager.todoEntries(includeCompleted: includeCompleted)
        guard typeFilter != .all else { return all }
        return all.filter { entry in
            switch typeFilter {
            case .all: return true
            case .exam: return entry.kind == .exam || entry.kind == .comprehensiveExam
            case .homework: return entry.kind == .homework
            case .reading: return entry.kind == .reading
            }
        }
    }

    /// 未过期条目（截止 / 考试时间 >= 今天 0 点）
    private var upcomingEntries: [TodoEntry] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { $0.date >= todayStart }
    }

    /// 已过期条目
    private var pastEntries: [TodoEntry] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { $0.date < todayStart }
    }

    /// 把即将到来的条目按时间分组
    private var groupedUpcoming: [(sectionTitle: String, entries: [TodoEntry])] {
        let now = Date()
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now),
              let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now) else {
            return []
        }

        let week = upcomingEntries.filter { $0.date <= oneWeekLater }
        let month = upcomingEntries.filter { $0.date > oneWeekLater && $0.date <= oneMonthLater }
        let later = upcomingEntries.filter { $0.date > oneMonthLater }

        var result: [(String, [TodoEntry])] = []
        if !week.isEmpty { result.append(("Within 1 Week".localized(), week)) }
        if !month.isEmpty { result.append(("Within 1 Month".localized(), month)) }
        if !later.isEmpty { result.append(("Later".localized(), later)) }
        return result
    }

    // MARK: - 主体

    var body: some View {
        NavigationStack {
            Group {
                if allEntries.isEmpty && pastEntries.isEmpty {
                    VStack(spacing: 0) {
                        filterChips
                        ContentUnavailableView {
                            Label("No Items".localized(), systemImage: "checklist")
                        } description: {
                            Text("Tap '+' to add a homework, reading material, or exam.".localized())
                        } actions: {
                            Menu {
                                Button {
                                    showingNewExam = true
                                } label: {
                                    Label("New Exam".localized(), systemImage: "calendar.badge.plus")
                                }
                                Button {
                                    showingNewTask = .homework
                                } label: {
                                    Label("New Homework".localized(), systemImage: "pencil.and.list.clipboard")
                                }
                                Button {
                                    showingNewTask = .reading
                                } label: {
                                    Label("New Reading".localized(), systemImage: "book.fill")
                                }
                            } label: {
                                Label("Add First Item".localized(), systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                } else if viewMode == .calendar {
                    // 月历本身是 ZStack + .clipShape，没有顶层 ScrollView，
                    // iOS 会因为找不到可滚动视图而完全跳过 .large 标题的渲染。
                    // 用 ScrollView 套一层提供滚动内容，标题就能正常跟随显示/折叠。
                    VStack(spacing: 0) {
                        filterChips
                        ScrollView {
                            calendarContent
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    listContent
                }
            }
            .navigationTitle("Todo".localized())
            // 标准 NavigationView 标题行为：
            // - 列表在顶时显示大标题
            // - 列表上滑后 iOS 自动把大标题折叠为居中 inline 小字体
            // 胶囊现在是 List 的一行（filterChipsListRow），不会干扰 iOS 对主滚动内容的检测。
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .frame(maxWidth: .infinity)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !pastEntries.isEmpty {
                        Button {
                            showingPastSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("\(pastEntries.count)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCompleted.toggle()
                        }
                    } label: {
                        Image(systemName: showCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundColor(showCompleted ? Color(.systemGreen) : .accentColor)
                    }
                    .accessibilityLabel("Show Completed".localized())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    viewModeMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addMenu
                }
            }
            .sheet(isPresented: $showingNewExam) {
                NewExamSetView()
                    .adaptiveSheet()
            }
            .sheet(item: $showingNewTask) { taskType in
                NewTaskView(initialType: taskType)
                    .environmentObject(dataManager)
                    .adaptiveSheet()
            }
            .sheet(isPresented: $showingPastSheet) {
                PastItemsSheet(
                    pastEntries: pastEntries,
                    onSelectExam: { exam in
                        showingPastSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            selectedExam = exam
                        }
                    },
                    onSelectComprehensive: { exam in
                        showingPastSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            selectedComprehensive = exam
                        }
                    },
                    onSelectTask: { task in
                        showingPastSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            selectedTask = task
                        }
                    },
                    onDeleteEntry: deleteEntry
                )
                .adaptiveSheet(detents: [.medium, .large])
            }
            .navigationDestination(item: $selectedExam) { exam in
                ExamDetailView(exam: exam)
                    .background(Color(.systemBackground))
            }
            .navigationDestination(item: $selectedComprehensive) { exam in
                Text("Comprehensive Exam: ".localized() + exam.name)
                    .background(Color(.systemBackground))
            }
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
                    .background(Color(.systemBackground))
            }
            .onAppear {
                // 页面出现时从系统 Reminders 拉取一次完成态
                // Pull completion flags from the system Reminders app on view appear.
                dataManager.refreshTaskCompletionStatesFromReminders()
            }
    }
}

    /// 渲染在「待办」标题正下方的水平滚动筛选 chip 行
    @ViewBuilder
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TodoTypeFilter.allCases, id: \.self) { filter in
                    chip(for: filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func chip(for filter: TodoTypeFilter) -> some View {
        let selected = typeFilter == filter
        // iOS 26 风格筛选胶囊（Liquid Glass）：
        // - 选中：accent 同色边框 + 轻微 tint 叠加，文字保持 primary
        // - 未选中：纯 Liquid Glass 半透明
        // - 文字颜色在两种状态下都不变（不随选中切换颜色）
        let accent = chipAccent(for: filter)
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                typeFilter = filter
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: filter.systemImage)
                    .font(.footnote)
                Text(filter.label)
                    .font(.footnote)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                // 液态玻璃背景：iOS 26+ 用系统真正的 `glassEffect`，
                // 低版本用 `.regularMaterial` 兜底。
                // 注意：`glassEffect(_:in:)` 必须作用在透明画布上（`Color.clear`），
                // 并通过 `in:` 把形状传进去；直接给 `Capsule()` 调 `glassEffect` 会得到
                // 几乎不透明的大色块。
                if #available(iOS 26, *) {
                    Color.clear.glassEffect(.regular, in: Capsule())
                } else {
                    Capsule().fill(.regularMaterial)
                }
            }
            .overlay(
                // 选中态：accent 半透明填充 + 描边，叠在玻璃层之上
                Capsule()
                    .fill(selected ? accent.opacity(0.18) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(selected ? accent : Color.clear, lineWidth: selected ? 1.5 : 0)
            )
            .foregroundColor(Color.primary)
        }
        .buttonStyle(.plain)
    }

    /// 每个筛选项对应的活泼 accent 色
    /// 全部 → 蓝；考试 → 紫；作业 → 绿；阅读 → 青
    private func chipAccent(for filter: TodoTypeFilter) -> Color {
        switch filter {
        case .all:       return Color(red: 0.00, green: 0.42, blue: 1.00)   // 高饱和亮蓝
        case .exam:      return Color(red: 0.58, green: 0.18, blue: 1.00)   // 高饱和亮紫
        case .homework:  return Color(red: 0.05, green: 0.72, blue: 0.28)   // 高饱和亮绿
        case .reading:   return Color(red: 0.00, green: 0.62, blue: 0.92)   // 高饱和亮青
        }
    }

    // MARK: - 列表内容

    @ViewBuilder
    private var listContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部筛选胶囊行，跟随内容滚动
                filterChips
                    .padding(.bottom, 16)

                if upcomingEntries.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "checklist")
                                .font(.title2)
                                .foregroundColor(Color(.secondaryLabel))
                            Text("No upcoming items".localized())
                                .font(.subheadline)
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedUpcoming, id: \.0) { sectionTitle, entries in
                            sectionHeader(sectionTitle)
                            LazyVStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    TodoRowView(
                                        entry: entry,
                                        onTap: { tapped(entry) },
                                        onToggleCompletion: { toggleCompletion(of: entry) }
                                    )
                                    .contextMenu {
                                        if entry.kind == .homework || entry.kind == .reading {
                                            Button {
                                                toggleCompletion(of: entry)
                                            } label: {
                                                if entry.isCompleted {
                                                    Label("Pending".localized(), systemImage: "circle")
                                                } else {
                                                    Label("Done".localized(), systemImage: "checkmark")
                                                }
                                            }
                                        }
                                        Button(role: .destructive) {
                                            deleteEntry(entry)
                                        } label: {
                                            Label("Delete".localized(), systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    /// 分组标题
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(Color(.secondaryLabel))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }

    // MARK: - 日历内容

    @ViewBuilder
    private var calendarContent: some View {
        // 月历视图在四种筛选下都可用：考试 / 综合考试 / 作业 / 阅读统一展示
        ExamCalendarView(
            onSelectExam: { exam in selectedExam = exam },
            onSelectComprehensive: { exam in selectedComprehensive = exam },
            onSelectTask: { task in selectedTask = task },
            typeFilter: calendarFilter
        )
    }

    /// 把列表顶部的 TodoTypeFilter 映射为月历视图使用的 CalendarItemKindFilter
    private var calendarFilter: CalendarItemKindFilter {
        switch typeFilter {
        case .all: return .all
        case .exam: return .exam
        case .homework: return .homework
        case .reading: return .reading
        }
    }

    // MARK: - 视图模式菜单

    private var viewModeMenu: some View {
        Menu {
            Picker("View Mode".localized(), selection: $viewMode) {
                ForEach(ExamViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: viewMode == .calendar ? "calendar" : "list.bullet")
        }
        .onChange(of: viewMode) { _, newValue in
            newValue.saveToDefaults()
        }
    }

    // MARK: - 新增菜单

    private var addMenu: some View {
        Menu {
            Button {
                showingNewExam = true
            } label: {
                Label("New Exam".localized(), systemImage: "calendar.badge.plus")
            }
            Button {
                showingNewTask = .homework
            } label: {
                Label("New Homework".localized(), systemImage: "pencil.and.list.clipboard")
            }
            Button {
                showingNewTask = .reading
            } label: {
                Label("New Reading".localized(), systemImage: "book.fill")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    // MARK: - 行为

    private func tapped(_ entry: TodoEntry) {
        switch entry.kind {
        case .exam:
            if let exam = entry.exam { selectedExam = exam }
        case .comprehensiveExam:
            if let comp = entry.comprehensiveExam { selectedComprehensive = comp }
        case .homework, .reading:
            if let task = entry.taskItem { selectedTask = task }
        }
    }

    private func toggleCompletion(of entry: TodoEntry) {
        guard let task = entry.taskItem else { return }
        dataManager.setTaskCompletion(task.id, isCompleted: !task.isCompleted)
    }

    private func deleteEntry(_ entry: TodoEntry) {
        switch entry.kind {
        case .exam:
            if let exam = entry.exam, let idx = dataManager.examSets.firstIndex(where: { $0.id == exam.id }) {
                dataManager.examSets.remove(at: idx)
                dataManager.saveExamSets()
            }
        case .comprehensiveExam:
            if let comp = entry.comprehensiveExam, let idx = dataManager.comprehensiveExamSets.firstIndex(where: { $0.id == comp.id }) {
                dataManager.comprehensiveExamSets.remove(at: idx)
                dataManager.saveComprehensiveExams()
            }
        case .homework, .reading:
            if let task = entry.taskItem {
                dataManager.deleteTask(task)
            }
        }
    }
}

// MARK: - 过期条目 Sheet

struct PastItemsSheet: View {
    let pastEntries: [TodoEntry]
    let onSelectExam: (Exam) -> Void
    let onSelectComprehensive: (comprehensiveExam) -> Void
    let onSelectTask: (TaskItem) -> Void
    let onDeleteEntry: (TodoEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(pastEntries) { entry in
                    Button {
                        dismiss()
                        switch entry.kind {
                        case .exam:
                            if let exam = entry.exam { onSelectExam(exam) }
                        case .comprehensiveExam:
                            if let comp = entry.comprehensiveExam { onSelectComprehensive(comp) }
                        case .homework, .reading:
                            if let task = entry.taskItem { onSelectTask(task) }
                        }
                    } label: {
                        pastRow(entry: entry)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDeleteEntry(entry)
                        } label: {
                            Label("Delete".localized(), systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            .navigationTitle("Past Items".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func pastRow(entry: TodoEntry) -> some View {
        HStack {
            typeIcon(for: entry)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .foregroundColor(Color(.label))
                Text(entry.subject)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
                Text(typeLabel(for: entry))
                    .font(.caption2)
                    .foregroundColor(typeColor(for: entry))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func typeIcon(for entry: TodoEntry) -> some View {
        switch entry.kind {
        case .exam:
            Image(systemName: "calendar")
                .foregroundColor(Color(.systemBlue))
        case .comprehensiveExam:
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundColor(Color(.systemPurple))
        case .homework:
            Image(systemName: "pencil.and.list.clipboard")
                .foregroundColor(Color(.systemGreen))
        case .reading:
            Image(systemName: "book.fill")
                .foregroundColor(Color(.systemIndigo))
        }
    }

    private func typeLabel(for entry: TodoEntry) -> String {
        switch entry.kind {
        case .exam: return "Exam".localized()
        case .comprehensiveExam: return "Compre.".localized()
        case .homework: return "Homework".localized()
        case .reading: return "Reading".localized()
        }
    }

    private func typeColor(for entry: TodoEntry) -> Color {
        switch entry.kind {
        case .exam: return Color(.systemBlue)
        case .comprehensiveExam: return Color(.systemPurple)
        case .homework: return Color(.systemGreen)
        case .reading: return Color(.systemIndigo)
        }
    }
}

#Preview {
    let dm = DataManager()
    dm.subjects = [Subject(name: "Mathematics", enabled: true), Subject(name: "Physics", enabled: true)]
    dm.examSets = [
        Exam(name: "Midterm Math", date: Date().addingTimeInterval(86400 * 3),
             importance: 4, subject: "Mathematics", examName: "Midterm", masteryDegree: 60)
    ]
    dm.taskItems = [
        TaskItem(title: "Ch.3 Exercises", type: .homework,
                 dueDate: Date().addingTimeInterval(86400),
                 reminderDate: Date().addingTimeInterval(86400 - 3600),
                 subject: "Mathematics", importance: 3, notes: "1-20"),
        TaskItem(title: "Read Physics Ch.5", type: .reading,
                 dueDate: Date().addingTimeInterval(86400 * 5),
                 reminderDate: Date().addingTimeInterval(86400 * 4),
                 subject: "Physics", importance: 2)
    ]
    return TodoView()
        .environmentObject(dm)
        .preferredColorScheme(.light)
}
