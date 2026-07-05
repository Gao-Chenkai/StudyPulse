//
//  WeeklyReportSettingsView.swift
//  StudyPulse
//
//  Settings view for configuring weekly/monthly report notifications.
//

import SwiftUI

struct WeeklyReportSettingsView: View {
    @Environment(RepositoryContainer.self) private var container
    @State private var weeklyEnabled = WeeklyReportManager.isWeeklyEnabled
    @State private var monthlyEnabled = WeeklyReportManager.isMonthlyEnabled
    @State private var isSaving = false
    @State private var isGenerating = false
    @State private var reportImage: UIImage?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Weekly Report".localized(), isOn: $weeklyEnabled)
                    .onChange(of: weeklyEnabled) { _, newValue in
                        Task { await saveSettings(weekly: newValue, monthly: monthlyEnabled) }
                    }

                Toggle("Monthly Report".localized(), isOn: $monthlyEnabled)
                    .onChange(of: monthlyEnabled) { _, newValue in
                        Task { await saveSettings(weekly: weeklyEnabled, monthly: newValue) }
                    }
            } header: {
                Text("Automatic Reports".localized())
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly reports are generated every Monday at 9:00 AM.".localized())
                    Text("Monthly reports are generated on the 1st of each month at 9:00 AM.".localized())
                    if isSaving {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Saving...".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    Task { await generateReport(period: .weekly) }
                } label: {
                    Label("Generate Weekly Report Now".localized(), systemImage: "chart.bar.fill")
                }

                Button {
                    Task { await generateReport(period: .monthly) }
                } label: {
                    Label("Generate Monthly Report Now".localized(), systemImage: "chart.bar.xaxis")
                }
            } header: {
                Text("Manual Generation".localized())
            } footer: {
                Text("Generate a report for the past period and share it.".localized())
            }
        }
        .navigationTitle("Learning Reports".localized())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let image = reportImage {
                ReportShareSheet(items: [image], subject: "StudyPulse Report")
            }
        }
        .alert(
            "Report generation failed".localized(),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK".localized(), role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if isGenerating {
                ZStack {
                    Color.black.opacity(0.15)
                    ProgressView()
                        .scaleEffect(1.4)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
                .zIndex(99)
            }
        }
    }

    private func saveSettings(weekly: Bool, monthly: Bool) async {
        isSaving = true
        defer { isSaving = false }

        WeeklyReportManager.isWeeklyEnabled = weekly
        WeeklyReportManager.isMonthlyEnabled = monthly

        await WeeklyReportManager.scheduleNotification(period: .weekly, enabled: weekly)
        await WeeklyReportManager.scheduleNotification(period: .monthly, enabled: monthly)
    }

    @MainActor
    private func generateReport(period: WeeklyReportManager.ReportPeriod) async {
        isGenerating = true
        defer { isGenerating = false }

        let sessions = StudySessionStore.load()
        let reportData = WeeklyReportManager.aggregateData(
            period: period,
            sessions: sessions,
            grades: container.gradeRepo.grades,
            mistakes: container.mistakeRepo.mistakeSets,
            exams: container.examRepo.examSets,
            subjects: container.subjectRepo.subjects
        )

        guard let image = WeeklyReportManager.generateReportImage(
            data: reportData,
            profile: container.profileRepo.profile,
            subjects: container.subjectRepo.subjects
        ) else {
            errorMessage = "Failed to generate report image".localized()
            return
        }

        reportImage = image
        try? await Task.sleep(nanoseconds: 80_000_000)
        showingShareSheet = true
    }
}
