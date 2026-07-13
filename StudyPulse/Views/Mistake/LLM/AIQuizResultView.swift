//
//  AIQuizResultView.swift
//  StudyPulse
//
//  Created for AI Quiz feature.
//

import SwiftUI
import SwiftStreamingMarkdown

struct AIQuizResultView: View {
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject private var envManager: AppEnvironmentManager

    let subject: String
    let questions: [QuizQuestion]
    let userAnswers: [UUID: String]
    let gradingResponse: QuizGradingResponse
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 得分卡片
                scoreHeaderCard
                    .padding(.top)

                // 错题收录通知横幅
                mistakeSummaryBanner

                // 题目批改详情
                VStack(alignment: .leading, spacing: 16) {
                    Text("答题分析报告".localized())
                        .font(.title3.bold())
                        .padding(.horizontal)

                    ForEach(gradingResponse.results) { result in
                        if result.index < questions.count {
                            questionResultCard(result: result, question: questions[result.index])
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("自测报告".localized())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done".localized()) {
                    onDismiss()
                }
                .font(.headline)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var scoreHeaderCard: some View {
        VStack(spacing: 16) {
            Text("本次自测得分".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 环形分数图
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(gradingResponse.totalScore) / 100.0)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .frame(width: 140, height: 140)
                
                VStack(spacing: 2) {
                    Text("\(gradingResponse.totalScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(scoreColor)
                    Text("满分 100".localized())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Text(scoreLevelText)
                .font(.headline)
                .foregroundColor(scoreColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var mistakeSummaryBanner: some View {
        let incorrectCount = gradingResponse.results.filter { !$0.isCorrect }.count
        
        Group {
            if incorrectCount > 0 {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已自动将错题存入错题本".localized())
                            .font(.subheadline.bold())
                        Text("答错的 \(incorrectCount) 道题已自动加入错题库（科目：\(subjectDisplayName)），包含标准答案与解析，以便您后续进行 SRS 间隔重复复习。".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("全部正确，完美通关！".localized())
                            .font(.subheadline.bold())
                        Text("恭喜！您答对了本次自测的所有题目，这说明您对本部分内容的掌握度非常高。继续保持！".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.yellow.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func questionResultCard(result: QuizQuestionGradingResult, question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片头部
            HStack {
                Text("第 \(result.index + 1) 题").font(.headline)
                
                Spacer()
                
                // 状态徽章
                HStack(spacing: 4) {
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(result.isCorrect ? "正确".localized() : "错误".localized())
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(result.isCorrect ? Color.green : Color.red))
                
                Text("\(result.score) 分").font(.subheadline.bold())
            }

            // 题干内容
            VStack(alignment: .leading, spacing: 8) {
                Text("题目：".localized())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                MarkdownView(text: question.question.normalisingSingleDollarMath(), config: .previewConfig)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }

            // 用户作答与标准答案
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("您的作答：".localized())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text(userAnswers[question.id] ?? "(未作答)".localized())
                        .font(.subheadline.bold())
                        .foregroundColor(result.isCorrect ? .primary : .red)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("标准答案：".localized())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text(question.correctAnswer)
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)

            // AI 阅卷意见
            VStack(alignment: .leading, spacing: 8) {
                Text("AI 阅卷反馈：".localized())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                MarkdownView(text: result.feedback.normalisingSingleDollarMath(), config: .previewConfig)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 详细解析步骤
            VStack(alignment: .leading, spacing: 8) {
                Text("参考解析：".localized())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                MarkdownView(text: question.solution.normalisingSingleDollarMath(), config: .previewConfig)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var subjectDisplayName: String {
        container.subjectRepo.displayName(for: subject)
    }

    private var scoreColor: Color {
        if gradingResponse.totalScore >= 85 {
            return .green
        } else if gradingResponse.totalScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    private var scoreLevelText: String {
        if gradingResponse.totalScore >= 85 {
            return "优秀，掌握度高！".localized()
        } else if gradingResponse.totalScore >= 60 {
            return "及格，仍需巩固。".localized()
        } else {
            return "不及格，建议多做错题复习。".localized()
        }
    }

}
