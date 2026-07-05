//
//  DataManagementSettingsView.swift
//  StudyPulse
//

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import os

struct DataManagementSettingsView: View {
    @Environment(RepositoryContainer.self) private var container

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

    // Bulk delete state
    @State private var showingBulkDeleteSheet = false
    @State private var bulkDeleteSelected: Set<BulkClearCategory> = []
    @State private var bulkDeleteConfirmPhrase: String = ""
    @State private var showingBulkDeleteResult = false
    @State private var bulkDeleteResultMessage = ""
    @State private var bulkDeleteSuccess = false

    /// 用户必须完整输入的确认短语
    private static let bulkDeleteRequiredPhrase = "我已知晓且了解删除所有数据的后果，我愿意承担丢失所有数据的后果".localized()

    enum ImportType {
        case grades, mistakes, exams, tasks
    }

  var body: some View {
        List {
            Section {
                SettingsDetailHeader(category: .data)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Study Phases (学期 / 假期阶段)
            Section {
                NavigationLink(destination: PhaseManagementView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Study Phases".localized())
                            if let active = container.phaseRepo.activePhase {
                                Text("Active: \(active.name)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else if container.phaseRepo.phases.isEmpty {
                                Text("Create semester, break, or sprint phases to scope your data.".localized())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Showing all data (no active phase)".localized())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("Phase Management".localized())
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
                        Button { exportTasks() } label: {
                            Label("Tasks".localized(), systemImage: "checklist")
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
                        Button { importType = .tasks; isImporting = true } label: {
                            Label("Tasks".localized(), systemImage: "checklist")
                        }
                    } label: {
                        Label("Import Data".localized(), systemImage: "tray.and.arrow.down")
                    }
                }

                // Admin & Debug
                Section {
                    NavigationLink(destination: DataAdminView()) {
                        Label("Data Admin".localized(), systemImage: "tablecells")
                    }

                    Button {
                        sendTestNotification()
                        showingTestAlert = true
                    } label: {
                        Label("Test Notifications".localized(), systemImage: "bell.badge")
                    }
                }

                // Danger Zone: 一键清空数据
                Section {
                    Button {
                        bulkDeleteSelected = []
                        bulkDeleteConfirmPhrase = ""
                        showingBulkDeleteSheet = true
                    } label: {
                        Label("Delete All Data".localized(), systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Danger Zone".localized())
                } footer: {
                    Text("Permanently delete grades, mistakes and todos. This action cannot be undone. Please export your data first if you may need it later.".localized())
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
                    case .tasks: importTasks(from: fileURL)
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
        .sheet(isPresented: $showingBulkDeleteSheet) {
            BulkDeleteConfirmSheet(
                selected: $bulkDeleteSelected,
                confirmPhrase: $bulkDeleteConfirmPhrase,
                requiredPhrase: Self.bulkDeleteRequiredPhrase,
                onConfirm: performBulkDelete,
                onCancel: { showingBulkDeleteSheet = false }
            )
        }
        .alert(
            bulkDeleteSuccess ? "Delete Complete".localized() : "Delete Failed".localized(),
            isPresented: $showingBulkDeleteResult
        ) {
            Button("OK".localized()) { }
        } message: {
            Text(bulkDeleteResultMessage)
        }
    }

    // MARK: - Bulk Delete

    private func performBulkDelete() {
        guard !bulkDeleteSelected.isEmpty else { return }
        guard bulkDeleteConfirmPhrase == Self.bulkDeleteRequiredPhrase else { return }
        // 再做一次二次校验，防止输入框 trim 后比对失误
        let trimmed = bulkDeleteConfirmPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == Self.bulkDeleteRequiredPhrase else { return }

        let results = container.bulkClearData(categories: bulkDeleteSelected)
        showingBulkDeleteSheet = false

        if results.isEmpty {
            bulkDeleteSuccess = false
            bulkDeleteResultMessage = "No category was selected.".localized()
        } else {
            bulkDeleteSuccess = true
            let parts = results.map { entry -> String in
                let title = entry.category.displayName
                return "\(title): \(entry.count)"
            }
            bulkDeleteResultMessage = parts.joined(separator: "\n")
        }
        showingBulkDeleteResult = true
        // 复位输入,避免下次打开残留
        bulkDeleteConfirmPhrase = ""
        bulkDeleteSelected = []
    }

    // MARK: - Data Export

    private func exportGrades() {
        let csv = DataExportManager.exportGradesToCSV(
            grades: container.gradeRepo.grades,
            subjects: container.subjectRepo.subjects
        )
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Grades_\(dateFormatter.string(from: Date())).csv"
        exportSuccessMessage = "\(container.gradeRepo.grades.count) "
        exportDocument = CSVDocument(content: csv, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isExporting = true
        }
    }

    private func exportMistakes() {
        let csv = DataExportManager.exportMistakesToCSV(mistakes: container.mistakeRepo.mistakeSets)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Mistakes_\(dateFormatter.string(from: Date())).csv"
        exportSuccessMessage = "\(container.mistakeRepo.mistakeSets.count) "
        exportDocument = CSVDocument(content: csv, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isExporting = true
        }
    }

    private func exportExams() {
        let csv = DataExportManager.exportExamsToCSV(
            exams: container.examRepo.examSets,
            comprehensiveExams: container.examRepo.comprehensiveExamSets
        )
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Exams_\(dateFormatter.string(from: Date())).csv"
        let totalCount = container.examRepo.examSets.count + container.examRepo.comprehensiveExamSets.count
        exportSuccessMessage = "\(totalCount) "
        exportDocument = CSVDocument(content: csv, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isExporting = true
        }
    }

    private func exportTasks() {
        let csv = DataExportManager.exportTasksToCSV(tasks: container.taskRepo.taskItems)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Tasks_\(dateFormatter.string(from: Date())).csv"
        exportSuccessMessage = "\(container.taskRepo.taskItems.count) "
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
        let grades = DataExportManager.parseGrades(from: content, subjects: container.subjectRepo.subjects)
        if grades.isEmpty {
            importErrorMessage = ""
            showingImportError = true
            return
        }
        container.addGrades(grades)
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
        container.addMistakes(mistakes)
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
        container.addExams(single: single, comprehensive: comprehensive)
        let total = single.count + comprehensive.count
        importSuccessMessage = " \(total) "
        showingImportSuccess = true
    }

    private func importTasks(from fileURL: URL) {
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
        var cleanedContent = content
        if content.hasPrefix("\u{FEFF}") {
            cleanedContent = String(content.dropFirst())
        }
        let tasks = DataExportManager.parseTasks(from: cleanedContent)
        if tasks.isEmpty {
            importErrorMessage = ""
            showingImportError = true
            return
        }
        container.addTasks(tasks)
        importSuccessMessage = " \(tasks.count) "
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

// MARK: - 一键删除确认弹窗

/// 一键删除所有数据的二次确认弹窗
/// Secondary confirmation sheet for "Delete All Data" action.
///
/// 大面积红色警告 + 类别勾选 + 强制输入完整确认短语
struct BulkDeleteConfirmSheet: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: Set<BulkClearCategory>
    @Binding var confirmPhrase: String
    let requiredPhrase: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var phraseMatches: Bool {
        confirmPhrase.trimmingCharacters(in: .whitespacesAndNewlines) == requiredPhrase
    }
    private var canConfirm: Bool {
        !selected.isEmpty && phraseMatches
    }

    private func count(for cat: BulkClearCategory) -> Int {
        switch cat {
        case .grades: return container.gradeRepo.grades.count
        case .mistakes: return container.mistakeRepo.mistakeSets.count
        case .exams: return container.examRepo.examSets.count + container.examRepo.comprehensiveExamSets.count
        case .tasks: return container.taskRepo.taskItems.count
        case .profileReset: return 1
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    warningHeader
                    categoriesSection
                    phraseSection
                    confirmButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Delete All Data".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".localized()) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 大面积红色警告
    private var warningHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 92, height: 92)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.red)
            }
            Text("DANGER".localized())
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.red)
                .tracking(2)
            Text("This action CANNOT be undone. All selected data will be permanently erased from this device.".localized())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Please export your data first if you may need it later.".localized())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.55), lineWidth: 1.5)
        )
    }

    // MARK: - 类别勾选
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select data to delete".localized())
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            VStack(spacing: 0) {
                ForEach(BulkClearCategory.allCases) { cat in
                    BulkDeleteCategoryRow(
                        category: cat,
                        count: count(for: cat),
                        isSelected: selected.contains(cat)
                    ) {
                        if selected.contains(cat) {
                            selected.remove(cat)
                        } else {
                            selected.insert(cat)
                        }
                    }
                    if cat != BulkClearCategory.allCases.last {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - 确认短语
    private var phraseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type the following to confirm".localized())
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text(requiredPhrase)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.red)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            TextField(requiredPhrase, text: $confirmPhrase, axis: .vertical)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2...4)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(phraseMatches ? Color.red : Color(.separator), lineWidth: phraseMatches ? 1.5 : 1)
                )
            if !confirmPhrase.isEmpty && !phraseMatches {
                Text("Phrase does not match. Please type it exactly.".localized())
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - 确认按钮
    private var confirmButton: some View {
        Button {
            onConfirm()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                Text("Permanently Delete".localized())
                    .fontWeight(.bold)
            }
            .font(.system(size: 16))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(canConfirm ? Color.red : Color.gray.opacity(0.4))
            )
        }
        .disabled(!canConfirm)
    }
}

/// 一键删除弹窗中,每个类别勾选行
private struct BulkDeleteCategoryRow: View {
    let category: BulkClearCategory
    let count: Int
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: category.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text("\(count) " + "item(s)".localized())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .red : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
