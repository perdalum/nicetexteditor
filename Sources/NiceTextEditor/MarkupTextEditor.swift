import AppKit
import SwiftUI

struct MarkupTextEditor: NSViewRepresentable {
    @Binding var text: String
    let proportionalFontName: String
    let fontSize: Double
    let fullScreenTextWidthPercent: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]

        context.coordinator.configureTextWidth(for: textView)
        context.coordinator.applyMarkupStyles(to: textView)
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak textView] in
            guard let textView else { return }
            coordinator?.startObservingWindow(for: textView)
            coordinator?.configureTextWidth(for: textView)
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

        context.coordinator.startObservingWindow(for: textView)
        context.coordinator.configureTextWidth(for: textView)
        context.coordinator.applyMarkupStyles(to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
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

            // Full-screen Space transitions can report a transient stale content width.
            // Recheck once the window has become visible and AppKit has completed layout.
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let textView else { return }
                self?.configureTextWidth(for: textView)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak textView] in
                guard let textView else { return }
                self?.configureTextWidth(for: textView)
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
            guard fullRange.length > 0 else { return }

            let selectedRanges = textView.selectedRanges
            let proportionalFont = resolvedProportionalFont()
            let monospaceFont = NSFont.monospacedSystemFont(ofSize: CGFloat(parent.fontSize), weight: .regular)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.allowsDefaultTighteningForTruncation = false

            storage.beginEditing()
            storage.setAttributes([
                .font: proportionalFont,
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraphStyle
            ], range: fullRange)

            for range in verbatimBodyRanges(in: nsString) {
                storage.addAttributes([
                    .font: monospaceFont,
                    .foregroundColor: NSColor.textColor,
                    .paragraphStyle: paragraphStyle
                ], range: range)
            }
            storage.endEditing()

            textView.selectedRanges = selectedRanges.clamped(toLength: nsString.length)
            textView.typingAttributes = [
                .font: proportionalFont,
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraphStyle
            ]
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

        private func verbatimBodyRanges(in text: NSString) -> [NSRange] {
            var ranges: [NSRange] = []
            var insideVerbatimBlock = false
            var searchLocation = 0
            let textLength = text.length

            while searchLocation < textLength {
                var lineEnd = 0
                var contentsEnd = 0
                text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: searchLocation, length: 0))
                let lineRange = NSRange(location: searchLocation, length: contentsEnd - searchLocation)

                let line = text.substring(with: lineRange)
                let marker = line.trimmingCharacters(in: .whitespacesAndNewlines)

                if marker == ".VB" {
                    insideVerbatimBlock = true
                } else if marker == ".VE" {
                    insideVerbatimBlock = false
                } else if insideVerbatimBlock, lineRange.length > 0 {
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
