//
//  ExamDetailEditView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI
import os

struct ExamDetailEditView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode

    // 接收要编辑的原始对象
    let originalExam: Exam

    // 绑定到表单的状态变量 (初始化为原始值)
    @State private var name: String
    @State private var selectedSubject: String
    @State private var examDate: Date
    @State private var importance: Int
    @State private var masteryDegree: Int
    @State private var examNote: String
    @State private var subjectStartTime: Date
    @State private var subjectEndTime: Date
    // 考前待办 / 考场 / 倒计时通知
    @State private var checklist: [ExamChecklistItem]
    @State private var locationSchool: String
    @State private var locationClassroom: String
    @State private var locationSeat: String
    @State private var notifyDays: Set<Int>
    @State private var newChecklistText: String = ""

    /// 考前 N 天倒计时通知的候选天数
    /// Candidate day options for the pre-exam countdown.
    private static let candidateDays: [Int] = [1, 2, 3, 5, 7, 10, 14, 21, 30]

    init(exam: Exam) {
        self.originalExam = exam
        // 初始化状态
        _name = State(initialValue: exam.name)
        _selectedSubject = State(initialValue: exam.subject)
        _examDate = State(initialValue: exam.examDate)
        _importance = State(initialValue: exam.importance)
        _masteryDegree = State(initialValue: exam.masteryDegree)
        _examNote = State(initialValue: exam.examName)
        let slot = exam.timeSlot
        _subjectStartTime = State(initialValue: slot?.startTime ?? exam.examDate)
        _subjectEndTime = State(initialValue: slot?.endTime ?? Calendar.current.date(byAdding: .hour, value: 2, to: slot?.startTime ?? exam.examDate) ?? exam.examDate)
        _checklist = State(initialValue: exam.checklist)
        _locationSchool = State(initialValue: exam.locationSchool)
        _locationClassroom = State(initialValue: exam.locationClassroom)
        _locationSeat = State(initialValue: exam.locationSeat)
        // 默认使用 [1, 3, 5, 10, 30] —— 跟 ExamDetailView / ExamPrepareNotifications 默认值保持一致
        _notifyDays = State(initialValue: Set(exam.countdownNotifyDays ?? [1, 3, 5, 10, 30]))
    }

    private var availableSubjects: [String] {
        dataManager.subjects.filter { $0.enabled }.map { $0.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info".localized())) {
                    TextField("Exam Name".localized(), text: $name)

                    Picker("Subject".localized(), selection: $selectedSubject) {
                        ForEach(availableSubjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }

                    DatePicker("Date".localized(), selection: $examDate, displayedComponents: .date)

                    DatePicker("Start Time".localized(), selection: $subjectStartTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time".localized(), selection: $subjectEndTime, displayedComponents: .hourAndMinute)
                }

                Section(header: Text("Assessment".localized())) {
                    // 重要性
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Importance".localized())
                            Spacer()
                            Text("\(importance) / 5".localized())
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= importance ? "star.fill" : "star")
                                    .foregroundColor(index <= importance ? .yellow : .gray)
                                    .font(.title3)
                                    .onTapGesture {
                                        withAnimation { importance = index }
                                    }
                            }
                        }
                    }

                    // 掌握程度
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Mastery Degree".localized())
                            Spacer()
                            Text("\(masteryDegree)%".localized())
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(
                            get: { Double(masteryDegree) },
                            set: { masteryDegree = Int($0) }
                        ), in: 0...100, step: 5)
                    }
                }

                Section(header: Text("Notes".localized())) {
                    TextField("Specific Exam Title or Notes".localized(), text: $examNote)
                }

                // MARK: - 考场信息
                Section(header: Text("Exam Location".localized()),
                        footer: Text("Fill in the school / classroom / seat number so you can find it on exam day.".localized())) {
                    TextField("School".localized(), text: $locationSchool)
                    TextField("Classroom".localized(), text: $locationClassroom)
                    TextField("Seat".localized(), text: $locationSeat)
                }

                // MARK: - 考前待办清单
                Section(header: Text("Pre-Exam Checklist".localized()),
                        footer: Text("Tap a row to mark as done. Examples: ID, admission ticket, stationery, review list.".localized())) {
                    if checklist.isEmpty {
                        HStack {
                            Image(systemName: "checklist")
                                .foregroundColor(.secondary)
                            Text("No items yet".localized())
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    } else {
                        ForEach(checklist.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                            HStack {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isChecked ? Color(.systemGreen) : Color(.tertiaryLabel))
                                TextField("Item".localized(), text: Binding(
                                    get: { item.title },
                                    set: { newValue in
                                        if let idx = checklist.firstIndex(where: { $0.id == item.id }) {
                                            checklist[idx].title = newValue
                                        }
                                    }
                                ))
                                .strikethrough(item.isChecked, color: .secondary)
                                .foregroundColor(item.isChecked ? Color(.secondaryLabel) : Color(.label))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    checklist.removeAll { $0.id == item.id }
                                } label: {
                                    Label("Delete".localized(), systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                if let idx = checklist.firstIndex(where: { $0.id == item.id }) {
                                    checklist[idx].isChecked.toggle()
                                }
                            }
                        }
                        .onMove { source, destination in
                            var sorted = checklist.sorted(by: { $0.sortOrder < $1.sortOrder })
                            sorted.move(fromOffsets: source, toOffset: destination)
                            for (i, _) in sorted.enumerated() {
                                sorted[i].sortOrder = i
                            }
                            checklist = sorted
                        }
                    }
                    HStack {
                        TextField("Add item (e.g. 身份证, 2B 铅笔, 复习清单)".localized(), text: $newChecklistText)
                            .submitLabel(.done)
                            .onSubmit { addChecklistItem() }
                        Button {
                            addChecklistItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newChecklistText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // MARK: - 倒计时通知
                Section(header: Text("Countdown Notifications".localized()),
                        footer: Text("Pick how many days before the exam you want a reminder. Empty = no notifications. Save will reschedule.".localized())) {
                    ForEach(Self.candidateDays, id: \.self) { day in
                        Toggle(isOn: Binding(
                            get: { notifyDays.contains(day) },
                            set: { isOn in
                                if isOn { notifyDays.insert(day) } else { notifyDays.remove(day) }
                            }
                        )) {
                            Text(String(format: "%d day(s) before".localized(), day))
                        }
                    }
                }
            }
            .adaptiveForm()
            .navigationTitle("Edit Exam".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized()) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized()) {
                        updateExam()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addChecklistItem() {
        let trimmed = newChecklistText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (checklist.map(\.sortOrder).max() ?? -1) + 1
        checklist.append(ExamChecklistItem(title: trimmed, sortOrder: nextOrder))
        newChecklistText = ""
    }

    private func updateExam() {
        // 构造新的 Exam
        let updatedExam = Exam(
            id: originalExam.id,
            name: name.trimmingCharacters(in: .whitespaces),
            date: examDate,
            importance: importance,
            subject: selectedSubject,
            examName: examNote.trimmingCharacters(in: .whitespaces),
            masteryDegree: masteryDegree,
            timeSlot: ExamTimeSlot(startTime: subjectStartTime, endTime: subjectEndTime),
            examEndDate: originalExam.examEndDate,
            phaseId: originalExam.phaseId,
            checklist: checklist,
            locationSchool: locationSchool.trimmingCharacters(in: .whitespaces),
            locationClassroom: locationClassroom.trimmingCharacters(in: .whitespaces),
            locationSeat: locationSeat.trimmingCharacters(in: .whitespaces),
            countdownNotifyDays: Array(notifyDays).sorted()
        )

        // 通知：先取消旧的，再用新的天数列表重排
        ExamPrepareNotifications.shared.cancelNotifications(for: originalExam.name)
        if !notifyDays.isEmpty {
            ExamPrepareNotifications.shared.scheduleNotifications(
                for: updatedExam.name,
                date: updatedExam.examDate,
                days: Array(notifyDays).sorted()
            )
        }

        // 写回 DataManager（同时落盘 SwiftData）
        dataManager.updateExam(updatedExam)
        Log.data.info("考试编辑成功 / Exam updated: name=\(updatedExam.name, privacy: .public) id=\(originalExam.id.uuidString, privacy: .public) checklist=\(updatedExam.checklist.count, privacy: .public) notifyDays=\(Array(notifyDays).sorted(), privacy: .public)")
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    let dm = DataManager()
    let testExam = Exam(
        name: "Final Physics",
        date: Date().addingTimeInterval(86400 * 20),
        importance: 5,
        subject: "Physics",
        examName: "Mechanics",
        masteryDegree: 40,
        checklist: [
            ExamChecklistItem(title: "身份证", sortOrder: 0),
            ExamChecklistItem(title: "2B 铅笔", sortOrder: 1)
        ],
        locationSchool: "市一中",
        locationClassroom: "305",
        locationSeat: "23"
    )
    dm.examSets = [testExam]

    return ExamDetailEditView(exam: testExam)
        .environmentObject(dm)
}
