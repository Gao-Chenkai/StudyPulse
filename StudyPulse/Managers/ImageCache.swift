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
        cache.countLimit = 50  // 最多缓存 50 张
    }
    
    /// 根据图片 Data 生成缓存 Key（使用哈希值）
    private func makeKey(_ data: Data) -> NSString {
        NSString(string: String(data.hashValue, radix: 16))
    }
    
    /// 从缓存获取图片
    func getImage(_ data: Data) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: makeKey(data))
    }
    
    /// 存入图片到缓存
    func putImage(_ image: UIImage, _ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(image, forKey: makeKey(data))
    }
    
    /// 生成缩略图（固定最大尺寸，减少内存占用）
    /// - Parameters:
    ///   - data: 原始图片数据
    ///   - maxDimension: 最大边长（默认 300px）
    /// - Returns: 缩放后的缩略图
    static func thumbnail(from data: Data, maxDimension: CGFloat = 300) -> UIImage? {
        guard let original = UIImage(data: data) else { return nil }
        // 如果原图已小于最大尺寸，直接返回
        guard original.size.width > maxDimension || original.size.height > maxDimension else {
            return original
        }
        
        // 按比例缩放
        let ratio = min(maxDimension / original.size.width, maxDimension / original.size.height)
        let newSize = CGSize(width: original.size.width * ratio, height: original.size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
