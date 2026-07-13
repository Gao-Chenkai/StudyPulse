//
//  AudioStorage.swift
//  StudyPulse
//
//

import Foundation
import os

/// Handles file system operations for audio voice memos.
/// 处理语音备忘录的文件系统操作。
nonisolated struct AudioStorage {
    private static let logger = Logger(subsystem: "com.chenkai.gao.studypulse", category: "AudioStorage")

    /// The directory where audio files are stored (`~/Documents/audio/`).
    /// 录音文件所在目录（`~/Documents/audio/`）。
    static var audioDirectoryURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("audio")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    /// Generates a new unique filename for an audio file.
    /// 生成新的录音文件名。
    static func generateFileName() -> String {
        return UUID().uuidString + ".m4a"
    }

    /// Returns the full file URL for a given audio filename.
    /// 根据文件名返回完整文件 URL。
    static func url(for filename: String) -> URL {
        return audioDirectoryURL.appendingPathComponent(filename)
    }

    /// Deletes the audio file with the given filename.
    /// 删除指定文件名的录音文件。
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