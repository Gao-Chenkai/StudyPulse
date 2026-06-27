//
//  ChartTypeSettingsView.swift
//  StudyPulse
//
//  让用户选择成绩趋势图显示类型（折线/柱状/饼图/散点/热力）。
//

import SwiftUI

struct ChartTypeSettingsView: View {
    @EnvironmentObject var envManager: AppEnvironmentManager

    private var currentType: ChartType {
        envManager.preferences.chartType
    }

    var body: some View {
        List {
            Section {
                ForEach(ChartType.allCases) { type in
                    Button {
                        envManager.preferences.chartType = type
                    } label: {
                        ChartTypeRow(
                            type: type,
                            isSelected: currentType == type
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Trend Chart Style".localized())
            } footer: {
                Text("Choose how scores are visualized across the app. This applies to Home, Trends, and Widgets.".localized())
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Chart Type".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChartTypeRow: View {
    let type: ChartType
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.18) : Color(.tertiarySystemFill))
                Image(systemName: type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .blue : .primary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(type.localizedDisplayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(type.localizedDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ChartTypeSettingsView()
            .environmentObject(AppEnvironmentManager.shared)
    }
}
