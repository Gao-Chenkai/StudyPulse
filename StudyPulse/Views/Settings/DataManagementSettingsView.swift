//
//  DataManagementSettingsView.swift
//  StudyPulse
//

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import os

struct DataManagementSettingsView: View {
    @EnvironmentObject var dataManager: DataManager

    // Export state
    @State private var isExporting = false
    @State private var exportDocument: CSVDocument?
    @State private var exportSuccessMessage = ""
    @State private var showingExportSuccess = false

    // Log export state
    @State private var isExportingLog = false
    @State private var exportLogDocument: LogDocument?
    @State private var showingLogExportSuccess = false

    // Import state
    @State private var isImporting = false
    @State private var importType: ImportType = .grades
    @State private var importSuccessMessage = ""
    @State private var showingImportSuccess = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""

    // Test notification
    @State private var showingTestAlert = false

    enum ImportType {
        case grades, mistakes, exams
    }

  var body: some View {
         List {
             Section {
                 SettingsDetailHeader(category: .data)
                     .listRowInsets(EdgeInsets())
                     .listRowBackground(Color.clear)
             }
 
                // Export
                Section {
                    Menu {
                        Button { exportGrades() } label: {
                            Label("Grades".localized(), systemImage: "number.circle")
                        }
                        Button { exportMistakes() } label: {
                            Label("Mistakes".localized(), systemImage: "pencil.circle")
                        }
                        Button { exportExams() } label: {
                            Label("Exams".localized(), systemImage: "calendar.circle")
                        }
                    } label: {
                        Label("Export Data".localized(), systemImage: "tray.and.arrow.up")
                    }

                    Button {
                        exportLog()
                    } label: {
                        Label("Export Log".localized(), systemImage: "doc.text.magnifyingglass")
                    }
                }

                // Import
                Section {
                    Menu {
                        Button { importType = .grades; isImporting = true } label: {
                            Label("Grades".localized(), systemImage: "number.circle")
                        }
                        Button { importType = .mistakes; isImporting = true } label: {
                            Label("Mistakes".localized(), systemImage: "pencil.circle")
                        }
                        Button { importType = .exams; isImporting = true } label: {
                            Label("Exams".localized(), systemImage: "calendar.circle")
                        }
                    } label: {
                        Label("Import Data".localized(), systemImage: "tray.and.arrow.down")
                    }
                }

                // Admin & Debug
                Section {
                    NavigationLink(destination: DataAdminView().environmentObject(dataManager)) {
                        Label("Data Admin".localized(), systemImage: "tablecells")
                    }

                    Button {
                        sendTestNotification()
                        showingTestAlert = true
                    } label: {
                        Label("Test Notifications".localized(), systemImage: "bell.badge")
                    }
                }
         }
         .listStyle(.insetGrouped)
         .background(Color(.systemGroupedBackground))
        .navigationTitle("Data Management".localized())
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportDocument?.fileName
        ) { result in
            switch result {
            case .success(let url):
                Log.record(.info, category: "Export", message: "数据导出成功 / Data export succeeded: url=\(url.path)")
                showingExportSuccess = true
            case .failure(let error):
                Log.record(.error, category: "Export", message: "数据导出失败 / Data export failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exportDocument = nil
            }
        }
        .fileExporter(
            isPresented: $isExportingLog,
            document: exportLogDocument,
            contentType: .log,
            defaultFilename: exportLogDocument?.fileName
        ) { result in
            switch result {
            case .success(let url):
                Log.record(.info, category: "Export", message: "日志导出成功 / Log export succeeded: url=\(url.path)")
                showingLogExportSuccess = true
            case .failure(let error):
                Log.record(.error, category: "Export", message: "日志导出失败 / Log export failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exportLogDocument = nil
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
                    case .grades: importGrades(from: fileURL)
                    case .mistakes: importMistakes(from: fileURL)
                    case .exams: importExams(from: fileURL)
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
        .alert("Log Export Success".localized(), isPresented: $showingLogExportSuccess) {
            Button("OK".localized()) { }
        } message: {
            Text("Application logs have been exported.".localized())
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

    // MARK: - Log Export

    private func exportLog() {
        let logText = LogStore.shared.exportAsText()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Log_\(dateFormatter.string(from: Date())).log"
        exportLogDocument = LogDocument(content: logText, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isExportingLog = true
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
        var csvString: String?
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let str = try? String(contentsOf: fileURL, encoding: encoding) {
                csvString = str
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
        }
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

    // MARK: - Test Notification

    private func sendTestNotification() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Test Notification".localized()
        content.body = String(format: "Test #%d".localized(), Int.random(in: 1000...9999))
        content.subtitle = "If you see this, notifications are working.".localized()
        content.badge = 1
        content.sound = .defaultCritical

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let identifier = "FORCE_TEST_\(UUID().uuidString)"

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.removeAllPendingNotificationRequests()
        center.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    Log.record(.error, category: "Notification", message: "测试通知发送失败 / Test notification send failed: \(error.localizedDescription)")
                } else {
                    Log.record(.info, category: "Notification", message: "测试通知发送成功 / Test notification sent: identifier=\(identifier)")
                }
            }
        }
    }
}
