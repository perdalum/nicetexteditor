import SwiftUI

struct ContentView: View {
    @Binding var document: PlainTextDocument
    let fileURL: URL?

    @AppStorage("proportionalFontName") private var proportionalFontName = "SF Pro"
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("fullScreenTextWidthPercent") private var fullScreenTextWidthPercent = 70.0

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
                fullScreenTextWidthPercent: fullScreenTextWidthPercent
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
