//
//  DebugView.swift
//  StudyPulse
//
//  Debug 模式总入口（彩蛋解锁后弹出）。
//  Top-level entry of the Debug mode (unlocked via the About-version Easter egg).
//
//  内含 3 个子页面：
//  - LogViewerView        日志查看器
//  - PerformancePanelView 性能面板（FPS / 内存 / 卡顿）
//  - DebugCacheView       状态 & 缓存管理
//

import SwiftUI
import os

struct DebugView: View {
    @Environment(RepositoryContainer.self) private var container
    @State private var logCount = 0

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LogViewerView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("debug.logViewer".localized())
                                .foregroundColor(.primary)
                            Text(logViewerSubtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(.blue)
                    }
                }

                NavigationLink {
                    PerformancePanelView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("debug.performancePanel".localized())
                                .foregroundColor(.primary)
                            Text("FPS · Memory · Lags".localized())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "speedometer")
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("debug.diagnostics".localized())
            }

            Section {
                NavigationLink {
                    DebugCacheView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("debug.stateAndCache".localized())
                                .foregroundColor(.primary)
                            Text("Widget · Notifications · Caches".localized())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundStyle(.purple)
                    }
                }
            } header: {
                Text("debug.maintenance".localized())
            }

            Section {
                LabeledContent("Version".localized(),
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                LabeledContent("Build".localized(),
                    value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
                LabeledContent("OS".localized(),
                    value: ProcessInfo.processInfo.operatingSystemVersionString)
                LabeledContent("App Language".localized(),
                    value: container.envManager.effectiveLanguage ?? "auto")
                LabeledContent("Accent".localized(),
                    value: container.envManager.effectiveAccent.rawValue)
            } header: {
                Text("debug.buildInfo".localized())
            }

            Section {
                NavigationLink {
                    PlantDebugView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("debug.plant.title".localized())
                                .foregroundColor(.primary)
                            Text("Force Stage · State Inspection".localized())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "leaf.circle")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("debug.experiments".localized())
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("debug.title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let entries = await LogStore.shared.allEntries
            logCount = entries.count
        }
    }

    private var logViewerSubtitle: String {
        return "\(logCount) / 5000 " + "entries".localized()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DebugView()
            .environment(RepositoryContainer())
    }
}
#endif
