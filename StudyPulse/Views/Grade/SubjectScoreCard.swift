//
//  SubjectScoreCard.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/25.
//

import SwiftUI
import Charts

// 假设你已有 ChartDataPoint 定义，若没有请取消注释下面这段
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
    let scoreRate: Double
    let ranking: Int?
}

struct SubjectScoreCard: View {
    struct Series: Identifiable {
        let id = UUID()
        let name: String
        let dataPoints: [ChartDataPoint]
        let color: Color
    }
    
    let subject: String
    let latestGrade: Grade?
    let history: [Grade]
    let displayMode: String // 新增：接收显示模式
    @EnvironmentObject var dataManager: DataManager
    @State private var animateIn = false
    
    var fullScore: Double {
        dataManager.fullScore(for: subject)
    }
    
    var displayTitle: String {
        if let s = dataManager.subjects.first(where: { $0.name == subject }) {
            return s.displayName.isEmpty ? subject.localized() : s.displayName
        }
        return subject.localized()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: subjectIcon(subject))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title3)
                Text(displayTitle) // 使用自定义显示名
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(.label))
                Spacer()
                if let g = latestGrade {
                    HStack(spacing: 6) {
                        Text(g.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                } else {
                    Text("--").foregroundColor(Color(.secondaryLabel))
                }
            }
            
            if let g = latestGrade {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // 根据模式切换显示内容
                        if displayMode == "score" {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", g.score))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor(g.score, fullScore: fullScore))
                                Text("/ \(Int(fullScore))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let rank = g.ranking {
                                Text(String(format: "Rank: %d".localized(), rank))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            if let rank = g.ranking, rank > 0 {
                                Text("\(rank)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor(g.score, fullScore: fullScore))
                                Text(String(format: "%.1f", g.score))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("N/A".localized())
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.indigo, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(String(format: "%.1f", g.score))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    // 
                    // 只展示最近 3 个月的成绩
                    let cutoffDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                    let recentHistory = history.filter { $0.date >= cutoffDate }
                    miniChartView(
                        series: [
                            Series(
                                name: subject,
                                dataPoints: recentHistory.map {
                                    ChartDataPoint(
                                        date: $0.date,
                                        score: $0.score,
                                        scoreRate: $0.scoreRate(subjectFullScore: fullScore),
                                        ranking: $0.ranking
                                    )
                                },
                                color: displayMode == "score" ? .blue : .indigo
                            )
                        ],
                        displayMode: displayMode,
                        fullScore: fullScore
                    )
                    .frame(width: 100, height: 60)
                }
            } else {
                Text("No data available".localized())
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(.systemBlue).opacity(0.3),
                                Color(.systemBlue).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 10,
            x: 0,
            y: 5
        )
        .hoverHighlight()
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }
    
    private func subjectIcon(_ subject: String) -> String {
        switch subject {
        case "Chinese": return "character.textbox"
        case "Mathematics", "Mathematics A", "Mathematics B": return "function"
        case "English": return "textformat.abc"
        case "Science": return "atom"
        case "Physics": return "magnet"
        case "Chemistry": return "flask.fill"
        case "Biology": return "leaf.fill"
        case "History": return "hourglass"
        case "Geography": return "globe.europe.africa.fill"
        case "Politics": return "building.columns.fill"
        case "History & Society": return "book.and.wrench"
        case "Information Technology": return "laptopcomputer"
        case "General Technology": return "hammer.fill"
        case "Art": return "paintpalette.fill"
        case "Music": return "music.note.list"
        case "PE & Health": return "figure.run"
        default: return "book.fill"
        }
    }
}

// MARK: - 迷你图表（支持用户自选图表类型）
struct miniChartView: View {
    var series: [SubjectScoreCard.Series]
    var showYAxisAsPercentage: Bool = false
    var displayMode: String // 接收显示模式：score / ranking
    var fullScore: Double = 100 // 科目满分（用于按比例显示颜色）
    @EnvironmentObject var envManager: AppEnvironmentManager

    private var history: [Grade] {
        // 合并所有 series 的成绩（这里通常只有一个 subject）
        series.flatMap { s in
            s.dataPoints.map { dp in
                Grade(
                    subject: s.name,
                    score: dp.score,
                    ranking: dp.ranking,
                    date: dp.date
                )
            }
        }
    }

    var body: some View {
        if displayMode == "ranking" {
            // 排名仍用折线图（排名只有 1 个维度，不适合饼/直方图/热力）
            rankingLineChart
        } else {
            // 分数模式：按设置里选定的图表类型渲染
            let grades = history
            if grades.isEmpty {
                Color.clear
            } else {
                TrendChartView(
                    grades: grades,
                    fullScore: fullScore,
                    chartType: envManager.preferences.chartType,
                    compact: true
                )
            }
        }
    }

    private var rankingLineChart: some View {
        Chart {
            ForEach(series) { s in
                ForEach(s.dataPoints.filter { ($0.ranking ?? 0) > 0 }) { p in
                    if let rank = p.ranking, rank > 0 {
                        LineMark(
                            x: .value("Time", p.date),
                            y: .value("Rank", rank),
                            series: .value("Subject", s.name)
                        )
                        .foregroundStyle(s.color)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Time", p.date),
                            y: .value("Rank", rank)
                        )
                        .symbol {
                            Circle()
                                .fill(Color(.secondarySystemGroupedBackground))
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle().stroke(scoreColor(p.score, fullScore: fullScore), lineWidth: 2)
                                }
                        }
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

// MARK: - 预览
#Preview {
    VStack {
        SubjectScoreCard(
            subject: "Chinese",
            latestGrade: Grade(subject: "Chinese", score: 112.0, ranking: 5, date: Date()),
            history: [
                Grade(subject: "Chinese", score: 98.0, date: Date().addingTimeInterval(-86400 * 10)),
                Grade(subject: "Chinese", score: 105.0, date: Date().addingTimeInterval(-86400 * 5)),
                Grade(subject: "Chinese", score: 112.0, date: Date())
            ],
            displayMode: "score"
        )
        .environmentObject(DataManager())
        
        SubjectScoreCard(
            subject: "Mathematics",
            latestGrade: Grade(subject: "Mathematics", score: 89.0, ranking: 20, date: Date()),
            history: [
                Grade(subject: "Mathematics", score: 120.0, date: Date().addingTimeInterval(-86400 * 10)),
                Grade(subject: "Mathematics", score: 100.0, date: Date().addingTimeInterval(-86400 * 5)),
                Grade(subject: "Mathematics", score: 89.0, date: Date())
            ],
            displayMode: "ranking"
        )
        .environmentObject(DataManager())
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
