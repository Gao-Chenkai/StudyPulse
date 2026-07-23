import SwiftUI

struct ExamRoleSimulatorHomeCard: View {
    @Environment(RepositoryContainer.self) private var container
    let onOpen: () -> Void

    private var analyzed: [ExamSimulation] {
        container.examSimulationRepo.analyzedSimulations
    }

    private var latest: ExamSimulation? {
        analyzed.first
    }

    var body: some View {
        Button {
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: DesignToken.Spacing.medium) {
                HStack {
                    Image(systemName: latest?.analysis?.role.symbol ?? "person.crop.circle.badge.questionmark")
                        .font(.title2)
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("考场人格模拟器".localized())
                            .font(DesignToken.Font.titleSmall)
                            .foregroundStyle(.primary)
                        Text("识别压力下的答题决策模式，而不是定义你的性格。".localized())
                            .font(DesignToken.Font.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }

                if let analysis = latest?.analysis {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(analyzed.count >= 3 && analysis.isStable
                                 ? "你的常见考场模式".localized()
                                 : "本次考场模式".localized())
                                .font(DesignToken.Font.caption)
                                .foregroundStyle(.secondary)
                            Text(analysis.role.displayName)
                                .font(DesignToken.Font.bodyBold)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Text("\(Int(analysis.confidence * 100))%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.purple)
                    }
                    .padding(DesignToken.Spacing.medium)
                    .background(.purple.opacity(0.09), in: RoundedRectangle(cornerRadius: DesignToken.CornerRadius.medium))
                } else {
                    Label("开始第一次模拟".localized(), systemImage: "play.fill")
                        .font(DesignToken.Font.bodyBold)
                        .foregroundStyle(.purple)
                }
            }
            .padding(DesignToken.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSkin()
        }
        .buttonStyle(.plain)
    }
}
