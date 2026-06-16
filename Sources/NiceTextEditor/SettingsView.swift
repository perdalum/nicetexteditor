import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("proportionalFontName") private var proportionalFontName = "SF Pro"
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("fullScreenTextWidthPercent") private var fullScreenTextWidthPercent = 70.0
    @AppStorage("executeSelectionShortcut") private var executeSelectionShortcut = "shift-return"
    @AppStorage("replaceSelectionWithPipelineShortcut") private var replaceSelectionWithPipelineShortcut = "command-r"
    @AppStorage("insertPipelineAfterSelectionShortcut") private var insertPipelineAfterSelectionShortcut = "command-shift-r"

    var body: some View {
        Form {
            Section("Editor Font") {
                Picker("Proportional font", selection: $proportionalFontName) {
                    Text("SF Pro (system)").tag("SF Pro")
                    Text("New York").tag("New York")
                    Text("Helvetica Neue").tag("Helvetica Neue")
                    Text("Georgia").tag("Georgia")
                    Text("Times New Roman").tag("Times New Roman")
                }
                .pickerStyle(.menu)

                TextField("Font name", text: $proportionalFontName)
                    .textFieldStyle(.roundedBorder)
                    .help("Enter any installed PostScript font name or family name. SF Pro uses the macOS system font.")

                Stepper(value: $editorFontSize, in: 9...36, step: 1) {
                    Text("Size: \(Int(editorFontSize)) pt")
                }
            }

            Section("Full Screen") {
                Slider(value: $fullScreenTextWidthPercent, in: 40...100, step: 5) {
                    Text("Text width")
                } minimumValueLabel: {
                    Text("40%")
                } maximumValueLabel: {
                    Text("100%")
                }

                Stepper(value: $fullScreenTextWidthPercent, in: 40...100, step: 5) {
                    Text("Text width: \(Int(fullScreenTextWidthPercent))% of screen")
                }
                .help("When a document window is full screen, wrap text to this percentage of the screen width.")
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
                Text("Lines between .VB and .VE are displayed in SF Mono. The file remains plain text and the markers are preserved.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 560)
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

private struct ShortcutChoices: View {
    var body: some View {
        Text("Shift Return").tag("shift-return")
        Text("Command Return").tag("command-return")
        Text("Command Shift Return").tag("command-shift-return")
        Text("Command R").tag("command-r")
        Text("Command Shift R").tag("command-shift-r")
        Text("Command Option R").tag("command-option-r")
    }
}
