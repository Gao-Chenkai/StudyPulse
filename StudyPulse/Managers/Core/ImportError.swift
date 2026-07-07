//
//  ImportError.swift
//  StudyPulse
//
//  CSV 导入错误码与诊断信息。
//  在 import 失败时给用户一个可定位的 code，方便排查。
//

import Foundation

/// CSV 导入错误码
/// E001 - E099: 文件层错误（读取 / 编码 / 安全域）
/// E101 - E199: CSV 结构层错误（表头 / 行数 / 列数）
/// E201 - E299: 数据内容层错误（必填字段缺失 / 数值格式 / 枚举值非法）
/// E301 - E399: 数据库层错误（保存失败 / 重复 ID 等）
enum ImportErrorCode: String, Codable {
    case E001  // 读取文件失败
    case E002  // 文件为空
    case E003  // 仅表头，无数据行
    case E004  // 全部行解析失败
    case E005  // 部分行解析失败（行数 > 0 但成功 < 总数）
    case E101  // 表头与期望不匹配
    case E102  // 表头列数 < 期望最小列数
    case E201  // 必填字段缺失（如 Grade.Score / Mistake.Title）
    case E202  // 数值字段格式非法
    case E203  // 类型枚举非法（Task.Type / Exam.Type）
    case E301  // 写入数据库失败

    /// 简短的本地化描述 key
    var descriptionKey: String {
        switch self {
        case .E001: return "import.error.E001"
        case .E002: return "import.error.E002"
        case .E003: return "import.error.E003"
        case .E004: return "import.error.E004"
        case .E005: return "import.error.E005"
        case .E101: return "import.error.E101"
        case .E102: return "import.error.E102"
        case .E201: return "import.error.E201"
        case .E202: return "import.error.E202"
        case .E203: return "import.error.E203"
        case .E301: return "import.error.E301"
        }
    }
}

/// 一次导入操作的诊断信息
struct ImportDiagnostics {
    /// 错误码（成功时为 nil）
    let code: ImportErrorCode?
    /// 短消息（不带诊断细节）
    let message: String
    /// 文件名（不带路径）
    let fileName: String
    /// 实际使用的文件编码（nil 表示没有任何编码能解析）
    let encoding: String?
    /// 表头列数
    let headerColumnCount: Int
    /// 数据行数（不含表头）
    let dataRowCount: Int
    /// 成功解析的行数
    let successfulRowCount: Int
    /// 跳过的行数（解析失败或字段缺失）
    let skippedRowCount: Int
    /// 第一次失败的位置（行号 / 列名 / 原因）
    let firstFailure: String?

    static func success(
        fileName: String,
        encoding: String,
        headerColumnCount: Int,
        dataRowCount: Int,
        successfulRowCount: Int
    ) -> ImportDiagnostics {
        ImportDiagnostics(
            code: nil,
            message: "OK",
            fileName: fileName,
            encoding: encoding,
            headerColumnCount: headerColumnCount,
            dataRowCount: dataRowCount,
            successfulRowCount: successfulRowCount,
            skippedRowCount: dataRowCount - successfulRowCount,
            firstFailure: nil
        )
    }

    static func failure(
        code: ImportErrorCode,
        message: String,
        fileName: String,
        encoding: String? = nil,
        headerColumnCount: Int = 0,
        dataRowCount: Int = 0,
        successfulRowCount: Int = 0,
        firstFailure: String? = nil
    ) -> ImportDiagnostics {
        ImportDiagnostics(
            code: code,
            message: message,
            fileName: fileName,
            encoding: encoding,
            headerColumnCount: headerColumnCount,
            dataRowCount: dataRowCount,
            successfulRowCount: successfulRowCount,
            skippedRowCount: dataRowCount - successfulRowCount,
            firstFailure: firstFailure
        )
    }
}

extension ImportDiagnostics {
    /// 用户可见的详细文本
    var userVisibleDetail: String {
        var lines: [String] = []
        lines.append("[\(code?.rawValue ?? "OK")] \(message)")
        lines.append("File: \(fileName)")
        if let encoding = encoding {
            lines.append("Encoding: \(encoding)")
        }
        lines.append("Header cols: \(headerColumnCount)")
        lines.append("Data rows: \(dataRowCount) | Success: \(successfulRowCount) | Skipped: \(skippedRowCount)")
        if let firstFailure = firstFailure {
            lines.append("First failure: \(firstFailure)")
        }
        return lines.joined(separator: "\n")
    }
}
