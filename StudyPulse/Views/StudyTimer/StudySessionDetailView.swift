//
//  StudySessionDetailView.swift
//  StudyPulse
//
//  历史会话详情页:从历史列表 push 进入,复用心率曲线 + 标注 + AI 解读组件。
//  Historical session detail page: pushed from the history list.
//  Reuses HeartRateChartView + AnnotationListView + AI section.
//
//  与 StudySessionReviewSheet 的区别:作为 push 页面而非 sheet,
//  标题用会话日期,无 "Done" 按钮(用返回按钮)。
//

import SwiftUI
import SwiftStreamingMarkdown
import os

// MARK: - StudySessionDetailView

struct StudySessionDetailView: View {
    let sessionId: UUID

    @Environment(RepositoryContainer.self) private var container
    @Environment(HealthKitManager.self) private var hrv: HealthKitManager

    @State private var session: StudySession?
    @State private var annotations: [DifficultyAnnotation] = []
    @State private var editingAnnotation: DifficultyAnnotation?
    @State private var pendingNewAnnotation: (timestamp: Date, heartRate: Double?)?

    // AI 解读状态
    @State private var aiOutput: String = ""
    @State private var aiLoading: Bool = false
    @State private var aiTask: Task<Void, Never>?

    // MARK: - Derived

    private var samples: [HeartRateSample] { session?.heartRateSamples ?? [] }
    private var rhr: Double? { hrv.bodyStatus.restingHeartRate }
    private var peaks: [HeartRateSample] {
        HeartRateSample.detectPeaks(samples: samples, rhrBaseline: rhr)
    }
    private var subjects: [Subject] { container.subjectRepo.subjects }

    // MARK: - Body

    var body: some View {
        Group {
            if let s = session {
                if samples.isEmpty {
                    emptyHRState(session: s)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            headerSection(s)
                            chartSection
                            annotationListSection
                            aiSection
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(session.map {
            $0.startDate.formatted(date: .abbreviated, time: .shortened)
        } ?? "Session".localized())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingAnnotation) { anno in
            DifficultyAnnotationEditor(
                existing: anno,
                timestamp: anno.timestamp,
                heartRate: anno.heartRate,
                subjects: subjects,
                onSave: { updated in
                    replaceAnnotation(updated)
                },
                onDelete: { deleted in
                    deleteAnnotation(deleted)
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { pendingNewAnnotation != nil },
            set: { if !$0 { pendingNewAnnotation = nil } }
        )) {
            if let pending = pendingNewAnnotation {
                DifficultyAnnotationEditor(
                    existing: nil,
                    timestamp: pending.timestamp,
                    heartRate: pending.heartRate,
                    subjects: subjects,
                    onSave: { newAnno in
                        addAnnotation(newAnno)
                    }
                )
            }
        }
        .onAppear { loadSession() }
        .onDisappear { aiTask?.cancel() }
    }

    // MARK: - Load

    private func loadSession() {
        session = container.studySessionRepo.session(id: sessionId)
        if annotations.isEmpty {
            annotations = session?.difficultyAnnotations ?? []
        }
    }

    // MARK: - Header

    private func headerSection(_ s: StudySession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.intensity.displayName)
                        .font(.system(size: 18, weight: .bold))
                    Text(s.startDate, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(s.durationSeconds / 60) min")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: s.intensity.colorHex))
                    Text("\(samples.count) HR samples".localized())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            if !s.completed {
                Label("Session was cancelled".localized(), systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
            if samples.count < 5 {
                Label("Apple Watch passive sampling is sparse. Peak detection may be less accurate.".localized(), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.10)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heart Rate Curve".localized())
                .font(.system(size: 14, weight: .semibold))

            HeartRateChartView(
                samples: samples,
                sessionStart: session?.startDate ?? Date(),
                rhrBaseline: rhr,
                annotations: annotations,
                peaks: peaks,
                onTapPeak: { peak in
                    pendingNewAnnotation = (peak.timestamp, peak.bpm)
                },
                onLongPress: { timestamp, bpm in
                    pendingNewAnnotation = (timestamp, bpm)
                }
            )

            if !peaks.isEmpty {
                Text("Tap a red peak to log what you were struggling with. Long-press anywhere to add a manual annotation.".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Annotation list

    private var annotationListSection: some View {
        AnnotationListView(
            annotations: annotations,
            subjects: subjects,
            onEdit: { anno in
                editingAnnotation = anno
            },
            onDelete: { deleted in
                deleteAnnotation(deleted)
            }
        )
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - AI section

    private var aiSection: some View {
        Group {
            if container.envManager.llmConfig.isConfigured {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("AI Stress Interpretation".localized())
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button {
                            runAI()
                        } label: {
                            Label("✨ AI 解读".localized(), systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.purple.opacity(0.15)))
                                .foregroundColor(.purple)
                        }
                        .disabled(aiLoading || session == nil)
                    }

                    if aiLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Analyzing…".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if !aiOutput.isEmpty {
                        MarkdownView(text: aiOutput.normalisingSingleDollarMath(), config: .previewConfig)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    // MARK: - Empty HR state

    private func emptyHRState(session: StudySession) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No heart-rate data".localized())
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Apple Watch may not have been worn or no samples were recorded during this session.".localized())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider().padding(.vertical, 8)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(session.intensity.displayName)
                        .font(.system(size: 14, weight: .medium))
                    Text(session.startDate, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(session.durationSeconds / 60) min")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Duration".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Annotation mutations

    private func addAnnotation(_ anno: DifficultyAnnotation) {
        annotations.append(anno)
        persistAnnotations()
    }

    private func replaceAnnotation(_ updated: DifficultyAnnotation) {
        if let idx = annotations.firstIndex(where: { $0.id == updated.id }) {
            annotations[idx] = updated
            persistAnnotations()
        }
    }

    private func deleteAnnotation(_ deleted: DifficultyAnnotation) {
        annotations.removeAll { $0.id == deleted.id }
        persistAnnotations()
    }

    private func persistAnnotations() {
        guard let current = session else { return }
        let updated = StudySession(
            id: current.id,
            startDate: current.startDate,
            durationSeconds: current.durationSeconds,
            intensity: current.intensity,
            completed: current.completed,
            heartRateSamples: current.heartRateSamples,
            difficultyAnnotations: annotations,
            investmentTarget: current.investmentTarget,
            source: current.source,
            timeZoneIdentifier: current.timeZoneIdentifier
        )
        container.studySessionRepo.upsert(updated)
        session = container.studySessionRepo.session(id: sessionId)
    }

    // MARK: - AI

    private func runAI() {
        guard let s = session else { return }
        aiTask?.cancel()
        aiOutput = ""
        aiLoading = true
        let config = container.envManager.llmConfig
        let prompt = StudySessionStressLLM.makePrompt(
            session: s,
            rhrBaseline: rhr
        )
        aiTask = Task {
            do {
                _ = try await LLMClient.shared.stream(prompt: prompt, config: config, caller: "StudySessionStress") { snapshot in
                    aiOutput = snapshot
                }
                aiLoading = false
            } catch is CancellationError {
                aiLoading = false
            } catch {
                aiLoading = false
                Log.llm.error("StudySessionStressLLM failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - Preview

#Preview("Detail with HR data") {
    let now = Date()
    let samples: [HeartRateSample] = (0..<12).map { i in
        HeartRateSample(
            id: UUID(),
            timestamp: now.addingTimeInterval(Double(i) * 140),
            bpm: [70, 74, 88, 102, 115, 98, 82, 78, 90, 108, 95, 80][i]
        )
    }
    let session = StudySession(
        id: UUID(),
        startDate: now,
        durationSeconds: 30 * 60,
        intensity: .deepFocus,
        completed: true,
        heartRateSamples: samples,
        difficultyAnnotations: [
            DifficultyAnnotation(id: UUID(), timestamp: samples[4].timestamp, heartRate: 115, note: "物理电磁感应卡住", subjectId: nil)
        ]
    )
    return NavigationStack {
        StudySessionDetailView(sessionId: session.id)
            .environment(RepositoryContainer())
    }
}

#Preview("Detail without HR data") {
    let session = StudySession(
        id: UUID(),
        startDate: Date(),
        durationSeconds: 25 * 60,
        intensity: .steady,
        completed: true
    )
    return NavigationStack {
        StudySessionDetailView(sessionId: session.id)
            .environment(RepositoryContainer())
    }
}
