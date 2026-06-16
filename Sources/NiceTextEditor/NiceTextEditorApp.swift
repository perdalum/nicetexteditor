import AppKit
import SwiftUI

@main
struct NiceTextEditorApp: App {
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
                Button("Increase Text Size") { AppCommands.perform("increaseEditorTextSize:") }
                    .keyboardShortcut("+", modifiers: [.command])
                Button("Decrease Text Size") { AppCommands.perform("decreaseEditorTextSize:") }
                    .keyboardShortcut("-", modifiers: [.command])
                Button("Actual Size") { AppCommands.perform("resetEditorTextSize:") }
                    .keyboardShortcut("0", modifiers: [.command])
            }

            WorksheetCommands()
        }

        Settings {
            SettingsView()
        }
    }

}

private enum AppCommands {
    static func perform(_ selectorName: String) {
        NSApp.sendAction(NSSelectorFromString(selectorName), to: nil, from: nil)
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
    var body: some Commands {
        CommandMenu("Worksheet") {
            Button("Run Selection in Shell") {
                AppCommands.perform("runSelectionInShell:")
            }
            .keyboardShortcut(.return, modifiers: [.shift])

            Button("Replace Selection with Pipeline Output…") {
                AppCommands.perform("replaceSelectionWithPipeline:")
            }
            .keyboardShortcut("e", modifiers: [.command])

            Button("Insert Pipeline Output After Selection…") {
                AppCommands.perform("insertPipelineAfterSelection:")
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Reset Document Shell") {
                AppCommands.perform("resetDocumentShell:")
            }
        }
    }
}
