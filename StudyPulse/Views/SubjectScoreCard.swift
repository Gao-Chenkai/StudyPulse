//
//  SubjectScoreCard.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/25.
//

import SwiftUI
import Charts

 //假设你已有 ChartDataPoint 定义，若没有请取消注释下面这段
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: subjectIcon(subject))
                    .foregroundColor(.blue)
                Text(subject.localized()) // 本地化科目名
                    .font(.headline).bold()
                    .foregroundColor(Color(.label))
                Spacer()
                if let g = latestGrade {
                    HStack {
                        Text(g.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                    }
                } else {
                    Text("--").foregroundColor(Color(.secondaryLabel))
                }
            }
            
            if let g = latestGrade {
                HStack {
                    VStack(alignment: .leading) {
                        // 根据模式切换显示内容
                        if displayMode == "score" {
                            Text(String(format: "%.1f", g.score))
                                .font(.title).bold()
                                .foregroundColor(scoreColor(g.score))
                            if let rank = g.ranking {
                                Text("Rank: \(rank)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            if let rank = g.ranking, rank > 0 {
                                Text("\(rank)")
                                    .font(.title).bold()
                                    .foregroundColor(scoreColor(g.score))
                                Text(String(format: "%.1f", g.score))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("N/A")
                                    .font(.title).bold()
                                    .foregroundColor(.indigo)
                                Text(String(format: "%.1f", g.score))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    // 传递模式给迷你图表
                    miniChartView(
                        series: [
                            Series(
                                name: subject,
                                dataPoints: history.map {
                                    ChartDataPoint(
                                        date: $0.date,
                                        score: $0.score,
                                        scoreRate: $0.scoreRate,
                                        ranking: $0.ranking
                                    )
                                },
                                color: displayMode == "score" ? .blue : .indigo
                            )
                        ],
                        displayMode: displayMode
                    )
                    .frame(width: 80, height: 50)
                }
            } else {
                Text("No data available")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8)
    }
    
    private func subjectIcon(_ subject: String) -> String {
        switch subject {
        case "Chinese": return "character.textbox"
        case "Mathematics": return "function"
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

// MARK: - 迷你折线图（支持分数/排名切换）
struct miniChartView: View {
    var series: [SubjectScoreCard.Series]
    var showYAxisAsPercentage: Bool = false
    var displayMode: String // 新增：接收显示模式
    
    var body: some View {
        Chart {
            ForEach(series) { s in
                ForEach(s.dataPoints) { p in
                    if displayMode == "score" {
                        // 分数图表
                        LineMark(
                            x: .value("时间", p.date),
                            y: .value("分数", showYAxisAsPercentage ? p.scoreRate : p.score),
                            series: .value("科目", s.name)
                        )
                        .foregroundStyle(s.color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        PointMark(
                            x: .value("时间", p.date),
                            y: .value("分数", showYAxisAsPercentage ? p.scoreRate : p.score)
                        )
                        .symbol {
                            Circle()
                                .fill(Color(.secondarySystemGroupedBackground))
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle().stroke(scoreColor(p.score), lineWidth: 2)
                                }
                        }
                    } else {
                        // 排名图表（只画有效排名）
                        if let rank = p.ranking, rank > 0 {
                            LineMark(
                                x: .value("时间", p.date),
                                y: .value("排名", rank),
                                series: .value("科目", s.name)
                            )
                            .foregroundStyle(s.color)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            PointMark(
                                x: .value("时间", p.date),
                                y: .value("排名", rank)
                            )
                            .symbol {
                                Circle()
                                    .fill(Color(.secondarySystemGroupedBackground))
                                    .frame(width: 8, height: 8)
                                    .overlay {
                                        Circle().stroke(scoreColor(p.score), lineWidth: 2)
                                    }
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
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
