//
//  ImageCache.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import UIKit

// MARK: - Image Cache Manager (图片缓存管理器)

/// 轻量级内存图片缓存
/// 使用 NSCache 避免重复解码 Data → UIImage，提升列表滚动性能
/// 最大缓存 50 张图片，支持缩略图生成
nonisolated final class ImageCache {
    @MainActor static let shared = ImageCache()
    
    /// NSCache 内存缓存（自动 LRU 淘汰）
    private let cache = NSCache<NSString, UIImage>()
    /// 线程安全锁
    private let lock = NSLock()
    
    private init() {
        // countLimit 是 NSCache 的近似 LRU 上限;50 张 ≈ 50MB 内存预算
        // countLimit is the approximate LRU cap of NSCache; 50 images ≈ 50MB budget.
        cache.countLimit = 50  // 最多缓存 50 张
    }
    
    /// 根据图片 Data 生成缓存 Key（使用哈希值）
    private func makeKey(_ data: Data) -> NSString {
        NSString(string: String(data.hashValue, radix: 16))
    }

    /// 按文件名缓存的 Key(头像 / 成绩图片,文件名稳定)
    private func makeFilenameKey(_ filename: String) -> NSString {
        NSString(string: "f:\(filename)")
    }

    /// 从 Data 缓存获取
    func getImage(_ data: Data) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: makeKey(data))
    }

    /// 存入 Data 缓存
    func putImage(_ image: UIImage, _ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(image, forKey: makeKey(data))
    }

    /// 按文件名获取
    func getImageByFilename(_ filename: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: makeFilenameKey(filename))
    }

    /// 按文件名存入
    func putImageByFilename(_ image: UIImage, _ filename: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(image, forKey: makeFilenameKey(filename))
    }

    /// 清空内存缓存（Debug 模式手动触发）
    /// Drops all cached images from the in-memory NSCache. Used by Debug → State & Cache.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }
    
    /// 生成缩略图（固定最大尺寸，减少内存占用）
    /// - Parameters:
    ///   - data: 原始图片数据
    ///   - maxDimension: 最大边长（默认 300px）
    /// - Returns: 缩放后的缩略图
    /// Generate a thumbnail with a fixed max dimension to reduce memory.
    /// - Parameters:
    ///   - data: Original image data.
    ///   - maxDimension: Max edge length (default 300px).
    /// - Returns: The scaled thumbnail, or nil if decode fails.
    static func thumbnail(from data: Data, maxDimension: CGFloat = 300) -> UIImage? {
        guard let original = UIImage(data: data) else { return nil }
        // 如果原图已小于最大尺寸，直接返回
        // If the original is already small enough, return it as-is (no re-render).
        guard original.size.width > maxDimension || original.size.height > maxDimension else {
            return original
        }

        // 按比例缩放(取较小比例,保证长边 == maxDimension)
        // Scale uniformly; min() ratio ensures the longer edge equals maxDimension.
        let ratio = min(maxDimension / original.size.width, maxDimension / original.size.height)
        let newSize = CGSize(width: original.size.width * ratio, height: original.size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
