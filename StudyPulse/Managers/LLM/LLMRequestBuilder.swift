//
//  LLMRequestBuilder.swift
//  StudyPulse
//
//  把 StudyPulse 内部数据(学习建议上下文 / 错题 / 周报 / 对话历史)
//  拼装成 `LLMPrompt`(system + messages)与可选的 `suggestionParser`。
//
//  全部为纯函数 / enum,无副作用,易测。
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation
import SwiftUI

// MARK: - 1) Study Suggestions (学习建议)

/// 学习建议 prompt 工厂。
enum StudySuggestionsLLM {
    /// 默认 system prompt。要求 LLM 输出 Markdown 列表,
    /// 3 条,每条格式 `- **<icon> <title>** — <description>`。
    static let defaultSystem: String = """
        你是 StudyPulse 的学习教练。基于用户提供的成绩、错题、考试和身体数据,生成 3 条个性化、可执行的中文学习建议。
        要求:
        1. 每条建议聚焦一个不同维度(弱势科目 / 即将考试 / 错题复习 / 身体状态 / 持续提升),不要重复。
        2. 严格使用 Markdown 列表输出,每条格式:
           - **<SF Symbol 名> <建议标题>** — <一句话建议,20-60 字>
        3. SF Symbol 名从以下选择(不要自造):exclamationmark.triangle.fill / timer / doc.text.magnifyingglass / chart.line.uptrend.xyaxis / chart.line.downtrend.xyaxis / hand.thumbsup.fill / lightbulb.fill / heart.text.square / brain.head.profile
        4. 严禁输出 JSON、解释、客套话、Markdown 标题、代码块;只输出 3 行 Markdown 列表。
        """

    /// 构造 prompt。`context` 由 `StudySuggestionsContext` 提供,内部由
    /// `LLMClient` 之外的 View / ViewModel 准备(避免循环依赖)。
    static func makePrompt(_ context: StudySuggestionsContext) -> LLMPrompt {
        let userJSON = encodeContext(context)
        return LLMPrompt(
            system: defaultSystem,
            messages: [.user(userJSON)]
        )
    }

    /// 解析 LLM 输出为 `[StudySuggestion]`。
    /// 行格式:`- **<icon> <title>** — <description>`
    /// 解析失败返回 `nil`,UI 端应回退到本地建议。
    static func parse(_ output: String) -> [StudySuggestion]? {
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var results: [StudySuggestion] = []
        for line in lines {
            // 仅解析以 "- **" 开头的行
            guard line.hasPrefix("- **") || line.hasPrefix("-**") else { continue }
            // 提取 **...** 之间的 icon + title
            guard let boldRange = line.range(of: "**"),
                  let boldEnd = line.range(of: "**", range: boldRange.upperBound..<line.endIndex) else { continue }
            let boldContent = String(line[boldRange.upperBound..<boldEnd.lowerBound])
            // 在 boldContent 中找第一个空格分隔 icon / title
            let parts = boldContent.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            let icon = String(parts.first ?? "lightbulb.fill")
            let title = String(parts.count > 1 ? parts[1] : Substring(boldContent))
            // 提取 — 之后的描述
            let afterBold = line[boldEnd.upperBound...]
            let descText: String
            if let dashRange = afterBold.range(of: "—") {
                descText = String(afterBold[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else if let dashRange = afterBold.range(of: "-") {
                // fallback to ASCII dash
                descText = String(afterBold[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                descText = String(afterBold).trimmingCharacters(in: .whitespaces)
            }
            guard !descText.isEmpty else { continue }
            results.append(StudySuggestion(
                icon: icon,
                title: title,
                description: descText,
                priority: .medium,
                color: .blue
            ))
        }
        return results.isEmpty ? nil : Array(results.prefix(3))
    }

    // MARK: - Context Encoder (上下文序列化)

    private static func encodeContext(_ c: StudySuggestionsContext) -> String {
        // 简化版:只输出与决策相关的字段(避免 token 爆炸)
        let gradeCount = c.grades.count
        let weakSubjects = c.grades.isEmpty
            ? "无"
            : Dictionary(grouping: c.grades, by: \.subject)
                .map { (subject, items) in "\(subject)=\(String(format: "%.1f", items.map(\.score).reduce(0, +) / Double(items.count)))" }
                .sorted()
                .joined(separator: ", ")
        let mistakeCount = c.mistakeSets.count
        let upcoming = c.examSets
            .filter { $0.examDate >= c.now && $0.examDate <= Calendar.current.date(byAdding: .day, value: 14, to: c.now) ?? c.now }
            .prefix(5)
            .map { "\($0.subject)/\($0.name)(\($0.examDate.formatted(date: .abbreviated, time: .omitted)))" }
            .joined(separator: ", ")
        let body = c.bodyStatusSuggestion.map { "体力=\($0.title)" } ?? "无"
        return """
        当前日期:\(c.now.formatted(date: .abbreviated, time: .omitted))
        成绩数:\(gradeCount),各科均分:{\(weakSubjects)}
        错题数:\(mistakeCount)
        未来 14 天考试:\(upcoming.isEmpty ? "无" : upcoming)
        身体状态:\(body)
        """
    }
}

// MARK: - 2) Mistake Analysis (错题 AI 解析)

/// 错题 AI 解析 prompt 工厂。
enum MistakeAnalysisLLM {
    static let defaultSystem: String = """
        你是错题分析专家。给定错题内容,输出 Markdown 总结,中文。
        严格使用以下结构(每个 ## 标题独占一行,小标题顺序固定):

        ## 错因分析
        <2-4 行,定位知识漏洞 / 思维误区 / 计算失误>

        ## 正确思路
        <3-6 行,分步骤展示解题路径,必要时用列表>

        ## 类似题建议
        <1-3 条,具体可练习的方向>

        严禁输出解释、客套话、JSON、代码块语言标签。
        """

    /// 构造 prompt。
    /// `mistake` 字段为空时自动用 `(空)` 占位,避免 LLM 误判。
    static func makePrompt(
        subject: String,
        title: String,
        question: String,
        wrongSolution: String,
        correctSolution: String,
        reason: String
    ) -> LLMPrompt {
        let user = """
        学科:\(subject.isEmpty ? "(未填)" : subject)
        标题:\(title.isEmpty ? "(未填)" : title)
        题干:
        \(question.isEmpty ? "(空)" : question)
        错解:
        \(wrongSolution.isEmpty ? "(空)" : wrongSolution)
        正解:
        \(correctSolution.isEmpty ? "(空)" : correctSolution)
        学生自述错因:
        \(reason.isEmpty ? "(空)" : reason)
        """
        return LLMPrompt(system: defaultSystem, messages: [.user(user)])
    }
}

// MARK: - 3) Weekly Report Summary (周报 AI 总结)

/// 周/月报 AI 总结 prompt 工厂。
enum WeeklyReportLLM {
    static let defaultSystem: String = """
        你是 StudyPulse 学习报告分析师。基于给定的周/月数据,生成 200-400 字的中文 Markdown 总结。
        严格使用以下结构(每个 ## 标题独占一行,顺序固定):

        ## 整体表现
        <1-2 句总评 + 关键数字(学习时长 / 成绩数 / 错题数)>

        ## 学科亮点
        <1-3 条,基于数据中的强项 / 进步>

        ## 改进建议
        <1-3 条,基于数据中的弱项 / 错题 / 持续下滑>

        不要重复输入数据;不要输出客套话、JSON、代码块。
        """

    static func makePrompt(_ data: WeeklyReportManager.ReportData) -> LLMPrompt {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let daily = data.dailyStudyMinutes
            .map { "\(f.string(from: $0.date))=\($0.minutes)m" }
            .joined(separator: ", ")
        let subs = data.subjectDistribution
            .map { "\($0.subject)=\($0.mistakeCount)(\(String(format: "%.0f%%", $0.percentage)))" }
            .joined(separator: ", ")
        let user = """
        报告周期:\(data.period.displayName)(\(f.string(from: data.startDate)) ~ \(f.string(from: data.endDate)))
        总学习时长(分钟):\(data.totalStudyMinutes)
        完成的番茄数:\(data.sessionCount)
        平均番茄时长(分钟):\(String(format: "%.1f", data.averageSessionMinutes))
        成绩数:\(data.gradeCount)
        平均得分率:\(String(format: "%.0f%%", data.averageScoreRate * 100))
        错题数:\(data.mistakeCount)
        考试数:\(data.examCount)
        强项学科:\(data.topSubject ?? "无")
        弱势学科:\(data.weakestSubject ?? "无")
        错题学科分布:{\(subs.isEmpty ? "无" : subs)}
        每日学习分钟数:{\(daily.isEmpty ? "无" : daily)}
        """
        return LLMPrompt(system: defaultSystem, messages: [.user(user)])
    }
}

// MARK: - 6) Comprehensive Exam Score Prediction (综合考试 AI 预测)

/// 综合考试预测的 AI 第二意见 prompt 工厂。
/// 调用方先跑本地算法拿到 per-subject + total 的预测,再调用 LLM 给出"总分二次意见"。
enum ComprehensiveScorePredictionLLM {
    static let defaultSystem: String = """
        你是 StudyPulse 的考试预测分析师。基于给定的综合考试默认预测结果(各科 + 总分),给出"二次意见"。
        严格使用以下 Markdown 结构(每个 ## 标题独占一行,顺序固定):

        ## AI 总分预测
        - 点估计: <整数,基于 default 预测上下浮动>
        - 区间: <下限> ~ <上限>(用整数)
        - 置信度: <高 / 中 / 低>(根据各科样本量与波动判断)

        ## 各科关键观察
        <1-2 行/科,聚焦波动最大 / 最稳定 / 趋势最关键的科目>

        ## 总分风险点
        <1-3 条,影响总分达成的可能风险,每条 1 行>

        ## 复习建议
        <1-3 条,基于各科状态的优先级建议,每条 1 行>

        不要重复输入数据;不要输出客套话、JSON、代码块。
        """

    /// 构造 prompt。
    static func makePrompt(
        exam: comprehensiveExam,
        target: ComprehensivePredictionTarget
    ) -> LLMPrompt {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let subjectLines = target.perSubject
            .map { item -> String in
                let r = item.result
                let range = "\(Int(r.lowerBound.rounded()))~\(Int(r.upperBound.rounded()))"
                let n = r.usedSampleSize
                let half = String(format: "%.1f", r.halfWidth)
                return "  - \(item.subject): 点估计=\(Int(r.predicted.rounded())), 95% CI=[\(range)], ±\(half) pts, n=\(n), 满分=\(Int(r.fullScore.rounded()))"
            }
            .joined(separator: "\n")
        let totalHalf = (target.totalUpper - target.totalLower) / 2.0
        let user = """
        综合考试名称:\(exam.name)
        考试日期:\(f.string(from: exam.examDate))
        距离考试:\(max(0, Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate).day ?? 0)) 天
        学科数:\(target.perSubject.count)
        满分合计:\(Int(target.totalFull.rounded()))

        --- 各科默认预测 ---
        \(subjectLines.isEmpty ? "(无)" : subjectLines)

        --- 总分默认预测 ---
        点估计:\(Int(target.totalPredicted.rounded()))
        95% 区间:[\(Int(target.totalLower.rounded())), \(Int(target.totalUpper.rounded()))]
        区间半宽:±\(String(format: "%.1f", totalHalf))
        """
        return LLMPrompt(system: defaultSystem, messages: [.user(user)])
    }
}

// MARK: - 5) Score Prediction (预测分数 AI 分析)

/// 预测分数的 AI 补充分析 prompt 工厂。
/// 调用方先跑本地 `ScorePredictor` 拿到默认预测结果,再调用 LLM 给出"二次意见"
/// (可能给出不同的预测区间、关键驱动因素、风险点、复习建议)。
enum ScorePredictionLLM {
    static let defaultSystem: String = """
        你是 StudyPulse 的考试预测分析师。基于给定的历史成绩、错题复习情况和默认算法的预测结果,给出"二次意见"。
        严格使用以下 Markdown 结构(每个 ## 标题独占一行,顺序固定):

        ## AI 预测分数
        - 点估计: <整数,满分 = (满分),允许 ±3 分浮动>
        - 区间: <下限> ~ <上限>(用整数)
        - 置信度: <高 / 中 / 低>(根据样本量与波动判断)

        ## 关键驱动因素
        <3-5 条,基于成绩趋势 / 错题状态,每条 1 行>

        ## 风险点
        <1-3 条,影响达成的可能风险,每条 1 行>

        ## 复习建议
        <1-3 条,基于错题结构给出的具体方向,每条 1 行>

        不要重复输入数据;不要输出客套话、JSON、代码块。
        """

    /// 构造 prompt。
    /// - Parameters:
    ///   - exam: 目标考试
    ///   - history: 同科目历史成绩
    ///   - defaultResult: 本地 ScorePredictor 算出的结果
    ///   - fullScore: 满分
    ///   - mistakeContext: 同科目错题上下文(可空)
    static func makePrompt(
        exam: Exam,
        history: [Grade],
        defaultResult: ScorePredictionResult,
        fullScore: Double,
        mistakeContext: MistakeContext
    ) -> LLMPrompt {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let historyLines = history.sorted(by: { $0.date < $1.date })
            .suffix(15)
            .map { g in
                let full = g.fullScore ?? fullScore
                return "\(f.string(from: g.date))  \(Int(g.score.rounded()))/\(Int(full.rounded()))  \(g.examName.isEmpty ? "(无标题)" : g.examName)"
            }
            .joined(separator: "\n")
        let recentScores: [Double] = history.suffix(5).map { $0.score }
        let recentMean: Double = recentScores.isEmpty ? 0 : recentScores.reduce(0, +) / Double(recentScores.count)
        let user = """
        学科:\(exam.subject)
        考试名称:\(exam.name)
        考试日期:\(f.string(from: exam.examDate))
        距离考试:\(max(0, Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate).day ?? 0)) 天
        满分:\(Int(fullScore))

        --- 历史成绩(最多 15 条,按日期升序) ---
        \(historyLines.isEmpty ? "(无)" : historyLines)
        历史样本数:\(history.count)
        最近 5 次均分:\(String(format: "%.1f", recentMean))

        --- 默认算法预测 ---
        点估计:\(Int(defaultResult.predicted.rounded()))
        95% 区间:[\(Int(defaultResult.lowerBound.rounded())), \(Int(defaultResult.upperBound.rounded()))]
        区间半宽:±\(String(format: "%.1f", defaultResult.halfWidth))
        窗口:\(Int(defaultResult.windowDays)) 天 / EWMA \(Int(defaultResult.halfLifeDays)) 天
        样本量:\(defaultResult.usedSampleSize)
        """
        + (mistakeContext.reviewedMistakeCount > 0
           ? """

        --- 错题复习状态 ---
        已复习错题数:\(mistakeContext.reviewedMistakeCount)
        平均掌握度:\(String(format: "%.0f%%", mistakeContext.averageMastery * 100))
        总曝光次数:\(mistakeContext.totalExposureCount)
        """
           : "\n--- 错题复习状态 ---\n(本科目暂无错题数据)\n")
        return LLMPrompt(system: defaultSystem, messages: [.user(user)])
    }
}

// MARK: - 7) AI Discussion (深入探讨)

/// "深入探讨" 对话页 prompt 工厂。
/// 把预测数据作为 system 上下文,让 LLM 基于此与用户多轮对话。
enum AIDiscussionLLM {
    /// 默认 system prompt(包含用户语言指引)
    /// - Parameters:
    ///   - context: 预测 / 错题 / 考试等结构化上下文
    ///   - previousAIPrediction: 上一次的 AI 预测原文(用于在 system prompt 中显式标注"这是你刚才的输出")
    static func defaultSystem(context: String, previousAIPrediction: String?) -> String {
        let previousBlock: String
        if let prev = previousAIPrediction, !prev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            previousBlock = """

            ========================================
            你刚才已经给出的预测(用户会基于此继续提问,务必主动引用 / 衔接):
            ========================================
            \(prev)
            """
        } else {
            previousBlock = ""
        }
        return """
        你是 StudyPulse 的 AI 学习助手。用户会基于下面这段"预测 / 分析上下文",以及你刚才给出的预测,继续深入讨论。
        回答要:
        1. 严格基于上下文提供的数据;不要编造成绩 / 错题 / 考试信息;
        2. 优先给出可操作建议(分科目 / 错题 / 时间分配等),1-3 句起步,长时用列表;
        3. 使用 Markdown 渲染(标题 / 列表 / 表格 / 行内代码);
        4. 跟随用户提问的语言(中文 / 英文 / 日文 / 韩文等);
        5. **重要**:如果 system prompt 包含"你刚才已经给出的预测",请主动引用 / 衔接那段内容(例如"在我刚才的预测中..." / "基于上一次的预测..."),不要把对话当成全新话题。

        --- 预测 / 分析上下文 ---
        \(context)\(previousBlock)
        """
    }
}

// MARK: - 4) Free-form Chat (AI 助手)

/// AI 助手对话 prompt 工厂。
enum LLMChatLLM {
    static let defaultSystem: String = """
        你是 StudyPulse 的 AI 学习助手。你能基于用户的成绩、错题、考试和身体数据回答问题。
        回答尽量使用 Markdown(标题 / 列表 / 表格 / 代码块),中文为主,语言跟随用户提问。
        如果用户问的与学习数据无关,可以正常回答;不要主动编造未提供的个人数据。
        """
}
