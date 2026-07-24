//
//  CacheManagementView.swift
//  StudyPulse
//

import SwiftUI

struct CacheManagementView: View {
    private enum ClearMode: String, Identifiable {
        case selected
        case all
        var id: String { rawValue }
    }

    @State private var usage: CacheUsage = .zero
    @State private var selected = Set(CacheCategory.allCases)
    @State private var isCalculating = true
    @State private var isClearing = false
    @State private var pendingClear: ClearMode?
    @State private var showingResult = false
    @State private var lastResult = CacheClearResult(
        clearedCategories: [],
        releasedDiskBytes: 0,
        failures: [:]
    )

    private let service = CacheMaintenanceService()

    var body: some View {
        List {
            Section {
                LabeledContent {
                    if isCalculating {
                        ProgressView()
                            .accessibilityLabel("Calculating Cache Size".localized())
                    } else {
                        Text(Self.formatBytes(usage.diskBytes))
                            .font(.headline.monospacedDigit())
                    }
                } label: {
                    Label("Clearable Disk Space".localized(), systemImage: "internaldrive")
                }
            } footer: {
                Text("Cache data can be regenerated. Clearing it will not delete grades, mistakes, diaries, recordings, health history, or other personal data.".localized())
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                ForEach(CacheCategory.allCases) { category in
                    cacheRow(category)
                }
            } header: {
                Text("Cache Categories".localized())
            } footer: {
                Text("Selected categories will be cleared. Active tasks are not cancelled and may recreate cache data when they finish.".localized())
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Button {
                    pendingClear = .selected
                } label: {
                    Label("Clear Selected Cache".localized(), systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(selected.isEmpty || isClearing)

                Button(role: .destructive) {
                    pendingClear = .all
                } label: {
                    Label("Clear All Cache".localized(), systemImage: "trash.slash")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(isClearing)
            }

            if isClearing {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Clearing Cache".localized())
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cache Management".localized())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshUsage()
        }
        .refreshable {
            await refreshUsage()
        }
        .alert(item: $pendingClear) { mode in
            Alert(
                title: Text(
                    mode == .all
                        ? "Clear All Cache?".localized()
                        : "Clear Selected Cache?".localized()
                ),
                message: Text("Cache data can be regenerated. Clearing it will not delete grades, mistakes, diaries, recordings, health history, or other personal data.".localized()),
                primaryButton: .destructive(Text("Clear Cache".localized())) {
                    Task { await clear(mode) }
                },
                secondaryButton: .cancel()
            )
        }
        .alert(
            lastResult.failures.isEmpty
                ? "Cache Cleared".localized()
                : "Some Cache Could Not Be Cleared".localized(),
            isPresented: $showingResult
        ) {
            Button("OK".localized()) {}
        } message: {
            Text(resultMessage)
        }
    }

    private func cacheRow(_ category: CacheCategory) -> some View {
        let isSelected = selected.contains(category)
        return Button {
            if isSelected {
                selected.remove(category)
            } else {
                selected.insert(category)
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: category.icon)
                    .foregroundStyle(category.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.title)
                        .foregroundStyle(.primary)
                    Text(detail(for: category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .imageScale(.large)
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isClearing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.title)
        .accessibilityValue(
            "\(detail(for: category)), " +
            (isSelected ? "Selected".localized() : "Not Selected".localized())
        )
        .accessibilityHint("Double tap to change the cache selection.".localized())
    }

    private func detail(for category: CacheCategory) -> String {
        if isCalculating { return "Calculating Cache Size".localized() }
        let categoryUsage = usage.usage(for: category)
        switch category {
        case .images, .llmResponses:
            return String(
                format: "%lld cached items".localized(),
                Int64(categoryUsage.memoryEntryCount)
            )
        case .mindMaps:
            return String(
                format: "%@ · %lld cached items".localized(),
                Self.formatBytes(categoryUsage.diskBytes),
                Int64(categoryUsage.memoryEntryCount)
            )
        case .healthSnapshot:
            return Self.formatBytes(categoryUsage.diskBytes)
        }
    }

    private var resultMessage: String {
        var lines = [
            String(
                format: "Released %@".localized(),
                Self.formatBytes(lastResult.releasedDiskBytes)
            ),
        ]
        if !lastResult.failures.isEmpty {
            lines.append(
                lastResult.failures.keys
                    .sorted { $0.rawValue < $1.rawValue }
                    .map(\.title)
                    .joined(separator: ", ")
            )
        }
        return lines.joined(separator: "\n")
    }

    private func refreshUsage() async {
        isCalculating = true
        usage = await service.usage()
        isCalculating = false
    }

    private func clear(_ mode: ClearMode) async {
        guard !isClearing else { return }
        isClearing = true
        lastResult = switch mode {
        case .selected: await service.clear(selected)
        case .all: await service.clearAll()
        }
        await refreshUsage()
        isClearing = false
        showingResult = true
    }

    nonisolated private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private extension CacheCategory {
    var title: String {
        switch self {
        case .images: "Image Cache".localized()
        case .llmResponses: "AI Response Cache".localized()
        case .mindMaps: "AI Mind Maps".localized()
        case .healthSnapshot: "Health Status Snapshot".localized()
        }
    }

    var icon: String {
        switch self {
        case .images: "photo.on.rectangle.angled"
        case .llmResponses: "sparkles"
        case .mindMaps: "point.3.connected.trianglepath.dotted"
        case .healthSnapshot: "heart.text.square"
        }
    }

    var tint: Color {
        switch self {
        case .images: .blue
        case .llmResponses: .purple
        case .mindMaps: .indigo
        case .healthSnapshot: .pink
        }
    }
}
