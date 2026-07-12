//
//  AudioStorage.swift
//  StudyPulse
//
//  Created for Voice Memos feature.
//

import Foundation
import os

/// Handles file system operations for audio voice memos.
nonisolated struct AudioStorage {
    private static let logger = Logger(subsystem: "com.chenkai.gao.studypulse", category: "AudioStorage")
    
    /// The directory where audio files are stored (`~/Documents/audio/`).
    static var audioDirectoryURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("audio")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }
    
    /// Generates a new unique filename for an audio file.
    static func generateFileName() -> String {
        return UUID().uuidString + ".m4a"
    }
    
    /// Returns the full file URL for a given audio filename.
    static func url(for filename: String) -> URL {
        return audioDirectoryURL.appendingPathComponent(filename)
    }
    
    /// Deletes the audio file with the given filename.
    static func delete(filename: String) {
        let fileURL = url(for: filename)
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                logger.info("Deleted audio file: \(filename)")
            }
        } catch {
            logger.error("Failed to delete audio file \(filename): \(error.localizedDescription)")
        }
    }
}
