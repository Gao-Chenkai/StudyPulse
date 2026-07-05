//
//  EditSubjectsView.swift
//  StudyPulse

import SwiftUI

struct EditSubjectsView: View {
    @Environment(RepositoryContainer.self) private var container

    var body: some View {
        let subjectsBinding = Binding<[Subject]>(
            get: { container.subjectRepo.subjects },
            set: { container.subjectRepo.subjects = $0 }
        )
        List {
            Section(header: Text("Subjects".localized()),
                    footer: Text("Toggle the subjects you're studying. Tap the score to adjust the full score for each subject.".localized())) {
                ForEach(subjectsBinding) { $subject in
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
                    if let stage = EducationStage(rawValue: container.profileRepo.profile.educationStage) {
                        container.applySmartSubjectRecommendation(
                            stage: stage,
                            regionCode: container.profileRepo.profile.regionCode
                        )
                        container.subjectRepo.saveSubjects()
                    }
                }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .appleIntelligenceForeground()
                        Text("Reset to Recommended Subjects".localized())
                            .appleIntelligenceForeground()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Edit Subjects".localized())
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            container.profileRepo.saveProfile()
            container.subjectRepo.saveSubjects()
        }
    }
}

#Preview {
    NavigationStack {
        EditSubjectsView()
            .environment(RepositoryContainer())
    }
}
