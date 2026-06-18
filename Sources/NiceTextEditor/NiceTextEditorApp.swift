import AppKit
import SwiftUI

@main
struct NiceTextEditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: PlainTextDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .frame(minWidth: 260, minHeight: 300)
        }
        .commands {
            CommandGroup(after: .pasteboard) {
                Divider()

                Menu("Spelling and Grammar") {
                    Button("Show Spelling and Grammar") { AppCommands.perform("showGuessPanel:") }
                        .keyboardShortcut(":", modifiers: [.command])
                    Button("Check Document Now") { AppCommands.perform("checkSpelling:") }
                        .keyboardShortcut(";", modifiers: [.command])

                    Divider()

                    Button("Check Spelling While Typing") { AppCommands.perform("toggleContinuousSpellChecking:") }
                    Button("Check Grammar With Spelling") { AppCommands.perform("toggleGrammarChecking:") }
                    Button("Correct Spelling Automatically") { AppCommands.perform("toggleAutomaticSpellingCorrection:") }
                }

                Menu("Substitutions") {
                    Button("Show Substitutions") { AppCommands.perform("orderFrontSubstitutionsPanel:") }

                    Divider()

                    Button("Smart Copy/Paste") { AppCommands.perform("toggleSmartInsertDelete:") }
                    Button("Smart Quotes") { AppCommands.perform("toggleAutomaticQuoteSubstitution:") }
                    Button("Smart Dashes") { AppCommands.perform("toggleAutomaticDashSubstitution:") }
                    Button("Smart Links") { AppCommands.perform("toggleAutomaticLinkDetection:") }
                    Button("Data Detectors") { AppCommands.perform("toggleAutomaticDataDetection:") }
                    Button("Text Replacement") { AppCommands.perform("toggleAutomaticTextReplacement:") }
                }

                Divider()

                Button("Go To Line…") { AppCommands.perform("goToLine:") }
                    .keyboardShortcut("l", modifiers: [.command])

                Divider()

                Button("Find…") { FindCommands.perform(.showFindInterface) }
                    .keyboardShortcut("f", modifiers: [.command])
                Button("Find Next") { FindCommands.perform(.nextMatch) }
                    .keyboardShortcut("g", modifiers: [.command])
                Button("Find Previous") { FindCommands.perform(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { FindCommands.perform(.setSearchString) }
            }

            CommandGroup(after: .toolbar) {
                Divider()
                Button("Line Numbers") { AppCommands.perform("toggleLineNumbers:") }
                    .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Zoom In") { AppCommands.perform("increaseEditorTextSize:") }
                    .keyboardShortcut("+", modifiers: [.command])
                Button("Zoom Out") { AppCommands.perform("decreaseEditorTextSize:") }
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
