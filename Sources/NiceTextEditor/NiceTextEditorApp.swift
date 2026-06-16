import AppKit
import SwiftUI

@main
struct NiceTextEditorApp: App {
    @AppStorage("editorFontSize") private var editorFontSize = 15.0

    var body: some Scene {
        DocumentGroup(newDocument: PlainTextDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .frame(minWidth: 720, minHeight: 480)
        }
        .commands {
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find…") { FindCommands.perform(.showFindInterface) }
                    .keyboardShortcut("f", modifiers: [.command])
                Button("Find Next") { FindCommands.perform(.nextMatch) }
                    .keyboardShortcut("g", modifiers: [.command])
                Button("Find Previous") { FindCommands.perform(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { FindCommands.perform(.setSearchString) }
            }

            CommandGroup(after: .textFormatting) {
                Divider()
                Button("Increase Text Size") { increaseTextSize() }
                    .keyboardShortcut("+", modifiers: [.command])
                Button("Decrease Text Size") { decreaseTextSize() }
                    .keyboardShortcut("-", modifiers: [.command])
                Button("Actual Size") { resetTextSize() }
                    .keyboardShortcut("0", modifiers: [.command])
            }

            WorksheetCommands()
        }

        Settings {
            SettingsView()
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
}

private enum FindCommands {
    static func perform(_ action: NSTextFinder.Action) {
        let menuItem = NSMenuItem()
        menuItem.tag = action.rawValue
        NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: menuItem)
    }
}

private struct WorksheetCommands: Commands {
    @FocusedValue(\.resetWorksheetShell) private var resetWorksheetShell

    var body: some Commands {
        CommandMenu("Worksheet") {
            Button("Run Selection in Shell") {
                WorksheetCommands.perform("runSelectionInShell:")
            }
            .keyboardShortcut(.return, modifiers: [.shift])

            Button("Replace Selection with Pipeline Output…") {
                WorksheetCommands.perform("replaceSelectionWithPipeline:")
            }
            .keyboardShortcut("e", modifiers: [.command])

            Button("Insert Pipeline Output After Selection…") {
                WorksheetCommands.perform("insertPipelineAfterSelection:")
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Reset Document Shell") {
                resetWorksheetShell?()
            }
            .disabled(resetWorksheetShell == nil)
        }
    }

    private static func perform(_ selectorName: String) {
        NSApp.sendAction(NSSelectorFromString(selectorName), to: nil, from: nil)
    }
}
