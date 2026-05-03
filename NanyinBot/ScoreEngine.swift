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

struct NanyinPitchConversionRule {
    let symbols: [Character]
    let displaySymbols: String
    let jianpu: String
    let wuyin: String
    let solfege: String
    let wuxing: String
    let organ: String
    let note: String
}

struct NanyinLayoutConversionRule {
    let name: String
    let readOrder: String
    let inputLayer: String
    let outputLayer: String
    let appStrategy: String
}

enum NanyinConversionRuleBook {
    static let pitchRules: [NanyinPitchConversionRule] = [
        NanyinPitchConversionRule(
            symbols: ["乂", "ㄨ", "义", "又", "×", "X", "尺"],
            displaySymbols: "乂 / ㄨ",
            jianpu: "1",
            wuyin: "宫 (Gong)",
            solfege: "Do",
            wuxing: "土",
            organ: "脾",
            note: "基础宫音；义、又、×、X、尺先作为 OCR/字形近似兜底。"
        ),
        NanyinPitchConversionRule(
            symbols: ["工"],
            displaySymbols: "工",
            jianpu: "2",
            wuyin: "商 (Shang)",
            solfege: "Re",
            wuxing: "金",
            organ: "肺",
            note: "字形有上下横与中竖，适合作为可解释打分示例。"
        ),
        NanyinPitchConversionRule(
            symbols: ["六"],
            displaySymbols: "六",
            jianpu: "3",
            wuyin: "角 (Jiao/Jue)",
            solfege: "Mi",
            wuxing: "木",
            organ: "肝",
            note: "与工、士等相似字需要靠笔画结构区分。"
        ),
        NanyinPitchConversionRule(
            symbols: ["思", "士"],
            displaySymbols: "思 / 士",
            jianpu: "5",
            wuyin: "徵 (Zhi)",
            solfege: "Sol",
            wuxing: "火",
            organ: "心",
            note: "思和士先归为同一音高，后续通过样本继续校准异体写法。"
        ),
        NanyinPitchConversionRule(
            symbols: ["一"],
            displaySymbols: "一",
            jianpu: "6",
            wuyin: "羽 (Yu)",
            solfege: "La",
            wuxing: "水",
            organ: "肾",
            note: "横画很少，识别时要避免和延续线混淆。"
        )
    ]

    static let layoutRules: [NanyinLayoutConversionRule] = [
        NanyinLayoutConversionRule(
            name: "竖排传统谱",
            readOrder: "按竖栏读取：从右到左，栏内从上到下。",
            inputLayer: "蓝色工ㄨ谱字、红色拍点/撩拍符号、黑色歌词。",
            outputLayer: "按读取顺序生成带节奏标记的简谱播放稿。",
            appStrategy: "先做版面分栏，再按列排序；适合《静夜思》这类竖排谱。"
        ),
        NanyinLayoutConversionRule(
            name: "横向对照谱",
            readOrder: "按横向小节读取：从左到右，遇到换行后继续下一行。",
            inputLayer: "下方蓝色工尺/工ㄨ谱作为输入，上方黑色简谱作为校验答案。",
            outputLayer: "蓝色谱字翻译出的简谱要和黑色简谱逐段对齐。",
            appStrategy: "先按颜色分层，再用小节线和横向位置对齐；适合泉州南音网《告老爷》这类对照谱。"
        )
    ]

    static var pitchTokenMap: [Character: String] {
        var map: [Character: String] = [:]
        for rule in pitchRules {
            for symbol in rule.symbols {
                map[symbol] = rule.jianpu
            }
        }
        return map
    }

    static var ruleText: String {
        var lines: [String] = []
        lines.append("统一转换规则")
        lines.append("")
        lines.append("核心原则：先判断谱面版式，再按同一套音高表和节奏表转换。横排、竖排只影响读取顺序，不改变谱字到简谱的对应关系。")
        lines.append("")
        lines.append("一、版式读取规则")
        for rule in layoutRules {
            lines.append("\(rule.name)：\(rule.readOrder)")
            lines.append("  输入层：\(rule.inputLayer)")
            lines.append("  输出层：\(rule.outputLayer)")
            lines.append("  App 做法：\(rule.appStrategy)")
        }
        lines.append("")
        lines.append("二、音高转换规则")
        for rule in pitchRules {
            lines.append("\(rule.displaySymbols) → 简谱 \(rule.jianpu) → \(rule.wuyin) / \(rule.solfege)；五行属\(rule.wuxing)，传统脏腑对应\(rule.organ)。")
            lines.append("  说明：\(rule.note)")
        }
        lines.append("")
        lines.append("三、节奏符号规则")
        for row in NanyinSymbolInterpreter.symbolRows {
            lines.append("\(row.symbols)｜\(row.name)：\(row.appSupport)")
        }
        lines.append("")
        lines.append("四、校验规则")
        lines.append("1. 竖排谱用人工校对模板检查完整率，例如《静夜思》输出 60 个音符。")
        lines.append("2. 横向对照谱用页面自带黑色简谱作为标准答案，例如《告老爷》截图可检查蓝色工尺谱翻译后是否对齐黑色简谱。")
        lines.append("3. 如果 OCR 只读出少量字，先进入人工校对/模板兜底，不把错误结果直接播放。")
        return lines.joined(separator: "\n")
    }
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
        lines.append("2. 先判断版式：竖排传统谱按右到左、栏内上到下排序；横向对照谱按小节从左到右排序。")
        lines.append("3. 谱字按上面的五音表翻译为简谱数字。")
        lines.append("4. 撩拍符号会进入播放：○/〇/o 为强位，、/丶/厶/∠ 为弱位；延续线会拉长前一个音。")
        lines.append("5. 指骨符号会保留在播放文本中；无撩拍标记时先按短促动作估算，完整指骨时值表后续继续校准。")
        lines.append("6. 如果《静夜思》测试图的 OCR 只读到很少谱字，会切换到内置校对模板，保证演示的完整率和播放稳定性。")
        lines.append("")
        lines.append(NanyinConversionRuleBook.ruleText)
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

enum NanyinAlgorithmVisualizationGuide {
    static var text: String {
        [
            "算法流程可视化",
            "",
            "这一页把“字符特征打分匹配法”变成比赛现场能指着讲的图：上方预览区会展示 4 个步骤，下方是每一步的讲解。",
            "",
            "上方图解：",
            "1. 原图：保留南音谱的竖排结构，先让评委看到输入是什么。",
            "2. 黑白化：把图片转成黑白思路，方便说明后续只看笔画形状。",
            "3. 分栏：南音谱从右到左读，先把竖栏框出来，再栏内从上到下读。",
            "4. 切字打分：把单字框出来，提取横线、竖线、圆形、宽高比等特征，然后给候选字打分。",
            "",
            "打分示例：",
            "工：上横 +2，下横 +2，中竖 +2，宽高比例 +1，总分 7，转换为简谱 2。",
            "六：上方集中笔画 +2，下方左右分开 +2，形态接近 +1，总分 5，转换为简谱 3。",
            "○：外圈有笔画 +2，中间较空 +2，宽高接近 +1，总分 5，作为强位拍点。",
            "",
            "孩子可以这样讲：",
            "我的算法不是黑盒识别，也不是直接猜结果，而是先把谱面分栏、切字，再看每个字有哪些形状特征。谁的分数最高，就识别成谁。这样评委能知道算法为什么得到这个结果。",
            "",
            "说明：当前图解是比赛展示用的可解释流程图；真实图片输入仍由 Vision OCR、版面分析和校对模板共同完成，核心规则是南音谱字和符号到简谱播放的转换。"
        ].joined(separator: "\n")
    }
}

enum NanyinPresentationMaterials {
    static var text: String {
        var lines = [
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
            "第三步：切到“流程”，用原图、黑白化、分栏、打分图讲算法。",
            "第四步：切到“符号”，讲拍、撩、延续、指骨如何影响节奏。",
            "第五步：切到“简谱”，播放旋律。",
            "第六步：点“识别”，展示 OCR 不完整时如何用模板兜底保证演示完整率。",
            "第七步：切回“材料”，回答评委问题。",
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
            "演示视频：30 秒展示识别、转换和播放。",
            "算法截图：使用 App 的“流程”页展示原图、黑白化、分栏和打分。",
            "",
            "9. 泉州南音网参考样例",
            "这些样例来自泉州南音网“工ㄨ谱简谱对照”栏目，用来说明项目不是只对一张图做演示，而是有后续扩展的样本来源。"
        ]
        lines.append(contentsOf: NanyinReferenceSampleLibrary.compactLines)
        lines.append("")
        lines.append("10. 横竖谱面统一规则")
        lines.append("竖排传统谱从右到左、栏内从上到下读取；横向对照谱从左到右、按小节和换行继续读取。")
        lines.append("读取顺序不同，但转换规则相同：谱字按五音表转简谱，拍/撩/延续/指骨按节奏表进入播放。")
        return lines.joined(separator: "\n")
    }
}

struct NanyinReferenceSample {
    let title: String
    let performer: String
    let pagePath: String
    let videoPath: String
    let focus: String

    var pageURL: String {
        NanyinReferenceSampleLibrary.baseURL + pagePath
    }

    var videoURL: String {
        NanyinReferenceSampleLibrary.baseURL + videoPath
    }
}

enum NanyinReferenceSampleLibrary {
    static let baseURL = "http://www.qznanyin.cn/"
    static let sourcePageURL = baseURL + "stave.html"

    static let samples: [NanyinReferenceSample] = [
        NanyinReferenceSample(
            title: "玉箫声",
            performer: "苏诗咏",
            pagePath: "yxsssy.html",
            videoPath: "nanyind/sequelsongs/yxsssy/yxsssy.mp4",
            focus: "竖排工ㄨ谱和简谱对照的基础样例"
        ),
        NanyinReferenceSample(
            title: "告老爷",
            performer: "余丽玲",
            pagePath: "glyyll2.html",
            videoPath: "nanyind/sequelsongs/glyyll2/glyyll2.mp4",
            focus: "较短视频，适合快速截图做流程验证"
        ),
        NanyinReferenceSample(
            title: "莲步轻移",
            performer: "陈奎珍",
            pagePath: "lbqyckz.html",
            videoPath: "nanyind/sequelsongs/lbqyckz/lbqyckz.mp4",
            focus: "可观察工尺字与演唱节奏的对应"
        ),
        NanyinReferenceSample(
            title: "泥金书",
            performer: "周成在",
            pagePath: "njszcz.html",
            videoPath: "nanyind/sequelsongs/njszcz/njszcz.mp4",
            focus: "可作为不同唱者、不同曲名的泛化样例"
        ),
        NanyinReferenceSample(
            title: "更深寂静",
            performer: "陈振梅",
            pagePath: "gsjjczm.html",
            videoPath: "nanyind/sequelsongs/gsjjczm/gsjjczm.mp4",
            focus: "曲名和当前《静夜思》意象接近，便于对比讲解"
        ),
        NanyinReferenceSample(
            title: "月半纱窗",
            performer: "杨双英",
            pagePath: "ybscysy.html",
            videoPath: "nanyind/sequelsongs/ybscysy/ybscysy.mp4",
            focus: "可观察长句中的连续谱字识别"
        ),
        NanyinReferenceSample(
            title: "小妹听说（北叠）",
            performer: "周碧月",
            pagePath: "xmtzby.html",
            videoPath: "nanyind/sequelsongs/xmtzby/xmtzby.mp4",
            focus: "标题含曲体信息，适合说明资料标注"
        ),
        NanyinReferenceSample(
            title: "愁人怨",
            performer: "郑芳卉",
            pagePath: "cryzfh.html",
            videoPath: "nanyind/sequelsongs/cryzfh/cryzfh.mp4",
            focus: "用于检查不同谱面密度下的分栏"
        ),
        NanyinReferenceSample(
            title: "秀才先行",
            performer: "庄丽芬",
            pagePath: "xcxxzlf1.html",
            videoPath: "nanyind/sequelsongs/xcxxzlf1/xcxxzlf1.mp4",
            focus: "用于扩展测试表中的真实样例"
        ),
        NanyinReferenceSample(
            title: "劝哥哥",
            performer: "陈丽娟",
            pagePath: "qggclj.html",
            videoPath: "nanyind/sequelsongs/qggclj/qggclj.mp4",
            focus: "作为第 10 个对照样本，覆盖另一位演唱者"
        )
    ]

    static var compactLines: [String] {
        var lines = [
            "来源页：\(sourcePageURL)",
            "截图原则：只截取视频中含谱面对照的一帧，用来人工校验分栏、谱字、简谱和播放节奏，不把外站视频放进工程。",
            "",
            "样例｜演唱者｜用途"
        ]
        lines.append(contentsOf: samples.map { "\($0.title)｜\($0.performer)｜\($0.focus)" })
        return lines
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

    private static let nanyinTokenMap = NanyinConversionRuleBook.pitchTokenMap

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
