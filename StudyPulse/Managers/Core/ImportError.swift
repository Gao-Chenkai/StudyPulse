//
//  ImportError.swift
//  StudyPulse
//
//  CSV 导入错误码与诊断信息。
//  在 import 失败时给用户一个可定位的 code，方便排查。
//  CSV import error codes & diagnostics.
//  Gives a locatable code on import failure to make troubleshooting easier.
//

import Foundation

/// CSV 导入错误码
/// E001 - E099: 文件层错误（读取 / 编码 / 安全域）
/// E101 - E199: CSV 结构层错误（表头 / 行数 / 列数）
/// E201 - E299: 数据内容层错误（必填字段缺失 / 数值格式 / 枚举值非法）
/// E301 - E399: 数据库层错误（保存失败 / 重复 ID 等）
/// CSV import error codes.
/// E001–E099: file layer (read / encoding / security scope).
/// E101–E199: CSV structure layer (header / row / column counts).
/// E201–E299: data content layer (missing required field / bad number / bad enum).
/// E301–E399: database layer (save failure / duplicate ID, etc.).
enum ImportErrorCode: String, Codable {
    case E001  // 读取文件失败 / Read failure
    case E002  // 文件为空 / File is empty
    case E003  // 仅表头，无数据行 / Header only, no data rows
    case E004  // 全部行解析失败 / Every row failed to parse
    case E005  // 部分行解析失败（行数 > 0 但成功 < 总数）/ Partial parse failure (rows > 0 but successes < total)
    case E101  // 表头与期望不匹配 / Header doesn't match expected schema
    case E102  // 表头列数 < 期望最小列数 / Header column count < expected minimum
    case E201  // 必填字段缺失（如 Grade.Score / Mistake.Title）/ Required field missing (e.g. Grade.Score / Mistake.Title)
    case E202  // 数值字段格式非法 / Number field has an invalid format
    case E203  // 类型枚举非法（Task.Type / Exam.Type）/ Bad enum value (Task.Type / Exam.Type)
    case E301  // 写入数据库失败 / Database write failure

    /// 简短的本地化描述 key
    /// Short localization key.
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
/// Diagnostic information for a single import operation.
struct ImportDiagnostics {
    /// 错误码（成功时为 nil）
    /// Error code (nil on success).
    let code: ImportErrorCode?
    /// 短消息（不带诊断细节）
    /// Short message (no diagnostic detail).
    let message: String
    /// 文件名（不带路径）
    /// File name (without path).
    let fileName: String
    /// 实际使用的文件编码（nil 表示没有任何编码能解析）
    /// Effective file encoding (nil if no encoding could parse it).
    let encoding: String?
    /// 表头列数
    /// Header column count.
    let headerColumnCount: Int
    /// 数据行数（不含表头）
    /// Data row count (excluding the header).
    let dataRowCount: Int
    /// 成功解析的行数
    /// Successfully parsed row count.
    let successfulRowCount: Int
    /// 跳过的行数（解析失败或字段缺失）
    /// Skipped row count (parse failure or missing field).
    let skippedRowCount: Int
    /// 第一次失败的位置（行号 / 列名 / 原因）
    /// First failure position (row number / column name / reason).
    let firstFailure: String?

    /// 构造一个"成功"诊断。
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

    /// 构造一个"失败"诊断（所有字段都可由调用方提供）。
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
    /// 用户可见的详细文本（多行）。
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
