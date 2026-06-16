import AppKit
import SwiftUI

private struct ResetWorksheetShellFocusedValueKey: FocusedValueKey {
    typealias Value = @MainActor () -> Void
}

extension FocusedValues {
    var resetWorksheetShell: (@MainActor () -> Void)? {
        get { self[ResetWorksheetShellFocusedValueKey.self] }
        set { self[ResetWorksheetShellFocusedValueKey.self] = newValue }
    }
}

struct ContentView: View {
    @Binding var document: PlainTextDocument
    let fileURL: URL?

    @AppStorage("proportionalFontName") private var proportionalFontName = "SF Pro"
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("fullScreenTextWidthPercent") private var fullScreenTextWidthPercent = 70.0
    @AppStorage("executeSelectionShortcut") private var executeSelectionShortcut = "shift-return"
    @AppStorage("replaceSelectionWithPipelineShortcut") private var replaceSelectionWithPipelineShortcut = "command-r"
    @AppStorage("insertPipelineAfterSelectionShortcut") private var insertPipelineAfterSelectionShortcut = "command-shift-r"

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
        .focusedSceneValue(\.resetWorksheetShell) {
            resetWorksheetShell()
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

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        textField.placeholderString = "sed 's/_/ /g' | wc -w"
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let command = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return command.isEmpty ? nil : command
    }

    @MainActor
    private func present(error: Error, message: String) {
        let alert = NSAlert(error: error)
        alert.messageText = message
        alert.runModal()
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
