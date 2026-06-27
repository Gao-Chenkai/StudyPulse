//
//  FlashcardCalculatorView.swift
//  StudyPulse
//
//  闪卡复习界面的浮层简易计算器
//  - 支持 + - × ÷ 基本运算，AC、+/-、%、小数点
//  - 玻璃质感背景，浮于卡片之上
//  - 拖动手势可在 iPad 上自由拖动位置
//
//  Created by Chenkai Gao on 2026/6/27.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Calculator Engine

/// 计算器引擎（@MainActor ObservableObject）
@MainActor
final class CalculatorEngine: ObservableObject {
    /// 主显示区（当前输入或结果）
    @Published var display: String = "0"
    /// 表达式行（显示 "1 + 2" 这样的当前操作）
    @Published var expression: String = ""

    private var accumulator: Double?
    private var pendingOp: String?
    private var isTyping: Bool = false
    /// 输入上限（数字字符数），防止溢出
    private let maxInputLength: Int = 12

    /// 处理一次按键
    func input(_ token: String) {
        switch token {
        case "AC":
            display = "0"
            expression = ""
            accumulator = nil
            pendingOp = nil
            isTyping = false

        case "+/-":
            toggleSign()

        case "%":
            applyPercent()

        case ".":
            inputDecimal()

        case "+", "-", "×", "÷":
            inputOperator(token)

        case "=":
            computeEquals()

        default:
            // 数字 0-9
            inputDigit(token)
        }
    }

    /// 重置
    func reset() {
        input("AC")
    }

    // MARK: - Operations

    private func inputDigit(_ digit: String) {
        if isTyping {
            if display == "0" {
                display = digit
            } else if display == "-0" {
                display = "-" + digit
            } else if display.count < maxInputLength {
                display += digit
            }
        } else {
            display = digit
            isTyping = true
        }
    }

    private func inputDecimal() {
        if isTyping {
            if !display.contains(".") {
                display += "."
            }
        } else {
            display = "0."
            isTyping = true
        }
    }

    private func toggleSign() {
        guard display != "0" else { return }
        if display.hasPrefix("-") {
            display.removeFirst()
        } else {
            display = "-" + display
        }
    }

    private func applyPercent() {
        guard let value = Double(display) else { return }
        display = Self.format(value / 100.0)
    }

    private func inputOperator(_ op: String) {
        // 连续按操作符：替换上一个
        if !isTyping, let last = pendingOp {
            pendingOp = op
            expression = formatExpression(acc: accumulator, op: op, current: nil)
            return
        }
        // 已有挂起运算：先算
        if let acc = accumulator, let prev = pendingOp, isTyping, let cur = Double(display) {
            let result = Self.compute(a: acc, b: cur, op: prev)
            display = Self.format(result)
            accumulator = result
        } else {
            accumulator = Double(display)
        }
        pendingOp = op
        isTyping = false
        expression = formatExpression(acc: accumulator, op: op, current: nil)
    }

    private func computeEquals() {
        guard let acc = accumulator, let op = pendingOp else { return }
        let cur = Double(display) ?? acc
        let result = Self.compute(a: acc, b: cur, op: op)
        expression = formatExpression(acc: acc, op: op, current: cur)
        display = Self.format(result)
        accumulator = nil
        pendingOp = nil
        isTyping = false
    }

    // MARK: - Helpers

    private func formatExpression(acc: Double?, op: String?, current: Double?) -> String {
        var parts: [String] = []
        if let a = acc {
            parts.append(Self.format(a))
        }
        if let o = op {
            parts.append(o)
        }
        if let c = current, current != acc {
            parts.append(Self.format(c))
        }
        return parts.joined(separator: " ")
    }

    private static func compute(a: Double, b: Double, op: String) -> Double {
        switch op {
        case "+": return a + b
        case "-": return a - b
        case "×": return a * b
        case "÷": return b == 0 ? 0 : a / b
        default: return b
        }
    }

    /// 数字格式化：整数去掉小数点，超长截断到 maxInputLength
    private static func format(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "Error" }
        if value.truncatingRemainder(dividingBy: 1) == 0 &&
           abs(value) < 1e15 {
            return String(Int(value))
        }
        let str = String(value)
        // 截断超长
        if str.count > 12 {
            return String(str.prefix(12))
        }
        return str
    }
}

// MARK: - Flashcard Calculator View

/// 浮层简易计算器面板
struct FlashcardCalculatorView: View {
    @StateObject private var engine = CalculatorEngine()
    /// 关闭回调（由父视图注入）
    let onClose: () -> Void

    /// 当前拖动偏移
    @State private var dragOffset: CGSize = .zero
    /// 是否正在拖动
    @GestureState private var isDragging: Bool = false

    private let buttons: [[CalcButton]] = [
        [.op("AC", kind: .util), .op("+/-", kind: .util), .op("%", kind: .util), .op("÷", kind: .op)],
        [.digit("7"), .digit("8"), .digit("9"), .op("×", kind: .op)],
        [.digit("4"), .digit("5"), .digit("6"), .op("-", kind: .op)],
        [.digit("1"), .digit("2"), .digit("3"), .op("+", kind: .op)],
        [.digit("0", wide: true), .digit("."), .op("=", kind: .equals)],
    ]

    var body: some View {
        VStack(spacing: 10) {
            // 标题栏（可拖动区域）
            HStack(spacing: 8) {
                Image(systemName: "function")
                    .font(.subheadline.weight(.semibold))
                Text("Calculator".localized())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.secondary.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)

            // 显示屏
            VStack(alignment: .trailing, spacing: 2) {
                if !engine.expression.isEmpty {
                    Text(engine.expression)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(engine.display)
                    .font(.system(size: 36, weight: .light, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )

            // 按钮网格
            VStack(spacing: 6) {
                ForEach(buttons.indices, id: \.self) { rowIdx in
                    HStack(spacing: 6) {
                        ForEach(buttons[rowIdx], id: \.id) { button in
                            CalcButtonView(button: button) {
                                engine.input(button.label)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 268)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .offset(x: dragOffset.width, y: dragOffset.height)
        .gesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    // 限制拖动范围：左/上/右/下分别不超过容器一半
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = CGSize(
                            width: clamp(value.translation.width, min: -200, max: 200),
                            height: clamp(value.translation.height, min: -250, max: 250)
                        )
                    }
                }
        )
    }

    /// 玻璃质感背景（iOS 26 升级为 glassEffect）
    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private func clamp<T: Comparable>(_ value: T, min lo: T, max hi: T) -> T {
        return Swift.max(lo, Swift.min(hi, value))
    }
}

// MARK: - Calc Button

/// 按钮类型
enum CalcButtonKind {
    case digit
    case op       // +-×÷
    case equals
    case util     // AC, +/-, %
}

/// 按钮模型
struct CalcButton: Identifiable {
    let id: String
    let label: String
    let kind: CalcButtonKind
    let wide: Bool

    init(_ label: String, kind: CalcButtonKind = .digit, wide: Bool = false) {
        self.id = label + (wide ? "_wide" : "")
        self.label = label
        self.kind = kind
        self.wide = wide
    }

    static func digit(_ s: String, wide: Bool = false) -> CalcButton {
        CalcButton(s, kind: .digit, wide: wide)
    }

    static func op(_ s: String, kind: CalcButtonKind) -> CalcButton {
        CalcButton(s, kind: kind, wide: false)
    }
}

/// 按钮视图
struct CalcButtonView: View {
    let button: CalcButton
    let onTap: () -> Void

    var body: some View {
        Button {
            // 点击反馈
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            Text(button.label)
                .font(.title3.weight(button.kind == .equals ? .bold : .medium))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(background)
                .clipShape(button.wide
                           ? AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                           : AnyShape(Circle()))
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        Group {
            switch button.kind {
            case .equals:
                Circle().fill(LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            case .op:
                Circle().fill(Color.orange.opacity(0.85))
            case .util:
                Circle().fill(Color.secondary.opacity(0.25))
            case .digit:
                Circle().fill(Color.secondary.opacity(0.18))
            }
        }
    }

    private var foreground: Color {
        switch button.kind {
        case .equals, .op: return .white
        case .util, .digit: return .primary
        }
    }
}
