//
//  AboutSettingsView.swift
//  StudyPulse
//

import SwiftUI

struct AboutSettingsView: View {
    @State private var showingAbout = false
    @State private var showingCopyright = false

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
    }
}
