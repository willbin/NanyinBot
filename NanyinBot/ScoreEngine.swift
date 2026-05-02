//
//  ScoreEngine.swift
//  NanyinBot
//
//  Created by Will Wei on 2026/5/2.
//

import AVFoundation
import Foundation

struct JianpuEvent {
    let midiNote: Int?
    let beats: Double
    let symbol: String
    let accent: Double

    init(midiNote: Int?, beats: Double, symbol: String, accent: Double = 1.0) {
        self.midiNote = midiNote
        self.beats = beats
        self.symbol = symbol
        self.accent = accent
    }
}

struct NanyinTranslationEntry {
    let source: Character
    let jianpu: String
}

struct NanyinPitchKnowledge {
    let tokens: String
    let jianpu: String
    let wuyin: String
    let solfege: String
    let wuxing: String
    let organ: String
}

struct NanyinSymbolKnowledge {
    let symbols: String
    let name: String
    let purpose: String
    let appSupport: String
}

struct NanyinSymbolMatch {
    let source: Character
    let knowledge: NanyinSymbolKnowledge
}

enum NanyinSymbolInterpreter {
    static let symbolRows: [NanyinSymbolKnowledge] = [
        NanyinSymbolKnowledge(
            symbols: "○ / 〇 / o / O / 。",
            name: "拍",
            purpose: "拍板击节处，通常作为强位或段落骨架。",
            appSupport: "播放时作为强位重音，保持一个撩拍单位；不改变旋律音高。"
        ),
        NanyinSymbolKnowledge(
            symbols: "、 / 丶",
            name: "撩",
            purpose: "撩拍中的弱位，配合拍形成节奏骨架。",
            appSupport: "播放时作为弱位节奏单位，和拍一起组织强弱。"
        ),
        NanyinSymbolKnowledge(
            symbols: "厶 / ∠",
            name: "撩拍变体",
            purpose: "用于撩拍组合中的特殊位置，常见于较慢板式的节拍组织。",
            appSupport: "播放时按撩拍单位处理，并在符号页保留原始提示。"
        ),
        NanyinSymbolKnowledge(
            symbols: "√ / ） / ) / L / ㄥ / 口 / 十",
            name: "南琶指骨",
            purpose: "记录南琶弹奏指法；资料中常以 √、） 等说明钩、落指等动作。指骨同时影响时值。",
            appSupport: "播放文本保留指骨；无撩拍标记时先按短促动作估算，后续再按完整指骨表细化。"
        ),
        NanyinSymbolKnowledge(
            symbols: "- / — / | / │ / ｜",
            name: "延续/连贯提示",
            purpose: "图面上常见为谱字旁的延续线、连贯线或指骨形态。",
            appSupport: "播放时延长前一个音的时值。"
        )
    ]

    private static var symbolMap: [Character: NanyinSymbolKnowledge] {
        var map: [Character: NanyinSymbolKnowledge] = [:]
        for row in symbolRows {
            for symbol in row.symbols where !symbol.isWhitespace && symbol != "/" {
                map[symbol] = row
            }
        }
        return map
    }

    static func isKnownSymbolCharacter(_ character: Character) -> Bool {
        symbolMap[character] != nil
    }

    static func isBeatMarker(_ character: Character) -> Bool {
        guard let row = symbolMap[character] else { return false }
        return row.name == "拍" || row.name == "撩" || row.name == "撩拍变体"
    }

    static func isStrongBeatMarker(_ character: Character) -> Bool {
        ["○", "〇", "o", "O", "。"].contains(character)
    }

    static func isWeakBeatMarker(_ character: Character) -> Bool {
        ["、", "丶", "厶", "∠"].contains(character)
    }

    static func isFingerMarker(_ character: Character) -> Bool {
        ["√", "）", ")", "L", "ㄥ", "口", "十"].contains(character)
    }

    static func isExtensionMarker(_ character: Character) -> Bool {
        ["-", "—", "|", "│", "｜"].contains(character)
    }

    static func isPlaybackModifier(_ character: Character) -> Bool {
        isStrongBeatMarker(character)
            || isWeakBeatMarker(character)
            || isFingerMarker(character)
            || isExtensionMarker(character)
    }

    static func scan(_ text: String) -> [NanyinSymbolMatch] {
        let map = symbolMap
        return text.compactMap { character in
            guard let knowledge = map[character] else { return nil }
            return NanyinSymbolMatch(source: character, knowledge: knowledge)
        }
    }

    static func renderCompactSummary(from text: String) -> [String] {
        let matches = scan(text)
        guard !matches.isEmpty else { return [] }

        let grouped = Dictionary(grouping: matches) { match in
            String(match.source)
        }

        return grouped.keys.sorted().compactMap { key in
            guard let match = grouped[key]?.first else { return nil }
            let count = grouped[key]?.count ?? 0
            return "\(key) × \(count)：\(match.knowledge.name)"
        }
    }

    static func renderSymbolReport(from text: String, title: String? = nil) -> String {
        let matches = scan(text)
        var lines: [String] = []
        lines.append(title ?? "南音符号识别")

        guard !matches.isEmpty else {
            lines.append("没有识别到可解释的撩拍或指骨符号。")
            return lines.joined(separator: "\n")
        }

        lines.append("说明：符号不改变基础音高，但会进入播放节奏：拍/撩控制强弱，延续符号控制时长，指骨先作为演奏提示和短促估算。")
        lines.append("")
        lines.append("识别到的符号：")
        lines.append(contentsOf: renderCompactSummary(from: text))
        lines.append("")
        lines.append("用途表：")

        for row in symbolRows {
            lines.append("\(row.symbols)｜\(row.name)：\(row.purpose)")
            lines.append("  当前支持：\(row.appSupport)")
        }

        return lines.joined(separator: "\n")
    }
}

enum NanyinKnowledgeGuide {
    static let pitches: [NanyinPitchKnowledge] = [
        NanyinPitchKnowledge(tokens: "乂 / ㄨ", jianpu: "1", wuyin: "宫 (Gong)", solfege: "Do", wuxing: "土", organ: "脾"),
        NanyinPitchKnowledge(tokens: "工", jianpu: "2", wuyin: "商 (Shang)", solfege: "Re", wuxing: "金", organ: "肺"),
        NanyinPitchKnowledge(tokens: "六", jianpu: "3", wuyin: "角 (Jiao/Jue)", solfege: "Mi", wuxing: "木", organ: "肝"),
        NanyinPitchKnowledge(tokens: "思 / 士", jianpu: "5", wuyin: "徵 (Zhi)", solfege: "Sol", wuxing: "火", organ: "心"),
        NanyinPitchKnowledge(tokens: "一", jianpu: "6", wuyin: "羽 (Yu)", solfege: "La", wuxing: "水", organ: "肾")
    ]

    static var text: String {
        var lines: [String] = []
        lines.append("工ㄨ谱转换逻辑说明")
        lines.append("")
        lines.append("本 App 当前先做演示级核心链路：识别南音基础谱字和符号 → 转成带节奏标记的简谱 → 按简谱播放旋律。")
        lines.append("")
        lines.append("五音对应关系：")

        for pitch in pitches {
            lines.append("\(pitch.tokens) → 简谱 \(pitch.jianpu) → \(pitch.wuyin) / \(pitch.solfege)；五行属\(pitch.wuxing)，传统脏腑对应\(pitch.organ)。")
        }

        lines.append("")
        lines.append("符号用途：")
        for row in NanyinSymbolInterpreter.symbolRows {
            lines.append("\(row.symbols)｜\(row.name)：\(row.purpose)")
        }

        lines.append("")
        lines.append("播放节奏规则：")
        lines.append("1. 播放稿格式示例：2○ 5、 3、 2-。数字是简谱音高，后面的符号是该音的节奏/指法标记。")
        lines.append("2. ○ / 〇 / o / O / 。：强位拍点，播放时加重音，默认占 1 个拍/撩单位。")
        lines.append("3. 、 / 丶 / 厶 / ∠：弱位撩拍，播放时音量稍轻，默认占 1 个拍/撩单位。")
        lines.append("4. - / — / | / │ / ｜：延续/连贯，播放时把前一个音延长 1 个单位。")
        lines.append("5. √ / ） / ) / L / ㄥ / 口 / 十：南琶指骨，当前先保留在播放稿；没有撩拍符号时按 0.5 个单位的短促动作估算。")
        lines.append("6. 这些符号只控制节奏、重音和时值，不把音高改成其他简谱数字。")

        lines.append("")
        lines.append("识别策略：")
        lines.append("1. OCR 先读取图片文字，并按颜色/位置区分黑色歌词、蓝色谱字、红色拍点。")
        lines.append("2. 蓝色谱字按竖排版面从右到左、栏内从上到下排序。")
        lines.append("3. 谱字按上面的五音表翻译为简谱数字。")
        lines.append("4. 撩拍符号会进入播放：○/〇/o 为强位，、/丶/厶/∠ 为弱位；延续线会拉长前一个音。")
        lines.append("5. 指骨符号会保留在播放文本中；无撩拍标记时先按短促动作估算，完整指骨时值表后续继续校准。")
        lines.append("6. 如果《静夜思》测试图的 OCR 只读到很少谱字，会切换到内置校对模板，保证演示的完整率和播放稳定性。")
        lines.append("")
        lines.append("当前边界：")
        lines.append("这个版本覆盖基础音高、撩拍强弱、延续时值和指骨提示。更完整的南音工ㄨ谱还需要继续解析指骨时值表、管门和八度偏旁。")

        return lines.joined(separator: "\n")
    }
}

enum NanyinAlgorithmGuide {
    static var text: String {
        renderDemoReport(
            title: "可解释识谱算法演示",
            sourceText: NanyinTemplateLibrary.jingYeSi.sourceText,
            rhythmicText: NanyinTemplateLibrary.jingYeSi.rhythmicJianpuText
        )
    }

    static func renderDemoReport(title: String, sourceText: String, rhythmicText: String) -> String {
        let translated = JianpuParser.translateNanyin(from: sourceText)
        let events = JianpuParser.parse(rhythmicText)
        let symbolMatches = NanyinSymbolInterpreter.scan(rhythmicText)
        let noteCount = translated.count
        let totalBeats = events.reduce(0.0) { $0 + $1.beats }

        var lines: [String] = []
        lines.append(title)
        lines.append("")
        lines.append("项目算法名称：南音工ㄨ谱字符特征打分匹配法")
        lines.append("适合讲法：先把图片变成黑白图，再切出单字，观察字形特点并打分，分数最高的就是识别结果。")
        lines.append("")
        lines.append("算法流程：")
        lines.append("1. 图像预处理：灰度化、二值化、去噪、倾斜校正。")
        lines.append("2. 谱面分栏：南音谱竖排，从右到左分栏，栏内从上到下读取。")
        lines.append("3. 字符切分：用空白间隔和连通区域，把谱字和符号框出来。")
        lines.append("4. 特征提取：统计宽高比、黑色像素分布、横线、竖线、交叉点和圆形特征。")
        lines.append("5. 打分匹配：每个候选谱字得到一个分数，最高分作为识别结果。")
        lines.append("6. 翻译播放：谱字转简谱，拍/撩/延续符号控制节奏。")
        lines.append("")
        lines.append("打分样例：")
        lines.append("字符：工")
        lines.append("  上方横线：+2")
        lines.append("  下方横线：+2")
        lines.append("  中间竖线：+2")
        lines.append("  宽高比例接近：+1")
        lines.append("  工：7 分，六：3 分，一：2 分 → 识别为 工 → 简谱 2")
        lines.append("")
        lines.append("字符：六")
        lines.append("  上方有集中笔画：+2")
        lines.append("  下方左右分开：+2")
        lines.append("  没有明显上下双横：+1")
        lines.append("  六：5 分，工：2 分，思：2 分 → 识别为 六 → 简谱 3")
        lines.append("")
        lines.append("字符：○")
        lines.append("  宽高接近：+1")
        lines.append("  外圈有笔画：+2")
        lines.append("  中间较空：+2")
        lines.append("  ○：5 分，、：1 分 → 识别为 拍 → 播放强位")
        lines.append("")
        lines.append("当前样例统计：")
        lines.append("谱字数量：\(noteCount)")
        lines.append("播放事件：\(events.count)")
        lines.append("符号数量：\(symbolMatches.count)")
        lines.append("总节奏单位：\(formatBeats(totalBeats))")
        lines.append("")
        lines.append("输出示例：")
        lines.append(rhythmicText)
        lines.append("")
        lines.append("答辩口径：")
        lines.append("这个算法不是黑盒识别，而是把每个字为什么被识别出来讲清楚。评委能看到每一步：图片变清楚、字符被切出、特征被统计、分数被比较、最后转成简谱并播放。")
        lines.append("")
        lines.append("平台选择：")
        lines.append("iPad/iPhone 是稳定的比赛展示载体。项目核心不是依赖某个平台的 OCR，而是南音谱字规则、符号节奏规则和可解释识别流程；后续可迁移到网页或 Android。")

        return lines.joined(separator: "\n")
    }

    private static func formatBeats(_ beats: Double) -> String {
        if beats.rounded() == beats {
            return String(Int(beats))
        }
        return String(format: "%.1f", beats)
    }
}

enum NanyinPresentationMaterials {
    static var text: String {
        [
            "比赛材料目录",
            "",
            "1. 项目一句话",
            "用可解释算法把南音工ㄨ谱转换成可读的简谱和可听的旋律，让同龄人更容易理解南音。",
            "",
            "2. 作品定位",
            "项目不是做南音百科，也不是比拼通用 OCR，而是聚焦一个具体痛点：工ㄨ谱看不懂、不会读、听不出旋律。",
            "",
            "3. 指导老师建议对应",
            "建议：避免题目太泛。",
            "准备：聚焦“工ㄨ谱识别与翻译”。",
            "",
            "建议：算法类作品要体现算法结合。",
            "准备：使用“南音工ㄨ谱字符特征打分匹配法”，能解释每个字符为什么被识别。",
            "",
            "建议：适合初一学生讲清楚。",
            "准备：不讲深度学习黑盒，只讲灰度化、二值化、切字、看横线竖线圆形、打分匹配。",
            "",
            "建议：成果可展示。",
            "准备：iPad 打开即可看到谱图、算法、简谱、符号说明和播放控制。",
            "",
            "4. iPad 展示路径",
            "第一步：打开 App，默认进入《静夜思》算法页。",
            "第二步：讲项目算法名称和 6 步流程。",
            "第三步：切到“符号”，讲拍、撩、延续、指骨如何影响节奏。",
            "第四步：切到“简谱”，播放旋律。",
            "第五步：点“识别”，展示 OCR 不完整时如何用模板兜底保证演示完整率。",
            "第六步：切回“材料”，回答评委问题。",
            "",
            "5. 2 分钟讲解稿",
            "大家好，我的项目是《南音工ㄨ谱识别与翻译》。南音是泉州的重要非遗音乐，但它使用的工ㄨ谱和我们平时见到的简谱不一样，很多同学看不懂。",
            "我设计了一个可解释识谱算法：先把谱图处理得更清楚，再按竖排版面分栏，把单个谱字切出来，最后根据字形特征打分匹配。",
            "例如“工”字有上下两横和中间竖线，所以它会得到更高分，识别后转换成简谱 2。拍、撩、延续等符号不改变音高，但会影响播放时的强弱和时长。",
            "这个 App 可以在 iPad 上展示完整流程：看原谱、看算法、看简谱、听旋律。它让传统南音谱变得更容易被同龄人理解。",
            "",
            "6. 评委可能会问",
            "问：为什么只做 iPad/iPhone？",
            "答：比赛重点是算法流程和文化应用验证，不是商业化多端上线。iPad 展示稳定，规则库后续可以迁移到网页或 Android。",
            "",
            "问：OCR 不准怎么办？",
            "答：OCR 不是项目核心。核心是南音谱字规则和可解释转换。演示样例会使用校对模板兜底，保证完整率。",
            "",
            "问：算法在哪里？",
            "答：算法体现在图像预处理、竖排分栏、字符切分、特征提取、打分匹配和符号节奏转换。",
            "",
            "7. 测试记录表",
            "样本名称｜应有音符｜输出音符｜完整率｜符号识别｜播放是否成功｜备注",
            "静夜思｜60｜60｜100%｜拍/撩/延续/指骨已解释｜成功｜演示模板",
            "",
            "8. 后续材料清单",
            "PPT：问题、方案、算法、演示、测试、总结。",
            "海报：一张图讲清楚工ㄨ谱到简谱。",
            "测试表：记录 5 到 10 个同学使用前后的看懂率。",
            "演示视频：30 秒展示识别、转换和播放。"
        ].joined(separator: "\n")
    }
}

struct NanyinTemplateScore {
    let name: String
    let sourceText: String
    let symbolSourceText: String

    var jianpuText: String {
        JianpuParser.extractJianpu(from: sourceText, allowJianpuDigits: false)
    }

    var rhythmicJianpuText: String {
        JianpuParser.extractRhythmicJianpu(from: symbolSourceText, allowJianpuDigits: false)
    }

    var translationText: String {
        JianpuParser.renderTranslationReport(
            from: sourceText,
            symbolSource: symbolSourceText,
            note: "模板：\(name)；当照片 OCR 只抓到少量谱字时，使用这份校对序列保证演示可读、可听。"
        )
    }

    var symbolText: String {
        NanyinSymbolInterpreter.renderSymbolReport(
            from: symbolSourceText,
            title: "\(name)符号识别"
        )
    }

    var algorithmText: String {
        NanyinAlgorithmGuide.renderDemoReport(
            title: "\(name)算法演示",
            sourceText: sourceText,
            rhythmicText: rhythmicJianpuText
        )
    }

    var structureText: String {
        [
            "格式判断：竖排南音工ㄨ谱",
            "模板兜底：\(name)",
            "读取方向：右 → 左，栏内上 → 下",
            "说明：Vision 对蓝色手写谱字识别不足时，已切换到内置校对谱字序列。",
            "",
            "简谱草稿：",
            jianpuText,
            "",
            "播放节奏稿：",
            rhythmicJianpuText
        ].joined(separator: "\n")
    }
}

enum NanyinTemplateLibrary {
    static let jingYeSi = NanyinTemplateScore(
        name: "《静夜思》测试谱",
        sourceText: """
        工思六工六思六工乂工
        一思乂工六思工六思六
        六思一思一六思一工六
        工乂工六思六工六工乂
        工思六思工乂工乂六工
        一思一六思工六一思一
        """,
        symbolSourceText: """
        工○ 思、 六、 工- 六○ 思、 六- 工○ 乂、 工|
        一○ 思、 乂） 工√ 六、 思○ 工L 六、 思○ 六|
        六○ 思、 一、 思○ 一- 六、 思○ 一） 工√ 六|
        工○ 乂、 工√ 六○ 思、 六- 工○ 六、 工L 乂|
        工○ 思、 六、 思○ 工√ 乂、 工○ 乂） 六、 工|
        一○ 思、 一- 六○ 思、 工√ 六、 一○ 思、 一|
        厶 ∠ √ ） L ㄥ 口 十 │ ｜
        """
    )
}

enum JianpuParser {
    private static let scaleOffsets: [Int: Int] = [
        1: 0,
        2: 2,
        3: 4,
        4: 5,
        5: 7,
        6: 9,
        7: 11
    ]

    private static let nanyinTokenMap: [Character: String] = [
        "乂": "1",
        "ㄨ": "1",
        "义": "1",
        "又": "1",
        "×": "1",
        "X": "1",
        "尺": "1",
        "工": "2",
        "六": "3",
        "士": "5",
        "思": "5",
        "一": "6"
    ]

    static func isNanyinNotationCharacter(_ character: Character) -> Bool {
        nanyinTokenMap[character] != nil
    }

    static func jianpuToken(for character: Character) -> String? {
        nanyinTokenMap[character]
    }

    static func translateNanyin(from text: String) -> [NanyinTranslationEntry] {
        text.compactMap { character in
            guard let jianpu = nanyinTokenMap[character] else { return nil }
            return NanyinTranslationEntry(source: character, jianpu: jianpu)
        }
    }

    static func renderTranslationReport(from text: String, symbolSource: String? = nil, note: String? = nil) -> String {
        let entries = translateNanyin(from: text)
        guard !entries.isEmpty else {
            return "没有识别到可翻译的工ㄨ谱字。"
        }

        var lines: [String] = []
        lines.append("工ㄨ谱识别与翻译")
        if let note {
            lines.append(note)
        }
        lines.append("规则：乂/ㄨ → 1，工 → 2，六 → 3，思 → 5，一 → 6")
        lines.append("")
        lines.append("谱字序列：")
        lines.append(entries.map { String($0.source) }.joined(separator: " "))
        lines.append("")
        lines.append("简谱序列：")
        lines.append(entries.map(\.jianpu).joined(separator: " "))

        let rhythmicText = extractRhythmicJianpu(from: symbolSource ?? text, allowJianpuDigits: false)
        if !rhythmicText.isEmpty {
            lines.append("")
            lines.append("播放节奏稿：")
            lines.append(rhythmicText)
            lines.append("播放规则：○ 为强位，、/丶/厶/∠ 为弱位，- / │ / ｜ 延长前音。")
        }

        lines.append("")
        lines.append("逐字翻译：")

        for (index, entry) in entries.enumerated() {
            lines.append("\(index + 1). \(entry.source) → \(entry.jianpu)")
        }

        let symbolSummary = NanyinSymbolInterpreter.renderCompactSummary(from: symbolSource ?? text)
        if !symbolSummary.isEmpty {
            lines.append("")
            lines.append("符号摘要：")
            lines.append(contentsOf: symbolSummary)
        }

        return lines.joined(separator: "\n")
    }

    static func extractJianpu(from recognizedText: String, allowJianpuDigits: Bool = true) -> String {
        var tokens: [String] = []

        for character in recognizedText {
            if character.isWhitespace || character.isNewline {
                continue
            }

            if allowJianpuDigits, character.isJianpuDigit {
                tokens.append(String(character))
                continue
            }

            if let mapped = nanyinTokenMap[character] {
                tokens.append(mapped)
            }
        }

        return tokens.joined(separator: " ")
    }

    static func extractRhythmicJianpu(from recognizedText: String, allowJianpuDigits: Bool = true) -> String {
        let characters = Array(recognizedText)
        var tokens: [String] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]
            let mappedToken = nanyinTokenMap[character]
            let digitToken = allowJianpuDigits && character.isJianpuDigit ? String(character) : nil

            guard let baseToken = mappedToken ?? digitToken else {
                index += 1
                continue
            }

            var token = baseToken
            index += 1

            while index < characters.count {
                let modifier = characters[index]

                if modifier.isWhitespace || modifier.isNewline {
                    break
                }

                if nanyinTokenMap[modifier] != nil || modifier.isJianpuDigit {
                    break
                }

                if NanyinSymbolInterpreter.isPlaybackModifier(modifier) {
                    token.append(modifier)
                }

                index += 1
            }

            tokens.append(token)
        }

        return tokens.joined(separator: " ")
    }

    static func parse(_ text: String) -> [JianpuEvent] {
        let characters = Array(text)
        var events: [JianpuEvent] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if NanyinSymbolInterpreter.isExtensionMarker(character), let last = events.last {
                events[events.count - 1] = JianpuEvent(
                    midiNote: last.midiNote,
                    beats: last.beats + 1,
                    symbol: last.symbol + String(character),
                    accent: last.accent
                )
                index += 1
                continue
            }

            guard let digit = character.wholeNumberValue, (0...7).contains(digit) else {
                index += 1
                continue
            }

            var octaveShift = 0
            var beats = 1.0
            var symbol = String(character)
            var accent = 1.0
            var hasBeatMarker = false
            var hasFingerMarker = false
            index += 1

            while index < characters.count {
                let modifier = characters[index]

                if modifier == "'" || modifier == "’" || modifier == "˙" {
                    octaveShift += 12
                    symbol.append(modifier)
                    index += 1
                } else if modifier == "," || modifier == "，" || modifier == "̣" {
                    octaveShift -= 12
                    symbol.append(modifier)
                    index += 1
                } else if NanyinSymbolInterpreter.isStrongBeatMarker(modifier) {
                    hasBeatMarker = true
                    accent = max(accent, 1.24)
                    symbol.append(modifier)
                    index += 1
                } else if NanyinSymbolInterpreter.isWeakBeatMarker(modifier) {
                    hasBeatMarker = true
                    accent = min(accent, 0.92)
                    symbol.append(modifier)
                    index += 1
                } else if NanyinSymbolInterpreter.isFingerMarker(modifier) {
                    hasFingerMarker = true
                    symbol.append(modifier)
                    index += 1
                } else if modifier == "." {
                    beats += beats * 0.5
                    symbol.append(modifier)
                    index += 1
                } else if NanyinSymbolInterpreter.isExtensionMarker(modifier) {
                    beats += 1
                    symbol.append(modifier)
                    index += 1
                } else {
                    break
                }
            }

            if hasFingerMarker && !hasBeatMarker && beats == 1.0 {
                beats = 0.5
            }

            let midiNote: Int?
            if digit == 0 {
                midiNote = nil
            } else if let offset = scaleOffsets[digit] {
                midiNote = 60 + offset + octaveShift
            } else {
                midiNote = nil
            }

            events.append(JianpuEvent(midiNote: midiNote, beats: beats, symbol: symbol, accent: accent))
        }

        return events
    }
}

final class ScorePlaybackEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private let format: AVAudioFormat

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(events: [JianpuEvent], bpm: Double, completion: @escaping () -> Void) throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        if !engine.isRunning {
            try engine.start()
        }

        let beatSeconds = 60.0 / max(30.0, bpm)

        for (index, event) in events.enumerated() {
            let duration = max(0.08, beatSeconds * event.beats)
            let buffer = makeBuffer(for: event.midiNote, duration: duration, accent: event.accent)
            let isLast = index == events.indices.last

            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
                guard isLast else { return }
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        player.play()
    }

    func stop() {
        if player.isPlaying {
            player.stop()
        }
    }

    private func makeBuffer(for midiNote: Int?, duration: Double, accent: Double) -> AVAudioPCMBuffer {
        let frameCount = max(1, AVAudioFrameCount(duration * sampleRate))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0], let midiNote else {
            return buffer
        }

        let frequency = 440.0 * pow(2.0, (Double(midiNote) - 69.0) / 12.0)
        let totalFrames = Int(frameCount)
        let attackFrames = max(1, Int(sampleRate * 0.015))
        let releaseFrames = max(1, Int(sampleRate * 0.04))

        for frame in 0..<totalFrames {
            let time = Double(frame) / sampleRate
            let attack = min(1.0, Double(frame) / Double(attackFrames))
            let release = min(1.0, Double(totalFrames - frame) / Double(releaseFrames))
            let envelope = max(0.0, min(attack, release))
            let fundamental = sin(2.0 * .pi * frequency * time)
            let overtone = sin(2.0 * .pi * frequency * 2.0 * time) * 0.18
            let level = min(0.34, 0.22 * max(0.65, accent))
            channel[frame] = Float((fundamental + overtone) * level * envelope)
        }

        return buffer
    }
}

private extension Character {
    var isJianpuDigit: Bool {
        guard let value = wholeNumberValue else { return false }
        return (0...7).contains(value)
    }
}
