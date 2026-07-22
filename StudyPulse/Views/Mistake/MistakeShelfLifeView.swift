import SwiftUI

struct MistakeShelfLifeView: View {
    let mistake: MistakeNote
    let now: Date
    init(mistake: MistakeNote, now: Date = Date()) { self.mistake = mistake; self.now = now }

    private var estimate: MistakeShelfLifeEstimate { MistakeShelfLife.estimate(for: mistake, now: now) }
    private var tint: Color {
        switch estimate.status {
        case .fresh: return .green
        case .expiring: return .orange
        case .expired: return .red
        case .recurrentlyFailing: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.checkmark")
                Text("保质期 · \(estimate.status.title)").fontWeight(.semibold)
                Spacer()
                Text("建议 \(estimate.suggestedReviewDate, format: .dateTime.month().day())")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .font(.caption).foregroundStyle(tint)
            ProgressView(value: estimate.remainingFraction)
                .tint(tint)
                .accessibilityLabel("错题保质期剩余")
                .accessibilityValue("\(Int(estimate.remainingFraction * 100))%")
            Text("预计遗忘：\(estimate.expectedForgettingRange.lowerBound, format: .dateTime.month().day())–\(estimate.expectedForgettingRange.upperBound, format: .dateTime.month().day())")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }
}
