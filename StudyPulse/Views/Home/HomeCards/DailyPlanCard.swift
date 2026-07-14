//
//  DailyPlanCard.swift
//  StudyPulse
//
//  Home "今日 3 件最重要的事"卡片。参与主页卡片自定义排序
//  (与其他 HomeCardType 一样,可由用户在布局设置中拖动 / 隐藏)。
//  Home "Today's Top 3" card. Participates in the Home card reorderable layout
//  (like all other HomeCardType values, can be dragged/hidden by the user).
//
//  渲染来源:`HomeViewModel.dailyPlan`(由 `DailyPlanEngine` 派生)。
//  Data source: `HomeViewModel.dailyPlan` (derived by `DailyPlanEngine`).
//
//  Created for Plans & Routines spec (2026-07-09).
//

import SwiftUI

/// Home 可配置卡,展示今日 Top-3 计划。
/// 渲染来源:HomeViewModel.dailyPlan(由 DailyPlanEngine 派生)
/// Home configurable card that shows today's top-3 plan items.
/// Data source: HomeViewModel.dailyPlan (derived by DailyPlanEngine).
struct DailyPlanCard: View {
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject private var envManager: AppEnvironmentManager
    @State private var animateIn = false

    /// items 由 HomeView 传入(单一数据源,避免再次重算)
    /// Items are passed in by HomeView (single source of truth, avoid re-deriving here).
    let items: [DailyPlanItem]

    /// 占位 1 行短文本(单 item 时用)
    /// True when the only item is the "all clear" placeholder (used to show a short 1-line layout).
    private var isPlaceholder: Bool {
        items.count == 1 && items.first?.kind == .placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin()
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }

    // MARK: - Sections
    // MARK: - 子视图分区

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.85), Color.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Top 3".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitleText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isPlaceholder {
            placeholderRow
        } else {
            VStack(spacing: 10) {
                ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { idx, item in
                    PlanItemRow(rank: idx + 1, item: item, container: container)
                }
            }
        }
    }

    @ViewBuilder
    private var placeholderRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundColor(.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text("All clear".localized())
                    .font(.system(size: 15, weight: .semibold))
                Text("Pick something to study or add a routine.".localized())
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var subtitleText: String {
        let now = Date()
        let dateText = DateFormatters.weekdayDate.string(from: now)
        if let readiness = currentReadinessLabel() {
            return "\(dateText) · \(readiness)"
        }
        return dateText
    }

    private func currentReadinessLabel() -> String? {
        // 简单读 readiness category 标签(无值时返回 nil)
        // HealthKitManager 是环境单例,放在 HomeViewModel 里更合适,
        // 这里读 profile.hrvEnabled + 简单 fallback 文案
        // Simple readiness category label lookup (returns nil when no value).
        // HealthKitManager is an environment singleton and lives in HomeViewModel;
        // here we just read profile.hrvEnabled + a simple fallback string.
        return nil
    }
}

// MARK: - 单行 item
// MARK: - Single Plan Item Row

private struct PlanItemRow: View {
    let rank: Int
    let item: DailyPlanItem
    let container: RepositoryContainer

    @State private var animateIn = false

    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .center, spacing: 12) {
                // 排名圈
                // Rank badge (circle)
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Text("\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(item.color)
                }

                // 类型图标
                // Item-type icon
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(item.color)
                    .frame(width: 22)

                // 标题 + 理由
                // Title + reason text
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(item.reason)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground).opacity(0.55))
            )
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 6)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(rank) * 0.06)) {
                animateIn = true
            }
        }
    }

    private func handleTap() {
        // 跳转逻辑:目前只打日志 + 微震动;具体跳转由后续 View 接入。
        // 这里通过 NotificationCenter 让宿主 View 接管跳转。
        // Tap routing: currently just log + light haptics; the actual navigation
        // is handled by the host View. We post via NotificationCenter so the
        // host can take over the navigation.
        NotificationCenter.default.post(
            name: .dailyPlanItemTapped,
            object: nil,
            userInfo: ["item": item]
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

extension Notification.Name {
    /// 今日计划 item 被点击通知(供宿主 View 接管跳转)
    /// Notification posted when a today-plan item is tapped (host View takes over navigation).
    static let dailyPlanItemTapped = Notification.Name("StudyPulse.dailyPlanItemTapped")
}
