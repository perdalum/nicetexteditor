import AppKit
import SwiftUI

struct ContentView: View {
    @Binding var document: PlainTextDocument
    let fileURL: URL?

    @AppStorage("proportionalFontName") private var proportionalFontName = "SF Pro"
    @AppStorage("fullScreenTextWidthPercent") private var fullScreenTextWidthPercent = 70.0
    @State private var editorFontSize = 15.0
    @AppStorage("executeSelectionShortcut") private var executeSelectionShortcut = "shift-return"
    @AppStorage("replaceSelectionWithPipelineShortcut") private var replaceSelectionWithPipelineShortcut = "command-e"
    @AppStorage("insertPipelineAfterSelectionShortcut") private var insertPipelineAfterSelectionShortcut = "command-shift-e"

    @StateObject private var worksheetShell = WorksheetShell()

    private var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    private var locationDescription: String {
        fileURL?.path ?? "New document"
    }

    var body: some View {
        VStack(spacing: 0) {
            MarkupTextEditor(
                text: $document.text,
                proportionalFontName: proportionalFontName,
                fontSize: editorFontSize,
                fullScreenTextWidthPercent: fullScreenTextWidthPercent,
                executeSelectionShortcut: executeSelectionShortcut,
                replaceSelectionWithPipelineShortcut: replaceSelectionWithPipelineShortcut,
                insertPipelineAfterSelectionShortcut: insertPipelineAfterSelectionShortcut,
                executeSelection: { selectedText in
                    try await worksheetShell.execute(selectedText)
                },
                replaceSelectionWithPipeline: { selectedText in
                    guard let command = promptForPipelineCommand(title: "Replace Selection with Command Output") else { return nil }
                    return try await worksheetShell.runPipeline(command, stdin: selectedText)
                },
                insertPipelineAfterSelection: { selectedText in
                    guard let command = promptForPipelineCommand(title: "Insert Command Output After Selection") else { return nil }
                    return try await worksheetShell.runPipeline(command, stdin: selectedText)
                },
                resetDocumentShell: {
                    resetWorksheetShell()
                },
                increaseTextSize: {
                    increaseTextSize()
                },
                decreaseTextSize: {
                    decreaseTextSize()
                },
                resetTextSize: {
                    resetTextSize()
                }
            )

            Divider()

            HStack(spacing: 12) {
                Label(displayName, systemImage: "doc.text")
                    .labelStyle(.titleAndIcon)
                Text(locationDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(document.text.count) characters")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .navigationTitle(displayName)
        .onAppear {
            migrateWorksheetShortcutDefaults()
        }
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    FontChoiceButton(name: "SF Pro", selection: $proportionalFontName)
                    FontChoiceButton(name: "New York", selection: $proportionalFontName)
                    FontChoiceButton(name: "Helvetica Neue", selection: $proportionalFontName)
                    FontChoiceButton(name: "Georgia", selection: $proportionalFontName)
                    Divider()
                    Button("More fonts…") { NSFontPanel.shared.orderFront(nil) }
                } label: {
                    Label("Font", systemImage: "textformat")
                }

                Menu {
                    Button("Increase Text Size") { increaseTextSize() }
                        .keyboardShortcut("+", modifiers: [.command])
                    Button("Decrease Text Size") { decreaseTextSize() }
                        .keyboardShortcut("-", modifiers: [.command])
                    Button("Actual Size") { resetTextSize() }
                        .keyboardShortcut("0", modifiers: [.command])
                } label: {
                    Label("\(Int(editorFontSize)) pt", systemImage: "textformat.size")
                        .monospacedDigit()
                }
            }
        }
    }

    private func increaseTextSize() {
        editorFontSize = min(36, editorFontSize + 1)
    }

    private func decreaseTextSize() {
        editorFontSize = max(9, editorFontSize - 1)
    }

    private func resetTextSize() {
        editorFontSize = 15
    }

    private func migrateWorksheetShortcutDefaults() {
        if replaceSelectionWithPipelineShortcut == "command-r" {
            replaceSelectionWithPipelineShortcut = "command-e"
        }
        if replaceSelectionWithPipelineShortcut == "command-shift-r" {
            replaceSelectionWithPipelineShortcut = "command-shift-e"
        }
        if replaceSelectionWithPipelineShortcut == "command-option-r" {
            replaceSelectionWithPipelineShortcut = "command-option-e"
        }
        if insertPipelineAfterSelectionShortcut == "command-r" {
            insertPipelineAfterSelectionShortcut = "command-e"
        }
        if insertPipelineAfterSelectionShortcut == "command-shift-r" {
            insertPipelineAfterSelectionShortcut = "command-shift-e"
        }
        if insertPipelineAfterSelectionShortcut == "command-option-r" {
            insertPipelineAfterSelectionShortcut = "command-option-e"
        }
    }

    @MainActor
    private func resetWorksheetShell() {
        do {
            try worksheetShell.reset()
        } catch {
            present(error: error, message: "Could not reset the worksheet shell.")
        }
    }

    @MainActor
    private func promptForPipelineCommand(title: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Enter a zsh command or pipeline. The selected text is sent to the command as standard input."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Run")
        alert.addButton(withTitle: "Cancel")

        let textField = FocusedWorksheetCommandField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        textField.placeholderString = "sed 's/_/ /g' | wc -w"
        let historyDelegate = WorksheetCommandHistoryFieldDelegate(history: worksheetCommandHistory())
        textField.delegate = historyDelegate
        alert.accessoryView = textField
        alert.layout()
        alert.window.initialFirstResponder = textField
        alert.window.makeFirstResponder(textField)

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let command = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return nil }
        saveWorksheetCommandToHistory(command)
        return command
    }

    private func worksheetCommandHistory() -> [String] {
        UserDefaults.standard.stringArray(forKey: worksheetCommandHistoryKey) ?? []
    }

    private func saveWorksheetCommandToHistory(_ command: String) {
        var history = worksheetCommandHistory().filter { $0 != command }
        history.append(command)
        if history.count > 100 {
            history.removeFirst(history.count - 100)
        }
        UserDefaults.standard.set(history, forKey: worksheetCommandHistoryKey)
    }

    @MainActor
    private func present(error: Error, message: String) {
        let alert = NSAlert(error: error)
        alert.messageText = message
        alert.runModal()
    }
}

private let worksheetCommandHistoryKey = "worksheetPipelineCommandHistory"

private final class FocusedWorksheetCommandField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            window?.makeFirstResponder(self)
            currentEditor()?.selectedRange = NSRange(location: (stringValue as NSString).length, length: 0)
        }
    }
}

private final class WorksheetCommandHistoryFieldDelegate: NSObject, NSTextFieldDelegate {
    private let history: [String]
    private var navigationIndex: Int
    private var draft = ""

    init(history: [String]) {
        self.history = history
        self.navigationIndex = history.count
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            showPreviousCommand(in: textView)
            return true
        case #selector(NSResponder.moveDown(_:)):
            showNextCommand(in: textView)
            return true
        default:
            return false
        }
    }

    private func showPreviousCommand(in textView: NSTextView) {
        guard !history.isEmpty else { return }
        if navigationIndex == history.count {
            draft = textView.string
        }
        navigationIndex = max(0, navigationIndex - 1)
        replaceText(in: textView, with: history[navigationIndex])
    }

    private func showNextCommand(in textView: NSTextView) {
        guard !history.isEmpty else { return }
        navigationIndex = min(history.count, navigationIndex + 1)
        if navigationIndex == history.count {
            replaceText(in: textView, with: draft)
        } else {
            replaceText(in: textView, with: history[navigationIndex])
        }
    }

    private func replaceText(in textView: NSTextView, with string: String) {
        textView.string = string
        textView.setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
    }
}

private struct FontChoiceButton: View {
    let name: String
    @Binding var selection: String

    var body: some View {
        Button {
            selection = name
        } label: {
            if selection == name {
                Label(name, systemImage: "checkmark")
            } else {
                Text(name)
            }
        }
    }
}
