//
//  PlantDebugView.swift
//  StudyPulse
//
//  Debug 模式专属：用于手动设置 Plant 阶段 / 触发 recompute / 查看内部状态。
//  Reachable from DebugView → "Experiments" → "Plant Lab" NavigationLink.
//
//  三大能力：
//  1. Force Override — 强制锁定到某个阶段（最高优先级，覆盖 derive 结果）
//  2. Simulation     — 模拟 streak.current / 距上次活跃天数，derive 看到的是模拟值
//  3. Inspection     — 实时查看 snapshot / 切换历史 / 内部状态
//

import SwiftUI

struct PlantDebugView: View {
    @EnvironmentObject private var envManager: AppEnvironmentManager
    @State private var plantManager = PlantManager.shared
    @ObservedObject private var achievementManager = AchievementManager.shared

    @State private var streakInput: String = ""
    @State private var daysInput: Double = 0
    @State private var showResetConfirm = false
    @State private var showClearHistoryConfirm = false

    private let daysRange: ClosedRange<Double> = 0...14

    var body: some View {
        List {
            inspectionSection
            forceStageSection
            simulationSection
            historySection
            actionsSection
            dangerSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("debug.plant.title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .alert("debug.plant.resetConfirmTitle".localized(),
               isPresented: $showResetConfirm) {
            Button("debug.plant.resetConfirm".localized(), role: .destructive) {
                plantManager.resetToSeed()
            }
            Button("common.cancel".localized(), role: .cancel) {}
        } message: {
            Text("debug.plant.resetConfirmMessage".localized())
        }
        .alert("debug.plant.clearHistoryConfirmTitle".localized(),
               isPresented: $showClearHistoryConfirm) {
            Button("debug.plant.clearHistoryConfirm".localized(), role: .destructive) {
                plantManager.clearHistory()
            }
            Button("common.cancel".localized(), role: .cancel) {}
        } message: {
            Text("debug.plant.clearHistoryConfirmMessage".localized())
        }
        .onAppear(perform: refreshFromManager)
        .onChange(of: plantManager.currentStage) { _, _ in refreshFromManager() }
    }

    // MARK: - Sections

    private var inspectionSection: some View {
        Section {
            LabeledContent("debug.plant.currentStage".localized(),
                           value: "\(plantManager.currentStage.localizedTitle) (\(plantManager.currentStage.rawValue))")
            LabeledContent("Streak.current", value: "\(achievementManager.snapshot.streak.current)")
            LabeledContent("Streak.totalActiveDays", value: "\(achievementManager.snapshot.streak.totalActiveDays)")
            LabeledContent("Today active", value: "\(achievementManager.todayGoalsMet)")
            if let lastActive = achievementManager.snapshot.streak.lastActiveDate {
                LabeledContent("Last active", value: lastActive.formatted(date: .abbreviated, time: .omitted))
            }
            if let lastAct = plantManager.lastActivityAt {
                LabeledContent("Plant lastActivityAt",
                               value: lastAct.formatted(date: .abbreviated, time: .standard))
            }

            HStack {
                Text("debug.plant.overrideState".localized())
                Spacer()
                if plantManager.hasForceOverride {
                    Label("debug.plant.overrideActive".localized(), systemImage: "lock.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                } else {
                    Label("debug.plant.overrideNone".localized(), systemImage: "lock.open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if plantManager.hasSimulatedStreak || plantManager.hasSimulatedLastActive {
                HStack {
                    Text("debug.plant.simulationState".localized())
                    Spacer()
                    Label("debug.plant.simulationActive".localized(), systemImage: "wand.and.stars")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }
            }
        } header: {
            Text("debug.plant.stateHeader".localized())
        }
    }

    private var forceStageSection: some View {
        Section {
            ForEach(PlantStage.allCases) { stage in
                Button {
                    plantManager.setForceOverride(stage)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.localizedTitle)
                            Text(stage.localizedSubtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if plantManager.currentStage == stage {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .tint(.primary)
            }
            Button(role: .destructive) {
                plantManager.setForceOverride(nil)
            } label: {
                Label("debug.plant.clearOverride".localized(), systemImage: "arrow.uturn.left")
            }
        } header: {
            Text("debug.plant.forceStage".localized())
        } footer: {
            Text("debug.plant.forceStageFooter".localized())
        }
    }

    private var simulationSection: some View {
        Section {
            HStack {
                Text("debug.plant.simStreak".localized())
                Spacer()
                TextField("0", text: $streakInput)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(applyStreakInput)
                    .onChange(of: streakInput) { _, _ in }
            }
            HStack {
                Button("debug.plant.apply".localized()) { applyStreakInput() }
                    .buttonStyle(.borderedProminent)
                Button("debug.plant.clear".localized(), role: .destructive) {
                    plantManager.setSimulatedStreak(nil)
                    streakInput = ""
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("debug.plant.simDaysSince".localized())
                    Spacer()
                    Text("\(Int(daysInput))")
                        .monospacedDigit()
                        .foregroundStyle(plantManager.hasSimulatedLastActive ? .purple : .secondary)
                }
                Slider(value: $daysInput, in: daysRange, step: 1)
                HStack {
                    Button("debug.plant.apply".localized()) {
                        plantManager.setSimulatedDaysSinceLastActive(Int(daysInput))
                    }
                    .buttonStyle(.borderedProminent)
                    Button("debug.plant.clear".localized(), role: .destructive) {
                        plantManager.setSimulatedDaysSinceLastActive(nil)
                        daysInput = 0
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)
            }
        } header: {
            Text("debug.plant.simulationHeader".localized())
        } footer: {
            Text("debug.plant.simulationFooter".localized())
        }
    }

    private var historySection: some View {
        Section {
            if plantManager.history.isEmpty {
                Text("debug.plant.historyEmpty".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(plantManager.history.suffix(10).reversed()) { transition in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(transition.fromStage.localizedTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(transition.toStage.localizedTitle)
                                    .font(.caption.bold())
                            }
                            Text(transition.date.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(transition.trigger)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
            }
        } header: {
            HStack {
                Text("debug.plant.historyHeader".localized())
                Spacer()
                Text("\(plantManager.history.count) / 50")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                plantManager.recomputeStage()
            } label: {
                Label("debug.plant.recompute".localized(), systemImage: "arrow.triangle.2.circlepath")
            }
            Button {
                plantManager.recordActivity(trigger: .grade)
            } label: {
                Label("debug.plant.recordActivityGrade".localized(), systemImage: "checkmark.seal")
            }
        } header: {
            Text("debug.plant.actionsHeader".localized())
        }
    }

    private var dangerSection: some View {
        Section {
            Button {
                plantManager.clearAllSimulations()
                streakInput = ""
                daysInput = 0
            } label: {
                Label("debug.plant.clearAllSimulations".localized(), systemImage: "wand.and.stars.inverse")
            }
            .disabled(!plantManager.hasSimulatedStreak && !plantManager.hasSimulatedLastActive)

            Button(role: .destructive) {
                showClearHistoryConfirm = true
            } label: {
                Label("debug.plant.clearHistory".localized(), systemImage: "trash")
            }
            .disabled(plantManager.history.isEmpty)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("debug.plant.resetToSeed".localized(), systemImage: "arrow.uturn.backward.square")
            }
        } header: {
            Text("debug.plant.dangerHeader".localized())
        } footer: {
            Text("debug.plant.dangerFooter".localized())
        }
    }

    // MARK: - Helpers

    private func refreshFromManager() {
        if let sim = plantManager.currentRecordReflection?.simulatedStreak {
            streakInput = "\(sim)"
        } else if streakInput.isEmpty {
            streakInput = "\(achievementManager.snapshot.streak.current)"
        }
        if let simDate = plantManager.currentRecordReflection?.simulatedLastActiveDate {
            let days = Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: simDate),
                to: Calendar.current.startOfDay(for: Date())).day ?? 0
            daysInput = Double(max(0, days))
        }
    }

    private func applyStreakInput() {
        let trimmed = streakInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            plantManager.setSimulatedStreak(nil)
        } else if let value = Int(trimmed), value >= 0 {
            plantManager.setSimulatedStreak(value)
        }
    }
}

// MARK: - PlantManager debug read-only projection

private extension PlantManager {
    /// 给 Debug UI 用的只读镜像（避免在 View 里直接 fetch SwiftData）。
    var currentRecordReflection: PlantState? {
        currentRecord()?.toSnapshot()
    }
}

#Preview {
    NavigationStack {
        PlantDebugView()
            .environmentObject(AppEnvironmentManager.shared)
    }
}
