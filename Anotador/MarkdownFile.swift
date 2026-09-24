import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownText = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}

struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownText, .plainText, .text] }
    static var writableContentTypes: [UTType] { [.markdownText, .plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
