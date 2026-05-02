//
//  ViewController.swift
//  NanyinBot
//
//  Created by Will Wei on 2026/5/2.
//

import AVFoundation
import CoreImage
import ImageIO
import UIKit
import Vision

final class ViewController: UIViewController {

    private let playback = ScorePlaybackEngine()
    private let ocrQueue = DispatchQueue(label: "com.wecomic.NanyinBot.ocr", qos: .userInitiated)
    private static let ciContext = CIContext()

    private var selectedImage: UIImage?
    private var scoreText = "1○ 2、 3- 5√ 6○ 5、 3 2 1- 0 1' 6 5 3 2 1"
    private var translationText = "点击“模板”会加载《静夜思》测试谱，并显示工ㄨ谱字到简谱的逐字翻译。"
    private var symbolText = "点击“模板”会加载《静夜思》测试谱，并显示撩拍、指骨和延续符号的用途。"
    private var algorithmText = NanyinAlgorithmGuide.text
    private var visualizationText = NanyinAlgorithmVisualizationGuide.text
    private var materialsText = NanyinPresentationMaterials.text
    private var ocrText = ""
    private var structuredText = "点击“模板”会加载《静夜思》测试谱，并显示栏位、歌词、蓝色谱字、红色拍点和简谱草稿。"
    private var isUpdatingEditor = false

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()
    private let actionsStack = UIStackView()
    private let previewContainer = UIView()
    private let editorHeader = UIStackView()
    private let playbackStack = UIStackView()
    private let imageView = UIImageView()
    private let placeholderLabel = UILabel()
    private let statusLabel = UILabel()
    private let editorMode = UISegmentedControl(items: ["简谱", "翻译", "符号", "算法", "流程", "材料", "结构", "OCR", "说明"])
    private let editorTextView = UITextView()
    private let tempoSlider = UISlider()
    private let tempoLabel = UILabel()
    private let metricsLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let recognizeButton = UIButton(type: .system)
    private var mainStackLeadingConstraint: NSLayoutConstraint?
    private var mainStackTrailingConstraint: NSLayoutConstraint?
    private var mainStackFluidWidthConstraint: NSLayoutConstraint?
    private var mainStackMaxWidthConstraint: NSLayoutConstraint?
    private var previewHeightConstraint: NSLayoutConstraint?
    private var editorHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureKeyboardObservers()
        loadDemoTemplate(runRecognition: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyAdaptiveLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass else { return }
        applyAdaptiveLayout()
    }

    private func configureView() {
        title = "南音识谱"
        view.backgroundColor = NanyinStyle.background

        scrollView.keyboardDismissMode = .interactive
        scrollView.backgroundColor = NanyinStyle.background
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "南音识谱"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = NanyinStyle.ink

        let subtitleLabel = UILabel()
        subtitleLabel.text = "泉州南音 · 工ㄨ谱 · 简谱 · 播放"
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = NanyinStyle.mutedInk

        let captureButton = makeActionButton(title: "拍照", image: "camera.fill", style: .filled)
        captureButton.addTarget(self, action: #selector(captureScoreImage(_:)), for: .touchUpInside)

        let libraryButton = makeActionButton(title: "相册", image: "photo.on.rectangle.angled", style: .tinted)
        libraryButton.addTarget(self, action: #selector(importScoreImage(_:)), for: .touchUpInside)

        recognizeButton.configuration = actionConfiguration(title: "识别", image: "text.viewfinder", style: .tinted)
        recognizeButton.addTarget(self, action: #selector(recognizeCurrentImage), for: .touchUpInside)

        let sampleButton = makeActionButton(title: "演示谱", image: "doc.viewfinder", style: .tinted)
        sampleButton.addTarget(self, action: #selector(loadTemplateScore), for: .touchUpInside)

        actionsStack.addArrangedSubview(captureButton)
        actionsStack.addArrangedSubview(libraryButton)
        actionsStack.addArrangedSubview(recognizeButton)
        actionsStack.addArrangedSubview(sampleButton)
        actionsStack.axis = .horizontal
        actionsStack.alignment = .fill
        actionsStack.distribution = .fillEqually
        actionsStack.spacing = 10

        previewContainer.backgroundColor = NanyinStyle.paper
        previewContainer.layer.cornerRadius = 8
        previewContainer.layer.borderWidth = 1
        previewContainer.layer.borderColor = NanyinStyle.hairline.cgColor
        previewContainer.translatesAutoresizingMaskIntoConstraints = false

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.text = "等待谱图"
        placeholderLabel.font = .preferredFont(forTextStyle: .headline)
        placeholderLabel.textColor = NanyinStyle.faintInk
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        previewContainer.addSubview(imageView)
        previewContainer.addSubview(placeholderLabel)

        previewHeightConstraint = previewContainer.heightAnchor.constraint(equalToConstant: 220)

        NSLayoutConstraint.activate([
            previewHeightConstraint!,
            imageView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -10),
            imageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -10),
            placeholderLabel.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor)
        ])

        statusLabel.text = "已载入示例简谱"
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = NanyinStyle.mutedInk
        statusLabel.numberOfLines = 0

        editorMode.selectedSegmentIndex = 0
        editorMode.addTarget(self, action: #selector(editorModeChanged), for: .valueChanged)
        editorMode.backgroundColor = NanyinStyle.controlBackground
        editorMode.selectedSegmentTintColor = NanyinStyle.paper
        editorMode.setTitleTextAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .footnote), .foregroundColor: NanyinStyle.mutedInk],
            for: .normal
        )
        editorMode.setTitleTextAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .footnote), .foregroundColor: NanyinStyle.cinnabar],
            for: .selected
        )

        editorTextView.delegate = self
        editorTextView.font = .monospacedSystemFont(ofSize: 22, weight: .regular)
        editorTextView.adjustsFontForContentSizeCategory = true
        editorTextView.backgroundColor = NanyinStyle.paper
        editorTextView.textColor = NanyinStyle.ink
        editorTextView.layer.cornerRadius = 8
        editorTextView.layer.borderWidth = 1
        editorTextView.layer.borderColor = NanyinStyle.hairline.cgColor
        editorTextView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        editorTextView.autocorrectionType = .no
        editorTextView.autocapitalizationType = .none
        editorTextView.smartQuotesType = .no
        editorTextView.smartDashesType = .no
        editorTextView.translatesAutoresizingMaskIntoConstraints = false

        playButton.configuration = actionConfiguration(title: "播放", image: "play.fill", style: .filled)
        playButton.addTarget(self, action: #selector(playScore), for: .touchUpInside)

        stopButton.configuration = actionConfiguration(title: "停止", image: "stop.fill", style: .tinted)
        stopButton.addTarget(self, action: #selector(stopScore), for: .touchUpInside)

        playbackStack.addArrangedSubview(playButton)
        playbackStack.addArrangedSubview(stopButton)
        playbackStack.axis = .horizontal
        playbackStack.spacing = 10
        playbackStack.distribution = .fillEqually

        tempoSlider.minimumValue = 48
        tempoSlider.maximumValue = 132
        tempoSlider.value = 72
        tempoSlider.addTarget(self, action: #selector(tempoChanged), for: .valueChanged)

        tempoLabel.font = .preferredFont(forTextStyle: .subheadline)
        tempoLabel.adjustsFontForContentSizeCategory = true
        tempoLabel.textColor = NanyinStyle.mutedInk

        metricsLabel.font = .preferredFont(forTextStyle: .footnote)
        metricsLabel.adjustsFontForContentSizeCategory = true
        metricsLabel.textColor = NanyinStyle.mutedInk
        metricsLabel.numberOfLines = 0

        editorHeader.addArrangedSubview(editorMode)
        editorHeader.addArrangedSubview(metricsLabel)
        editorHeader.axis = .vertical
        editorHeader.spacing = 8

        mainStack.addArrangedSubview(titleLabel)
        mainStack.addArrangedSubview(subtitleLabel)
        mainStack.addArrangedSubview(actionsStack)
        mainStack.addArrangedSubview(previewContainer)
        mainStack.addArrangedSubview(statusLabel)
        mainStack.addArrangedSubview(editorHeader)
        mainStack.addArrangedSubview(editorTextView)
        mainStack.addArrangedSubview(playbackStack)
        mainStack.addArrangedSubview(tempoLabel)
        mainStack.addArrangedSubview(tempoSlider)
        mainStack.axis = .vertical
        mainStack.spacing = 14
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        mainStackLeadingConstraint = mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 18)
        mainStackTrailingConstraint = mainStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -18)
        mainStackFluidWidthConstraint = mainStack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -36)
        mainStackFluidWidthConstraint?.priority = .defaultHigh
        mainStackMaxWidthConstraint = mainStack.widthAnchor.constraint(lessThanOrEqualToConstant: 980)
        editorHeightConstraint = editorTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 210)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            mainStackLeadingConstraint!,
            mainStackTrailingConstraint!,
            mainStackFluidWidthConstraint!,
            mainStackMaxWidthConstraint!,
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -26),
            editorHeightConstraint!
        ])

        updateTempoLabel()
        applyAdaptiveLayout()
    }

    private func makeActionButton(title: String, image: String, style: ButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = actionConfiguration(title: title, image: image, style: style)
        return button
    }

    private func actionConfiguration(title: String, image: String, style: ButtonStyle) -> UIButton.Configuration {
        var configuration: UIButton.Configuration
        switch style {
        case .filled:
            configuration = .filled()
            configuration.baseBackgroundColor = NanyinStyle.cinnabar
            configuration.baseForegroundColor = .white
        case .tinted:
            configuration = .tinted()
            configuration.baseForegroundColor = NanyinStyle.jade
            configuration.baseBackgroundColor = NanyinStyle.jade.withAlphaComponent(0.12)
        case .plain:
            configuration = .plain()
            configuration.baseForegroundColor = NanyinStyle.jade
        }
        configuration.title = title
        configuration.image = UIImage(systemName: image)
        configuration.imagePlacement = .top
        configuration.imagePadding = 5
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
        return configuration
    }

    private func configureKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func applyAdaptiveLayout() {
        let regularWidth = view.bounds.width >= 700 || traitCollection.horizontalSizeClass == .regular
        let horizontalMargin: CGFloat = regularWidth ? 32 : 18

        mainStackLeadingConstraint?.constant = horizontalMargin
        mainStackTrailingConstraint?.constant = -horizontalMargin
        mainStackFluidWidthConstraint?.constant = -(horizontalMargin * 2)
        mainStackMaxWidthConstraint?.constant = regularWidth ? 980 : 640
        previewHeightConstraint?.constant = regularWidth ? 320 : 220
        editorHeightConstraint?.constant = regularWidth ? 360 : 210

        mainStack.spacing = regularWidth ? 18 : 14
        actionsStack.spacing = regularWidth ? 12 : 10
        playbackStack.spacing = regularWidth ? 12 : 10
        editorHeader.axis = regularWidth ? .horizontal : .vertical
        editorHeader.alignment = regularWidth ? .center : .fill
        editorHeader.spacing = regularWidth ? 12 : 8
        metricsLabel.numberOfLines = regularWidth ? 1 : 0

        editorMode.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        metricsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @objc private func captureScoreImage(_ sender: UIButton) {
        presentImagePicker(
            sourceType: UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary,
            from: sender
        )
    }

    @objc private func importScoreImage(_ sender: UIButton) {
        presentImagePicker(sourceType: .photoLibrary, from: sender)
    }

    private func presentImagePicker(sourceType: UIImagePickerController.SourceType, from sourceView: UIView) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        picker.sourceType = sourceType

        if sourceType == .photoLibrary {
            picker.modalPresentationStyle = .formSheet
            picker.popoverPresentationController?.sourceView = sourceView
            picker.popoverPresentationController?.sourceRect = sourceView.bounds
        } else {
            picker.modalPresentationStyle = .fullScreen
        }

        present(picker, animated: true)
    }

    @objc private func recognizeCurrentImage() {
        guard let selectedImage else {
            updateStatus("请先拍照或导入谱图", isError: true)
            return
        }
        let normalizedImage = selectedImage.normalizedForAnalysis()
        guard let cgImage = normalizedImage.cgImage else {
            updateStatus("图片格式暂时无法识别", isError: true)
            return
        }

        view.endEditing(true)
        recognizeButton.isEnabled = false
        updateStatus("正在识别谱面…", isError: false)

        ocrQueue.async { [weak self] in
            let request = VNRecognizeTextRequest { request, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.recognizeButton.isEnabled = true
                        self.updateStatus("识别失败：\(error.localizedDescription)", isError: true)
                    }
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let analysis = ScorePageAnalyzer.analyze(observations: observations, image: cgImage)

                DispatchQueue.main.async {
                    self.recognizeButton.isEnabled = true
                    self.ocrText = analysis.rawText
                    self.structuredText = analysis.structuredText
                    self.translationText = analysis.translationText
                    self.symbolText = analysis.symbolText
                    if analysis.templateName != nil {
                        self.algorithmText = NanyinTemplateLibrary.jingYeSi.algorithmText
                    } else {
                        self.algorithmText = NanyinAlgorithmGuide.renderDemoReport(
                            title: "当前识别结果算法演示",
                            sourceText: analysis.rawText.isEmpty ? analysis.jianpuDraft : analysis.rawText,
                            rhythmicText: analysis.jianpuDraft
                        )
                    }
                    if analysis.jianpuDraft.isEmpty {
                        self.editorMode.selectedSegmentIndex = 6
                        self.showStructureEditor()
                        self.updateStatus("已识别图片，但没有找到可转换的谱字", isError: true)
                    } else {
                        self.scoreText = analysis.jianpuDraft
                        self.editorMode.selectedSegmentIndex = 3
                        self.showAlgorithmEditor()
                        if let templateName = analysis.templateName {
                            self.updateStatus("OCR 谱字过少，已套用\(templateName)校对结果", isError: false)
                        } else {
                            self.updateStatus(
                                "已按竖排谱面生成简谱草稿：\(analysis.columnCount) 栏，谱字 \(analysis.notationCount)，拍点 \(analysis.beatCount)",
                                isError: false
                            )
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    self.updatePlaybackMetrics()
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.customWords = ["乂", "ㄨ", "工", "六", "思", "一", "静夜思", "床", "前", "明", "月", "光"]
            request.minimumTextHeight = 0.004

            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self?.recognizeButton.isEnabled = true
                    self?.updateStatus("识别失败：\(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    @objc private func loadTemplateScore() {
        loadDemoTemplate(runRecognition: false)
    }

    private func loadDemoTemplate(runRecognition: Bool) {
        playback.stop()
        guard let image = UIImage(named: "JingYeSiTemplate") else {
            updateStatus("模板图未找到", isError: true)
            return
        }

        selectedImage = image
        imageView.image = image
        placeholderLabel.isHidden = true
        ocrText = ""
        let template = NanyinTemplateLibrary.jingYeSi
        scoreText = template.rhythmicJianpuText
        translationText = template.translationText
        symbolText = template.symbolText
        algorithmText = template.algorithmText
        visualizationText = NanyinAlgorithmVisualizationGuide.text
        materialsText = NanyinPresentationMaterials.text
        structuredText = template.structureText
        editorMode.selectedSegmentIndex = 3
        showAlgorithmEditor()
        updatePlaybackMetrics()
        updateStatus("已载入《静夜思》演示谱；可直接播放，也可切到“材料”查看答辩目录", isError: false)

        if runRecognition {
            recognizeCurrentImage()
        }
    }

    @objc private func editorModeChanged() {
        if editorMode.selectedSegmentIndex == 0 {
            showScoreEditor()
        } else if editorMode.selectedSegmentIndex == 1 {
            showTranslationEditor()
        } else if editorMode.selectedSegmentIndex == 2 {
            showSymbolEditor()
        } else if editorMode.selectedSegmentIndex == 3 {
            showAlgorithmEditor()
        } else if editorMode.selectedSegmentIndex == 4 {
            showVisualizationEditor()
        } else if editorMode.selectedSegmentIndex == 5 {
            showMaterialsEditor()
        } else if editorMode.selectedSegmentIndex == 6 {
            showStructureEditor()
        } else if editorMode.selectedSegmentIndex == 7 {
            showOCREditor()
        } else {
            showGuideEditor()
        }
    }

    @objc private func playScore() {
        view.endEditing(true)
        let events = JianpuParser.parse(scoreText)
        guard !events.isEmpty else {
            updateStatus("简谱里还没有可播放的音符", isError: true)
            return
        }

        do {
            try playback.play(events: events, bpm: Double(tempoSlider.value)) { [weak self] in
                self?.playButton.isEnabled = true
                self?.updateStatus("播放完成", isError: false)
            }
            playButton.isEnabled = false
            updateStatus("正在按符号节奏播放", isError: false)
        } catch {
            playButton.isEnabled = true
            updateStatus("播放失败：\(error.localizedDescription)", isError: true)
        }
    }

    @objc private func stopScore() {
        playback.stop()
        playButton.isEnabled = true
        updateStatus("已停止", isError: false)
    }

    @objc private func tempoChanged() {
        updateTempoLabel()
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        let keyboardInView = view.convert(keyboardFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardInView.minY)
        scrollView.contentInset.bottom = overlap + 16
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }

    @objc private func keyboardWillHide() {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    private func showScoreEditor() {
        restoreScorePreview()
        isUpdatingEditor = true
        editorTextView.text = scoreText
        editorTextView.font = .monospacedSystemFont(ofSize: 22, weight: .regular)
        editorTextView.isEditable = true
        isUpdatingEditor = false
    }

    private func showTranslationEditor() {
        restoreScorePreview()
        isUpdatingEditor = true
        editorTextView.text = translationText
        editorTextView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        editorTextView.isEditable = false
        isUpdatingEditor = false
    }

    private func showSymbolEditor() {
        restoreScorePreview()
        isUpdatingEditor = true
        editorTextView.text = symbolText
        editorTextView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        editorTextView.isEditable = false
        isUpdatingEditor = false
    }

    private func showAlgorithmEditor() {
        restoreScorePreview()
        isUpdatingEditor = true
        editorTextView.text = algorithmText
        editorTextView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        editorTextView.isEditable = false
        isUpdatingEditor = false
    }

    private func showVisualizationEditor() {
        if let selectedImage {
            imageView.image = makeAlgorithmVisualizationImage(from: selectedImage)
            placeholderLabel.isHidden = true
        }
        isUpdatingEditor = true
        editorTextView.text = visualizationText
        editorTextView.font = .preferredFont(forTextStyle: .body)
        editorTextView.isEditable = false
        isUpdatingEditor = false
    }

    private func showMaterialsEditor() {
        restoreScorePreview()
        isUpdatingEditor = true
        editorTextView.text = materialsText
        editorTextView.font = .preferredFont(forTextStyle: .body)
        editorTextView.isEditable = false
        isUpdatingEditor = false
    }

    private func showStructureEditor() {
        restoreScorePreview()
        isUpdatingEditor = true
        editorTextView.text = structuredText
        editorTextView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        editorTextView.isEditable = false
        isUpdatingEditor = false
    }

    private func showOCREditor() {
        restoreScorePreview()
        isUpdatingEditor = true
        editorTextView.text = ocrText
        editorTextView.font = .preferredFont(forTextStyle: .body)
        editorTextView.isEditable = false
        isUpdatingEditor = false
    }

    private func showGuideEditor() {
        restoreScorePreview()
        isUpdatingEditor = true
        editorTextView.text = NanyinKnowledgeGuide.text
        editorTextView.font = .preferredFont(forTextStyle: .body)
        editorTextView.isEditable = false
        isUpdatingEditor = false
    }

    private func makeAlgorithmVisualizationImage(from sourceImage: UIImage) -> UIImage {
        let canvasSize = CGSize(width: 1600, height: 820)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            let cgContext = context.cgContext
            NanyinStyle.background.setFill()
            cgContext.fill(CGRect(origin: .zero, size: canvasSize))

            drawText(
                "南音工ㄨ谱识别流程",
                in: CGRect(x: 48, y: 32, width: 900, height: 52),
                font: .boldSystemFont(ofSize: 36),
                color: NanyinStyle.ink
            )
            drawText(
                "原图 → 黑白化 → 竖排分栏 → 单字特征打分",
                in: CGRect(x: 48, y: 82, width: 980, height: 38),
                font: .systemFont(ofSize: 24, weight: .medium),
                color: NanyinStyle.mutedInk
            )

            let topY: CGFloat = 146
            let gap: CGFloat = 28
            let panelWidth = (canvasSize.width - 96 - gap * 3) / 4
            let panelHeight: CGFloat = 560
            let panels = (0..<4).map { index in
                CGRect(
                    x: 48 + CGFloat(index) * (panelWidth + gap),
                    y: topY,
                    width: panelWidth,
                    height: panelHeight
                )
            }

            drawAlgorithmPanel(title: "1 原图", frame: panels[0], context: cgContext) { rect in
                drawImage(sourceImage, in: rect)
            }

            drawAlgorithmPanel(title: "2 黑白化", frame: panels[1], context: cgContext) { rect in
                drawImage(makeMonochromeImage(from: sourceImage) ?? sourceImage, in: rect)
                drawText(
                    "只保留笔画形状",
                    in: CGRect(x: rect.minX, y: rect.maxY - 34, width: rect.width, height: 28),
                    font: .systemFont(ofSize: 18, weight: .medium),
                    color: NanyinStyle.ink,
                    alignment: .center
                )
            }

            drawAlgorithmPanel(title: "3 竖排分栏", frame: panels[2], context: cgContext) { rect in
                drawImage(sourceImage, in: rect)
                drawColumnOverlay(in: rect, context: cgContext)
            }

            drawAlgorithmPanel(title: "4 单字打分", frame: panels[3], context: cgContext) { rect in
                drawScoringExample(in: rect, context: cgContext)
            }

            drawText(
                "答辩讲法：不是黑盒识别，而是把谱面分栏、把字切出、看横竖圆等特征，再用分数说明为什么识别成这个谱字。",
                in: CGRect(x: 48, y: 730, width: canvasSize.width - 96, height: 54),
                font: .systemFont(ofSize: 23, weight: .medium),
                color: NanyinStyle.ink
            )
        }
    }

    private func drawAlgorithmPanel(
        title: String,
        frame: CGRect,
        context: CGContext,
        content: (CGRect) -> Void
    ) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 3), blur: 12, color: UIColor.black.withAlphaComponent(0.08).cgColor)
        NanyinStyle.paper.setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 8).fill()
        context.restoreGState()

        NanyinStyle.hairline.setStroke()
        let borderPath = UIBezierPath(roundedRect: frame, cornerRadius: 8)
        borderPath.lineWidth = 1
        borderPath.stroke()

        drawText(
            title,
            in: CGRect(x: frame.minX + 18, y: frame.minY + 18, width: frame.width - 36, height: 30),
            font: .boldSystemFont(ofSize: 22),
            color: NanyinStyle.cinnabar
        )
        content(frame.insetBy(dx: 18, dy: 60))
    }

    private func drawImage(_ image: UIImage, in rect: CGRect) {
        let fitRect = aspectFitRect(for: image.size, in: rect)
        image.draw(in: fitRect)
    }

    private func makeMonochromeImage(from image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        let output = input
            .applyingFilter("CIPhotoEffectNoir")
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.45,
                kCIInputBrightnessKey: 0.05
            ])

        guard let cgImage = Self.ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func drawColumnOverlay(in rect: CGRect, context: CGContext) {
        let columnCount = 7
        let gap: CGFloat = 7
        let columnWidth = (rect.width - CGFloat(columnCount - 1) * gap) / CGFloat(columnCount)
        for index in 0..<columnCount {
            let x = rect.maxX - CGFloat(index + 1) * columnWidth - CGFloat(index) * gap
            let columnRect = CGRect(x: x, y: rect.minY + 18, width: columnWidth, height: rect.height - 64)
            let path = UIBezierPath(roundedRect: columnRect, cornerRadius: 4)
            (index == 0 ? NanyinStyle.cinnabar : NanyinStyle.jade).withAlphaComponent(0.88).setStroke()
            path.lineWidth = index == 0 ? 3 : 2
            path.stroke()
        }

        drawText(
            "读取方向：右 → 左",
            in: CGRect(x: rect.minX, y: rect.maxY - 36, width: rect.width, height: 28),
            font: .systemFont(ofSize: 18, weight: .medium),
            color: NanyinStyle.ink,
            alignment: .center
        )
    }

    private func drawScoringExample(in rect: CGRect, context: CGContext) {
        let characterRect = CGRect(x: rect.minX + 18, y: rect.minY + 18, width: 118, height: 150)
        NanyinStyle.background.setFill()
        UIBezierPath(roundedRect: characterRect, cornerRadius: 8).fill()
        NanyinStyle.hairline.setStroke()
        UIBezierPath(roundedRect: characterRect, cornerRadius: 8).stroke()

        drawText(
            "工",
            in: characterRect.insetBy(dx: 10, dy: 10),
            font: .systemFont(ofSize: 86, weight: .regular),
            color: NanyinStyle.ink,
            alignment: .center
        )

        let featureLines = [
            "上横 +2",
            "下横 +2",
            "中竖 +2",
            "比例 +1"
        ]

        for (index, line) in featureLines.enumerated() {
            drawText(
                line,
                in: CGRect(x: rect.minX + 160, y: rect.minY + 28 + CGFloat(index) * 34, width: rect.width - 178, height: 28),
                font: .systemFont(ofSize: 20, weight: .medium),
                color: NanyinStyle.ink
            )
        }

        let tableTop = rect.minY + 210
        let rows = [
            ("候选", "分数"),
            ("工", "7"),
            ("六", "3"),
            ("一", "2")
        ]

        for (index, row) in rows.enumerated() {
            let rowRect = CGRect(x: rect.minX + 18, y: tableTop + CGFloat(index) * 46, width: rect.width - 36, height: 44)
            (index == 1 ? NanyinStyle.cinnabar.withAlphaComponent(0.10) : UIColor.clear).setFill()
            UIBezierPath(roundedRect: rowRect, cornerRadius: 5).fill()
            NanyinStyle.hairline.setStroke()
            UIBezierPath(roundedRect: rowRect, cornerRadius: 5).stroke()

            drawText(
                row.0,
                in: CGRect(x: rowRect.minX + 14, y: rowRect.minY + 8, width: rowRect.width / 2, height: 28),
                font: .systemFont(ofSize: 20, weight: index == 0 ? .semibold : .regular),
                color: index == 1 ? NanyinStyle.cinnabar : NanyinStyle.ink
            )
            drawText(
                row.1,
                in: CGRect(x: rowRect.midX, y: rowRect.minY + 8, width: rowRect.width / 2 - 14, height: 28),
                font: .systemFont(ofSize: 20, weight: index == 1 ? .bold : .regular),
                color: index == 1 ? NanyinStyle.cinnabar : NanyinStyle.ink,
                alignment: .right
            )
        }

        drawText(
            "最高分：工 → 简谱 2",
            in: CGRect(x: rect.minX, y: rect.maxY - 42, width: rect.width, height: 32),
            font: .systemFont(ofSize: 20, weight: .bold),
            color: NanyinStyle.jade,
            alignment: .center
        )
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func updateStatus(_ text: String, isError: Bool) {
        statusLabel.text = text
        statusLabel.textColor = isError ? NanyinStyle.cinnabar : NanyinStyle.mutedInk
    }

    private func restoreScorePreview() {
        guard let selectedImage else { return }
        imageView.image = selectedImage
        placeholderLabel.isHidden = true
    }

    private func updateTempoLabel() {
        tempoLabel.text = "速度 \(Int(tempoSlider.value.rounded())) BPM · 1 拍/撩为一单位"
    }

    private func updatePlaybackMetrics() {
        let events = JianpuParser.parse(scoreText)
        let noteCount = events.filter { $0.midiNote != nil }.count
        let totalBeats = events.reduce(0.0) { $0 + $1.beats }
        metricsLabel.text = "\(noteCount) 个音符 · \(events.count) 个事件 · \(Self.formatBeats(totalBeats)) 拍"
    }

    private static func formatBeats(_ beats: Double) -> String {
        if beats.rounded() == beats {
            return String(Int(beats))
        }
        return String(format: "%.1f", beats)
    }

    private static func text(from observations: [VNRecognizedTextObservation]) -> String {
        let lines = observations.compactMap { observation -> RecognizedLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedLine(text: candidate.string, box: observation.boundingBox)
        }
        .sorted { lhs, rhs in
            if abs(lhs.box.midY - rhs.box.midY) > 0.025 {
                return lhs.box.midY > rhs.box.midY
            }
            return lhs.box.minX < rhs.box.minX
        }

        return lines.map(\.text).joined(separator: "\n")
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            guard let self, let image else { return }
            self.selectedImage = image
            self.imageView.image = image
            self.placeholderLabel.isHidden = true
            self.updateStatus("已载入谱图", isError: false)
            self.recognizeCurrentImage()
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension ViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard !isUpdatingEditor else { return }
        if editorMode.selectedSegmentIndex == 0 {
            scoreText = textView.text
            algorithmText = NanyinAlgorithmGuide.renderDemoReport(
                title: "当前简谱算法演示",
                sourceText: textView.text,
                rhythmicText: textView.text
            )
            updatePlaybackMetrics()
        }
    }
}

private enum NanyinStyle {
    static let background = UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1.0)
    static let paper = UIColor(red: 1.00, green: 0.985, blue: 0.94, alpha: 1.0)
    static let controlBackground = UIColor(red: 0.90, green: 0.91, blue: 0.86, alpha: 1.0)
    static let ink = UIColor(red: 0.13, green: 0.12, blue: 0.10, alpha: 1.0)
    static let mutedInk = UIColor(red: 0.42, green: 0.40, blue: 0.35, alpha: 1.0)
    static let faintInk = UIColor(red: 0.62, green: 0.59, blue: 0.52, alpha: 1.0)
    static let cinnabar = UIColor(red: 0.70, green: 0.17, blue: 0.12, alpha: 1.0)
    static let jade = UIColor(red: 0.05, green: 0.43, blue: 0.40, alpha: 1.0)
    static let hairline = UIColor(red: 0.67, green: 0.55, blue: 0.39, alpha: 0.45)
}

private enum ButtonStyle {
    case filled
    case tinted
    case plain
}

private struct RecognizedLine {
    let text: String
    let box: CGRect
}

private extension CGImagePropertyOrientation {
    init(_ imageOrientation: UIImage.Orientation) {
        switch imageOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

private extension UIImage {
    func normalizedForAnalysis() -> UIImage {
        guard imageOrientation != .up else { return self }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
