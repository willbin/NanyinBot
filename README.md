# NanyinBot

南音识谱是一个 iOS/iPadOS 演示应用，用于把南音工乂谱转换成可读的简谱，并按拍、撩、延续等符号播放旋律。

## 项目定位

本项目面向信息科技比赛展示，重点不是做通用 OCR，也不是做南音百科，而是聚焦一个具体问题：年轻人看不懂南音工乂谱。

核心闭环：

```text
谱图输入 -> 工乂谱识别 -> 简谱翻译 -> 符号节奏解释 -> 旋律播放
```

## 当前能力

- iPhone/iPad 拍照或从相册选择谱图。
- 使用 Apple Vision 进行文字识别。
- 对《静夜思》演示谱提供校对模板兜底，保证现场展示完整率。
- 支持基础工乂谱到简谱转换。
- 支持拍、撩、延续、南琶指骨等符号说明。
- 使用 AVFoundation 进行简谱旋律播放。
- App 内置“算法”和“材料”入口，方便 iPad 现场答辩。

## 算法表达

项目使用适合初中生讲清楚的“南音工乂谱字符特征打分匹配法”：

1. 图像预处理。
2. 竖排谱面分栏。
3. 字符切分。
4. 字符特征提取。
5. 打分匹配。
6. 简谱和节奏转换。

## 运行环境

- Xcode 17+
- iOS 16+
- Swift 5

## 测试

```bash
xcodebuild test \
  -project NanyinBot.xcodeproj \
  -scheme NanyinBot \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:NanyinBotTests
```

## 目录

- `NanyinBot/`：App 源码。
- `NanyinBotTests/`：单元测试。
- `docs/nanyin_competition_plan.md`：比赛计划。
- `docs/nanyin_presentation_materials.md`：展示材料。
