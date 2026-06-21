//
//  HealthSettingsView.swift
//  StudyPulse
//

import SwiftUI

struct HealthSettingsView: View {
    @EnvironmentObject var hrvManager: HealthKitManager
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
         }
         .listStyle(.insetGrouped)
         .background(Color(.systemGroupedBackground))
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

    private func detailLevelLabel(_ level: HRVDetailLevel) -> String {
        switch level {
        case .suggestionOnly: return "Suggestion Only".localized()
        case .dataAndSuggestion: return "Data + Suggestion".localized()
        case .chartAndData: return "Chart + Data + Suggestion".localized()
        }
    }
}
