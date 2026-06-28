//
//  AchievementUnlockToast.swift
//  StudyPulse
//
//  成就解锁即时提示 — 顶部滑入 toast。
//  Slide-down toast shown when one or more achievements unlock.
//  Queues multiple badges and displays them one at a time.
//

import SwiftUI

struct AchievementUnlockToast: View {
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var currentProgress: AchievementProgress?
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .top) {
            if let progress = currentProgress, isVisible {
                toastView(for: progress)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isVisible)
        .onChange(of: achievementManager.newlyUnlocked) { _, newValue in
            showNextIfNeeded()
        }
        .onAppear {
            showNextIfNeeded()
        }
    }

    // MARK: - Queue management

    private func showNextIfNeeded() {
        guard currentProgress == nil, !achievementManager.newlyUnlocked.isEmpty else { return }
        guard let next = achievementManager.newlyUnlocked.first else { return }
        currentProgress = next
        withAnimation { isVisible = true }

        // Auto-dismiss after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dismissCurrent()
        }
    }

    private func dismissCurrent() {
        guard let progress = currentProgress else { return }
        withAnimation { isVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            achievementManager.dismissNewlyUnlocked(progress)
            currentProgress = nil
            showNextIfNeeded()
        }
    }

    // MARK: - Toast View

    private func toastView(for progress: AchievementProgress) -> some View {
        let def = progress.definition

        return Button {
            dismissCurrent()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tierColor(for: def.tier).opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: def.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(tierColor(for: def.tier))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("toast.unlocked".localized())
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("achievement.\(def.id).title".localized())
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }

    private func tierColor(for tier: AchievementDefinition.Tier) -> Color {
        switch tier {
        case .onboarding: return .green
        case .streak: return .orange
        case .volume: return .purple
        case .mastery: return .blue
        case .special: return .pink
        }
    }
}
