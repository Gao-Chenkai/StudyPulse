//
//  AppearanceSettingsView.swift
//  StudyPulse
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager

  var body: some View {
         List {
             Section {
                 SettingsDetailHeader(category: .appearance)
                     .listRowInsets(EdgeInsets())
                     .listRowBackground(Color.clear)
             }

                // Language & Theme
                Section {
                    NavigationLink(destination: PreferencesView()) {
                        Label("Language & Theme".localized(), systemImage: "gearshape")
                    }
                }

                // Home Layout
                Section {
                    NavigationLink(destination: HomeLayoutSettingsView()) {
                        Label("Home Layout".localized(), systemImage: "rectangle.3.group")
                    }
                }

                // Chart Type
                Section {
                    NavigationLink(destination: ChartTypeSettingsView()) {
                        HStack {
                            Label("Chart Type".localized(), systemImage: "chart.xyaxis.line")
                            Spacer()
                            Text(envManager.preferences.chartType.localizedDisplayName)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Choose how grades are visualized: line, bar, pie, scatter, or heatmap.".localized())
                }

                // Widget
                Section {
                    trendWidgetSubjectPicker
                }
         }
         .listStyle(.insetGrouped)
         .background(Color(.systemGroupedBackground))
        .navigationTitle("Appearance & Layout".localized())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trendWidgetSubjectPicker: some View {
        let preferredSubject = TrendWidgetDataStore.loadPreferredSubject()
        let subjectsWithGrades = Dictionary(grouping: dataManager.grades, by: \.subject).keys.sorted()

        return Picker(selection: Binding<String?>(
            get: { preferredSubject },
            set: { newSubject in
                TrendWidgetDataStore.savePreferredSubject(newSubject)
                TrendWidgetSyncManager.syncTrend(grades: dataManager.grades, subjects: dataManager.subjects)
            }
        )) {
            Text("Auto".localized()).tag(String?.none)
            ForEach(subjectsWithGrades, id: \.self) { subjectName in
                Text(dataManager.displayName(for: subjectName)).tag(String?.some(subjectName))
            }
        } label: {
            Label("Trend Widget Subject".localized(), systemImage: "chart.line.uptrend.xyaxis")
        }
    }
}
