//
//  SettingsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager
    @EnvironmentObject var hrvManager: HealthKitManager

    // Sheet presentation state
    @State private var showingProfileEdit = false
    @State private var showingHRVOnboarding = false
    @State private var showingAbout = false
    @State private var showingCopyright = false
    @State private var showingAvatarPicker = false
    @State private var showingTestAlert = false

    // Export state
    @State private var isExporting = false
    @State private var exportDocument: CSVDocument?
    @State private var exportSuccessMessage = ""
    @State private var showingExportSuccess = false

    // Import state
    @State private var isImporting = false
    @State private var importType: ImportType = .grades
    @State private var importSuccessMessage = ""
    @State private var showingImportSuccess = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""

    enum ImportType {
        case grades, mistakes, exams
    }

    var body: some View {
        NavigationStack {
            List {
                profileSection
                preferencesSection
                hrvSection
                dataManagementSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings".localized())
            .frame(maxWidth: .infinity)
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView()
                    .adaptiveSheet()
            }
            .sheet(isPresented: $showingHRVOnboarding) {
                HRVOnboardingView()
                    .environmentObject(hrvManager)
                    .adaptiveSheet()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
                    .adaptiveSheet()
            }
            .sheet(isPresented: $showingCopyright) {
                CopyrightView()
                    .adaptiveSheet()
            }
            .sheet(isPresented: $showingAvatarPicker) {
                AvatarPickerSheet()
                    .adaptiveSheet()
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: exportDocument?.fileName
            ) { result in
                switch result {
                case .success(let url):
                    print("[OK] Successfully exported to: \(url)")
                    showingExportSuccess = true
                case .failure(let error):
                    print("[ERROR] Export failed: \(error)")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    exportDocument = nil
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let fileURL = urls.first {
                        switch importType {
                        case .grades:
                            importGrades(from: fileURL)
                        case .mistakes:
                            importMistakes(from: fileURL)
                        case .exams:
                            importExams(from: fileURL)
                        }
                    }
                case .failure(let error):
                    importErrorMessage = ": \(error.localizedDescription)"
                    showingImportError = true
                }
            }
            .alert("Export Success".localized(), isPresented: $showingExportSuccess) {
                Button("OK".localized()) { }
            } message: {
                Text(exportSuccessMessage)
            }
            .alert("Import Success".localized(), isPresented: $showingImportSuccess) {
                Button("OK".localized()) { }
            } message: {
                Text(importSuccessMessage)
            }
            .alert("Import Error".localized(), isPresented: $showingImportError) {
                Button("OK".localized()) { }
            } message: {
                Text(importErrorMessage)
            }
            .alert("Test Notification Sent".localized(), isPresented: $showingTestAlert) {
                Button("OK".localized()) { }
            } message: {
                Text("Check your notification center in 5 seconds!".localized())
            }
        }
    }

    // MARK: - Section 1: Profile

    private var profileSection: some View {
        Section {
            // Profile card — tap anywhere to edit full profile
            HStack(spacing: 14) {
                Button {
                    showingAvatarPicker = true
                } label: {
                    AvatarView(
                        username: dataManager.profile.username,
                        avatarData: dataManager.loadAvatar(),
                        size: 52
                    )
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                            .padding(3)
                            .background(Circle().fill(Color.blue))
                            .offset(x: 18, y: 18)
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(dataManager.profile.username)
                        .font(.system(size: 17, weight: .semibold))
                    profileSubtitleView
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture { showingProfileEdit = true }

            NavigationLink(destination: EditSubjectsView()) {
                Label("Edit Subjects".localized(), systemImage: "book.closed")
            }
        }
    }

    @ViewBuilder
    private var profileSubtitleView: some View {
        let p = dataManager.profile
        if !p.schoolName.isEmpty {
            Text("\(p.schoolName)\(p.grade.isEmpty ? "" : " · \(p.grade)")")
        } else if !p.educationLevel.isEmpty {
            Text(p.educationLevel.localized())
        } else {
            Text("Tap to set up your profile".localized())
        }
    }

    // MARK: - Section 2: Preferences

    private var preferencesSection: some View {
        Section(header: Text("Preferences".localized())) {
            NavigationLink(destination: PreferencesView()) {
                Label("Language & Theme".localized(), systemImage: "gearshape")
            }
            NavigationLink(destination: HomeLayoutSettingsView()) {
                Label("Home Layout".localized(), systemImage: "rectangle.3.group")
            }
        }
    }

    // MARK: - Section 3: Health & Readiness

    private var hrvSection: some View {
        Section(header: Text("Health & Readiness".localized()),
                footer: Text("HRV is read from Apple Health with your permission. Your data stays on device and is never uploaded.".localized())) {
            HStack {
                Label("HRV Monitoring".localized(), systemImage: "heart.text.square")
                Spacer()
                Toggle("", isOn: $hrvManager.hrvEnabled)
                    .onChange(of: hrvManager.hrvEnabled) { _, newValue in
                        if newValue {
                            if !hrvManager.hrvOnboardingCompleted {
                                showingHRVOnboarding = true
                            } else {
                                Task { await hrvManager.enable() }
                            }
                        } else {
                            hrvManager.disable()
                        }
                    }
            }

            if hrvManager.hrvEnabled && hrvManager.hrvOnboardingCompleted {
                detailLevelPicker

                Button {
                    showingHRVOnboarding = true
                } label: {
                    Label("Learn About HRV".localized(), systemImage: "info.circle")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
    }

    private var detailLevelBinding: Binding<HRVDetailLevel> {
        Binding(
            get: { hrvManager.hrvDetailLevel },
            set: { hrvManager.hrvDetailLevel = $0 }
        )
    }

    private var detailLevelPicker: some View {
        Picker("HRV Card Detail".localized(), selection: detailLevelBinding) {
            ForEach(HRVDetailLevel.allCases, id: \.rawValue) { level in
                Text(detailLevelLabel(level)).tag(level)
            }
        }
    }

    private func detailLevelLabel(_ level: HRVDetailLevel) -> String {
        switch level {
        case .suggestionOnly: return "Suggestion Only".localized()
        case .dataAndSuggestion: return "Data + Suggestion".localized()
        case .chartAndData: return "Chart + Data + Suggestion".localized()
        }
    }

    // MARK: - Section 4: Data Management

    private var dataManagementSection: some View {
        Section(header: Text("Data Management".localized())) {
            Menu {
                Button {
                    exportGrades()
                } label: {
                    Label("Grades".localized(), systemImage: "number.circle")
                }
                Button {
                    exportMistakes()
                } label: {
                    Label("Mistakes".localized(), systemImage: "pencil.circle")
                }
                Button {
                    exportExams()
                } label: {
                    Label("Exams".localized(), systemImage: "calendar.circle")
                }
            } label: {
                Label("Export Data".localized(), systemImage: "tray.and.arrow.up")
            }

            Menu {
                Button {
                    importType = .grades
                    isImporting = true
                } label: {
                    Label("Grades".localized(), systemImage: "number.circle")
                }
                Button {
                    importType = .mistakes
                    isImporting = true
                } label: {
                    Label("Mistakes".localized(), systemImage: "pencil.circle")
                }
                Button {
                    importType = .exams
                    isImporting = true
                } label: {
                    Label("Exams".localized(), systemImage: "calendar.circle")
                }
            } label: {
                Label("Import Data".localized(), systemImage: "tray.and.arrow.down")
            }

            NavigationLink(destination: DataAdminView().environmentObject(dataManager)) {
                Label("Data Admin".localized(), systemImage: "tablecells")
            }
        }
    }

    // MARK: - Section 5: About

    private var aboutSection: some View {
        Section(header: Text("About".localized())) {
            Button {
                showingAbout = true
            } label: {
                Label("About StudyPulse".localized(), systemImage: "info.circle")
            }

            Button {
                showingCopyright = true
            } label: {
                Label("Copyright & License".localized(), systemImage: "checkmark.shield")
            }

            Button {
                sendTestNotification()
                showingTestAlert = true
            } label: {
                Label("Test Notifications".localized(), systemImage: "bell.badge")
            }
        }
    }

    // MARK: - Test Notification

    private func sendTestNotification() {
        print("[Launch] Starting test notification...")

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Test Notification".localized()
        content.body = String(format: "Test #%d".localized(), Int.random(in: 1000...9999))
        content.subtitle = "If you see this, notifications are working.".localized()
        content.badge = 1
        content.sound = .defaultCritical

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let identifier = "FORCE_TEST_\(UUID().uuidString)"
        print("[Key] Using ID: \(identifier)")

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.removeAllPendingNotificationRequests()
        center.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("ERROR send failed: \(error.localizedDescription)")
                    self.showingTestAlert = true
                } else {
                    print("[OK] Send success! Check home screen or wait 5 seconds")
                    self.showingTestAlert = true
                }
            }
        }
    }

    // MARK: - Data Export

    private func exportGrades() {
        let csv = DataExportManager.exportGradesToCSV(
            grades: dataManager.grades,
            subjects: dataManager.subjects
        )
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Grades_\(dateFormatter.string(from: Date())).csv"
        exportSuccessMessage = "\(dataManager.grades.count) "
        exportDocument = CSVDocument(content: csv, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isExporting = true
        }
    }

    private func exportMistakes() {
        let csv = DataExportManager.exportMistakesToCSV(mistakes: dataManager.mistakeSets)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Mistakes_\(dateFormatter.string(from: Date())).csv"
        exportSuccessMessage = "\(dataManager.mistakeSets.count) "
        exportDocument = CSVDocument(content: csv, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isExporting = true
        }
    }

    private func exportExams() {
        let csv = DataExportManager.exportExamsToCSV(
            exams: dataManager.examSets,
            comprehensiveExams: dataManager.comprehensiveExamSets
        )
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Exams_\(dateFormatter.string(from: Date())).csv"
        let totalCount = dataManager.examSets.count + dataManager.comprehensiveExamSets.count
        exportSuccessMessage = "\(totalCount) "
        exportDocument = CSVDocument(content: csv, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isExporting = true
        }
    }

    // MARK: - Data Import

    private func importGrades(from fileURL: URL) {
        var csvString: String?
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let str = try? String(contentsOf: fileURL, encoding: encoding) {
                csvString = str
                break
            }
        }
        guard let content = csvString else {
            importErrorMessage = ""
            showingImportError = true
            return
        }
        let grades = DataExportManager.parseGrades(from: content, subjects: dataManager.subjects)
        if grades.isEmpty {
            importErrorMessage = ""
            showingImportError = true
            return
        }
        dataManager.addGrades(grades)
        importSuccessMessage = " \(grades.count) "
        showingImportSuccess = true
    }

    private func importMistakes(from fileURL: URL) {
        print("[File] Starting to import mistakes file: \(fileURL.lastPathComponent)")
        var csvString: String?
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let str = try? String(contentsOf: fileURL, encoding: encoding) {
                csvString = str
                print("[OK] Read successfully with encoding: \(encoding)")
                break
            }
        }
        guard let content = csvString else {
            importErrorMessage = "Cannot read file: encoding not supported. Please make sure the file is a valid CSV file.".localized()
            showingImportError = true
            return
        }
        var cleanedContent = content
        if content.hasPrefix("\u{FEFF}") {
            cleanedContent = String(content.dropFirst())
            print("[Tool] Removed BOM character")
        }
        print("[Data] File content length: \(cleanedContent.count) characters")
        print("[Data] File preview: \(String(cleanedContent.prefix(200)))")
        let mistakes = DataExportManager.parseMistakes(from: cleanedContent)
        if mistakes.isEmpty {
            importErrorMessage = "CSV"
            showingImportError = true
            return
        }
        dataManager.addMistakes(mistakes)
        importSuccessMessage = " \(mistakes.count) "
        showingImportSuccess = true
    }

    private func importExams(from fileURL: URL) {
        var csvString: String?
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let str = try? String(contentsOf: fileURL, encoding: encoding) {
                csvString = str
                break
            }
        }
        guard let content = csvString else {
            importErrorMessage = ""
            showingImportError = true
            return
        }
        let (single, comprehensive) = DataExportManager.parseExams(from: content)
        if single.isEmpty && comprehensive.isEmpty {
            importErrorMessage = ""
            showingImportError = true
            return
        }
        dataManager.addExams(single: single, comprehensive: comprehensive)
        let total = single.count + comprehensive.count
        importSuccessMessage = " \(total) "
        showingImportSuccess = true
    }
}
