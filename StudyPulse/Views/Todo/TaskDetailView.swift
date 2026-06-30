//
//  TaskDetailView.swift
//  StudyPulse
//
//  作业 / 阅读材料任务详情页：展示完整字段、提供标记完成、编辑、绑定到系统 Reminders。
//  Task detail page: shows full fields, supports toggle completion, edit, and binding to system Reminders.
//

import SwiftUI

struct TaskDetailView: View {
    let task: TaskItem
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditSheet: Bool = false
    @State private var showingReminderAlert: Bool = false
    @State private var reminderAlertMessage: String = ""

    /// 用于反映 dataManager 中实时状态（例如外部删除后页面同步）
    private var currentTask: TaskItem? {
        dataManager.taskItems.first(where: { $0.id == task.id })
    }

    private var typeColor: Color {
        task.type == .homework ? Color(.systemGreen) : Color(.systemIndigo)
    }

    private var typeLabel: String {
        task.type == .homework ? "Homework".localized() : "Reading".localized()
    }

    var body: some View {
        Group {
            if let current = currentTask {
                contentBody(for: current)
                    .navigationTitle(current.title)
                    .navigationBarTitleDisplayMode(.large)
            } else {
                ContentUnavailableView(
                    "Task Deleted".localized(),
                    systemImage: "trash",
                    description: Text("This task no longer exists.".localized())
                )
            }
        }
        .alert("Reminders".localized(), isPresented: $showingReminderAlert) {
            Button("OK".localized()) {}
        } message: {
            Text(reminderAlertMessage)
        }
    }

    @ViewBuilder
    private func contentBody(for current: TaskItem) -> some View {
        Form {
            // MARK: - 概览
            Section(header: Text("Overview".localized())
                .foregroundColor(Color(.secondaryLabel))) {
                HStack {
                    Image(systemName: current.type == .homework ? "pencil.and.list.clipboard" : "book.fill")
                        .foregroundColor(typeColor)
                    Text(typeLabel)
                        .font(.subheadline)
                        .foregroundColor(Color(.label))
                    Spacer()
                }
                LabeledContent("Title".localized(), value: current.title)
                    .foregroundColor(Color(.label))
                if !current.subject.isEmpty {
                    LabeledContent("Subject".localized(), value: current.subject)
                        .foregroundColor(Color(.label))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 时间
            Section(header: Text("Schedule".localized())
                .foregroundColor(Color(.secondaryLabel))) {
                LabeledContent("Due Date".localized(),
                               value: current.dueDate.formatted(date: .complete, time: .shortened))
                    .foregroundColor(Color(.label))
                LabeledContent("Reminder Time".localized(),
                               value: current.reminderDate.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(Color(.label))

                HStack {
                    Text("Days Until Due".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: current.dueDate).day ?? 0
                    Text("\(max(0, daysLeft)) " + "days".localized())
                        .fontWeight(.semibold)
                        .foregroundColor(daysLeft <= 1 ? Color(.systemRed) : (daysLeft <= 3 ? Color(.systemOrange) : Color(.label)))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 评估
            Section(header: Text("Assessment".localized())
                .foregroundColor(Color(.secondaryLabel))) {
                HStack {
                    Text("Importance".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= current.importance ? "star.fill" : "star")
                                .foregroundColor(i <= current.importance ? .yellow : Color(.tertiaryLabel))
                        }
                    }
                }
                HStack {
                    Text("Status".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    if current.isCompleted {
                        Label("Completed".localized(), systemImage: "checkmark.circle.fill")
                            .foregroundColor(Color(.systemGreen))
                            .font(.subheadline)
                    } else {
                        Text("Pending".localized())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 备注
            if !current.notes.isEmpty {
                Section(header: Text("Notes".localized())
                    .foregroundColor(Color(.secondaryLabel))) {
                    Text(current.notes)
                        .foregroundColor(Color(.label))
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }

            // MARK: - 同步状态
            Section(header: Text("Reminders".localized())
                .foregroundColor(Color(.secondaryLabel)),
                    footer: Text(current.reminderEventId == nil
                                 ? "This task is not synced to system Reminders.".localized()
                                 : "Synced with the system Reminders app.".localized())) {
                if current.reminderEventId == nil {
                    Button(action: { addToReminders(current) }) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.accentColor)
                            Text("Add to System Reminders".localized())
                                .foregroundColor(.accentColor)
                        }
                    }
                } else {
                    Label("Synced".localized(), systemImage: "bell.fill")
                        .foregroundColor(Color(.systemGreen))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .adaptiveMaxWidth(720)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit".localized(), systemImage: "pencil")
                    }
                    Button {
                        dataManager.setTaskCompletion(current.id, isCompleted: !current.isCompleted)
                    } label: {
                        if current.isCompleted {
                            Label("Mark Pending".localized(), systemImage: "circle")
                        } else {
                            Label("Mark Completed".localized(), systemImage: "checkmark.circle")
                        }
                    }
                    Button(role: .destructive) {
                        dataManager.deleteTask(current)
                    } label: {
                        Label("Delete".localized(), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskDetailEditView(task: current)
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
    }

    private func addToReminders(_ current: TaskItem) {
        Task {
            do {
                let result = try await CalendarManager.shared.addTaskToReminders(
                    title: current.title,
                    dueDate: current.dueDate,
                    alarmDate: current.reminderDate,
                    notes: current.notes,
                    subject: current.subject.isEmpty ? nil : current.subject
                )
                await MainActor.run {
                    dataManager.updateTask(current, reminderResult: result)
                    reminderAlertMessage = "Added to system Reminders.".localized()
                    showingReminderAlert = true
                }
            } catch {
                await MainActor.run {
                    reminderAlertMessage = "Failed: \(error.localizedDescription)"
                    showingReminderAlert = true
                }
            }
        }
    }
}

#Preview {
    let dm = DataManager()
    let task = TaskItem(
        title: "Math Homework Ch.3",
        type: .homework,
        dueDate: Date().addingTimeInterval(86400 * 2),
        reminderDate: Date().addingTimeInterval(86400),
        subject: "Mathematics",
        importance: 4,
        notes: "Problems 1-20"
    )
    dm.taskItems = [task]
    return NavigationStack {
        TaskDetailView(task: task)
            .environmentObject(dm)
    }
}
