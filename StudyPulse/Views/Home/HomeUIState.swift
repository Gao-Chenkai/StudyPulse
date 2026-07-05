//
//  HomeUIState.swift
//  StudyPulse
//
//  主页 UI 状态聚合:把 HomeView 之前散落的 8 个 @State
//  (renderPhase / showingFlashcards / 报告导出相关 6 个)打包成单个 struct,
//  减少 HomeView 的 @State 数量并明确这组状态的语义边界(仅主页 UI 临时状态,
//  与 HomeViewModel 的派生数据解耦)。
//
//  - 业务派生数据(SRS / recent grades / upcoming exams / chart 选科)→ HomeViewModel
//  - 临时 UI 状态(模态/分阶段渲染/报告导出)→ HomeUIState
//  - 外部输入(tab 切换)→ @Binding selectedTab
//
//  Created for HomeView card extraction refactor (2026-07-05).
//

import Foundation
import SwiftUI

/// 主页 UI 状态聚合(纯 struct,放 @State 里使用)。
/// 不放任何派生业务数据,只承载"当前打开什么 modal / 报告导出进行到哪一步"。
struct HomeUIState {
    // MARK: - 分阶段渲染

    /// 0 = 仅 WelcomeHeader 1 = WelcomeHeader + MainStatsCard 2 = 全部
    /// 0 = only WelcomeHeader; 1 = + MainStatsCard; 2 = all dynamic cards.
    /// 用于首次进入页面时分 3 帧渲染,避免一次性构建所有复杂子视图。
    var renderPhase: Int = 0

    // MARK: - 闪卡复习 fullScreenCover

    /// 是否显示闪卡复习全屏视图
    var showingFlashcards: Bool = false

    // MARK: - 学习报告导出

    /// 是否显示 ReportOptionsSheet
    var showingReportOptions: Bool = false

    /// 整页/单卡报告渲染进行中(用于 ProgressView 蒙层)
    var isRenderingReport: Bool = false

    /// 渲染完成的整页报告图片(走 ReportShareSheet)
    var reportImage: UIImage?

    /// 渲染完成的单卡图片(走 ReportShareSheet,带标题)
    var singleCardImage: UIImage?

    /// 单卡分享时的本地化标题
    var singleCardTitle: String = ""

    /// 是否显示分享 sheet
    var showingShareSheet: Bool = false

    /// 报告渲染错误消息(nil = 无错误)
    var reportErrorMessage: String?
}

extension HomeUIState {
    /// 是否正在导出报告(用于禁用 toolbar 分享按钮)
    var isExporting: Bool { isRenderingReport }

    /// 是否可以打开分享 sheet(必须有一张已渲染的图)
    var canShare: Bool { reportImage != nil || singleCardImage != nil }
}
