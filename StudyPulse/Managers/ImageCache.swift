//
//  ImageCache.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import UIKit

/// 轻量级内存图片缓存，避免重复解码 Data → UIImage
nonisolated final class ImageCache {
    @MainActor static let shared = ImageCache()
    
    /// LRU 缓存，最大 50 张
    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    
    private init() {
        cache.countLimit = 50
    }
    
    /// 生成缓存 key（基于 Data 的哈希）
    private func makeKey(_ data: Data) -> NSString {
        NSString(string: String(data.hashValue, radix: 16))
    }
    
    /// 获取缓存图片
    func getImage(_ data: Data) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: makeKey(data))
    }
    
    /// 存入缓存
    func putImage(_ image: UIImage, _ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(image, forKey: makeKey(data))
    }
    
    /// 生成缩略图（固定最大尺寸，减少内存占用）
    static func thumbnail(from data: Data, maxDimension: CGFloat = 300) -> UIImage? {
        guard let original = UIImage(data: data) else { return nil }
        guard original.size.width > maxDimension || original.size.height > maxDimension else {
            return original
        }
        
        let ratio = min(maxDimension / original.size.width, maxDimension / original.size.height)
        let newSize = CGSize(width: original.size.width * ratio, height: original.size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
