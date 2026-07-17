//
//  HealthSettingsView.swift
//  StudyPulse
//

import SwiftUI

struct HealthSettingsView: View {
    @EnvironmentObject var hrvManager: HealthKitManager
    @Environment(RepositoryContainer.self) private var container
    @State private var showingHRVOnboarding = false

  var body: some View {
         List {
             Section {
                 SettingsDetailHeader(category: .health)
                     .listRowInsets(EdgeInsets())
                     .listRowBackground(Color.clear)
             }
 
                Section {
                    HStack {
                        Label("Health Monitoring".localized(), systemImage: "heart.text.square")
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
                } footer: {
                    Text("Reads HRV, resting heart rate, respiratory rate and last night's sleep from Apple Health with your permission. Your data stays on device and is never uploaded.".localized())
                }

                if hrvManager.hrvEnabled && hrvManager.hrvOnboardingCompleted {
                    Section {
                        Toggle(isOn: heartRateStreamingBinding) {
                            Label("Stream Apple Watch HR during study".localized(), systemImage: "applewatch.radiowaves.left.and.right")
                        }
                    } footer: {
                        Text("When enabled, the study timer collects Apple Watch heart-rate samples in real time. After the session ends, a chart is shown with high-HR peaks highlighted for logging difficulties encountered. Sample density depends on Apple Watch passive monitoring frequency.".localized())
                    }

                    Section {
                        Picker("HRV Card Detail".localized(), selection: detailLevelBinding) {
                            ForEach(HRVDetailLevel.allCases, id: \.rawValue) { level in
                                Text(detailLevelLabel(level)).tag(level)
                            }
                        }
                    }

                    Section {
                        Button {
                            Task { await hrvManager.refreshReadiness() }
                            Task { await hrvManager.refreshBodyStatus() }
                        } label: {
                            Label("Refresh Now".localized(), systemImage: "arrow.clockwise")
                        }
                    } footer: {
                        Text("Re-reads HRV and today's body signals from Apple Health.".localized())
                    }

                    Section {
                        Button {
                            showingHRVOnboarding = true
                        } label: {
                            Label("Learn About Health Monitoring".localized(), systemImage: "info.circle")
                        }
                    }
                }

                // 学习日记入口(独立于 HRV 开关,始终显示)
                // Study Diary entry (independent of HRV toggle; always shown).
                Section {
                    NavigationLink {
                        DiarySettingsView()
                    } label: {
                        Label("Study Diary".localized(), systemImage: "book.fill")
                    }
                } footer: {
                    Text("Daily study diary with mood and energy tags. Syncs to Apple Health Mindful Session.".localized())
                }
         }
         .listStyle(.insetGrouped)
         .background(Color(.systemGroupedBackground))
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
        .navigationTitle("Health & Readiness".localized())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingHRVOnboarding) {
            HRVOnboardingView()
                .environmentObject(hrvManager)
                .adaptiveSheet()
        }
    }

    private var detailLevelBinding: Binding<HRVDetailLevel> {
        Binding(
            get: { hrvManager.hrvDetailLevel },
            set: { hrvManager.hrvDetailLevel = $0 }
        )
    }

    private var heartRateStreamingBinding: Binding<Bool> {
        Binding(
            get: { container.envManager.heartRateStreamingEnabled },
            set: { container.envManager.setHeartRateStreamingEnabled($0) }
        )
    }

    private func detailLevelLabel(_ level: HRVDetailLevel) -> String {
        switch level {
        case .suggestionOnly: return "Suggestion Only".localized()
        case .dataAndSuggestion: return "Data + Suggestion".localized()
        case .chartAndData: return "Chart + Data + Suggestion".localized()
        }
    }
}
