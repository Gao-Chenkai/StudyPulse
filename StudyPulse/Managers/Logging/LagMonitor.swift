//
//  LagMonitor.swift
//  StudyPulse
//
//  主线程卡顿检测器，使用 CADisplayLink 监测帧间隔。
//  当帧间隔超过阈值时，记录日志到 LogStore。
//

import Foundation
import QuartzCore
import UIKit

/// 主线程卡顿检测器。
///
/// 通过 CADisplayLink 在主线程 RunLoop 中检测帧间隔，
/// 当实际帧间隔超过 expected × allowedMissedFrames 时判定为卡顿，
/// 将详情写入 LogStore（可通过导出日志功能导出）。
///
/// 使用方式：`LagMonitor.shared.start()`
@MainActor
final class LagMonitor: NSObject {
    static let shared = LagMonitor()

    // MARK: - 配置
    /// 连续卡顿之间的最小间隔（秒），避免日志刷屏。
    private let cooldown: TimeInterval = 1.0
    /// 允许连续丢失的帧数。= 3 表示连续丢帧超过 3 帧才报告。
    private let allowedMissedFrames: Int = 3

    // MARK: - 状态
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var lastReportTime: CFTimeInterval = 0
    private var isRunning = false

    private override init() {
        super.init()
    }

    /// 启动卡顿监测。
    /// 在 StudyPulseApp 的 init() 或 .task 中调用。
    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastTimestamp = CACurrentMediaTime()
        lastReportTime = lastTimestamp

        displayLink = CADisplayLink(target: self, selector: #selector(linkCallback(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    /// 停止卡顿监测。
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    /// 监测当前是否在检测中。
    var isMonitoring: Bool { isRunning }

    // MARK: - CADisplayLink Callback

    @objc private func linkCallback(_ link: CADisplayLink) {
        let now = link.timestamp
        let delta = now - lastTimestamp
        let expected: CFTimeInterval = link.duration  // 60 Hz → ~16.7 ms, 120 Hz → ~8.3 ms
        let threshold = expected * CFTimeInterval(allowedMissedFrames)

        if delta > threshold {
            let missedFrames = Int(delta / expected)
            let deltaMs = delta * 1000
            let nowTime = CACurrentMediaTime()

            // 冷却期内不再重复报告
            guard (nowTime - lastReportTime) >= cooldown else {
                lastTimestamp = now
                return
            }
            lastReportTime = nowTime

            // 记录卡顿详情
            let detail: String
            if missedFrames >= 100 {
                detail = "\(String(format: "%.0f", deltaMs)) ms (严重)"
            } else {
                detail = "\(String(format: "%.0f", deltaMs)) ms (\(missedFrames) 帧)"
            }

            let message = "主线程卡顿 / Main thread lag: \(detail)"
            Log.record(.warning, category: "Performance", message: message)

            // 记录调用栈（最多前 20 行），帮助定位卡顿来源
            let stackSymbols = Thread.callStackSymbols
            let limitedStack = stackSymbols.prefix(20)
            for frame in limitedStack {
                LogStore.shared.record(category: "Performance", level: .debug, message: frame)
            }
        }

        lastTimestamp = now
    }
}
