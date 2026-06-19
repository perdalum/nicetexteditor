import AppKit
import SwiftUI

private enum WorksheetEditorCommand {
    case executeSelection
    case replaceSelectionWithPipeline
    case insertPipelineAfterSelection
    case resetDocumentShell
    case increaseTextSize
    case decreaseTextSize
    case resetTextSize
    case toggleLineNumbers
}

private protocol WorksheetTextViewDelegate: AnyObject {
    func worksheetTextView(_ textView: WorksheetTextView, didRequest command: WorksheetEditorCommand)
}

private final class WorksheetTextView: NSTextView {
    weak var worksheetCommandDelegate: WorksheetTextViewDelegate?
    var executeSelectionShortcut = "shift-return"
    var replaceSelectionWithPipelineShortcut = "command-e"
    var insertPipelineAfterSelectionShortcut = "command-shift-e"

    override func keyDown(with event: NSEvent) {
        if handleWorksheetShortcut(event) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleWorksheetShortcut(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    @objc func runSelectionInShell(_ sender: Any?) {
        worksheetCommandDelegate?.worksheetTextView(self, didRequest: .executeSelection)
    }

    @objc func replaceSelectionWithPipeline(_ sender: Any?) {
        worksheetCommandDelegate?.worksheetTextView(self, didRequest: .replaceSelectionWithPipeline)
    }

    @objc func insertPipelineAfterSelection(_ sender: Any?) {
        worksheetCommandDelegate?.worksheetTextView(self, didRequest: .insertPipelineAfterSelection)
    }

    @objc func resetDocumentShell(_ sender: Any?) {
        worksheetCommandDelegate?.worksheetTextView(self, didRequest: .resetDocumentShell)
    }

    @objc func increaseEditorTextSize(_ sender: Any?) {
        worksheetCommandDelegate?.worksheetTextView(self, didRequest: .increaseTextSize)
    }

    @objc func decreaseEditorTextSize(_ sender: Any?) {
        worksheetCommandDelegate?.worksheetTextView(self, didRequest: .decreaseTextSize)
    }

    @objc func resetEditorTextSize(_ sender: Any?) {
        worksheetCommandDelegate?.worksheetTextView(self, didRequest: .resetTextSize)
    }

    @objc func toggleLineNumbers(_ sender: Any?) {
        worksheetCommandDelegate?.worksheetTextView(self, didRequest: .toggleLineNumbers)
    }

    @objc func goToLine(_ sender: Any?) {
        let lineStarts = lineStartLocations()
        let lineCount = lineStarts.count

        let alert = NSAlert()
        alert.messageText = "Go To Line"
        alert.informativeText = "Enter a line number, start/s, or end/eof/e. Negative numbers count back from the end."
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        textField.stringValue = String(currentLineNumber(in: lineStarts))
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let requestedValue = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let targetLine = resolvedLineNumber(from: requestedValue, lineCount: lineCount) else {
            presentGoToLineError("Could not understand “\(requestedValue)”.")
            return
        }

        let targetLocation = lineStarts[targetLine - 1]
        setSelectedRange(NSRange(location: targetLocation, length: 0))
        scrollRangeToVisible(NSRange(location: targetLocation, length: 0))
        window?.makeFirstResponder(self)
    }

    private func handleWorksheetShortcut(_ event: NSEvent) -> Bool {
        if event.matchesShortcut(executeSelectionShortcut) {
            runSelectionInShell(nil)
            return true
        }

        if event.matchesShortcut(replaceSelectionWithPipelineShortcut) {
            replaceSelectionWithPipeline(nil)
            return true
        }

        if event.matchesShortcut(insertPipelineAfterSelectionShortcut) {
            insertPipelineAfterSelection(nil)
            return true
        }

        return false
    }

    private func resolvedLineNumber(from value: String, lineCount: Int) -> Int? {
        let normalized = value.lowercased()
        if normalized == "start" || normalized == "s" { return 1 }
        if normalized == "end" || normalized == "eof" || normalized == "e" { return lineCount }

        guard let requestedLine = Int(normalized) else { return nil }
        if requestedLine <= 0 {
            if requestedLine == 0 { return 1 }
            return max(1, min(lineCount, lineCount - abs(requestedLine)))
        }
        return max(1, min(lineCount, requestedLine))
    }

    private func lineStartLocations() -> [Int] {
        let nsString = string as NSString
        guard nsString.length > 0 else { return [0] }

        var starts = [0]
        var searchLocation = 0
        while searchLocation < nsString.length {
            var lineEnd = 0
            nsString.getLineStart(nil, end: &lineEnd, contentsEnd: nil, for: NSRange(location: searchLocation, length: 0))

            if lineEnd < nsString.length {
                starts.append(lineEnd)
            } else if lineEnd == nsString.length, lineEnd > 0 {
                let finalCharacter = nsString.substring(with: NSRange(location: lineEnd - 1, length: 1))
                if finalCharacter == "\n" || finalCharacter == "\r" {
                    starts.append(lineEnd)
                }
            }

            if lineEnd <= searchLocation { break }
            searchLocation = lineEnd
        }

        return starts
    }

    private func currentLineNumber(in lineStarts: [Int]) -> Int {
        let location = selectedRange().location
        return (lineStarts.lastIndex { $0 <= location } ?? 0) + 1
    }

    private func presentGoToLineError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Cannot Go To Line"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct MarkupTextEditor: NSViewRepresentable {
    @Binding var text: String
    let proportionalFontName: String
    let fontSize: Double
    let tabWidth: Int
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let showLineNumbers: Bool
    let fullScreenTextWidthPercent: Double
    let executeSelectionShortcut: String
    let replaceSelectionWithPipelineShortcut: String
    let insertPipelineAfterSelectionShortcut: String
    let executeSelection: @MainActor (String) async throws -> String
    let replaceSelectionWithPipeline: @MainActor (String) async throws -> String?
    let insertPipelineAfterSelection: @MainActor (String) async throws -> String?
    let resetDocumentShell: @MainActor () -> Void
    let increaseTextSize: @MainActor () -> Void
    let decreaseTextSize: @MainActor () -> Void
    let resetTextSize: @MainActor () -> Void
    let toggleLineNumbers: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = WorksheetTextView()

        scrollView.drawsBackground = true
        scrollView.backgroundColor = backgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.worksheetCommandDelegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = true
        textView.backgroundColor = backgroundColor
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.usesFindBar = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticDataDetectionEnabled = true
        textView.smartInsertDeleteEnabled = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
        context.coordinator.configureShortcuts(for: textView)

        context.coordinator.configureTextWidth(for: textView)
        context.coordinator.configureVirtualBottomSpace(for: textView)
        context.coordinator.configureLineNumbers(for: scrollView, textView: textView)
        context.coordinator.applyMarkupStyles(to: textView)
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak textView] in
            guard let textView else { return }
            coordinator?.startObservingWindow(for: textView)
            coordinator?.configureTextWidth(for: textView)
            coordinator?.configureVirtualBottomSpace(for: textView)
            if let scrollView = textView.enclosingScrollView {
                coordinator?.configureLineNumbers(for: scrollView, textView: textView)
            }
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            context.coordinator.isApplyingProgrammaticChange = true
            textView.string = text
            textView.selectedRanges = selectedRanges.clamped(toLength: (text as NSString).length)
            context.coordinator.isApplyingProgrammaticChange = false
        }

        scrollView.backgroundColor = backgroundColor
        textView.backgroundColor = backgroundColor

        context.coordinator.startObservingWindow(for: textView)
        context.coordinator.configureShortcuts(for: textView)
        context.coordinator.configureTextWidth(for: textView)
        context.coordinator.configureVirtualBottomSpace(for: textView)
        context.coordinator.configureLineNumbers(for: scrollView, textView: textView)
        context.coordinator.applyMarkupStyles(to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, WorksheetTextViewDelegate {
        var parent: MarkupTextEditor
        var isApplyingProgrammaticChange = false
        private weak var observedWindow: NSWindow?
        private weak var observedClipView: NSClipView?
        private weak var observedTextView: NSTextView?
        private var notificationObservers: [NSObjectProtocol] = []

        init(_ parent: MarkupTextEditor) {
            self.parent = parent
        }

        deinit {
            stopObservingWindow()
        }

        func configureShortcuts(for textView: NSTextView) {
            guard let textView = textView as? WorksheetTextView else { return }
            textView.executeSelectionShortcut = parent.executeSelectionShortcut
            textView.replaceSelectionWithPipelineShortcut = parent.replaceSelectionWithPipelineShortcut
            textView.insertPipelineAfterSelectionShortcut = parent.insertPipelineAfterSelectionShortcut
        }

        func startObservingWindow(for textView: NSTextView) {
            guard let window = textView.window else {
                startObservingLayout(for: textView)
                return
            }

            if window === observedWindow {
                startObservingLayout(for: textView)
                return
            }

            stopObservingWindow()
            observedWindow = window
            startObservingLayout(for: textView)

            let windowNotificationNames: [Notification.Name] = [
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didResizeNotification,
                NSWindow.didChangeScreenNotification,
                NSWindow.didChangeOcclusionStateNotification,
                NSWindow.didBecomeKeyNotification
            ]

            notificationObservers += windowNotificationNames.map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self, weak textView] _ in
                    guard let textView else { return }
                    self?.scheduleTextWidthConfiguration(for: textView)
                }
            }

            notificationObservers.append(
                NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: NSApp, queue: .main) { [weak self, weak textView] _ in
                    guard let textView else { return }
                    self?.scheduleTextWidthConfiguration(for: textView)
                }
            )
        }

        func configureTextWidth(for textView: NSTextView) {
            let availableWidth = textView.enclosingScrollView?.contentSize.width ?? textView.bounds.width
            guard availableWidth > 100, let textContainer = textView.textContainer else { return }

            let metrics = textWidthMetrics(for: textView, availableWidth: availableWidth)
            let currentInset = textView.textContainerInset
            let currentContainerWidth = textContainer.containerSize.width
            let needsUpdate = textContainer.widthTracksTextView != metrics.widthTracksTextView
                || abs(currentContainerWidth - metrics.containerWidth) > 0.5
                || abs(currentInset.width - metrics.horizontalInset) > 0.5
                || currentInset.height != 12

            guard needsUpdate else { return }

            textContainer.widthTracksTextView = metrics.widthTracksTextView
            textContainer.containerSize = NSSize(
                width: metrics.containerWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.textContainerInset = NSSize(width: metrics.horizontalInset, height: 12)
            textView.layoutManager?.ensureLayout(for: textContainer)
            textView.needsLayout = true
            textView.needsDisplay = true
        }

        func configureLineNumbers(for scrollView: NSScrollView, textView: NSTextView) {
            if parent.showLineNumbers {
                let rulerView: LineNumberRulerView
                if let existingRulerView = scrollView.verticalRulerView as? LineNumberRulerView {
                    rulerView = existingRulerView
                    rulerView.textView = textView
                } else {
                    rulerView = LineNumberRulerView(textView: textView)
                    scrollView.verticalRulerView = rulerView
                }

                rulerView.configure(
                    backgroundColor: parent.backgroundColor,
                    foregroundColor: parent.foregroundColor,
                    fontSize: CGFloat(parent.fontSize)
                )
                scrollView.hasVerticalRuler = true
                scrollView.rulersVisible = true
            } else {
                scrollView.rulersVisible = false
                scrollView.hasVerticalRuler = false
            }
        }

        func configureVirtualBottomSpace(for textView: NSTextView) {
            guard let scrollView = textView.enclosingScrollView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let viewportHeight = scrollView.contentView.bounds.height
            guard viewportHeight > 0 else { return }

            // Do not use NSScrollView.contentInsets for the virtual space. AppKit treats
            // contentInsets as obscured viewport area and will auto-scroll the insertion
            // point above that inset while typing. Instead, make the document view taller
            // than its laid-out text, which creates scrollable blank space without changing
            // the visible rect used for normal editing.
            if scrollView.contentInsets.bottom != 0 {
                scrollView.contentInsets = NSEdgeInsets(
                    top: scrollView.contentInsets.top,
                    left: scrollView.contentInsets.left,
                    bottom: 0,
                    right: scrollView.contentInsets.right
                )
            }

            layoutManager.ensureLayout(for: textContainer)
            let textHeight = layoutManager.usedRect(for: textContainer).height + (textView.textContainerInset.height * 2)
            let bottomSpace = viewportHeight * 0.75
            let desiredHeight = max(viewportHeight, ceil(textHeight + bottomSpace))
            let currentSize = textView.frame.size
            guard abs(currentSize.height - desiredHeight) > 0.5 else { return }

            let visibleOrigin = scrollView.contentView.bounds.origin
            textView.minSize = NSSize(width: 0, height: desiredHeight)
            textView.setFrameSize(NSSize(width: currentSize.width, height: desiredHeight))
            scrollView.contentView.setBoundsOrigin(visibleOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        private func startObservingLayout(for textView: NSTextView) {
            guard let clipView = textView.enclosingScrollView?.contentView else { return }
            guard clipView !== observedClipView || textView !== observedTextView else { return }

            observedClipView = clipView
            observedTextView = textView
            clipView.postsBoundsChangedNotifications = true
            textView.postsFrameChangedNotifications = true

            notificationObservers.append(
                NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clipView, queue: .main) { [weak self, weak textView] _ in
                    guard let textView else { return }
                    self?.scheduleTextWidthConfiguration(for: textView)
                }
            )
            notificationObservers.append(
                NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: textView, queue: .main) { [weak self, weak textView] _ in
                    guard let textView else { return }
                    self?.scheduleTextWidthConfiguration(for: textView)
                }
            )
        }

        private func scheduleTextWidthConfiguration(for textView: NSTextView) {
            configureTextWidth(for: textView)
            configureVirtualBottomSpace(for: textView)
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true

            // Full-screen Space transitions can report a transient stale content width.
            // Recheck once the window has become visible and AppKit has completed layout.
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let textView else { return }
                self?.configureTextWidth(for: textView)
                self?.configureVirtualBottomSpace(for: textView)
                textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak textView] in
                guard let textView else { return }
                self?.configureTextWidth(for: textView)
                self?.configureVirtualBottomSpace(for: textView)
                textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            }
        }

        private func stopObservingWindow() {
            for observer in notificationObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            notificationObservers.removeAll()
            observedWindow = nil
            observedClipView = nil
            observedTextView = nil
        }

        private func textWidthMetrics(
            for textView: NSTextView,
            availableWidth: CGFloat
        ) -> (widthTracksTextView: Bool, containerWidth: CGFloat, horizontalInset: CGFloat) {
            let defaultInset: CGFloat = 12
            guard let window = textView.window, window.styleMask.contains(.fullScreen) else {
                return (true, availableWidth, defaultInset)
            }

            let percent = CGFloat(min(100, max(40, parent.fullScreenTextWidthPercent))) / 100
            let screenWidth = window.screen?.frame.width ?? NSScreen.main?.frame.width ?? availableWidth
            let targetTextWidth = min(availableWidth - (defaultInset * 2), max(240, screenWidth * percent))
            let horizontalInset = max(defaultInset, (availableWidth - targetTextWidth) / 2)

            // In full screen the inset alone only moves the text origin. The container width
            // must also be narrowed, otherwise lines still wrap at the full window width and
            // the right edge can extend off screen by the added left margin.
            return (false, targetTextWidth, horizontalInset)
        }

        fileprivate func worksheetTextView(_ textView: WorksheetTextView, didRequest command: WorksheetEditorCommand) {
            switch command {
            case .resetDocumentShell:
                Task { @MainActor in parent.resetDocumentShell() }
                return
            case .increaseTextSize:
                Task { @MainActor in parent.increaseTextSize() }
                return
            case .decreaseTextSize:
                Task { @MainActor in parent.decreaseTextSize() }
                return
            case .resetTextSize:
                Task { @MainActor in parent.resetTextSize() }
                return
            case .toggleLineNumbers:
                Task { @MainActor in parent.toggleLineNumbers() }
                return
            case .executeSelection, .replaceSelectionWithPipeline, .insertPipelineAfterSelection:
                break
            }

            let selectedRange = textView.selectedRange()
            guard selectedRange.length > 0 else {
                NSSound.beep()
                return
            }

            let nsString = textView.string as NSString
            let selectedText = nsString.substring(with: selectedRange)

            Task { @MainActor in
                do {
                    switch command {
                    case .executeSelection:
                        let output = try await parent.executeSelection(selectedText)
                        insert(output, after: selectedRange, selectedText: selectedText, in: textView)
                    case .replaceSelectionWithPipeline:
                        guard let output = try await parent.replaceSelectionWithPipeline(selectedText) else { return }
                        replace(range: selectedRange, with: output, in: textView)
                    case .insertPipelineAfterSelection:
                        guard let output = try await parent.insertPipelineAfterSelection(selectedText) else { return }
                        insert(output, after: selectedRange, selectedText: selectedText, in: textView)
                    case .resetDocumentShell, .increaseTextSize, .decreaseTextSize, .resetTextSize, .toggleLineNumbers:
                        return
                    }
                } catch {
                    present(error: error, in: textView.window)
                }
            }
        }

        private func insert(_ output: String, after selectedRange: NSRange, selectedText: String, in textView: NSTextView) {
            guard !output.isEmpty else { return }
            let insertion = selectedText.hasSuffix("\n") ? output : "\n" + output
            let location = Swift.min(selectedRange.location + selectedRange.length, (textView.string as NSString).length)
            replace(range: NSRange(location: location, length: 0), with: insertion, in: textView)
        }

        private func replace(range: NSRange, with string: String, in textView: NSTextView) {
            let textLength = (textView.string as NSString).length
            let location = Swift.min(range.location, textLength)
            let length = Swift.min(range.length, textLength - location)
            let replacementRange = NSRange(location: location, length: length)

            guard textView.shouldChangeText(in: replacementRange, replacementString: string) else { return }
            textView.textStorage?.replaceCharacters(in: replacementRange, with: string)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: location + (string as NSString).length, length: 0))
        }

        private func present(error: Error, in window: NSWindow?) {
            let alert = NSAlert(error: error)
            alert.messageText = "Worksheet command failed"
            if let window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammaticChange else { return }
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyMarkupStyles(to: textView)
        }

        func applyMarkupStyles(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }

            let nsString = storage.string as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)
            let selectedRanges = textView.selectedRanges
            let proportionalFont = resolvedProportionalFont()
            let quoteFont = NSFontManager.shared.convert(proportionalFont, toHaveTrait: .italicFontMask)
            let monospaceFont = NSFont.monospacedSystemFont(ofSize: CGFloat(parent.fontSize), weight: .regular)
            let proportionalParagraphStyle = paragraphStyle(for: proportionalFont)
            let quoteParagraphStyle = paragraphStyle(for: quoteFont)
            let monospaceParagraphStyle = paragraphStyle(for: monospaceFont)

            textView.backgroundColor = parent.backgroundColor

            if fullRange.length > 0 {
                storage.beginEditing()
                storage.setAttributes([
                    .font: proportionalFont,
                    .foregroundColor: parent.foregroundColor,
                    .paragraphStyle: proportionalParagraphStyle
                ], range: fullRange)

                for range in blockBodyRanges(in: nsString, startMarker: ".VB", endMarker: ".VE") {
                    storage.addAttributes([
                        .font: monospaceFont,
                        .foregroundColor: parent.foregroundColor,
                        .paragraphStyle: monospaceParagraphStyle
                    ], range: range)
                }

                for range in blockBodyRanges(in: nsString, startMarker: ".QB", endMarker: ".QE") {
                    storage.addAttributes([
                        .font: quoteFont,
                        .foregroundColor: parent.foregroundColor,
                        .paragraphStyle: quoteParagraphStyle
                    ], range: range)
                }
                storage.endEditing()
            }

            textView.selectedRanges = selectedRanges.clamped(toLength: nsString.length)
            textView.typingAttributes = [
                .font: proportionalFont,
                .foregroundColor: parent.foregroundColor,
                .paragraphStyle: proportionalParagraphStyle
            ]
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        private func paragraphStyle(for font: NSFont) -> NSMutableParagraphStyle {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.allowsDefaultTighteningForTruncation = false

            let clampedTabWidth = max(1, min(parent.tabWidth, 16))
            let spaceWidth = max(1, (" " as NSString).size(withAttributes: [.font: font]).width)
            paragraphStyle.defaultTabInterval = spaceWidth * CGFloat(clampedTabWidth)
            paragraphStyle.tabStops = []

            return paragraphStyle
        }

        private func resolvedProportionalFont() -> NSFont {
            let requested = parent.proportionalFontName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !requested.isEmpty, let font = NSFont(name: requested, size: CGFloat(parent.fontSize)) {
                return font
            }

            // “SF Pro” is exposed to AppKit as the system font rather than as a normal named family.
            if requested.isEmpty || requested.localizedCaseInsensitiveContains("SF Pro") {
                return NSFont.systemFont(ofSize: CGFloat(parent.fontSize), weight: .regular)
            }

            return NSFont.systemFont(ofSize: CGFloat(parent.fontSize), weight: .regular)
        }

        private func blockBodyRanges(in text: NSString, startMarker: String, endMarker: String) -> [NSRange] {
            var ranges: [NSRange] = []
            var insideBlock = false
            var searchLocation = 0
            let textLength = text.length

            while searchLocation < textLength {
                var lineEnd = 0
                var contentsEnd = 0
                text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: searchLocation, length: 0))
                let lineRange = NSRange(location: searchLocation, length: contentsEnd - searchLocation)

                let line = text.substring(with: lineRange)
                let marker = line.trimmingCharacters(in: .whitespacesAndNewlines)

                if marker == startMarker {
                    insideBlock = true
                } else if marker == endMarker {
                    insideBlock = false
                } else if insideBlock, lineRange.length > 0 {
                    ranges.append(lineRange)
                }

                if lineEnd <= searchLocation {
                    break
                }
                searchLocation = lineEnd
            }

            return ranges
        }
    }
}

private extension NSEvent {
    func matchesShortcut(_ rawValue: String) -> Bool {
        let normalized = modifierFlags.intersection([.command, .shift, .option, .control])
        let key = charactersIgnoringModifiers?.lowercased()
        let isReturn = keyCode == 36 || keyCode == 76 || key == "\r"

        switch rawValue {
        case "shift-return":
            return isReturn && normalized == [.shift]
        case "command-return":
            return isReturn && normalized == [.command]
        case "command-shift-return":
            return isReturn && normalized == [.command, .shift]
        case "command-e":
            return key == "e" && normalized == [.command]
        case "command-shift-e":
            return key == "e" && normalized == [.command, .shift]
        case "command-option-e":
            return key == "e" && normalized == [.command, .option]
        case "command-r":
            return key == "r" && normalized == [.command]
        case "command-shift-r":
            return key == "r" && normalized == [.command, .shift]
        case "command-option-r":
            return key == "r" && normalized == [.command, .option]
        default:
            return false
        }
    }
}

private extension Array where Element == NSValue {
    func clamped(toLength length: Int) -> [NSValue] {
        map { value in
            let range = value.rangeValue
            let location = Swift.min(range.location, length)
            let maxLength = Swift.max(0, length - location)
            return NSValue(range: NSRange(location: location, length: Swift.min(range.length, maxLength)))
        }
    }
}
