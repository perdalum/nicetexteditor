import SwiftUI

struct SettingsView: View {
    @AppStorage("proportionalFontName") private var proportionalFontName = "SF Pro"
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("fullScreenTextWidthPercent") private var fullScreenTextWidthPercent = 70.0

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

            Section("Markup") {
                Text("Lines between .VB and .VE are displayed in SF Mono. The file remains plain text and the markers are preserved.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
