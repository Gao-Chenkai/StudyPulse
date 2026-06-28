//
//  DailyGoalsConfigView.swift
//  StudyPulse
//
//  每日目标阈值配置页。
//  User-configurable daily targets: mistake reviews, grade records, focus minutes,
//  plus the daily reminder toggle and time picker.
//

import SwiftUI

struct DailyGoalsConfigView: View {
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var mistakeTarget: Int
    @State private var gradeTarget: Int
    @State private var focusTarget: Int
    @State private var reminderEnabled: Bool
    @State private var reminderHour: Int
    @State private var reminderMinute: Int

    init() {
        let config = AchievementManager.shared.snapshot.config
        _mistakeTarget = State(initialValue: config.mistakeReviewTarget)
        _gradeTarget = State(initialValue: config.gradeRecordTarget)
        _focusTarget = State(initialValue: config.focusMinutesTarget)
        _reminderEnabled = State(initialValue: config.reminderEnabled)
        _reminderHour = State(initialValue: config.reminderHour)
        _reminderMinute = State(initialValue: config.reminderMinute)
    }

    var body: some View {
        let currentConfig = achievementManager.snapshot.config
        let hasChanges = mistakeTarget != currentConfig.mistakeReviewTarget
            || gradeTarget != currentConfig.gradeRecordTarget
            || focusTarget != currentConfig.focusMinutesTarget
            || reminderEnabled != currentConfig.reminderEnabled
            || reminderHour != currentConfig.reminderHour
            || reminderMinute != currentConfig.reminderMinute

        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set your daily minimums. Reach any one goal to keep your streak alive.".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                StepperRow(
                    icon: "rectangle.stack.fill",
                    color: .purple,
                    title: "Mistake Reviews".localized(),
                    value: $mistakeTarget,
                    range: DailyGoalConfig.Bounds.mistakeReviewRange,
                    unit: "cards".localized()
                )
            }

            Section {
                StepperRow(
                    icon: "list.bullet.rectangle",
                    color: .blue,
                    title: "Grades Recorded".localized(),
                    value: $gradeTarget,
                    range: DailyGoalConfig.Bounds.gradeRecordRange,
                    unit: "entries".localized()
                )
            }

            Section {
                StepperRow(
                    icon: "timer",
                    color: .orange,
                    title: "Focus Minutes".localized(),
                    value: $focusTarget,
                    range: DailyGoalConfig.Bounds.focusMinutesRange,
                    unit: "min".localized()
                )
            }

            Section {
                Toggle(isOn: $reminderEnabled) {
                    Label("Daily Reminder".localized(), systemImage: "bell.fill")
                        .foregroundColor(.primary)
                }

                if reminderEnabled {
                    HStack {
                        Label("Reminder Time".localized(), systemImage: "clock")
                            .foregroundColor(.primary)
                        Spacer()
                        HStack(spacing: 4) {
                            Picker("Hour".localized(), selection: $reminderHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(String(format: "%02d", hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 56)
                            Text(":")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.secondary)
                            Picker("Minute".localized(), selection: $reminderMinute) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text(String(format: "%02d", minute)).tag(minute)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 56)
                        }
                    }
                }
            } footer: {
                Text("We’ll check at this time whether you’ve completed any daily goal. If not, a gentle nudge will remind you.".localized())
            }

            if hasChanges {
                Section {
                    Button {
                        saveConfig()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Save Goals".localized(), systemImage: "checkmark")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Daily Goals".localized())
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private func saveConfig() {
        let config = DailyGoalConfig(
            mistakeReviewTarget: mistakeTarget,
            gradeRecordTarget: gradeTarget,
            focusMinutesTarget: focusTarget,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
        achievementManager.updateConfig(config, markCustomized: true)
        DailyGoalReminder.shared.reschedule(for: Date(), config: config)
    }
}

// MARK: - Stepper Row

private struct StepperRow: View {
    let icon: String
    let color: Color
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Stepper("\(value) \(unit)", value: $value, in: range)
                .labelsHidden()
            Text("\(value) \(unit)")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 56, alignment: .trailing)
        }
    }
}
