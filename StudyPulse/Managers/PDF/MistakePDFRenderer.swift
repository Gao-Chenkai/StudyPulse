//
//  MistakePDFRenderer.swift
//  StudyPulse
//
//  错题 PDF 渲染器：使用 Core Text + NSAttributedString 渲染多页 A4 PDF。
//  与之前 ImageRenderer 方案的差异：
//    1. 文字以矢量 PDF 字体嵌入，可选择 / 复制 / 搜索。
//    2. Core Text CTFramesetter 自动按页 path 切分（CTFrameGetVisibleStringRange）。
//    3. 图片用 UIImage.draw(in:) 在文字分页后的页面绘制。
//
//  流程：
//    - 封面页：单页，绘制 StudyPulse 标题 + 用户 + 错题统计 + 模式说明。
//    - 目录页：单页，列出每题编号 / 科目 / 日期 / 标题（题目多时由 Core Text 分页）。
//    - 每题：可能多页，题头 + 4 段（原题/错因/错解/正解）自动分页；图片段在文字之后。
//

import UIKit
import PDFKit
import CoreText

@MainActor
enum MistakePDFRenderer {

    // MARK: - 页面规格（A4 in pt = 595×842）

    /// A4 页面大小（72 dpi）。
    static let pageSize = CGSize(width: 595, height: 842)

    /// 页面四周的留白。
    static let margin: CGFloat = 36

    /// 内容区矩形。
    static var contentRect: CGRect {
        CGRect(
            x: margin,
            y: margin,
            width: pageSize.width - 2 * margin,
            height: pageSize.height - 2 * margin
        )
    }

    /// 单张 UIImage 渲染时使用的缩放比例（保留常量以备将来使用）。
    static let imageScale: CGFloat = 2.0

    // MARK: - 公共 API

    /// 把快照渲染为多页 A4 PDF。
    /// - Parameters:
    ///   - snapshot: 数据快照
    ///   - progress: 进度回调（0.0 - 1.0），主线程调用
    /// - Returns: PDF Data；失败时返回 nil
    static func makePDF(
        from snapshot: MistakePDFSnapshot,
        progress: ((Double) -> Void)? = nil
    ) -> Data? {
        let totalSteps = 2 + snapshot.mistakes.count
        var step = 0
        let advance: () -> Void = {
            step += 1
            progress?(Double(step) / Double(max(totalSteps, 1)))
        }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "StudyPulse Mistake Notebook".localized(),
            kCGPDFContextCreator as String: "StudyPulse"
        ]
        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: format
        )

        let data = pdfRenderer.pdfData { context in
            // 封面
            context.beginPage()
            drawCover(snapshot: snapshot, in: context)
            advance()

            // 目录
            context.beginPage()
            drawTOC(snapshot: snapshot, in: context)
            advance()

            // 每题（题头 + 4 段文字 + 图片组）
            for (idx, mistake) in snapshot.mistakes.enumerated() {
                context.beginPage()
                let (text, images) = buildMistakeComponents(
                    mistake: mistake,
                    mistakeIndex: idx + 1,
                    totalMistakes: snapshot.mistakes.count,
                    snapshot: snapshot
                )
                drawAttributedString(text, in: context)
                if snapshot.includeImages && !images.isEmpty {
                    drawImages(images, in: context)
                }
                advance()
            }
        }

        if data != nil {
            Log.record(.info, category: "Export", message: "错题 PDF Core Text 渲染完成 / Mistake PDF Core Text rendered: mistakes=\(snapshot.mistakes.count)")
        } else {
            Log.record(.error, category: "Export", message: "错题 PDF Core Text 拼装失败 / Mistake PDF Core Text assembly failed")
        }
        return data
    }

    // MARK: - 封面 / 目录

    private static func drawCover(snapshot: MistakePDFSnapshot, in context: UIGraphicsPDFRendererContext) {
        let attr = buildCoverAttributedString(snapshot: snapshot)
        drawAttributedString(attr, in: context)
    }

    private static func drawTOC(snapshot: MistakePDFSnapshot, in context: UIGraphicsPDFRendererContext) {
        let attr = buildTOCAttributedString(snapshot: snapshot)
        drawAttributedString(attr, in: context)
    }

    // MARK: - 核心：Core Text 分页绘制 NSAttributedString

    /// 用 CTFramesetter 把 NSAttributedString 渲染到当前 PDF 上下文。
    /// 当内容超出单页 contentRect 时，自动 beginPage 继续绘制。
    private static func drawAttributedString(
        _ attr: NSAttributedString,
        in context: UIGraphicsPDFRendererContext
    ) {
        let totalLength = attr.length
        guard totalLength > 0 else { return }

        let path = CGPath(rect: contentRect, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attr)
        var startIndex = 0
        var pageCount = 0

        while startIndex < totalLength {
            pageCount += 1
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRangeMake(startIndex, 0),
                path,
                nil
            )
            let visibleRange = CTFrameGetVisibleStringRange(frame)

            // 翻转坐标系：UIGraphicsPDFRenderer 的 CGContext 用 UIKit 风格（左上原点），
            // Core Text 期望左下原点。在 beginPage() 后翻转一次即可。
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: pageSize.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            context.cgContext.textMatrix = .identity
            CTFrameDraw(frame, context.cgContext)
            context.cgContext.restoreGState()

            if visibleRange.length <= 0 {
                // 一页放不下任何字符时保护性退出，避免死循环
                Log.record(.error, category: "Export", message: "Core Text 单页放不下任何字符 / Core Text cannot fit any char: index=\(startIndex), total=\(totalLength), page=\(pageCount)")
                break
            }
            startIndex += visibleRange.length
            if startIndex >= totalLength { break }

            context.beginPage()
        }
    }

    // MARK: - 图片（多张时按 2 列网格排版，自动分页）

    private static func drawImages(_ images: [UIImage], in context: UIGraphicsPDFRendererContext) {
        let columnsPerRow = 2
        let horizontalGap: CGFloat = 12
        let verticalGap: CGFloat = 12
        let maxRowHeight: CGFloat = 220
        let cellWidth = (contentRect.width - horizontalGap * CGFloat(columnsPerRow - 1)) / CGFloat(columnsPerRow)

        var column = 0
        var currentY = contentRect.minY

        for (idx, image) in images.enumerated() {
            // 等比缩放
            let aspectRatio = image.size.height / max(image.size.width, 1)
            let drawWidth: CGFloat
            let drawHeight: CGFloat
            if aspectRatio >= 1 {
                // 高图：以 maxRowHeight 为高上限
                drawHeight = min(maxRowHeight, image.size.height)
                drawWidth = drawHeight / aspectRatio
            } else {
                // 宽图：以 cellWidth 为宽上限
                drawWidth = min(cellWidth, image.size.width)
                drawHeight = drawWidth * aspectRatio
            }

            // 换页检查
            let rowH = max(drawHeight, maxRowHeight * 0.5)  // 行最小高度
            if currentY + rowH > contentRect.maxY {
                context.beginPage()
                currentY = contentRect.minY
                column = 0
            }

            let x = contentRect.minX + CGFloat(column) * (cellWidth + horizontalGap)
            let drawRect = CGRect(x: x, y: currentY, width: drawWidth, height: drawHeight)
            image.draw(in: drawRect)

            _ = idx  // 抑制未使用警告

            column += 1
            if column >= columnsPerRow {
                column = 0
                currentY += maxRowHeight + verticalGap
            }
        }
    }

    // MARK: - 构造 NSAttributedString

    private static func buildCoverAttributedString(snapshot: MistakePDFSnapshot) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let labelColor = UIColor.label
        let secondary = UIColor.secondaryLabel
        let tertiary = UIColor.tertiaryLabel

        // 大标题
        result.append(NSAttributedString(string: "StudyPulse\n", attributes: [
            .font: UIFont.systemFont(ofSize: 44, weight: .bold),
            .foregroundColor: labelColor
        ]))
        result.append(NSAttributedString(string: "Mistake Notebook\n", attributes: [
            .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
            .foregroundColor: labelColor
        ]))
        result.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 12)]))

        // 用户 / 学校
        let username = snapshot.profile.username.isEmpty ? "Student" : snapshot.profile.username
        result.append(NSAttributedString(string: username + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: secondary
        ]))
        if !snapshot.profile.schoolName.isEmpty {
            result.append(NSAttributedString(string: snapshot.profile.schoolName + "\n", attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: secondary
            ]))
        }
        result.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 18)]))

        // 概览
        result.append(NSAttributedString(string: "Summary\n", attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor.systemBlue
        ]))
        let summaryText = String(
            format: "  •  %d mistakes\n  •  %d subjects\n",
            snapshot.mistakeCount,
            snapshot.mistakeCountBySubject.count
        )
        result.append(NSAttributedString(string: summaryText, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: labelColor
        ]))
        result.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 12)]))

        // 模式
        result.append(NSAttributedString(string: "Mode\n", attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor.systemBlue
        ]))
        result.append(NSAttributedString(string: "  " + snapshot.selectionDescription + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: labelColor
        ]))
        if let range = snapshot.dateRangeDescription {
            result.append(NSAttributedString(string: "  " + range + "\n", attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: secondary
            ]))
        }
        result.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 12)]))

        // 按科目
        if !snapshot.mistakeCountBySubject.isEmpty {
            result.append(NSAttributedString(string: "By Subject\n", attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                .foregroundColor: UIColor.systemBlue
            ]))
            for item in snapshot.mistakeCountBySubject {
                let line = String(format: "  •  %@  —  %d\n", snapshot.displayName(for: item.subject), item.count)
                result.append(NSAttributedString(string: line, attributes: [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: labelColor
                ]))
            }
        }

        // 生成时间
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        result.append(NSAttributedString(string: "\n\n\n", attributes: [.font: UIFont.systemFont(ofSize: 14)]))
        result.append(NSAttributedString(string: "Generated at " + formatter.string(from: snapshot.generatedAt) + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: tertiary
        ]))
        result.append(NSAttributedString(string: "Generated by StudyPulse", attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: tertiary
        ]))

        return result
    }

    private static func buildTOCAttributedString(snapshot: MistakePDFSnapshot) -> NSAttributedString {
        let result = NSMutableAttributedString()

        result.append(NSAttributedString(string: "Table of Contents\n\n", attributes: [
            .font: UIFont.systemFont(ofSize: 30, weight: .bold),
            .foregroundColor: UIColor.label
        ]))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let lineStyle = NSMutableParagraphStyle()
        lineStyle.lineSpacing = 6
        lineStyle.paragraphSpacing = 4

        for (idx, mistake) in snapshot.mistakes.enumerated() {
            let title = mistake.title.isEmpty ? "Untitled".localized() : mistake.title
            let subject = snapshot.displayName(for: mistake.subject)
            let date = dateFormatter.string(from: mistake.date)

            let line = String(format: "%3d.  %@   %@   %@\n", idx + 1, subject, date, title)
            result.append(NSAttributedString(string: line, attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label,
                .paragraphStyle: lineStyle
            ]))
        }

        return result
    }

    /// 构造单题的"文字部分"和"图片数组"。文字部分由 Core Text 自动分页。
    private static func buildMistakeComponents(
        mistake: MistakeNote,
        mistakeIndex: Int,
        totalMistakes: Int,
        snapshot: MistakePDFSnapshot
    ) -> (text: NSAttributedString, images: [UIImage]) {
        let result = NSMutableAttributedString()
        let labelColor = UIColor.label
        let secondary = UIColor.secondaryLabel

        // 题头
        let title = mistake.title.isEmpty ? "Untitled".localized() : mistake.title
        result.append(NSAttributedString(string: "#\(mistakeIndex)   \(title)\n", attributes: [
            .font: UIFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: UIColor.systemPurple
        ]))

        // 元信息
        let subjectName = snapshot.displayName(for: mistake.subject)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let meta = "\(subjectName)   •   \(dateFormatter.string(from: mistake.date))"
        let metaLine = mistake.source.isEmpty ? meta : "\(meta)   •   \(mistake.source)"
        result.append(NSAttributedString(string: metaLine + "\n\n", attributes: [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: secondary
        ]))

        // 4 段
        result.append(buildSection(
            title: "Original Question".localized(),
            body: mistake.originalQuestion,
            color: UIColor.systemBlue
        ))
        result.append(buildSection(
            title: "Error Reason".localized(),
            body: mistake.errorReason,
            color: UIColor.systemOrange
        ))
        result.append(buildSection(
            title: "Wrong Solution".localized(),
            body: mistake.wrongSolution,
            color: UIColor.systemRed
        ))
        result.append(buildSection(
            title: "Correct Solution".localized(),
            body: mistake.correctSolution,
            color: UIColor.systemGreen
        ))

        // 收集图片（按 4 段顺序）
        var images: [UIImage] = []
        if snapshot.includeImages {
            for data in mistake.questionImages {
                if let img = UIImage(data: data) { images.append(img) }
            }
            for data in mistake.reasonImages {
                if let img = UIImage(data: data) { images.append(img) }
            }
            for data in mistake.wrongSolutionImages {
                if let img = UIImage(data: data) { images.append(img) }
            }
            for data in mistake.correctSolutionImages {
                if let img = UIImage(data: data) { images.append(img) }
            }
        }

        _ = totalMistakes  // 保留
        _ = labelColor
        return (result, images)
    }

    /// 构造单个段落（标题 + 正文）。
    private static func buildSection(
        title: String,
        body: String,
        color: UIColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 段头（带色）
        result.append(NSAttributedString(string: title + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: color
        ]))

        // 段体
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 8
            paragraphStyle.paragraphSpacing = 18
            paragraphStyle.lineBreakMode = .byWordWrapping
            result.append(NSAttributedString(string: trimmed + "\n\n", attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]))
        } else {
            // 即使为空也加一个空行，保持排版节奏
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: UIFont.systemFont(ofSize: 8)
            ]))
        }

        return result
    }
}
