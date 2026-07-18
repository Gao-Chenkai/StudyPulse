//
//  CachedAsyncImage.swift
//  StudyPulse
//
//  异步解码 + 下采样的图片显示组件。
//  输入 `Data`,通过 `ImageCache.thumbnail` 在后台线程解码为缩略图,
//  避免主线程同步大图解码。
//
//  Async-decode + downsample image view. Takes `Data`, decodes a thumbnail
//  on a background thread via `ImageCache.thumbnail`, avoiding main-thread
//  full-image decode.
//
//  Created for P1-3 performance pass (2026-07-18).
//

import SwiftUI
import UIKit

struct CachedAsyncImage: View {
    let data: Data?
    /// 缩略图最大边长(px)。默认 400,覆盖 80x80 缩略图(2x 屏 160px)甚至全屏放大查看。
    /// Max edge length (px) of the decoded thumbnail. Default 400 covers 80x80
    /// cells (2x screen = 160px) and even full-screen zoom.
    var maxDimension: CGFloat = 400

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray5)
            }
        }
        // `.task(id: data)`:data 变化时自动取消旧任务、启动新任务
        // `.task(id: data)`: cancels the previous task and starts a new one when `data` changes.
        .task(id: data) {
            guard let data else { image = nil; return }
            let maxSize = maxDimension
            image = await Task.detached(priority: .userInitiated) {
                ImageCache.thumbnail(from: data, maxDimension: maxSize)
            }.value
        }
    }
}

#Preview {
    CachedAsyncImage(data: nil)
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
}
