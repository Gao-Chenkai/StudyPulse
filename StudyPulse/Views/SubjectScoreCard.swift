//
//  SubjectScoreCard.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/25.
//

import SwiftUI
import Charts

struct SubjectScoreCard: View {
    
    // 补全了 Series 结构体，去掉了不存在的 type，增加了 color 以便区分系列
    struct Series: Identifiable {
        let id = UUID()
        let name: String
        let dataPoints: [ChartDataPoint]
        let color: Color
    }
    
    let subject: String
    let latestGrade: Grade?
    let history: [Grade] // 新增：传入历史成绩用于绘制图表
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: subjectIcon(subject))
                    .foregroundColor(.blue)
                Text(subject).font(.headline).bold()
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
                        Text(String(format: "%.1f", g.score))
                            .font(.title).bold().foregroundColor(scoreColor(g.score))
                        if let rank = g.ranking {
                            Text("Rank: \(rank) =ChartDemo=v0425=").font(.caption).foregroundColor(.secondary)
                            
                        }
                    }
                    Spacer()
                    // 传递参数给 miniChartView
                    miniChartView(series: [
                        Series(name: subject, dataPoints: history.map { ChartDataPoint(date: $0.date, score: $0.score, scoreRate: $0.scoreRate) }, color: .blue)
                    ])
                    .frame(width: 80, height: 50) // 限制迷你图表大小
                }
            } else {
                Text("No data available").font(.caption).foregroundColor(Color(.secondaryLabel))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8)
    }
    
//    private func scoreColor(_ score: Double) -> Color {
//        // 假设满分150，如果满分不同可自行调整阈值
//        score >= 120 ? Color(.systemBlue) : score >= 90 ? Color(.systemGreen) : score >= 60 ? Color(.systemOrange) : Color(.systemRed)
//    }
    
    private func subjectIcon(_ subject: String) -> String {
        switch subject {
        case "Chinese":
            return "character.textbox" // 或者用 "pencil.and.ruler.fill"
        case "Mathematics":
            return "function"
        case "English":
            return "textformat.abc"
        case "Science":
            return "atom"
        case "Physics":
            return "magnet"
        case "Chemistry":
            return "flask.fill"
        case "Biology":
            return "leaf.fill"
        case "History":
            return "hourglass"
        case "Geography":
            return "globe.europe.africa.fill"
        case "Politics":
            return "building.columns.fill"
        case "History & Society":
            return "book.and.wrench" // 综合学科用组合图标
        case "Information Technology":
            return "laptopcomputer"
        case "General Technology":
            return "hammer.fill"
        case "Art":
            return "paintpalette.fill"
        case "Music":
            return "music.note.list"
        case "PE & Health":
            return "figure.run" // 或者用 "heart.fill" 代表健康
        default:
            return "book.fill"
        }
    }
}

// MARK: - 迷你折线统计图视图
struct miniChartView: View {
    var series: [SubjectScoreCard.Series]
    var showYAxisAsPercentage: Bool = false

    var body: some View {
        Chart {
            ForEach(series) { s in
                ForEach(s.dataPoints) { p in
                    // 绘制折线
                    LineMark(
                        x: .value("时间", p.date),
                        y: .value("分数", showYAxisAsPercentage ? p.scoreRate : p.score),
                        series: .value("科目", s.name) // 加上系列区分，方便多科目对比
                    )
                    .foregroundStyle(s.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    
                    // 绘制数据点（折线统计图标配）
                    PointMark(
                        x: .value("时间", p.date),
                        y: .value("分数", showYAxisAsPercentage ? p.scoreRate : p.score)
                    )
                    .foregroundStyle(s.color)
                    .symbolSize(20) // 数据点的大小
                }
            }
        }
        .chartXAxis(.hidden) // 迷你图隐藏X轴，保持界面简洁
        .chartYAxis(.hidden) // 迷你图隐藏Y轴
    }
}

// MARK: - 预览数据
#Preview {
    VStack {
        SubjectScoreCard(
            subject: "Chinese",
            latestGrade: Grade(subject: "Chinese", score: 112.0, ranking: 5, date: Date()),
            history: [
                Grade(subject: "Chinese", score: 98.0, date: Date().addingTimeInterval(-86400 * 10)),
                Grade(subject: "Chinese", score: 105.0, date: Date().addingTimeInterval(-86400 * 5)),
                Grade(subject: "Chinese", score: 112.0, date: Date())
            ]
        )
        
        SubjectScoreCard(
            subject: "Mathematics",
            latestGrade: Grade(subject: "Mathematics", score: 89.0, ranking: 20, date: Date()),
            history: [
                Grade(subject: "Mathematics", score: 120.0, date: Date().addingTimeInterval(-86400 * 10)),
                Grade(subject: "Mathematics", score: 100.0, date: Date().addingTimeInterval(-86400 * 5)),
                Grade(subject: "Mathematics", score: 89.0, date: Date())
            ]
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
