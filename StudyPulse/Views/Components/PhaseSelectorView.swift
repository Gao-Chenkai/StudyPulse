//
//  PhaseSelectorView.swift
//  StudyPulse
//
//  全局 phase 切换器(胶囊 pill),放在各主页面 toolbar 顶部。
//  Global phase switcher pill shown in each main page's toolbar.
//

import SwiftUI

/// 全局 phase 切换器。
/// Global phase switcher. Shows current phase (or "All Data") and opens a menu
/// to switch. Embedded in each main page's toolbar.
struct PhaseSelectorView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager

    var body: some View {
        Menu {
            // 全部数据选项
            Button {
                dataManager.activatePhase(nil)
            } label: {
                Label {
                    Text("All Data".localized())
                } icon: {
                    Image(systemName: envManager.activePhaseId == nil
                         ? "checkmark.circle.fill"
                         : "circle")
                }
            }

            if !dataManager.phases.isEmpty {
                Divider()
                // 按 startDate 降序(最新优先)
                ForEach(dataManager.phases) { phase in
                    Button {
                        dataManager.activatePhase(phase)
                    } label: {
                        Label {
                            HStack {
                                Text(phase.name)
                                if phase.isArchived {
                                    Text("·")
                                    Text("Archived".localized())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: envManager.activePhaseId == phase.id
                                 ? "checkmark.circle.fill"
                                 : "circle")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12, weight: .semibold))
                Text(labelText)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(envManager.activePhaseId == nil
                             ? Color.secondary
                             : envManager.effectiveAccentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(envManager.activePhaseId == nil
                          ? Color.secondary.opacity(0.12)
                          : envManager.effectiveAccentColor.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        envManager.activePhaseId == nil
                            ? Color.secondary.opacity(0.25)
                            : envManager.effectiveAccentColor.opacity(0.35),
                        lineWidth: 0.5
                    )
            )
        }
        .accessibilityLabel(Text("Study Phase".localized()))
    }

    private var labelText: String {
        if let phase = dataManager.activePhase {
            return phase.name
        }
        return "All Data".localized()
    }
}
