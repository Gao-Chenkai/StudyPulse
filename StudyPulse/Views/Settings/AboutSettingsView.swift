//
//  AboutSettingsView.swift
//  StudyPulse
//

import SwiftUI
import os

struct AboutSettingsView: View {
    @State private var showingCopyright = false
    @State private var showingUserAgreement = false
    @EnvironmentObject private var envManager: AppEnvironmentManager

  var body: some View {
         List {
             Section {
                 SettingsDetailHeader(category: .about)
                     .listRowInsets(EdgeInsets())
                     .listRowBackground(Color.clear)
             }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About StudyPulse".localized(), systemImage: "info.circle")
                    }
                }

                Section {
                    Button {
                        showingCopyright = true
                    } label: {
                        Label("Copyright & License".localized(), systemImage: "checkmark.shield")
                    }
                }

                Section {
                    Button {
                        showingUserAgreement = true
                    } label: {
                        Label("User Agreement".localized(), systemImage: "doc.text")
                    }
                } footer: {
                    Text("Please read the terms carefully before using StudyPulse.".localized())
                }

                debugModeSection
         }
         .listStyle(.insetGrouped)
         .background(Color(.systemGroupedBackground))
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
        .navigationTitle("About".localized())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCopyright) {
            CopyrightView()
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingUserAgreement) {
            UserAgreementView()
                .adaptiveSheet()
        }
    }

    // MARK: - Debug Mode Section

    @ViewBuilder
    private var debugModeSection: some View {
        Section {
            Toggle(isOn: $envManager.preferences.debugModeEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("debug.masterToggle".localized())
                            .foregroundColor(.primary)
                        Text("debug.masterToggleDesc".localized())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "ladybug.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .tint(.yellow)
            .onChange(of: envManager.preferences.debugModeEnabled) { _, newValue in
                Log.preferences.info("Debug 总开关 / master toggle: -> \(newValue, privacy: .public)")
            }

            if envManager.preferences.debugModeEnabled {
                Toggle(isOn: $envManager.preferences.debugVerboseLogging) {
                    Label("debug.verboseLogging".localized(), systemImage: "text.alignleft")
                }
                .tint(.yellow)

                Toggle(isOn: $envManager.preferences.debugFPSOverlay) {
                    Label("debug.fpsOverlay".localized(), systemImage: "speedometer")
                }
                .tint(.yellow)

                Toggle(isOn: $envManager.preferences.debugLayoutBounds) {
                    Label("debug.layoutBounds".localized(), systemImage: "rectangle.dashed")
                }
                .tint(.yellow)

                Toggle(isOn: $envManager.preferences.debugLongPressInspect) {
                    Label("debug.longPressInspect".localized(), systemImage: "hand.point.up.left.fill")
                }
                .tint(.yellow)

                NavigationLink {
                    DebugView()
                } label: {
                    Label("debug.openConsole".localized(), systemImage: "terminal")
                }
            }
        } header: {
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundStyle(.yellow)
                Text("debug.sectionTitle".localized())
            }
        } footer: {
            Text("debug.sectionFooter".localized())
                .font(.caption2)
        }
    }
}
