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

    // 编辑 / 模态
    @State private var showingProfileEdit = false
    @State private var showingSubjectsEdit = false
    @State private var showingAbout = false
    @State private var showingCopyright = false
    @State private var showingAvatarPicker = false
    @State private var showingTestAlert = false

    // 导出
    @State private var isExporting = false
    @State private var exportDocument: CSVDocument?
    @State private var exportSuccessMessage = ""
    @State private var showingExportSuccess = false

    // 导入
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
        NavigationView {
            List {
                // MARK: 用户资料卡
                Section {
                    profileCard
                }

                // MARK: 编辑操作
                Section(header: Text("Edit".localized())) {
                    Button {
                        showingProfileEdit = true
                    } label: {
                        Label("Edit Profile".localized(), systemImage: "person.text.rectangle")
                    }

                    Button {
                        showingSubjectsEdit = true
                    } label: {
                        Label("Edit Subjects".localized(), systemImage: "book.closed")
                    }
                }

                // MARK: 偏好设置
                Section(header: Text("Preferences".localized())) {
                    NavigationLink(destination: PreferencesView()) {
                        Label("App Preferences".localized(), systemImage: "gearshape")
                    }
                }

                // MARK: 学术信息
                Section(header: Text("Academic Info".localized())) {
                    if !dataManager.profile.schoolName.isEmpty {
                        infoRow(
                            icon: "building.columns",
                            color: .indigo,
                            title: "School".localized(),
                            value: dataManager.profile.schoolName
                        )
                    }

                    if !dataManager.profile.grade.isEmpty || !dataManager.profile.className.isEmpty {
                        infoRow(
                            icon: "graduationcap",
                            color: .green,
                            title: "Grade & Class".localized(),
                            value: "\(dataManager.profile.grade)\(dataManager.profile.className.isEmpty ? "" : " · \(dataManager.profile.className)")"
                        )
                    }

                    infoRow(
                        icon: "building.columns",
                        color: .orange,
                        title: "Education System".localized(),
                        value: dataManager.profile.educationSystem
                    )

                    infoRow(
                        icon: "globe",
                        color: .blue,
                        title: "Region".localized(),
                        value: dataManager.profile.region.localized()
                    )

                    if dataManager.profile.targetScore > 0 {
                        infoRow(
                            icon: "star.fill",
                            color: .yellow,
                            title: "Target Score".localized(),
                            value: String(format: "%.1f", dataManager.profile.targetScore)
                        )
                    }

                    if !dataManager.profile.targetSchool.isEmpty {
                        infoRow(
                            icon: "target",
                            color: .red,
                            title: "Target School".localized(),
                            value: dataManager.profile.targetSchool
                        )
                    }
                }

                // MARK: 数据管理
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
                    .foregroundColor(.green)
                }

                // MARK: 关于
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
                        Label("Send Test Notification in 5 Seconds".localized(), systemImage: "bell.badge")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings".localized())
            // iPad 上限制最大宽度并居中，避免设置项被拉得过宽
            .adaptiveMaxWidth(720)
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView()
            }
            .sheet(isPresented: $showingSubjectsEdit) {
                EditSubjectsView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingCopyright) {
                CopyrightView()
            }
            .sheet(isPresented: $showingAvatarPicker) {
                AvatarPickerSheet()
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
                // 重置状态
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

    // MARK: - Helpers (profileCard & infoRow)

    private var profileCard: some View {
        HStack(spacing: 16) {
            Button {
                showingAvatarPicker = true
            } label: {
                AvatarView(
                    username: dataManager.profile.username,
                    avatarData: dataManager.loadAvatar(),
                    size: 60
                )
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: 22, y: 22)
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(dataManager.profile.username)
                    .font(.headline)
                Text("\(dataManager.profile.age) \(String(localized: "years old")) · \(dataManager.profile.educationLevel.localized())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func infoRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func sendTestNotification() {
        print("[Launch] Starting test notification...")
        
        let center = UNUserNotificationCenter.current()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Test Notification".localized()
        content.body = String(format: "Test #%d".localized(), Int.random(in: 1000...9999))
        content.subtitle = "If you see this, notifications are working.".localized()
        content.badge = 1
        content.sound = .defaultCritical
        
        // Set trigger (fire after 5 seconds)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        // Create unique identifier
        let identifier = "FORCE_TEST_\(UUID().uuidString)"
        print("[Key] Using ID: \(identifier)")
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Remove all pending notification requests
        center.removeAllPendingNotificationRequests()
        
        // Add new notification request
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
    
    // MARK: - 数据导出
    
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
    
    // MARK: - 数据导入
    
    private func importGrades(from fileURL: URL) {
        // 
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
        
        // 尝试多种编码读取
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
        
        // Remove BOM
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
        // 
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

// MARK: - CSVDocument

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    let content: String
    let fileName: String
    
    init(content: String, fileName: String) {
        //  UTF-8 BOM  Excel 
        let bom = "\u{FEFF}"
        self.content = bom + content
        self.fileName = fileName
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // 
        var string: String?
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let str = String(data: data, encoding: encoding) {
                string = str
                break
            }
        }
        
        guard let content = string else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        //  BOM 
        var cleanedContent = content
        if content.hasPrefix("\u{FEFF}") {
            cleanedContent = String(content.dropFirst())
        }
        
        self.content = cleanedContent
        self.fileName = "export.csv"
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

struct EditSubjectsView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Subjects".localized()),
                        footer: Text("Toggle the subjects you're studying. Tap the score to adjust the full score for each subject.".localized())) {
                    ForEach($dataManager.subjects) { $subject in
                        HStack(spacing: 12) {
                            Toggle(isOn: $subject.enabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subject.displayName.isEmpty ? subject.name.localized() : subject.displayName)
                                        .foregroundColor(.primary)
                                    Text(subject.name)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .frame(width: 50)
                            
                            Text(subject.displayName.isEmpty ? subject.name.localized() : subject.displayName)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 4) {
                                Text("/")
                                    .foregroundColor(.secondary)
                                TextField("100", value: $subject.fullScore, formatter: NumberFormatter())
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        if let stage = EducationStage(rawValue: dataManager.profile.educationStage) {
                            dataManager.applySmartSubjectRecommendation(
                                stage: stage,
                                regionCode: dataManager.profile.regionCode
                            )
                            dataManager.saveSubjects()
                        }
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Reset to Recommended Subjects".localized())
                            Spacer()
                        }
                    }
                    .foregroundColor(.purple)
                }
            }
            .navigationTitle("Edit Subjects".localized())
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                dataManager.saveProfile()
                dataManager.saveSubjects()
            }
        }
    }
}

struct ProfileEditView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var username = ""
    @State private var realName = ""
    @State private var age = 0
    @State private var gender = "Not Specified"
    @State private var educationStage: EducationStage = .highSchool
    @State private var categoryFilter: EducationCategory? = nil
    @State private var regionCode = "mainland"
    @State private var grade = ""
    @State private var className = ""
    @State private var schoolName = ""
    @State private var studentId = ""
    @State private var enrollmentYear = Calendar.current.component(.year, from: Date())
    @State private var examYear = Calendar.current.component(.year, from: Date())
    @State private var targetSchool = ""
    @State private var targetScore: Double = 0
    @State private var theme = ""
    @State private var showSmartRecommendation = false
    
    /// 
    private var availableRegions: [EducationRegion] {
        var regions = EducationConfig.availableRegions(for: educationStage)
        if let filter = categoryFilter {
            regions = regions.filter { $0.category == filter }
        }
        return regions
    }
    
    /// 
    private var currentRegion: EducationRegion? {
        EducationConfig.region(named: regionCode, stage: educationStage)
    }
    
    var body: some View {
        NavigationView {
            Form {
                //  - 
                Section(header: Text("Education Stage".localized())) {
                    Menu {
                        ForEach(EducationStage.allCases) { stage in
                            Button {
                                educationStage = stage
                            } label: {
                                HStack {
                                    Text(stageLabel(stage).localized())
                                    if educationStage == stage {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "graduationcap.fill")
                                .foregroundColor(stageColor(educationStage))
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stage".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(stageLabel(educationStage).localized())
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                // /
                Section(header: Text("Region / Education System".localized()),
                        footer: Text("Different regions and education systems have different subjects and grading scales. Includes domestic and international curricula (A-Level, IB, AP, SAT, ACT, IGCSE).".localized())) {
                    Picker("Category".localized(), selection: $categoryFilter) {
                        Text("All".localized()).tag(EducationCategory?.none)
                        Text("Domestic".localized()).tag(EducationCategory?.some(.domestic))
                        Text("International".localized()).tag(EducationCategory?.some(.international))
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Region".localized(), selection: $regionCode) {
                        ForEach(availableRegions) { region in
                            HStack {
                                if region.category == .international {
                                    Text(String(format: "Intl. %@".localized(), region.displayName))
                                } else {
                                    Text(region.displayName)
                                }
                            }
                            .tag(region.name)
                        }
                    }
                    
                    if let region = currentRegion, !region.notes.isEmpty {
                        Label(region.notes, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if educationStage != .primarySchool {
                        Button(action: {
                            showSmartRecommendation = true
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .foregroundColor(.purple)
                                Text("Apply Smart Subject Recommendation".localized())
                                    .foregroundColor(.purple)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // 
                Section(header: Text("Personal Info".localized())) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 30)
                        Text("Display Name".localized())
                        Spacer()
                        TextField("Username".localized(), text: $username)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        Text("Real Name".localized())
                        Spacer()
                        TextField("Real Name".localized(), text: $realName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.pink)
                            .frame(width: 30)
                        Text("Age".localized())
                        Spacer()
                        TextField("Age".localized(), value: $age, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Image(systemName: genderIcon)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Gender".localized())
                        Spacer()
                        Picker("Gender".localized(), selection: $gender) {
                            Text("Not Specified".localized()).tag("Not Specified")
                            Text("Male".localized()).tag("Male")
                            Text("Female".localized()).tag("Female")
                            Text("Other".localized()).tag("Other")
                        }
                        .labelsHidden()
                    }
                }
                
                // 
                Section(header: Text("School Info".localized())) {
                    HStack {
                        Image(systemName: "building.columns")
                            .foregroundColor(.indigo)
                            .frame(width: 30)
                        Text("School".localized())
                        Spacer()
                        TextField("School Name".localized(), text: $schoolName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.purple)
                            .frame(width: 30)
                        Text("Student ID".localized())
                        Spacer()
                        TextField("Student ID".localized(), text: $studentId)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Image(systemName: "graduationcap")
                            .foregroundColor(.green)
                            .frame(width: 30)
                        Text("Grade".localized())
                        Spacer()
                        TextField("e.g. Grade 11".localized(), text: $grade)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Image(systemName: "person.3")
                            .foregroundColor(.teal)
                            .frame(width: 30)
                        Text("Class".localized())
                        Spacer()
                        TextField("Class".localized(), text: $className)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // /
                Section(header: Text("Academic Year".localized())) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.cyan)
                            .frame(width: 30)
                        Text("Enrollment Year".localized())
                        Spacer()
                        Picker("Year".localized(), selection: $enrollmentYear) {
                            ForEach((enrollmentYear-5)...(enrollmentYear+5), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .labelsHidden()
                    }
                    
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(.mint)
                            .frame(width: 30)
                        Text("Target Exam Year".localized())
                        Spacer()
                        Picker("Year".localized(), selection: $examYear) {
                            ForEach((examYear-5)...(examYear+5), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .labelsHidden()
                    }
                }
                
                if educationStage == .highSchool || educationStage == .university {
                    Section(header: Text("Goals".localized()),
                            footer: Text("Track your progress towards your target school and score.".localized())) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.red)
                                .frame(width: 30)
                            Text("Target School".localized())
                            Spacer()
                            TextField("e.g. Tsinghua University".localized(), text: $targetSchool)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 30)
                            Text("Target Score".localized())
                            Spacer()
                            TextField("Target".localized(), value: $targetScore, formatter: NumberFormatter())
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile".localized())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFromProfile()
            }
            .onChange(of: educationStage) { _, newValue in
                // 
                if EducationConfig.region(named: regionCode, stage: newValue) == nil {
                    regionCode = EducationConfig.defaultRegion(for: newValue).name
                }
            }
            .onChange(of: categoryFilter) { _, _ in
                // 
                if !availableRegions.contains(where: { $0.name == regionCode }) {
                    regionCode = availableRegions.first?.name ?? "mainland"
                }
            }
            .alert("Apply Smart Recommendation".localized(), isPresented: $showSmartRecommendation) {
                Button("Cancel".localized(), role: .cancel) { }
                Button("Apply".localized()) {
                    applySmartRecommendation()
                }
            } message: {
                Text(String(format: "This will reset subject list and auto-check required subjects for %@ - %@. Existing enabled preferences will be kept.".localized(), currentRegion?.displayName ?? "", educationStage.rawValue))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized()) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized()) {
                        saveToProfile()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .bold()
                }
            }
        }
    }
    
    private var genderIcon: String {
        switch gender {
        case "Male": return "person.fill"
        case "Female": return "person.fill"
        case "Other": return "person.fill.questionmark"
        default: return "person.fill.questionmark"
        }
    }
    
    /// 
    private func stageLabel(_ stage: EducationStage) -> String {
        switch stage {
        case .primarySchool: return "Primary School"
        case .middleSchool: return "Middle School"
        case .highSchool: return "High School"
        case .internationalHighSchool: return "International High School"
        case .university: return "University"
        case .graduate: return "Graduate"
        }
    }
    
    /// 
    private func stageColor(_ stage: EducationStage) -> Color {
        switch stage {
        case .primarySchool: return .orange
        case .middleSchool: return .green
        case .highSchool: return .blue
        case .internationalHighSchool: return .purple
        case .university: return .indigo
        case .graduate: return .pink
        }
    }
    
    private func loadFromProfile() {
        username = dataManager.profile.username
        realName = dataManager.profile.realName
        age = dataManager.profile.age
        gender = dataManager.profile.gender
        educationStage = EducationStage(rawValue: dataManager.profile.educationStage) ?? .highSchool
        regionCode = dataManager.profile.regionCode
        grade = dataManager.profile.grade
        className = dataManager.profile.className
        schoolName = dataManager.profile.schoolName
        studentId = dataManager.profile.studentId
        enrollmentYear = dataManager.profile.enrollmentYear
        examYear = dataManager.profile.examYear
        targetSchool = dataManager.profile.targetSchool
        targetScore = dataManager.profile.targetScore
    }
    
    private func saveToProfile() {
        dataManager.profile.username = username
        dataManager.profile.realName = realName
        dataManager.profile.age = age
        dataManager.profile.gender = gender
        dataManager.profile.educationStage = educationStage.rawValue
        dataManager.profile.regionCode = regionCode
        // 
        dataManager.profile.educationLevel = educationStage.rawValue
        if let region = currentRegion {
            dataManager.profile.educationSystem = region.displayName
            dataManager.profile.region = region.displayName
        }
        dataManager.profile.grade = grade
        dataManager.profile.className = className
        dataManager.profile.schoolName = schoolName
        dataManager.profile.studentId = studentId
        dataManager.profile.enrollmentYear = enrollmentYear
        dataManager.profile.examYear = examYear
        dataManager.profile.targetSchool = targetSchool
        dataManager.profile.targetScore = targetScore
        
        dataManager.saveProfile()
    }
    
    private func applySmartRecommendation() {
        dataManager.applySmartSubjectRecommendation(stage: educationStage, regionCode: regionCode)
        dataManager.saveSubjects()
    }
}

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "graduationcap.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text("StudyPulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version beta 0.0.1")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About StudyPulse".localized())
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("StudyPulse is a comprehensive learning management application designed to help students track their academic performance, analyze trends, and manage their study materials effectively.".localized())
                        
                        Text("Features:".localized())
                        Text("- Track grades across multiple subjects".localized())
                        Text("- Visualize progress with interactive charts".localized())
                        Text("- Manage mistake collections with detailed analysis".localized())
                        Text("- Personalized learning recommendations".localized())
                        Text("- Support for photo uploads for exam papers and mistakes".localized())
                    }
                    .padding()
                    
                    Link("Click to View the Repository on Github".localized(), destination: URL(string: "https://github.com/Gao-Chenkai/StudyPulse")!)
                        .font(.body)
                        .padding(.top, 10)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("About".localized())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CopyrightView: View {
    @State private var showLicenseSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    Image(systemName: "graduationcap.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text("StudyPulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version beta0.1")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.horizontal, 40)
                    
                    VStack(spacing: 8) {
                        Text("Developed by".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Gao Chenkai")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Copyright & License".localized())
                            .font(.headline)
                        
                        Button(action: {
                            withAnimation {
                                showLicenseSheet.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.orange)
                                Text("CC BY-NC-SA 4.0")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Attribution — NonCommercial — ShareAlike — 4.0 International".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            Group {
                                Label("Attribution".localized(), systemImage: "person.circle")
                                Label("Non-Commercial".localized(), systemImage: "slash.circle")
                                Label("ShareAlike".localized(), systemImage: "arrow.2.squarepath")
                            }
                            .foregroundColor(.primary)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Text("StudyPulse helps students track performance and manage study materials.\nStudyPulse 成绩追踪与学习资料管理应用".localized())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.callout)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Copyright".localized())
            .navigationBarTitleDisplayMode(.inline)
            
            .sheet(isPresented: $showLicenseSheet) {
                LicenseDetailView()
            }
        }
    }
}

// ---  ---
struct LicenseDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International".localized())
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    SectionHeader(title: "Summary".localized())
                    Text("Attribution — NonCommercial — ShareAlike — 4.0 International".localized())
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Divider()
                    
                    SectionHeader(title: "Legal Code (English Summary)".localized())
                    Text("""
                    You are free to:
                    • Share — copy and redistribute the material in any medium or format
                    • Adapt — remix, transform, and build upon the material
                    
                    Under the following terms:
                    • Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
                    • NonCommercial — You may not use the material for commercial purposes.
                    • ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
                    
                    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
                    """)
                    .font(.body)
                    .foregroundColor(.primary)
                    
                    Link("Click to View Full Legal Code in Browser".localized(), destination: URL(string: "https://creativecommons.org/licenses/by-nc-sa/4.0/")!)
                        .font(.body)
                        .padding(.top, 10)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("License Details".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done".localized()) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.blue)
            .padding(.top, 10)
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataManager())
}
