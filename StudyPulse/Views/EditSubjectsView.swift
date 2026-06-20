//
//  EditSubjectsView.swift
//  StudyPulse

import SwiftUI

struct EditSubjectsView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
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

#Preview {
    NavigationStack {
        EditSubjectsView()
            .environmentObject(DataManager())
    }
}
