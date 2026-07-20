//
//  DiarySettingsView.swift
//  StudyPulse
//
//  学习日记设置子页:启用开关 / 每日提醒 / Apple Health 同步 / AI 元认知反思。
//  Diary settings sub-page: master toggle / daily reminder / Apple Health
//  sync / AI metacognition reflection.
//

import SwiftUI

struct DiarySettingsView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    /// DatePicker 用的小时:分钟 → Date 转换辅助
    /// Helper to bridge Int hour ↔ Date for the DatePicker.
    private func hourToDate(_ hour: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        return cal.date(bySettingHour: max(0, min(23, hour)), minute: 0, second: 0, of: now) ?? now
    }

    private func dateToHour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 总开关 / Master Toggle
                Section {
                    Toggle(isOn: Binding(
                        get: { container.envManager.preferences.diaryEnabled },
                        set: { container.envManager.preferences.diaryEnabled = $0 }
                    )) {
                        Label("Enable Study Diary".localized(), systemImage: "book.fill")
                    }
                } footer: {
                    Text("Adds a Study Diary card to the home screen for daily mood and energy tracking.".localized())
                }

                // MARK: - 每日提醒 / Daily Reminder
                Section {
                    Toggle(isOn: Binding(
                        get: { container.envManager.preferences.diaryDailyReminderEnabled },
                        set: { newValue in
                            container.envManager.preferences.diaryDailyReminderEnabled = newValue
                            DiaryReminderNotifications.shared.reschedule(
                                enabled: newValue,
                                hour: container.envManager.preferences.diaryDailyReminderHour
                            )
                        }
                    )) {
                        Label("Daily Reminder".localized(), systemImage: "bell.badge")
                    }

                    if container.envManager.preferences.diaryDailyReminderEnabled {
                        DatePicker(
                            "Reminder Time".localized(),
                            selection: Binding(
                                get: { hourToDate(container.envManager.preferences.diaryDailyReminderHour) },
                                set: { newDate in
                                    let hour = dateToHour(newDate)
                                    container.envManager.preferences.diaryDailyReminderHour = hour
                                    DiaryReminderNotifications.shared.reschedule(
                                        enabled: container.envManager.preferences.diaryDailyReminderEnabled,
                                        hour: hour
                                    )
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                } footer: {
                    Text("A daily notification nudges you to log your mood and reflections.".localized())
                }

                // MARK: - Apple Health 同步 / Apple Health Sync
                Section {
                    Toggle(isOn: Binding(
                        get: { container.envManager.preferences.diarySyncToHealthEnabled },
                        set: { newValue in
                            container.envManager.preferences.diarySyncToHealthEnabled = newValue
                            if newValue {
                                Task {
                                    await HealthKitManager.shared.requestDiaryAuthorization()
                                }
                            }
                        }
                    )) {
                        Label("Sync to Apple Health".localized(), systemImage: "heart.text.square")
                    }
                } header: {
                    Text("Apple Health".localized())
                } footer: {
                    Text("Writes a 1-minute Mindful Session to Apple Health each time you log a diary entry. Mood values stay on-device and are not uploaded.".localized())
                }

                // MARK: - AI 元认知反思 / AI Metacognition Reflection
                Section {
                    Toggle(isOn: Binding(
                        get: { container.envManager.preferences.diaryLLMReflectionEnabled },
                        set: { container.envManager.preferences.diaryLLMReflectionEnabled = $0 }
                    )) {
                        Label("AI Metacognition Reflection".localized(), systemImage: "brain.head.profile")
                    }
                } header: {
                    Text("AI Reflection".localized())
                } footer: {
                    Text("When enabled, weekly and monthly reports include a 4th \"Metacognition Reflection\" section that connects your mood / energy with study performance to guide self-awareness. Requires LLM to be configured.".localized())
                }

                // MARK: - 数据管理 / Data Management
                Section {
                    Button(role: .destructive) {
                        _ = container.diaryRepo.clearAll()
                    } label: {
                        Label("Clear All Diary Entries".localized(), systemImage: "trash")
                    }
                    .disabled(container.diaryRepo.diaryEntries.isEmpty)
                } footer: {
                    Text("Removes all diary entries from this device. Apple Health Mindful Session records are not removed.".localized())
                }
            }
            .navigationTitle("Diary Settings".localized())
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(.clear, for: .navigation)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).opacity(0.4).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) { dismiss() }
                }
            }
        }
    }
}

// MARK: - 预览 / Preview

#Preview {
    DiarySettingsView()
        .environment(RepositoryContainer())
}
