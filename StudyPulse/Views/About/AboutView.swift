//
//  AboutView.swift
//  StudyPulse

import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "graduationcap.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)

                    Text("StudyPulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Group {
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("Version \(version)")
                        }
                    }
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("About StudyPulse".localized())
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("StudyPulse is a comprehensive learning management application designed to help students track their academic performance, analyze trends, and manage their study materials effectively.".localized())

                        Text("Features:".localized())
                        Text("- Track grades across multiple subjects".localized())
                        Text("- Visualize progress with interactive charts".localized())
                        Text("- Manage mistake collections with detailed analysis".localized())
                        Text("- Personalized learning recommendations".localized())
                        Text("- Support for photo uploads for exam papers and mistakes".localized())
                    }
                    .padding()

                    Spacer()
                }
                .padding()
            }
            .adaptiveMaxWidth(640)
            .navigationTitle("About".localized())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
