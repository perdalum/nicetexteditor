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
            CommandGroup(after: .textFormatting) {
                Divider()
                Button("Increase Text Size") { increaseTextSize() }
                    .keyboardShortcut("+", modifiers: [.command])
                Button("Decrease Text Size") { decreaseTextSize() }
                    .keyboardShortcut("-", modifiers: [.command])
                Button("Actual Size") { resetTextSize() }
                    .keyboardShortcut("0", modifiers: [.command])
            }
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
