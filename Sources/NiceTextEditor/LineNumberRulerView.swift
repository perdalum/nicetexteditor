import AppKit

final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?

    private var editorBackgroundColor = NSColor.textBackgroundColor
    private var editorForegroundColor = NSColor.textColor
    private var editorFontSize: CGFloat = 15
    private let horizontalPadding: CGFloat = 8
    private let minimumThickness: CGFloat = 38

    override var isFlipped: Bool { true }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = minimumThickness
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(backgroundColor: NSColor, foregroundColor: NSColor, fontSize: CGFloat) {
        editorBackgroundColor = backgroundColor
        editorForegroundColor = foregroundColor
        editorFontSize = fontSize
        updateRuleThickness()
        needsDisplay = true
    }

    override var requiredThickness: CGFloat {
        guard let textView else { return minimumThickness }
        let lineCount = lineStartLocations(in: textView.string as NSString).count
        return thickness(forLineCount: lineCount)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        editorBackgroundColor.setFill()
        bounds.fill()

        editorForegroundColor.withAlphaComponent(0.18).setStroke()
        let separatorX = bounds.maxX - 0.5
        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: separatorX, y: bounds.minY))
        separator.line(to: NSPoint(x: separatorX, y: bounds.maxY))
        separator.stroke()

        let nsString = textView.string as NSString
        let lineStarts = lineStartLocations(in: nsString)
        let font = rulerFont()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: editorForegroundColor.withAlphaComponent(0.48),
            .paragraphStyle: paragraphStyle
        ]
        let drawWidth = max(0, bounds.width - (horizontalPadding * 2))
        let textOrigin = textView.textContainerOrigin
        let textViewOffset = convert(NSPoint.zero, from: textView)

        guard nsString.length > 0 else {
            draw(lineNumber: 1, y: textOrigin.y + textViewOffset.y, width: drawWidth, attributes: attributes)
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        var drawnLineNumbers = Set<Int>()

        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { _, usedRect, _, glyphRange, _ in
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            guard characterRange.location < nsString.length else { return }

            let lineNumber = self.lineNumber(forCharacterLocation: characterRange.location, lineStarts: lineStarts)
            guard !drawnLineNumbers.contains(lineNumber) else { return }
            guard lineStarts[lineNumber - 1] == characterRange.location else { return }

            drawnLineNumbers.insert(lineNumber)
            let lineCenterOffset = max(0, (usedRect.height - font.ascender + font.descender) / 2)
            let y = textOrigin.y + textViewOffset.y + usedRect.minY + lineCenterOffset
            self.draw(lineNumber: lineNumber, y: y, width: drawWidth, attributes: attributes)
        }
    }

    private func draw(lineNumber: Int, y: CGFloat, width: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        let string = NSString(string: String(lineNumber))
        let font = rulerFont()
        string.draw(in: NSRect(x: horizontalPadding, y: y, width: width, height: font.ascender - font.descender + font.leading), withAttributes: attributes)
    }

    private func updateRuleThickness() {
        let desiredThickness = requiredThickness
        if abs(ruleThickness - desiredThickness) > 0.5 {
            ruleThickness = desiredThickness
            enclosingScrollView?.tile()
        }
    }

    private func thickness(forLineCount lineCount: Int) -> CGFloat {
        let digits = max(1, String(lineCount).count)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = sample.size(withAttributes: [.font: rulerFont()]).width
        return max(minimumThickness, ceil(width + (horizontalPadding * 2) + 8))
    }

    private func rulerFont() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: min(13, max(9, editorFontSize - 2)), weight: .regular)
    }

    private func lineNumber(forCharacterLocation location: Int, lineStarts: [Int]) -> Int {
        var lowerBound = 0
        var upperBound = lineStarts.count
        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if lineStarts[middle] <= location {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }
        return max(1, lowerBound)
    }

    private func lineStartLocations(in text: NSString) -> [Int] {
        guard text.length > 0 else { return [0] }

        var starts = [0]
        var searchLocation = 0
        while searchLocation < text.length {
            var lineEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: nil, for: NSRange(location: searchLocation, length: 0))

            if lineEnd < text.length {
                starts.append(lineEnd)
            } else if lineEnd == text.length, lineEnd > 0 {
                let finalCharacter = text.substring(with: NSRange(location: lineEnd - 1, length: 1))
                if finalCharacter == "\n" || finalCharacter == "\r" {
                    starts.append(lineEnd)
                }
            }

            if lineEnd <= searchLocation { break }
            searchLocation = lineEnd
        }

        return starts
    }
}
