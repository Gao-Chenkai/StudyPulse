//
//  OCRManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import UIKit
import Vision

// MARK: - OCR Text Recognition Manager (OCR 文字识别管理器)

/// OCR 操作相关错误
enum OCRError: Error, LocalizedError {
    case noTextFound          /// 图片中未找到文字
    case imageProcessingFailed /// 图片处理失败
    case invalidImageData     /// 无效的图片数据
    
    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text was found in the image."
        case .imageProcessingFailed:
            return "Failed to process the image for text recognition."
        case .invalidImageData:
            return "The provided image data is invalid or not a valid image."
        }
    }
}

/// OCR 文字识别管理器
/// 使用 Apple Vision 框架从图片中提取文字，用于错题识别
class OCRManager {
    
    /// 从 UIImage 中识别文字
    /// - Parameter image: 要识别的图片
    /// - Returns: 识别出的文字（每行用换行符分隔）
    /// - Throws: OCRError（未找到文字 / 识别失败）
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageProcessingFailed
        }
        
        // 配置文字识别请求
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate  // 高精度模式
        request.usesLanguageCorrection = true // 启用语言校正
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        try handler.perform([request])
        
        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextFound
        }
        
        // 提取每个识别结果的最佳候选文字
        let textLines = observations.compactMap { observation -> String? in
            guard let topCandidate = observation.topCandidates(1).first else { return nil }
            return topCandidate.string
        }
        
        guard !textLines.isEmpty else {
            throw OCRError.noTextFound
        }
        
        return textLines.joined(separator: "\n")
    }
    
    /// 从图片 Data 中识别文字（便捷方法）
    /// - Parameter imageData: 图片数据
    /// - Returns: 识别出的文字
    /// - Throws: OCRError（数据无效 / 未找到文字 / 识别失败）
    static func recognizeText(from imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData) else {
            throw OCRError.invalidImageData
        }
        return try await recognizeText(in: image)
    }
}
