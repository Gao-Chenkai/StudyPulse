//
//  OCRManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import UIKit
import Vision

/// Error cases for OCR operations
enum OCRError: Error, LocalizedError {
    case noTextFound
    case imageProcessingFailed
    case invalidImageData
    
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

/// OCR helper that uses Apple's Vision framework to extract text from images
class OCRManager {
    
    /// Recognizes text in a UIImage using Vision framework
    /// - Parameter image: The image to perform OCR on
    /// - Returns: The recognized text as a single string, with line breaks between text lines
    /// - Throws: OCRError if no text is found or recognition fails
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageProcessingFailed
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        try handler.perform([request])
        
        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextFound
        }
        
        let textLines = observations.compactMap { observation -> String? in
            guard let topCandidate = observation.topCandidates(1).first else { return nil }
            return topCandidate.string
        }
        
        guard !textLines.isEmpty else {
            throw OCRError.noTextFound
        }
        
        return textLines.joined(separator: "\n")
    }
    
    /// Convenience method that takes image Data and returns recognized text
    /// - Parameter imageData: The image data to perform OCR on
    /// - Returns: The recognized text as a single string, with line breaks between text lines
    /// - Throws: OCRError if the data is invalid, no text is found, or recognition fails
    static func recognizeText(from imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData) else {
            throw OCRError.invalidImageData
        }
        return try await recognizeText(in: image)
    }
}
