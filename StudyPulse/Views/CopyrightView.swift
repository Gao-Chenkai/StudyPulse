//
//  CopyrightView.swift
//  StudyPulse

import SwiftUI

// MARK: - CopyrightView

struct CopyrightView: View {
    @State private var showLicenseSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    Image(systemName: "graduationcap.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                        .padding(.top, 20)

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

                    Divider()
                        .padding(.horizontal, 40)

                    VStack(spacing: 8) {
                        Text("Developed by".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Gao Chenkai")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Copyright & License".localized())
                            .font(.headline)

                        Button(action: {
                            withAnimation {
                                showLicenseSheet.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.orange)
                                Text("CC BY-NC-SA 4.0")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        VStack(alignment: .leading, spacing: 6) {
                            Text("This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Attribution — NonCommercial — ShareAlike — 4.0 International".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider()
                                .padding(.vertical, 4)

                            Group {
                                Label("Attribution".localized(), systemImage: "person.circle")
                                Label("Non-Commercial".localized(), systemImage: "slash.circle")
                                Label("ShareAlike".localized(), systemImage: "arrow.2.squarepath")
                            }
                            .foregroundColor(.primary)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    Text("StudyPulse helps students track performance and manage study materials.\nStudyPulse 成绩追踪与学习资料管理应用".localized())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.callout)

                    Spacer()
                }
                .padding()
            }
            .adaptiveMaxWidth(640)
            .navigationTitle("Copyright".localized())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLicenseSheet) {
                LicenseDetailView()
                    .adaptiveSheet()
            }
        }
    }
}

// MARK: - LicenseDetailView

struct LicenseDetailView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International".localized())
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)

                    SectionHeader(title: "Summary".localized())
                    Text("Attribution — NonCommercial — ShareAlike — 4.0 International".localized())
                        .font(.body)
                        .foregroundColor(.primary)

                    Divider()

                    SectionHeader(title: "Legal Code (English Summary)".localized())
                    Text("""
                    You are free to:
                    • Share — copy and redistribute the material in any medium or format
                    • Adapt — remix, transform, and build upon the material

                    Under the following terms:
                    • Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
                    • NonCommercial — You may not use the material for commercial purposes.
                    • ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.

                    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
                    """)
                    .font(.body)
                    .foregroundColor(.primary)

                    Link("Click to View Full Legal Code in Browser".localized(), destination: URL(string: "https://creativecommons.org/licenses/by-nc-sa/4.0/")!)
                        .font(.body)
                        .padding(.top, 10)

                    Spacer()
                }
                .padding()
            }
            .adaptiveMaxWidth(720)
            .navigationTitle("License Details".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done".localized()) {
                        dismiss()
                    }
                }
            }
        }
    }
}
