import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText, .text, .utf8PlainText, .utf16PlainText, .sourceCode, .data]
    }

    static var writableContentTypes: [UTType] {
        [.plainText, .text]
    }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        if let utf8 = String(data: data, encoding: .utf8) {
            text = utf8
        } else if let utf16 = String(data: data, encoding: .utf16) {
            text = utf16
        } else if let macRoman = String(data: data, encoding: .macOSRoman) {
            text = macRoman
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
