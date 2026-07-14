//
//  StreakHomeCard.swift
//  StudyPulse
//
//  主页连续打卡卡片。
//  Shows current streak, today's three-goal progress, and a visual
//  bar that fills as each goal is met. Turns green when all three
//  goals are met. Tapping pushes AchievementsView.
//
//  数据源:AchievementManager.shared(单例,全局状态)
//  三档目标:错题复习 N 张 / 登记 N 个成绩 / 专注 N 分钟
//  Data source: `AchievementManager.shared` (singleton, app-wide state).
//  Three goal categories: review N mistakes / record N grades / focus N minutes.
//

import SwiftUI

/// 主页"连续打卡"卡片:展示当前连续天数 + 今日 3 档目标进度。
/// Home "Streak" card: shows current streak length + today's 3 goal bars.
struct StreakHomeCard: View {
    @ObservedObject private var achievementManager = AchievementManager.shared
    @EnvironmentObject private var envManager: AppEnvironmentManager

    /// 今日目标配置(从 AchievementManager 快照中取)
    /// Today's goal configuration (from `AchievementManager`'s snapshot).
    private var config: DailyGoalConfig {
        achievementManager.snapshot.config
    }

    /// 今日活动日志(默认空,首次访问时新建)
    /// Today's activity log (empty default; created on first access).
    private var todayLog: DailyActivityLog {
        achievementManager.todayLog
    }

    /// 当前 / 最长连续天数
    /// Current / longest streak.
    private var streak: StreakState {
        achievementManager.snapshot.streak
    }

    var body: some View {
        NavigationLink(destination: AchievementsView()) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card Content
    // MARK: - 卡片内容

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部:当前连续天数
            // Header: current streak
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                    Text(String(format: "streak.card.title".localized(), streak.current))
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                if streak.longest > 0 {
                    Text(String(format: "streak.card.longest".localized(), streak.longest))
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                        )
                }
            }

            if achievementManager.todayGoalsMet {
                todayDoneBanner
            } else if todayLog.totalActivityPoints == 0 {
                noActivityBanner
            } else {
                goalsProgress
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin()
        .debugLayoutBoundsAuto()
    }

    // MARK: - Today Done Banner
    // MARK: - 今日完成 banner

    private var todayDoneBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundColor(.green)
            Text("streak.card.allGoalsMet".localized())
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.green)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.green.opacity(0.1))
        )
    }

    // MARK: - No Activity
    // MARK: - 无活动状态

    private var noActivityBanner: some View {
        Text("streak.card.noActivity".localized())
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
    }

    // MARK: - Goals Progress
    // MARK: - 目标进度

    private var goalsProgress: some View {
        VStack(spacing: 8) {
            goalRow(
                icon: "rectangle.stack.fill",
                color: .purple,
                current: todayLog.mistakeReviews,
                target: config.mistakeReviewTarget,
                unit: "cards".localized()
            )
            goalRow(
                icon: "list.bullet.rectangle",
                color: .blue,
                current: todayLog.gradesRecorded,
                target: config.gradeRecordTarget,
                unit: "entries".localized()
            )
            goalRow(
                icon: "timer",
                color: .orange,
                current: todayLog.focusMinutes,
                target: config.focusMinutesTarget,
                unit: "min".localized()
            )
        }
    }

    @ViewBuilder
    private func goalRow(icon: String, color: Color, current: Int, target: Int, unit: String) -> some View {
        // target > 0 时比例用 current/target,否则显示空
        // When target > 0, fill the bar with current/target; otherwise empty.
        let isMet = current >= target
        let fraction = target > 0 ? min(1.0, Double(current) / Double(target)) : 0.0

        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isMet ? .green : color)
                .frame(width: 20)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(isMet ? Color.green : color)
                        .frame(width: max(6, proxy.size.width * fraction))
                }
            }
            .frame(height: 8)

            Text("\(current)/\(target) \(unit)")
                .font(.caption.monospacedDigit())
                .foregroundColor(isMet ? .green : .secondary)
                .frame(width: 72, alignment: .trailing)

            if isMet {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.green)
            }
        }
    }
}
