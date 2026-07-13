//
//  EditSubjectsView.swift
//  StudyPulse
//
//  学科编辑页：开关 + 满分设置 + 一键还原推荐学科。
//  Subject editor: enable/disable toggle, full score, smart recommendation reset.
//

import SwiftUI

/// 学科编辑视图：用户可启用/停用学科、调整满分，并可一键还原推荐配置。
/// Subject editor: enable/disable, adjust full score, and reset to recommended.
struct EditSubjectsView: View {
    @Environment(RepositoryContainer.self) private var container

    var body: some View {
        // 双向绑定 subjects 数组：写回时自动同步到 repository
        // Two-way binding for subjects array: writes back to the repository.
        let subjectsBinding = Binding<[Subject]>(
            get: { container.subjectRepo.subjects },
            set: { container.subjectRepo.subjects = $0 }
        )
        List {
            // 学科列表：Toggle 启用、名称显示、满分输入
            // Subject list: enable toggle, display name, full score field.
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

            // 一键重置为推荐学科（基于 educationStage + regionCode）
            // One-tap reset to recommended subjects based on stage + region.
            Section {
                Button(action: {
                    if let stage = EducationStage(rawValue: container.profileRepo.profile.educationStage) {
                        // 应用智能推荐 + 持久化
                        // Apply smart recommendation and persist subjects.
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
        // 退出时持久化 profile + subjects
        // Persist profile + subjects on disappear.
        .onDisappear {
            container.profileRepo.saveProfile()
            container.subjectRepo.saveSubjects()
        }
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
    }
}

#Preview {
    NavigationStack {
        EditSubjectsView()
            .environment(RepositoryContainer())
    }
}
