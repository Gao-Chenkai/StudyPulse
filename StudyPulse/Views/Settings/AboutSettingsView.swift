//
//  AboutSettingsView.swift
//  StudyPulse
//

import SwiftUI

struct AboutSettingsView: View {
    @State private var showingAbout = false
    @State private var showingCopyright = false
    @State private var showingUserAgreement = false

  var body: some View {
         List {
             Section {
                 SettingsDetailHeader(category: .about)
                     .listRowInsets(EdgeInsets())
                     .listRowBackground(Color.clear)
             }

                Section {
                    Button {
                        showingAbout = true
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
         }
         .listStyle(.insetGrouped)
         .background(Color(.systemGroupedBackground))
        .navigationTitle("About".localized())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAbout) {
            AboutView()
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingCopyright) {
            CopyrightView()
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingUserAgreement) {
            UserAgreementView()
                .adaptiveSheet()
        }
    }
}
