import SwiftUI

struct BrainUsageSettingsView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    private var prefs: AppPreferences { container.envManager.preferences }

    var body: some View {
        NavigationStack {
            Form {
                Section { Picker("Quota Planning".localized(), selection: binding(\.brainUsageMode)) { Text("Manual".localized()).tag(BrainUsagePreferences.Mode.manual); Text("Dynamic from Body Data".localized()).tag(BrainUsagePreferences.Mode.dynamic) } }
                Section("Manual Quotas".localized()) {
                    Stepper("5-hour quota: \(prefs.brainUsageManualFiveHourQuota)".localized(), value: binding(\.brainUsageManualFiveHourQuota), in: BrainUsageQuota.bounds.fiveHour, step: 10)
                    Stepper("7-day quota: \(prefs.brainUsageManualSevenDayQuota)".localized(), value: binding(\.brainUsageManualSevenDayQuota), in: BrainUsageQuota.bounds.sevenDay, step: 25)
                }
                Section("Notifications".localized()) {
                    Toggle("5-hour goal reached".localized(), isOn: binding(\.brainUsageNotifyFiveHour))
                    Toggle("7-day goal reached".localized(), isOn: binding(\.brainUsageNotifySevenDay))
                }
                Section { Text("Points: mistake review 3, grade entry 5, focus analysis 1 per minute. Dynamic quotas use HRV, sleep, heart rate, breathing rate, exercise, age and grades.".localized()).font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Brain Usage".localized())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done".localized()) { dismiss() } } }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(get: { container.envManager.preferences[keyPath: keyPath] }, set: { container.envManager.preferences[keyPath: keyPath] = $0 })
    }
}
