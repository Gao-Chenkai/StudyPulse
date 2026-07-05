//
//  ViewModelError.swift
//  StudyPulse
//
//  统一 ViewModel 错误类型。所有 ViewModel 抛错 / 错误提示都走此类型,
// 避免 View 内散落 String? 错误消息。
//
//  Created for MVVM refactor (2026-07-05).
//

import Foundation

/// ViewModel 统一错误类型。
/// 视图层只需把 `errorDescription` 显示给用户,不必关心来源。
enum ViewModelError: LocalizedError {
    /// 数据尚未就绪(例如初始加载期间被访问)
    case dataNotReady
    /// 预测计算失败(底层算法抛错等)
    case predictionFailed(String)
    /// 导出 / 分享失败(报告渲染、PDF 生成等)
    case exportFailed(String)
    /// 数据校验失败(用户输入非法)
    case validationFailed(String)
    /// 其它业务错误
    case other(String)

    var errorDescription: String? {
        switch self {
        case .dataNotReady:
            return "Data is not ready yet".localized()
        case .predictionFailed(let msg):
            return "Prediction failed: \(msg)".localized()
        case .exportFailed(let msg):
            return "Export failed: \(msg)".localized()
        case .validationFailed(let msg):
            return msg.localized()
        case .other(let msg):
            return msg.localized()
        }
    }
}
