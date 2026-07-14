//
//  AboutSettingsView.swift
//  StudyPulse
//

import SwiftUI
import os

struct AboutSettingsView: View {
    @State private var showingCopyright = false
    @State private var showingUserAgreement = false
    @Environment(RepositoryContainer.self) private var container

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
            Toggle(isOn: Binding(
                get: { container.envManager.preferences.debugModeEnabled },
                set: { container.envManager.preferences.debugModeEnabled = $0 }
            )) {
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
            .onChange(of: container.envManager.preferences.debugModeEnabled) { _, newValue in
                Log.preferences.info("Debug 总开关 / master toggle: -> \(newValue, privacy: .public)")
            }

            if container.envManager.preferences.debugModeEnabled {
                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.debugVerboseLogging },
                    set: { container.envManager.preferences.debugVerboseLogging = $0 }
                )) {
                    Label("debug.verboseLogging".localized(), systemImage: "text.alignleft")
                }
                .tint(.yellow)

                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.debugFPSOverlay },
                    set: { container.envManager.preferences.debugFPSOverlay = $0 }
                )) {
                    Label("debug.fpsOverlay".localized(), systemImage: "speedometer")
                }
                .tint(.yellow)

                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.debugLayoutBounds },
                    set: { container.envManager.preferences.debugLayoutBounds = $0 }
                )) {
                    Label("debug.layoutBounds".localized(), systemImage: "rectangle.dashed")
                }
                .tint(.yellow)

                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.debugLongPressInspect },
                    set: { container.envManager.preferences.debugLongPressInspect = $0 }
                )) {
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
