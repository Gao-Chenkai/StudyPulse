//
//  PreferencesView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import SwiftUI

/// 应用偏好设置界面：语言与主题
struct PreferencesView: View {
    @EnvironmentObject var envManager: AppEnvironmentManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Appearance".localized()),
                    footer: Text("Choose your preferred color scheme.".localized())
                ) {
                    Picker("Theme".localized(), selection: Binding(
                        get: { envManager.preferences.colorScheme },
                        set: { envManager.setColorScheme($0) }
                    )) {
                        ForEach(ColorSchemeOption.allCases, id: \.self) { option in
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text(option.localizedDisplayName)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section(
                    header: Text("Language".localized()),
                    footer: Text("App language can be changed here independently of the system language.".localized())
                ) {
                    Picker("App Language".localized(), selection: Binding(
                        get: { envManager.preferences.appLanguage },
                        set: { envManager.setLanguage($0) }
                    )) {
                        ForEach(AppPreferences.Language.allLocalized, id: \.code) { lang in
                            Text(lang.displayName)
                                .tag(lang.code)
                        }
                    }
                }
                
                Section(footer: Text("Language changes require app restart to take full effect.".localized())) {
                    Button(role: .destructive) {
                        restartApp()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Restart Now".localized())
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Preferences".localized())
            .navigationBarTitleDisplayMode(.inline)
            .adaptiveMaxWidth(640)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done".localized()) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func restartApp() {
        // iOS 不支持程序内重启，提示用户手动重启
        exit(0)
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppEnvironmentManager.shared)
}
