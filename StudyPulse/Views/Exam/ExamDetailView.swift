//
//  ExamDetailView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI
import EventKit

struct ExamDetailView: View {
    let exam: Exam
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditSheet = false
    @State private var showingCalendarAlert = false
    @State private var calendarAlertMessage = ""
    /// 预测目标(非空时弹出 ScorePredictionSheet)
    @State private var predictionTarget: PredictionTarget? = nil
    /// 复盘编辑器(为空时不弹)
    @State private var showingReviewSheet = false

    // 关联的错题
    var relatedMistakes: [MistakeNote] {
        dataManager.mistakeSets
            .filter { $0.subject == exam.subject }
            .sorted { $0.date > $1.date }
    }

    /// 始终从 dataManager 拿最新的 Exam（确保 checklist 勾选状态等实时同步）
    /// Always read the latest Exam snapshot from dataManager so checklist toggles etc. are reflected immediately.
    private var currentExam: Exam {
        dataManager.examSets.first(where: { $0.id == exam.id }) ?? exam
    }

    /// 倒计时通知天数（默认 [1, 3, 5, 10, 30]）
    /// Countdown notification days (default [1, 3, 5, 10, 30])
    private var effectiveNotifyDays: [Int] {
        currentExam.countdownNotifyDays ?? [1, 3, 5, 10, 30]
    }

    var body: some View {
        Form {
            Section(header: Text("Overview".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                LabeledContent("Exam Name".localized(), value: currentExam.name)
                    .foregroundColor(Color(.label))
                LabeledContent("Subject".localized(), value: currentExam.subject)
                    .foregroundColor(Color(.label))

                LabeledContent("Date".localized(), value: currentExam.examDate.formatted(date: .complete, time: .omitted))
                    .foregroundColor(Color(.label))

                if !currentExam.examName.isEmpty {
                    LabeledContent("Note/Title".localized(), value: currentExam.examName)
                        .foregroundColor(Color(.label))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section(header: Text("Metrics".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                HStack {
                    Text("Importance".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= currentExam.importance ? "star.fill" : "star")
                                .foregroundColor(i <= currentExam.importance ? .yellow : Color(.tertiaryLabel))
                        }
                    }
                }

                HStack {
                    Text("Mastery Degree".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text("\(currentExam.masteryDegree)%")
                        .fontWeight(.semibold)
                        .foregroundColor(masteryColor)
                }
                ProgressView(value: Double(currentExam.masteryDegree), total: 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: masteryProgressColor))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section(header: Text("Time Status".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: currentExam.examDate).day ?? 0
                HStack {
                    Text("Days Remaining".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text("\(max(0, daysLeft)) days")
                        .fontWeight(.semibold)
                        .foregroundColor(daysLeft <= 3 ? Color(.systemRed) : Color(.label))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 考场信息
            Section(header: Text("Exam Location".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                if currentExam.locationSchool.isEmpty &&
                   currentExam.locationClassroom.isEmpty &&
                   currentExam.locationSeat.isEmpty {
                    HStack {
                        Image(systemName: "mappin.slash")
                            .foregroundColor(.secondary)
                        Text("No location set".localized())
                            .foregroundColor(.secondary)
                    }
                } else {
                    if !currentExam.locationSchool.isEmpty {
                        LabeledContent("School".localized(), value: currentExam.locationSchool)
                            .foregroundColor(Color(.label))
                    }
                    if !currentExam.locationClassroom.isEmpty {
                        LabeledContent("Classroom".localized(), value: currentExam.locationClassroom)
                            .foregroundColor(Color(.label))
                    }
                    if !currentExam.locationSeat.isEmpty {
                        LabeledContent("Seat".localized(), value: currentExam.locationSeat)
                            .foregroundColor(Color(.label))
                    }
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 考前待办清单
            Section {
                if currentExam.checklist.isEmpty {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(.secondary)
                        Text("No checklist items. Tap Edit to add some.".localized())
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(currentExam.checklist.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                        ChecklistRowView(
                            item: item,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    dataManager.toggleExamChecklistItem(currentExam.id, itemId: item.id)
                                }
                            }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Pre-Exam Checklist".localized())
                        .foregroundColor(Color(.secondaryLabel))
                    Spacer()
                    Text(String(format: "%d / %d".localized(),
                                currentExam.checklist.filter { $0.isChecked }.count,
                                currentExam.checklist.count))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 倒计时通知
            Section {
                if effectiveNotifyDays.isEmpty {
                    HStack {
                        Image(systemName: "bell.slash")
                            .foregroundColor(.secondary)
                        Text("Notifications disabled".localized())
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.accentColor)
                        Text(String(format: "Notify me %@ day(s) before the exam".localized(),
                                    effectiveNotifyDays.sorted(by: >).map(String.init).joined(separator: ", ")))
                            .foregroundColor(Color(.label))
                            .font(.subheadline)
                    }
                }
                Button {
                    ExamPrepareNotifications.shared.requestAuthorization()
                    ExamPrepareNotifications.shared.scheduleNotifications(
                        for: currentExam.name,
                        date: currentExam.examDate,
                        days: effectiveNotifyDays
                    )
                    calendarAlertMessage = "Notifications rescheduled.".localized()
                    showingCalendarAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.bell")
                            .foregroundColor(.accentColor)
                        Text("Reschedule Notifications".localized())
                            .foregroundColor(.accentColor)
                    }
                }
            } header: {
                Text("Countdown Notifications".localized())
                    .foregroundColor(Color(.secondaryLabel))
            } footer: {
                Text("Default schedule: 1, 3, 5, 10, 30 day(s) before the exam. Edit the exam to customize.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 添加到日历
            Section {
                Button(action: { addToCalendar() }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Add to Calendar".localized())
                            .foregroundColor(.accentColor)
                    }
                }
            } footer: {
                Text(currentExam.timeSlot != nil
                     ? "Will create a timed event with a 1-day advance reminder in your system calendar.".localized()
                     : "Will create an all-day event with a 1-day advance reminder in your system calendar.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 分享给家人
            Section {
                ShareLink(
                    item: shareText,
                    subject: Text(currentExam.name),
                    message: Text("Exam Details".localized())
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Share with Family".localized())
                            .foregroundColor(.accentColor)
                    }
                }
            } footer: {
                Text("Generate a summary of the exam (date, subject, location) and share it via WeChat, Mail, Messages, etc.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 关联的错题
            Section(header: Text("Related Mistakes".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                if relatedMistakes.isEmpty {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                        Text("No related mistakes for this subject".localized())
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                } else {
                    ForEach(relatedMistakes.prefix(4)) { mistake in
                        NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistake).environmentObject(dataManager)) {
                            RelatedMistakeCard(mistake: mistake)
                        }
                    }

                    if relatedMistakes.count > 4 {
                        HStack {
                            Spacer()
                            Text(String(format: "+ %d more mistakes".localized(), relatedMistakes.count - 4))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 考试复盘
            examReviewSection

            // MARK: - 预测入口
            Section {
                Button {
                    openPrediction()
                } label: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Predict Next Score".localized())
                            .foregroundColor(.accentColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            } header: {
                Text("Score Prediction".localized())
                    .foregroundColor(Color(.secondaryLabel))
            } footer: {
                Text("Uses the last 5 same-subject grades to predict a 95% confidence interval for the next exam.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentExam.name)
        .navigationBarTitleDisplayMode(.large)
        .adaptiveMaxWidth(720)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    openPrediction()
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
                .accessibilityLabel("Predict".localized())
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit".localized()) {
                    showingEditSheet = true
                }
                .foregroundColor(Color(.systemBlue))
            }
        }
        .sheet(item: $predictionTarget) { target in
            ScorePredictionSheet(
                exam: target.exam,
                history: target.history,
                fullScore: target.fullScore,
                onDismiss: { predictionTarget = nil }
            )
            .adaptiveSheet(detents: [.medium, .large])
        }
        .sheet(isPresented: $showingEditSheet) {
            ExamDetailEditView(exam: currentExam)
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingReviewSheet) {
            ExamReviewView(exam: currentExam)
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
        .alert("Calendar".localized(), isPresented: $showingCalendarAlert) {
            Button("OK".localized()) { }
        } message: {
            Text(calendarAlertMessage)
        }
    }

    private func addToCalendar() {
        Task {
            do {
                _ = try await CalendarManager.shared.addExamToCalendar(
                    examName: currentExam.name,
                    subject: currentExam.subject,
                    examDate: currentExam.examDate,
                    startTime: currentExam.timeSlot?.startTime,
                    endTime: currentExam.timeSlot?.endTime,
                    note: currentExam.examName.isEmpty ? nil : currentExam.examName
                )
                await MainActor.run {
                    calendarAlertMessage = "Successfully added to calendar!".localized()
                    showingCalendarAlert = true
                }
            } catch {
                await MainActor.run {
                    calendarAlertMessage = error.localizedDescription
                    showingCalendarAlert = true
                }
            }
        }
    }

    /// 打开预测 Sheet(用同科目历史成绩 + 满分)
    private func openPrediction() {
        let subjectGrades = dataManager.filteredGrades
            .filter { $0.subject == currentExam.subject }
        let fullScore = dataManager.subjects.first(where: { $0.name == currentExam.subject })?.fullScore ?? 100
        predictionTarget = PredictionTarget(
            exam: currentExam,
            history: subjectGrades,
            fullScore: fullScore
        )
    }

    /// 构造可分享的考试信息文本
    /// Build a shareable text summary of the exam.
    private var shareText: String {
        var lines: [String] = []
        lines.append("📚 " + currentExam.name)
        lines.append("📅 " + currentExam.examDate.formatted(date: .complete, time: .omitted))
        if let slot = currentExam.timeSlot {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            lines.append("⏰ " + String(format: "%@ - %@".localized(), fmt.string(from: slot.startTime), fmt.string(from: slot.endTime)))
        }
        lines.append("📝 " + currentExam.subject.localized())
        if !currentExam.locationSchool.isEmpty {
            var loc = "📍 " + currentExam.locationSchool
            if !currentExam.locationClassroom.isEmpty {
                loc += " · " + currentExam.locationClassroom
            }
            if !currentExam.locationSeat.isEmpty {
                loc += " · Seat: " + currentExam.locationSeat
            }
            lines.append(loc)
        }
        let unchecked = currentExam.checklist.filter { !$0.isChecked }
        if !unchecked.isEmpty {
            lines.append("")
            lines.append("✅ " + "Checklist".localized() + ":")
            for item in unchecked.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                lines.append("  • " + item.title)
            }
        }
        lines.append("")
        lines.append("— from StudyPulse")
        return lines.joined(separator: "\n")
    }

    // MARK: - 复盘 Section
    // Exam review section: shows 4-section rendered markdown, lets user
    // fill/edit the review, and share the full review as Markdown.

    /// 4 段复盘 Section(若有则展示 + 分享;若否则引导填写 + 24h 提醒说明)
    @ViewBuilder
    private var examReviewSection: some View {
        if let review = currentExam.examReview {
            Section {
                // 顶部元信息行:复盘时间 + 操作按钮
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(.systemGreen))
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reviewed On".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(review.reviewedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Button {
                        showingReviewSheet = true
                    } label: {
                        Text("Edit Review".localized())
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                // 4 段折叠预览
                ReviewSectionRow(
                    title: "What Was Tested".localized(),
                    icon: "doc.text.magnifyingglass",
                    markdown: review.whatWasTested
                )
                ReviewSectionRow(
                    title: "What Went Wrong".localized(),
                    icon: "exclamationmark.triangle",
                    markdown: review.whatWentWrong
                )
                ReviewSectionRow(
                    title: "What I Learned".localized(),
                    icon: "lightbulb",
                    markdown: review.whatLearned
                )
                ReviewSectionRow(
                    title: "Next Strategy".localized(),
                    icon: "arrow.uturn.forward",
                    markdown: review.nextStrategy
                )

                // 关联错题
                if !review.linkedMistakeIds.isEmpty {
                    NavigationLink {
                        LinkedMistakesListView(
                            mistakeIds: review.linkedMistakeIds,
                            subject: currentExam.subject
                        )
                        .environmentObject(dataManager)
                    } label: {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.accentColor)
                            Text("Linked Mistakes".localized())
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%d".localized(), review.linkedMistakeIds.count))
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }

                // 分享整段复盘
                ShareLink(
                    item: review.fullShareText,
                    subject: Text("Exam Review · \(currentExam.name)"),
                    message: Text("Post-Exam Review".localized())
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Share Review".localized())
                            .foregroundColor(.accentColor)
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            } header: {
                Text("Exam Review".localized())
                    .foregroundColor(Color(.secondaryLabel))
            } footer: {
                Text("A reflection filled in within 24h of the exam. Edit anytime to add new insights.".localized())
                    .foregroundColor(.secondary)
            }
        } else {
            Section {
                Button {
                    showingReviewSheet = true
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fill Out Review".localized())
                                .foregroundColor(.accentColor)
                                .fontWeight(.medium)
                            Text("4-section Markdown: tested / wrong / learned / strategy".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            } header: {
                Text("Exam Review".localized())
                    .foregroundColor(Color(.secondaryLabel))
            } footer: {
                Text(reviewReminderFooter)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// "复盘窗口说明" 页脚文案:考试已结束 24h 后改为"窗口已关闭"提示
    private var reviewReminderFooter: String {
        let baseDate = currentExam.examEndDate ?? currentExam.examDate
        let elapsed = Date().timeIntervalSince(baseDate)
        if elapsed > 24 * 3600 {
            return "The 24h review window has closed. You can still fill it out now — useful as a delayed reflection.".localized()
        } else {
            return "We'll remind you to fill this out 24h after the exam ends.".localized()
        }
    }

    // 根据掌握程度确定颜色
    private var masteryColor: Color {
        if currentExam.masteryDegree <= 20 {
            return Color(.systemRed)
        } else if currentExam.masteryDegree <= 60 {
            return Color(.systemOrange)
        } else {
            return Color(.systemGreen)
        }
    }

    // 进度条颜色
    private var masteryProgressColor: Color {
        if currentExam.masteryDegree <= 20 {
            return Color(.systemRed)
        } else if currentExam.masteryDegree <= 60 {
            return Color(.systemOrange)
        } else {
            return Color(.systemBlue)
        }
    }
}

// MARK: - Checklist Row

struct ChecklistRowView: View {
    let item: ExamChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isChecked ? Color(.systemGreen) : Color(.tertiaryLabel))
                Text(item.title)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundColor(item.isChecked ? Color(.secondaryLabel) : Color(.label))
                    .font(.subheadline)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let dm = DataManager()
    let testExam = Exam(
        name: "Test",
        date: Date().addingTimeInterval(1000),
        importance: 3,
        subject: "Math",
        examName: "",
        masteryDegree: 50,
        checklist: [
            ExamChecklistItem(title: "身份证", sortOrder: 0),
            ExamChecklistItem(title: "准考证", isChecked: true, sortOrder: 1),
            ExamChecklistItem(title: "2B 铅笔 + 橡皮", sortOrder: 2)
        ],
        locationSchool: "市一中",
        locationClassroom: "教学楼 3 楼 305",
        locationSeat: "23"
    )
    dm.examSets = [testExam]
    return ExamDetailView(exam: testExam)
        .environmentObject(dm)
}

// MARK: - 关联的错题卡片
struct RelatedMistakeCard: View {
    let mistake: MistakeNote
    @State private var animateIn = false

    var totalImages: Int {
        mistake.questionImages.count + mistake.reasonImages.count +
        mistake.wrongSolutionImages.count + mistake.correctSolutionImages.count
    }

    var daysSinceAdded: String {
        let components = Calendar.current.dateComponents([.day], from: mistake.date, to: Date())
        let days = components.day ?? 0
        if days == 0 {
            return "Today".localized()
        } else if days == 1 {
            return "Yesterday".localized()
        } else if days < 7 {
            return "\(days) " + "days ago".localized()
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: mistake.date)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mistake.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !mistake.originalQuestion.isEmpty {
                    Text(mistake.originalQuestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if !mistake.subject.isEmpty {
                        Text(mistake.subject.localized())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemPurple).opacity(0.15))
                            .foregroundColor(Color(.systemPurple))
                            .cornerRadius(4)
                    }

                    Text(daysSinceAdded)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if totalImages > 0 {
                        Label("\(totalImages)", systemImage: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : -15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                animateIn = true
            }
        }
    }
}

#Preview("Dark Mode") {
    let dm = DataManager()
    let testExam = Exam(name: "Test", date: Date().addingTimeInterval(1000), importance: 3, subject: "Math", examName: "", masteryDegree: 50)
    dm.examSets = [testExam]
    return ExamDetailView(exam: testExam)
        .environmentObject(dm)
        .preferredColorScheme(.dark)
}

// MARK: - 复盘 4 段行(折叠预览)

/// 复盘单段折叠行:点击展开渲染后的 Markdown。
/// Collapsible row showing a single review section's rendered markdown.
struct ReviewSectionRow: View {
    let title: String
    let icon: String
    let markdown: String

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Empty".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                MarkdownPreviewView(text: markdown)
                    .frame(minHeight: 80)
                    .frame(maxHeight: 240)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if markdown.isEmpty {
                    Text("Empty".localized())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listRowBackground(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - 关联错题列表(从复盘跳进去看)

/// 复盘"关联错题"行点击进入的子页面:列出复盘里勾选的所有错题。
/// Sub-page shown when tapping "Linked Mistakes" on the review — lists
/// the mistakes the user ticked in the review editor.
struct LinkedMistakesListView: View {
    let mistakeIds: [UUID]
    let subject: String

    @EnvironmentObject var dataManager: DataManager

    /// 实际能查到的错题(过滤掉已删除的 id)
    private var resolved: [MistakeNote] {
        dataManager.mistakeSets.filter { mistakeIds.contains($0.id) }
    }

    var body: some View {
        Form {
            if resolved.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(.secondary)
                        Text("No related mistakes for this subject".localized())
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Section {
                    ForEach(resolved) { mistake in
                        NavigationLink {
                            MistakeSetDetailView(mistakeSet: mistake)
                                .environmentObject(dataManager)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mistake.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !mistake.subject.isEmpty {
                                    Text(mistake.subject.localized())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Linked Mistakes".localized())
                } footer: {
                    Text(String(format: "%d mistakes".localized(), resolved.count))
                }
            }
        }
        .navigationTitle("Linked Mistakes".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}
