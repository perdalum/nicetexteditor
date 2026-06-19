import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("proportionalFontName") private var proportionalFontName = "SF Pro"
    @AppStorage("executeSelectionShortcut") private var executeSelectionShortcut = "shift-return"
    @AppStorage("replaceSelectionWithPipelineShortcut") private var replaceSelectionWithPipelineShortcut = "command-e"
    @AppStorage("insertPipelineAfterSelectionShortcut") private var insertPipelineAfterSelectionShortcut = "command-shift-e"
    @StateObject private var fontPanel = FontPanelCoordinator()

    var body: some View {
        Form {
            Section("Editor Font") {
                HStack {
                    Text(proportionalFontName)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("Choose Font…") {
                        fontPanel.show(selectedFontName: proportionalFontName)
                    }
                }

                Text("Choose the proportional editor font with the standard macOS Font panel. Text size is adjusted per document window from the toolbar or View menu.")
                    .foregroundStyle(.secondary)
            }

            Section("Worksheet Shell") {
                Button("Open Startup File Folder") {
                    openWorksheetStartupFolder()
                }

                Text("The global worksheet startup file is stored at ~/Library/Application Support/NiceTextEditor/WorksheetStartup.zsh and sourced before each document shell starts. Define PATH, aliases, functions, exports, and shell options there. Use Worksheet > Reset Document Shell in an open document to apply shell setup changes there.")
                    .foregroundStyle(.secondary)
            }

            Section("Worksheet Shortcuts") {
                Picker("Run selection in shell", selection: $executeSelectionShortcut) {
                    ShortcutChoices()
                }
                Picker("Filter selection", selection: $replaceSelectionWithPipelineShortcut) {
                    ShortcutChoices()
                }
                Picker("Insert filtered output", selection: $insertPipelineAfterSelectionShortcut) {
                    ShortcutChoices()
                }

                Text("Each document owns a background /bin/zsh process. Run Selection inserts command output after the selection. Filter Selection prompts for a pipeline and replaces the selection with stdout. Insert Filtered Output prompts for a pipeline and inserts stdout after the selection.")
                    .foregroundStyle(.secondary)
            }

            Section("Markup") {
                Text("Lines between .VB and .VE are displayed in SF Mono. Lines between .QB and .QE are displayed in the editor font italic. The file remains plain text and the markers are preserved.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 560)
        .onAppear {
            fontPanel.selectedFontName = proportionalFontName
            migrateWorksheetShortcutDefaults()
        }
        .onChange(of: fontPanel.selectedFontName) { _, newValue in
            proportionalFontName = newValue
        }
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

    private func openWorksheetStartupFolder() {
        do {
            let folderURL = try worksheetStartupFolderURL()
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let startupFileURL = folderURL.appendingPathComponent("WorksheetStartup.zsh")
            if !FileManager.default.fileExists(atPath: startupFileURL.path) {
                let contents = """
                # NiceTextEditor worksheet shell startup file
                #
                # This file is sourced before each document shell starts.
                # Use it for PATH, aliases, functions, exports, and shell options.
                #
                # Example:
                # export PATH=\"/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin\"
                #
                # After editing this file, use Worksheet > Reset Document Shell
                # in open documents to apply changes there.
                
                """
                try contents.write(to: startupFileURL, atomically: true, encoding: .utf8)
            }
            NSWorkspace.shared.activateFileViewerSelecting([startupFileURL])
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Could not open the worksheet startup folder."
            alert.runModal()
        }
    }

    private func worksheetStartupFolderURL() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return baseURL.appendingPathComponent("NiceTextEditor", isDirectory: true)
    }
}

@MainActor
private final class FontPanelCoordinator: NSObject, ObservableObject {
    @Published var selectedFontName = "SF Pro"

    func show(selectedFontName: String) {
        self.selectedFontName = selectedFontName
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.action = #selector(changeFont(_:))
        fontManager.setSelectedFont(resolvedFont(), isMultiple: false)
        NSFontPanel.shared.orderFront(nil)
    }

    @objc private func changeFont(_ sender: NSFontManager) {
        let convertedFont = sender.convert(resolvedFont())
        selectedFontName = convertedFont.fontName
    }

    private func resolvedFont() -> NSFont {
        let requested = selectedFontName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !requested.isEmpty, let font = NSFont(name: requested, size: 15) {
            return font
        }
        return NSFont.systemFont(ofSize: 15)
    }
}

private struct ShortcutChoices: View {
    var body: some View {
        Text("Shift Return").tag("shift-return")
        Text("Command Return").tag("command-return")
        Text("Command Shift Return").tag("command-shift-return")
        Text("Command E").tag("command-e")
        Text("Command Shift E").tag("command-shift-e")
        Text("Command Option E").tag("command-option-e")
    }
}
