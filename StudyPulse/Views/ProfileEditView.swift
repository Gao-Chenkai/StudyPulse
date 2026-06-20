//
//  ProfileEditView.swift
//  StudyPulse

import SwiftUI

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

    private var availableRegions: [EducationRegion] {
        var regions = EducationConfig.availableRegions(for: educationStage)
        if let filter = categoryFilter {
            regions = regions.filter { $0.category == filter }
        }
        return regions
    }

    private var currentRegion: EducationRegion? {
        EducationConfig.region(named: regionCode, stage: educationStage)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Education Stage
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

                // Region / Education System
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

                // Personal Info
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

                // School Info
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

                // Academic Year
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
            .adaptiveForm()
            .navigationTitle("Edit Profile".localized())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFromProfile()
            }
            .onChange(of: educationStage) { _, newValue in
                // Reset region if the current one doesn't exist for the new stage.
                if EducationConfig.region(named: regionCode, stage: newValue) == nil {
                    regionCode = EducationConfig.defaultRegion(for: newValue).name
                }
            }
            .onChange(of: categoryFilter) { _, _ in
                // Reset region if it's no longer in the filtered list.
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

    private func stageLabel(_ stage: EducationStage) -> String {
        switch stage {
        case .primarySchool: return "Primary School".localized()
        case .middleSchool: return "Middle School".localized()
        case .highSchool: return "High School".localized()
        case .internationalHighSchool: return "International High School".localized()
        case .university: return "University".localized()
        case .graduate: return "Graduate".localized()
        }
    }

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
        // Sync derived fields.
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
