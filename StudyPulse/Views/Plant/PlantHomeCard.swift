//
//  PlantHomeCard.swift
//  StudyPulse
//
//  主页植物卡片：基于 PlantManager.currentStage 渲染 PlantCanvasView。
//  复用 cardSkin + symbolEffect(.bounce) 风格。
//  关闭总开关时显示 "Plant hidden" 卡片（带一个 re-enable Toggle）。
//

import SwiftUI

struct PlantHomeCard: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme
    @State private var plantManager = PlantManager.shared

    var body: some View {
        Group {
            if container.envManager.preferences.plantCardEnabled {
                activeContent
            } else {
                hiddenContent
            }
        }
        .debugLayoutBoundsAuto()
    }

    // MARK: - Active

    private var activeContent: some View {
        let stage = plantManager.currentStage
        let petalColorId = container.envManager.preferences.plantPetalColorId
        let petal = PetalColorCatalog.resolve(petalColorId).resolved(colorScheme: colorScheme)
        return NavigationLink(destination: PlantDetailView()) {
            cardContent(stage: stage, petal: petal)
        }
        .buttonStyle(.plain)
    }

    private func cardContent(stage: PlantStage, petal: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 头部：标题 + 当前阶段
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.title3)
                        .foregroundColor(container.envManager.effectiveAccentColor)
                        .symbolEffect(.bounce, value: stage)
                    Text("plant.card.title".localized())
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Text(stage.localizedTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color(.tertiarySystemFill))
                    )
            }

            // Canvas 渲染
            HStack {
                Spacer()
                PlantCanvasView(
                    stage: stage,
                    petalColor: petal,
                    accent: container.envManager.effectiveAccentColor
                )
                .frame(width: 160, height: 200)
                Spacer()
            }

            // 副标题
            Text(stage.localizedSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignToken.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin()
    }

    // MARK: - Hidden

    private var hiddenContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "leaf")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("plant.card.title".localized())
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            Text("plant.card.hiddenHint".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Toggle(isOn: Binding(
                get: { container.envManager.preferences.plantCardEnabled },
                set: { container.envManager.preferences.plantCardEnabled = $0 }
            )) {
                Text("plant.card.toggle".localized()).font(.subheadline)
            }
        }
        .padding(DesignToken.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin()
    }
}

// MARK: - Preview

#Preview("Plant Card - Active") {
    PlantHomeCard()
        .environment(RepositoryContainer())
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Plant Card - Hidden") {
    let container = RepositoryContainer()
    PlantHomeCard()
        .environment(container)
        .padding()
        .background(Color(.systemGroupedBackground))
        .onAppear {
            container.envManager.preferences.plantCardEnabled = false
        }
}
