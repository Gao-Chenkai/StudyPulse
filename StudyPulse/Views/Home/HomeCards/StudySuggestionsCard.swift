//
//  StudySuggestionsCard.swift
//  StudyPulse
//
//  主页"学习建议"卡片:基于 grades / mistakes / exams / 身体状态
// 给出 3 条最高优先级建议。建议生成已迁入 HomeViewModel.generateSuggestions(...)
// (底层调用 SuggestionEngine);卡片本身只负责渲染。
//
//  Extracted from HomeView.swift during card-extraction refactor (2026-07-05).
//

import SwiftUI

/// 主页"学习建议"卡片。
/// 由父 View 注入 `HomeViewModel`(VM 暴露 `generateSuggestions(limit:)`)。
/// 卡片观察 `HealthKitManager.shared` 的 `bodyStatus`,身体状态变化时刷新建议。
struct StudySuggestionsCard: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject private var healthManager = HealthKitManager.shared
    @State private var suggestions: [StudySuggestion] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Study Suggestions".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
            }

            if suggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Start adding grades to get suggestions!".localized())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(suggestions.prefix(3), id: \.id) { suggestion in
                        SuggestionRowView(suggestion: suggestion)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .onAppear { reload() }
        .onChange(of: healthManager.bodyStatus) { _, _ in reload() }
    }

    /// 拉取最新 3 条建议。底层走 `HomeViewModel.generateSuggestions(limit:)`。
    private func reload() {
        suggestions = viewModel.generateSuggestions(limit: 3)
    }
}

// MARK: - 建议行视图

/// 单条学习建议行(展开/收起描述)。
struct SuggestionRowView: View {
    let suggestion: StudySuggestion
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(suggestion.color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: suggestion.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(suggestion.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(suggestion.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                Spacer()

                PriorityIndicator(priority: suggestion.priority)
            }

            if !isExpanded {
                Button(action: { isExpanded = true }) {
                    Text("Read more".localized())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(14)
    }
}

// MARK: - 优先级指示器

/// SuggestionRowView 右上角小色块(HIGH / MED / LOW)。
struct PriorityIndicator: View {
    let priority: StudySuggestion.Priority

    var body: some View {
        ZStack {
            Capsule()
                .fill(color.opacity(0.15))

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
        .frame(height: 20)
    }

    private var label: String {
        switch priority {
        case .high: return "HIGH".localized()
        case .medium: return "MED".localized()
        case .low: return "LOW".localized()
        }
    }

    private var color: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}
