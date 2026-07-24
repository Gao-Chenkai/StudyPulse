//
//  FPSMonitor.swift
//  StudyPulse
//
//  实时 FPS 监测器（供 Debug → Performance Panel 使用）。
//  Live FPS monitor used by the Debug → Performance Panel.
//
//  与 LagMonitor 并存：两者各持有一个 CADisplayLink，互不冲突。
//  Coexists with LagMonitor; each owns its own CADisplayLink.
//

import Foundation
import QuartzCore

/// 实时 FPS 监测器。
///
/// 维护最近 60 帧的 timestamp 数组，rolling 计算出最近 1 秒内的实际帧数。
/// `currentFPS` 为 0 表示尚未开始采样（冷启动期）。
@MainActor
@Observable
final class FPSMonitor {
    static let shared = FPSMonitor()

    /// 最近 1 秒的滚动平均 FPS
    private(set) var currentFPS: Double = 0

    /// 最近 120 帧的帧间隔（毫秒），供 PerformancePanel 画图
    private(set) var recentFrameIntervalsMs: [Double] = []

    private let maxSamples = 60        // 60 帧 = 1 秒 @ 60Hz;窗口越长越平滑,但冷启动期偏长
    private let maxHistory = 120       // Performance Panel 折线图最近帧间隔缓存长度
    private var timestamps: [CFTimeInterval] = []  // 滚动窗口内的帧时间戳
    private var displayLink: CADisplayLink?         // 系统帧驱动回调源
    private var isRunning = false                  // start/stop 幂等保护

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timestamps.removeAll(keepingCapacity: true)
        recentFrameIntervalsMs.removeAll(keepingCapacity: true)
        let link = CADisplayLink(target: self, selector: #selector(linkCallback(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    var isMonitoring: Bool { isRunning }

    @objc private func linkCallback(_ link: CADisplayLink) {
        let now = link.timestamp
        timestamps.append(now)
        if timestamps.count > maxSamples {
            timestamps.removeFirst(timestamps.count - maxSamples)
        }

        // 计算最近 1 秒的帧数
        if let first = timestamps.first {
            let window = now - first
            if window > 0 {
                currentFPS = Double(timestamps.count - 1) / window
            }
        }

        // 记录帧间隔（毫秒）
        if timestamps.count >= 2 {
            let last = timestamps[timestamps.count - 1]
            let prev = timestamps[timestamps.count - 2]
            let intervalMs = (last - prev) * 1000.0
            recentFrameIntervalsMs.append(intervalMs)
            if recentFrameIntervalsMs.count > maxHistory {
                recentFrameIntervalsMs.removeFirst(recentFrameIntervalsMs.count - maxHistory)
            }
        }
    }
}
