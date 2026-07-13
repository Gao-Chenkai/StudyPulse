//
//  ViewModelError.swift
//  StudyPulse
//
import Foundation

/// ViewModel 统一错误类型 / Unified ViewModel error type.
enum ViewModelError: LocalizedError {
    /// 数据尚未就绪 / Data not ready
    case dataNotReady
    /// 预测计算失败 / Prediction failed
    case predictionFailed(String)
    /// 导出 / 分享失败 / Export / share failed
    case exportFailed(String)
    /// 数据校验失败 / Validation failed
    case validationFailed(String)
    /// 其它业务错误 / Other business error
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
