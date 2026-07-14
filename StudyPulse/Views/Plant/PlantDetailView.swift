//
//  PlantDetailView.swift
//  StudyPulse
//
//  主页植物详情页：放大版 Canvas、阶段历史、连续打卡 / 总活跃天数、花色选择器、总开关。
//

import SwiftUI

struct PlantDetailView: View {
    @EnvironmentObject private var envManager: AppEnvironmentManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var plantManager = PlantManager.shared
    @ObservedObject private var achievementManager = AchievementManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 大号 Canvas
                PlantCanvasView(
                    stage: plantManager.currentStage,
                    petalColor: selectedPetalColor,
                    accent: envManager.effectiveAccentColor
                )
                .frame(width: 240, height: 300)
                .padding(.top, 12)

                // 当前阶段名 + 副标题
                VStack(spacing: 4) {
                    Text(plantManager.currentStage.localizedTitle)
                        .font(.title.weight(.bold))
                        .foregroundColor(.primary)
                    Text(plantManager.currentStage.localizedSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // 连续打卡 / 总活跃
                statsRow

                // 阶段历史
                historySection

                // 花色选择器
                petalColorSection

                // 总开关
                masterToggleSection
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("plant.detail.title".localized())
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var selectedPetalColor: Color {
        PetalColorCatalog.resolve(envManager.preferences.plantPetalColorId).resolved(colorScheme: colorScheme)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(
                icon: "flame.fill",
                color: .orange,
                title: "Streak",
                value: "\(achievementManager.snapshot.streak.current)"
            )
            statTile(
                icon: "calendar",
                color: .blue,
                title: "Total",
                value: "\(achievementManager.snapshot.streak.totalActiveDays)"
            )
        }
        .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
    }

    private func statTile(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color)
            Text(value).font(.title2.weight(.bold))
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("plant.detail.historyHeader".localized())
                .font(.headline)
                .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
            if plantManager.history.isEmpty {
                Text("plant.detail.historyEmpty".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(plantManager.history.reversed()) { transition in
                        HStack {
                            Image(systemName: iconForStage(transition.toStage))
                                .foregroundColor(colorForStage(transition.toStage))
                            VStack(alignment: .leading) {
                                Text("\(transition.fromStage.localizedTitle) → \(transition.toStage.localizedTitle)")
                                    .font(.subheadline)
                                Text(transition.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
            }
        }
    }

    private var petalColorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("plant.card.colorSection".localized())
                .font(.headline)
                .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
            HStack(spacing: 12) {
                ForEach(PetalColorCatalog.all) { petal in
                    Button {
                        envManager.preferences.plantPetalColorId = petal.id
                    } label: {
                        Circle()
                            .fill(petal.resolved(colorScheme: colorScheme))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        envManager.preferences.plantPetalColorId == petal.id
                                            ? Color.primary : Color.primary.opacity(0.15),
                                        lineWidth: envManager.preferences.plantPetalColorId == petal.id ? 2.5 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(petal.id)
                }
            }
            .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
        }
    }

    private var masterToggleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { envManager.preferences.plantCardEnabled },
                set: { envManager.preferences.plantCardEnabled = $0 }
            )) {
                Text("plant.card.toggle".localized())
            }
            Text("plant.card.footer".localized())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
    }

    private func iconForStage(_ stage: PlantStage) -> String {
        switch stage {
        case .seed: return "circle.fill"
        case .sprout: return "leaf.fill"
        case .bud: return "camera.macro"
        case .bloom: return "camera.fill"
        case .flourish: return "sparkles"
        case .lush: return "tree.fill"
        case .withered: return "leaf.fill"
        case .reborn: return "arrow.clockwise"
        }
    }

    private func colorForStage(_ stage: PlantStage) -> Color {
        switch stage {
        case .seed: return .brown
        case .sprout, .bud, .bloom, .flourish, .lush: return .green
        case .withered: return .gray
        case .reborn: return .blue
        }
    }
}

#Preview {
    NavigationStack {
        PlantDetailView()
            .environmentObject(AppEnvironmentManager.shared)
    }
}
