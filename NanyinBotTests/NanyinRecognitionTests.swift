//
//  NanyinRecognitionTests.swift
//  NanyinBotTests
//
//  Created by Codex on 2026/5/2.
//

import UIKit
import Vision
import XCTest
@testable import NanyinBot

final class NanyinRecognitionTests: XCTestCase {
    func testJingYeSiTemplateParserProducesCompletePlayableScore() {
        let template = NanyinTemplateLibrary.jingYeSi
        let events = JianpuParser.parse(template.jianpuText)

        XCTAssertEqual(events.count, 60)
        XCTAssertEqual(events.filter { $0.midiNote != nil }.count, 60)
        XCTAssertTrue(template.jianpuText.hasPrefix("2 5 3 2"))
        XCTAssertTrue(template.translationText.contains("工ㄨ谱识别与翻译"))
        XCTAssertTrue(template.translationText.contains("模板：《静夜思》测试谱"))
        XCTAssertTrue(template.translationText.contains("逐字翻译"))
        XCTAssertTrue(template.translationText.contains("符号摘要"))
    }

    func testJingYeSiTemplateSymbolsAffectPlaybackRhythm() {
        let template = NanyinTemplateLibrary.jingYeSi
        let events = JianpuParser.parse(template.rhythmicJianpuText)
        let totalBeats = events.reduce(0.0) { $0 + $1.beats }

        XCTAssertEqual(events.count, 60)
        XCTAssertEqual(events.filter { $0.midiNote != nil }.count, 60)
        XCTAssertTrue(template.rhythmicJianpuText.hasPrefix("2○ 5、 3、 2-"))
        XCTAssertTrue(events.contains { $0.symbol.contains("○") && $0.accent > 1.0 })
        XCTAssertTrue(events.contains { $0.symbol.contains("-") && $0.beats > 1.0 })
        XCTAssertTrue(events.contains { $0.symbol.contains("√") })
        XCTAssertGreaterThan(totalBeats, 60.0)
    }

    func testConversionGuideDocumentsPitchFiveElementMapping() {
        let guide = NanyinKnowledgeGuide.text

        XCTAssertEqual(NanyinKnowledgeGuide.pitches.count, 5)
        XCTAssertEqual(NanyinSymbolInterpreter.symbolRows.count, 5)
        XCTAssertTrue(guide.contains("工ㄨ谱转换逻辑说明"))
        XCTAssertTrue(guide.contains("乂 / ㄨ → 简谱 1 → 宫 (Gong) / Do；五行属土，传统脏腑对应脾。"))
        XCTAssertTrue(guide.contains("工 → 简谱 2 → 商 (Shang) / Re；五行属金，传统脏腑对应肺。"))
        XCTAssertTrue(guide.contains("六 → 简谱 3 → 角 (Jiao/Jue) / Mi；五行属木，传统脏腑对应肝。"))
        XCTAssertTrue(guide.contains("思 / 士 → 简谱 5 → 徵 (Zhi) / Sol；五行属火，传统脏腑对应心。"))
        XCTAssertTrue(guide.contains("一 → 简谱 6 → 羽 (Yu) / La；五行属水，传统脏腑对应肾。"))
        XCTAssertTrue(guide.contains("○ / 〇 / o / O / 。｜拍"))
        XCTAssertTrue(guide.contains("√ / ） / ) / L / ㄥ / 口 / 十｜南琶指骨"))
        XCTAssertTrue(guide.contains("播放节奏规则"))
        XCTAssertTrue(guide.contains("播放稿格式示例：2○ 5、 3、 2-"))
        XCTAssertTrue(guide.contains("这些符号只控制节奏、重音和时值"))
        XCTAssertTrue(guide.contains("当前边界"))
    }

    func testAlgorithmGuideExplainsExplainableScoring() {
        let report = NanyinTemplateLibrary.jingYeSi.algorithmText

        XCTAssertTrue(report.contains("南音工ㄨ谱字符特征打分匹配法"))
        XCTAssertTrue(report.contains("图像预处理"))
        XCTAssertTrue(report.contains("特征提取"))
        XCTAssertTrue(report.contains("打分匹配"))
        XCTAssertTrue(report.contains("工：7 分，六：3 分，一：2 分"))
        XCTAssertTrue(report.contains("○：5 分，、：1 分"))
        XCTAssertTrue(report.contains("谱字数量：60"))
        XCTAssertTrue(report.contains("答辩口径"))
        XCTAssertTrue(report.contains("iPad/iPhone 是稳定的比赛展示载体"))
    }

    func testPresentationMaterialsCoverTeacherGuidanceAndDemoFlow() {
        let materials = NanyinPresentationMaterials.text

        XCTAssertTrue(materials.contains("比赛材料目录"))
        XCTAssertTrue(materials.contains("不是做南音百科"))
        XCTAssertTrue(materials.contains("指导老师建议对应"))
        XCTAssertTrue(materials.contains("iPad 展示路径"))
        XCTAssertTrue(materials.contains("2 分钟讲解稿"))
        XCTAssertTrue(materials.contains("OCR 不是项目核心"))
        XCTAssertTrue(materials.contains("测试记录表"))
    }

    func testTemplateSymbolReportExplainsLiaoPaiAndFingerMarks() {
        let template = NanyinTemplateLibrary.jingYeSi
        let matches = NanyinSymbolInterpreter.scan(template.symbolSourceText)

        XCTAssertGreaterThan(matches.count, 20)
        XCTAssertTrue(template.symbolText.contains("《静夜思》测试谱符号识别"))
        XCTAssertTrue(template.symbolText.contains("拍"))
        XCTAssertTrue(template.symbolText.contains("撩"))
        XCTAssertTrue(template.symbolText.contains("南琶指骨"))
        XCTAssertTrue(template.symbolText.contains("延续/连贯提示"))
    }

    func testJingYeSiImageRecognitionFallsBackToCompleteTemplateWhenOCRIsIncomplete() throws {
        let image = try loadJingYeSiTemplateImage()
        guard let cgImage = image.normalizedForTest().cgImage else {
            XCTFail("测试图片无法转换为 CGImage")
            return
        }

        let observations = try recognizeText(in: cgImage)
        let analysis = ScorePageAnalyzer.analyze(observations: observations, image: cgImage)
        let expected = NanyinTemplateLibrary.jingYeSi
        let expectedEventCount = JianpuParser.parse(expected.jianpuText).count
        let actualEventCount = JianpuParser.parse(analysis.jianpuDraft).count
        let completeness = Double(actualEventCount) / Double(expectedEventCount)

        XCTAssertEqual(analysis.templateName, expected.name)
        XCTAssertEqual(analysis.jianpuDraft, expected.rhythmicJianpuText)
        XCTAssertEqual(actualEventCount, expectedEventCount)
        XCTAssertGreaterThanOrEqual(completeness, 0.95)
        XCTAssertTrue(analysis.translationText.contains("模板：《静夜思》测试谱"))
        XCTAssertTrue(analysis.symbolText.contains("南琶指骨"))
        XCTAssertTrue(analysis.structuredText.contains("模板兜底"))
        XCTAssertNotEqual(analysis.jianpuDraft, "2 2")
    }

    private func loadJingYeSiTemplateImage() throws -> UIImage {
        let candidateBundles = [
            Bundle(identifier: "com.wecomic.NanyinBot"),
            Bundle(for: ViewController.self),
            Bundle.main
        ].compactMap { $0 }

        for bundle in candidateBundles {
            if let image = UIImage(named: "JingYeSiTemplate", in: bundle, compatibleWith: nil) {
                return image
            }
        }

        throw XCTSkip("未能从 App bundle 加载 JingYeSiTemplate 测试图")
    }

    private func recognizeText(in cgImage: CGImage) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.customWords = ["乂", "ㄨ", "工", "六", "思", "一", "静夜思", "床", "前", "明", "月", "光"]
        request.minimumTextHeight = 0.004

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        return request.results ?? []
    }
}

private extension UIImage {
    func normalizedForTest() -> UIImage {
        guard imageOrientation != .up else { return self }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
