import Foundation

enum OutputPublisher {
    static func publish(_ markdown: String, to destination: URL, allowingOverwrite: Bool) throws {
        let fileManager = FileManager.default
        let input = destination.standardizedFileURL
        let attributes = try? fileManager.attributesOfItem(atPath: input.path)
        if attributes?[.type] as? FileAttributeType == .typeSymbolicLink {
            throw ConversionError.invalidOutput(input)
        }
        if fileManager.fileExists(atPath: input.path) {
            guard allowingOverwrite else { throw ConversionError.outputExists(input) }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: input.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                throw ConversionError.invalidOutput(input)
            }
        }
        if input.path.isEmpty || input.path == "/" { throw ConversionError.invalidOutput(input) }
        let parent = input.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parent.path) else { throw ConversionError.invalidOutput(input) }
        let temporary = parent.appendingPathComponent(".\(input.lastPathComponent).\(UUID().uuidString).tmp")
        try Data(markdown.utf8).write(to: temporary, options: .atomic)
        defer { try? fileManager.removeItem(at: temporary) }
        if allowingOverwrite && fileManager.fileExists(atPath: input.path) {
            _ = try fileManager.replaceItemAt(input, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: input)
        }
    }
}
