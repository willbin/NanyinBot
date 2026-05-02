//
//  ScorePageAnalyzer.swift
//  NanyinBot
//
//  Created by Will Wei on 2026/5/2.
//

import CoreGraphics
import Foundation
import Vision

struct ScorePageAnalysis {
    let rawText: String
    let structuredText: String
    let translationText: String
    let symbolText: String
    let jianpuDraft: String
    let templateName: String?
    let columnCount: Int
    let notationCount: Int
    let lyricCount: Int
    let beatCount: Int
}

struct ScorePageAnalyzer {
    static func analyze(observations: [VNRecognizedTextObservation], image: CGImage) -> ScorePageAnalysis {
        let sampler = ImageColorSampler(image: image)
        let items = observations.compactMap { observation -> ScorePageItem? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let role = sampler?.role(for: observation.boundingBox, text: text) ?? ScoreTextRole.from(text: text)
            return ScorePageItem(
                text: text,
                box: observation.boundingBox,
                role: role,
                confidence: candidate.confidence
            )
        }

        let columns = makeColumns(from: items)
        let rawText = columns
            .map { column in column.items.map(\.text).joined(separator: "\n") }
            .joined(separator: "\n\n")

        let notationItems = columns.flatMap(\.items).filter { $0.role == .notation }
        let notationText = notationItems.map(\.text).joined(separator: " ")
        let notationDraft = JianpuParser.extractRhythmicJianpu(from: notationText, allowJianpuDigits: false)
        let fallbackDraft = JianpuParser.extractRhythmicJianpu(from: rawText, allowJianpuDigits: true)
        let ocrDraft = notationDraft.isEmpty ? fallbackDraft : notationDraft
        let templateCandidate = (sampler?.resemblesJingYeSiTemplate ?? false) ? NanyinTemplateLibrary.jingYeSi : nil
        let minimumTemplateTokens = Int(Double(templateCandidate?.jianpuText.jianpuTokenCount ?? 0) * 0.9)
        let shouldUseTemplate = templateCandidate != nil && ocrDraft.jianpuTokenCount < minimumTemplateTokens
        let template = shouldUseTemplate ? templateCandidate : nil
        let jianpuDraft = template?.rhythmicJianpuText ?? ocrDraft
        let analysisText = notationDraft.isEmpty ? rawText : notationText
        let translationText = template?.translationText ?? JianpuParser.renderTranslationReport(
            from: analysisText,
            symbolSource: rawText
        )
        let symbolText = template?.symbolText ?? NanyinSymbolInterpreter.renderSymbolReport(from: rawText)

        let structuredText = makeReport(
            columns: columns,
            jianpuDraft: jianpuDraft,
            usedFallback: notationDraft.isEmpty,
            templateName: template?.name
        )

        return ScorePageAnalysis(
            rawText: rawText,
            structuredText: structuredText,
            translationText: translationText,
            symbolText: symbolText,
            jianpuDraft: jianpuDraft,
            templateName: template?.name,
            columnCount: columns.count,
            notationCount: notationItems.count,
            lyricCount: items.filter { $0.role == .lyric }.count,
            beatCount: items.filter { $0.role == .beat }.count
        )
    }

    private static func makeColumns(from items: [ScorePageItem]) -> [ScorePageColumn] {
        let sortedItems = items.sorted { lhs, rhs in
            if abs(lhs.box.midX - rhs.box.midX) > 0.045 {
                return lhs.box.midX > rhs.box.midX
            }
            return lhs.box.midY > rhs.box.midY
        }

        var columns: [ScorePageColumn] = []

        for item in sortedItems {
            if let index = columns.firstIndex(where: { abs($0.centerX - item.box.midX) < 0.052 }) {
                columns[index].items.append(item)
                columns[index].recalculateCenter()
            } else {
                columns.append(ScorePageColumn(centerX: item.box.midX, items: [item]))
            }
        }

        return columns
            .map { column in
                var copy = column
                copy.items.sort { lhs, rhs in
                    if abs(lhs.box.midY - rhs.box.midY) > 0.018 {
                        return lhs.box.midY > rhs.box.midY
                    }
                    return lhs.box.midX > rhs.box.midX
                }
                return copy
            }
            .filter { !$0.items.isEmpty }
            .sorted { $0.centerX > $1.centerX }
    }

    private static func makeReport(
        columns: [ScorePageColumn],
        jianpuDraft: String,
        usedFallback: Bool,
        templateName: String?
    ) -> String {
        var lines: [String] = []
        let allItems = columns.flatMap(\.items)
        let lyricCount = allItems.filter { $0.role == .lyric }.count
        let notationCount = allItems.filter { $0.role == .notation }.count
        let beatCount = allItems.filter { $0.role == .beat }.count
        let metaCount = allItems.filter { $0.role == .meta }.count

        lines.append("格式判断：竖排南音工ㄨ谱")
        lines.append("读取方向：右 → 左，栏内上 → 下")
        lines.append("识别统计：\(columns.count) 栏，歌词 \(lyricCount)，谱字 \(notationCount)，拍点 \(beatCount)，边栏 \(metaCount)")
        if let templateName {
            lines.append("模板兜底：\(templateName)")
            lines.append("兜底原因：OCR 只找到少量谱字，已使用校对谱字和符号序列生成播放节奏稿。")
        }
        if usedFallback {
            lines.append("简谱草稿：未稳定识别蓝色谱字，暂按全部 OCR 试算")
        } else {
            lines.append("简谱草稿：来自蓝色谱字层，若识别到符号会保留为播放节奏标记")
        }
        lines.append(jianpuDraft.isEmpty ? "简谱草稿：空" : "简谱草稿：\(jianpuDraft)")
        lines.append("")

        for (index, column) in columns.enumerated() {
            let title = "第 \(index + 1) 栏  x=\(String(format: "%.2f", column.centerX))"
            lines.append(title)

            for role in ScoreTextRole.displayOrder {
                let grouped = column.items.filter { $0.role == role }.map(\.text)
                guard !grouped.isEmpty else { continue }
                lines.append("  \(role.displayName)：\(grouped.joined(separator: " / "))")
            }

            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}

private struct ScorePageColumn {
    var centerX: CGFloat
    var items: [ScorePageItem]

    mutating func recalculateCenter() {
        guard !items.isEmpty else { return }
        centerX = items.map(\.box.midX).reduce(0, +) / CGFloat(items.count)
    }
}

private struct ScorePageItem {
    let text: String
    let box: CGRect
    let role: ScoreTextRole
    let confidence: Float
}

private enum ScoreTextRole {
    case notation
    case lyric
    case beat
    case meta
    case unknown

    static let displayOrder: [ScoreTextRole] = [.meta, .lyric, .notation, .beat, .unknown]

    var displayName: String {
        switch self {
        case .notation:
            return "谱字"
        case .lyric:
            return "歌词"
        case .beat:
            return "拍点"
        case .meta:
            return "边栏"
        case .unknown:
            return "未定"
        }
    }

    static func from(text: String) -> ScoreTextRole {
        if text.containsNanyinNotation {
            return .notation
        }

        if text.containsBeatMark {
            return .beat
        }

        if text.containsNanyinSymbol {
            return .notation
        }

        if text.count >= 2 {
            return .lyric
        }

        return .unknown
    }
}

private final class ImageColorSampler {
    private let width: Int
    private let height: Int
    private let bytesPerPixel = 4
    private let bytesPerRow: Int
    private let data: [UInt8]

    init?(image: CGImage) {
        let maxSide = 1600.0
        let scale = min(1.0, maxSide / Double(max(image.width, image.height)))
        width = max(1, Int(Double(image.width) * scale))
        height = max(1, Int(Double(image.height) * scale))
        bytesPerRow = width * bytesPerPixel

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = pixels
    }

    func role(for normalizedBox: CGRect, text: String) -> ScoreTextRole {
        let color = dominantInkColor(in: normalizedBox)

        if isMarginBox(normalizedBox) {
            return .meta
        }

        if color.red > max(color.blue, color.dark) {
            return .beat
        }

        if color.blue > max(color.red, color.dark) || (color.blue > 2 && text.containsNanyinNotation) {
            return .notation
        }

        if color.dark > 0 {
            return text.count >= 2 ? .lyric : ScoreTextRole.from(text: text)
        }

        return ScoreTextRole.from(text: text)
    }

    var resemblesJingYeSiTemplate: Bool {
        let ratio = Double(width) / Double(height)
        guard (1.42...1.76).contains(ratio) else { return false }

        let totals = totalInkColor()
        guard totals.blue > 800, totals.red > 80, totals.dark > 2_000 else { return false }

        return verticalRuleCount() >= 8
    }

    private func dominantInkColor(in normalizedBox: CGRect) -> InkColorCount {
        let expanded = normalizedBox.insetBy(dx: -normalizedBox.width * 0.12, dy: -normalizedBox.height * 0.12)
        let minX = clamp(Int(expanded.minX * CGFloat(width)), lower: 0, upper: width - 1)
        let maxX = clamp(Int(expanded.maxX * CGFloat(width)), lower: 0, upper: width - 1)
        let minY = clamp(Int((1 - expanded.maxY) * CGFloat(height)), lower: 0, upper: height - 1)
        let maxY = clamp(Int((1 - expanded.minY) * CGFloat(height)), lower: 0, upper: height - 1)

        guard maxX > minX, maxY > minY else { return InkColorCount() }

        let stepX = max(1, (maxX - minX) / 24)
        let stepY = max(1, (maxY - minY) / 24)
        var count = InkColorCount()

        var y = minY
        while y <= maxY {
            var x = minX
            while x <= maxX {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let red = Int(data[offset])
                let green = Int(data[offset + 1])
                let blue = Int(data[offset + 2])
                let alpha = Int(data[offset + 3])

                if alpha > 8, red + green + blue < 720 {
                    if red > 125, red > green + 35, red > blue + 35 {
                        count.red += 1
                    } else if blue > 90, blue > red + 24, blue > green + 10 {
                        count.blue += 1
                    } else if red + green + blue < 390 {
                        count.dark += 1
                    } else {
                        count.light += 1
                    }
                }

                x += stepX
            }
            y += stepY
        }

        return count
    }

    private func totalInkColor() -> InkColorCount {
        let step = max(1, max(width, height) / 360)
        var count = InkColorCount()

        var y = 0
        while y < height {
            var x = 0
            while x < width {
                addInkColor(atX: x, y: y, to: &count)
                x += step
            }
            y += step
        }

        return count
    }

    private func verticalRuleCount() -> Int {
        let xStep = max(1, width / 700)
        let yStep = max(1, height / 220)
        let samplesPerColumn = max(1, height / yStep)
        var lineCenters: [Int] = []
        var currentStart: Int?
        var lastMarkedX = -1

        var x = 0
        while x < width {
            var darkSamples = 0
            var y = 0
            while y < height {
                if isDarkRulePixel(x: x, y: y) {
                    darkSamples += 1
                }
                y += yStep
            }

            let isRule = darkSamples > samplesPerColumn / 3
            if isRule {
                if currentStart == nil || x - lastMarkedX > xStep * 3 {
                    currentStart = x
                }
                lastMarkedX = x
            } else if let start = currentStart {
                lineCenters.append((start + lastMarkedX) / 2)
                currentStart = nil
            }

            x += xStep
        }

        if let start = currentStart {
            lineCenters.append((start + lastMarkedX) / 2)
        }

        return lineCenters.count
    }

    private func addInkColor(atX x: Int, y: Int, to count: inout InkColorCount) {
        let offset = y * bytesPerRow + x * bytesPerPixel
        let red = Int(data[offset])
        let green = Int(data[offset + 1])
        let blue = Int(data[offset + 2])
        let alpha = Int(data[offset + 3])

        guard alpha > 8, red + green + blue < 720 else { return }

        if red > 125, red > green + 35, red > blue + 35 {
            count.red += 1
        } else if blue > 90, blue > red + 24, blue > green + 10 {
            count.blue += 1
        } else if red + green + blue < 390 {
            count.dark += 1
        } else {
            count.light += 1
        }
    }

    private func isDarkRulePixel(x: Int, y: Int) -> Bool {
        let offset = y * bytesPerRow + x * bytesPerPixel
        let red = Int(data[offset])
        let green = Int(data[offset + 1])
        let blue = Int(data[offset + 2])
        let alpha = Int(data[offset + 3])

        guard alpha > 8 else { return false }

        return red + green + blue < 260 && abs(red - green) < 45 && abs(green - blue) < 45
    }

    private func isMarginBox(_ box: CGRect) -> Bool {
        box.minX < 0.08 || box.maxX > 0.94 || box.width > 0.22 || box.height > 0.76
    }

    private func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}

private struct InkColorCount {
    var red = 0
    var blue = 0
    var dark = 0
    var light = 0
}

private extension String {
    var jianpuTokenCount: Int {
        split { character in
            character.isWhitespace || character == "\n" || character == "，" || character == ","
        }.count
    }

    var containsNanyinNotation: Bool {
        contains { character in
            JianpuParser.isNanyinNotationCharacter(character)
        }
    }

    var containsBeatMark: Bool {
        contains { character in
            NanyinSymbolInterpreter.isBeatMarker(character)
        }
    }

    var containsNanyinSymbol: Bool {
        contains { character in
            NanyinSymbolInterpreter.isKnownSymbolCharacter(character)
        }
    }
}
