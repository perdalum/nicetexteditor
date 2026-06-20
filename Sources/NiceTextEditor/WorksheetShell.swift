import Foundation

@MainActor
final class WorksheetShell: ObservableObject {
    enum ShellError: LocalizedError {
        case busy
        case launchFailed
        case writeFailed
        case missingOutputMarker
        case reset

        var errorDescription: String? {
            switch self {
            case .busy:
                return "The worksheet shell is still running the previous command."
            case .launchFailed:
                return "Could not start /bin/zsh for this document."
            case .writeFailed:
                return "Could not send text to the worksheet shell."
            case .missingOutputMarker:
                return "The worksheet shell returned an incomplete response."
            case .reset:
                return "The worksheet shell was reset."
            }
        }
    }

    private struct PendingCommand {
        let marker: String
        let continuation: CheckedContinuation<String, Error>
    }

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var pendingCommand: PendingCommand?
    private var outputBuffer = ""
    private var zshEnvironmentDirectory: URL?

    deinit {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        if let zshEnvironmentDirectory {
            try? FileManager.default.removeItem(at: zshEnvironmentDirectory)
        }
    }

    func execute(_ commandText: String) async throws -> String {
        try await runInShell(commandText)
    }

    func executeStdoutOnly(_ commandText: String) async throws -> String {
        let script = """
        {
        \(commandText)
        } 2>/dev/null
        """
        return try await runInShell(script)
    }

    func runPipeline(_ command: String, stdin: String) async throws -> String {
        let temporaryFileURL = try writeTemporaryStandardInput(stdin)
        let script = """
        {
        \(command)
        } < \(shellQuotedPath(temporaryFileURL.path))
        rm -f \(shellQuotedPath(temporaryFileURL.path))
        """
        return try await runInShell(script)
    }

    func reset() throws {
        stopShell(resumePendingWith: ShellError.reset)
        try startShellIfNeeded()
    }

    private func runInShell(_ script: String) async throws -> String {
        try startShellIfNeeded()

        guard pendingCommand == nil else { throw ShellError.busy }
        guard let inputHandle = inputPipe?.fileHandleForWriting else { throw ShellError.launchFailed }
        outputBuffer = ""

        let marker = "__NICE_TEXT_EDITOR_DONE_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))__"
        var command = script
        if !command.hasSuffix("\n") {
            command.append("\n")
        }
        command.append("printf '\(marker)'\n")

        return try await withCheckedThrowingContinuation { continuation in
            pendingCommand = PendingCommand(marker: marker, continuation: continuation)

            guard let data = command.data(using: .utf8) else {
                pendingCommand = nil
                continuation.resume(throwing: ShellError.writeFailed)
                return
            }

            do {
                try inputHandle.write(contentsOf: data)
            } catch {
                pendingCommand = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private func startShellIfNeeded() throws {
        if let process, process.isRunning { return }

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputBuffer = ""

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = []
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "dumb"
        environment["ZDOTDIR"] = try writeZshEnvironmentDirectory().path
        process.environment = environment

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in
                self?.consumeOutput(data)
            }
        }

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed
        }

        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.process = process
    }

    private func stopShell(resumePendingWith error: Error?) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil

        if let error, let pendingCommand {
            self.pendingCommand = nil
            pendingCommand.continuation.resume(throwing: error)
        } else {
            pendingCommand = nil
        }

        inputPipe?.fileHandleForWriting.closeFile()
        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe = nil
        outputBuffer = ""
        removeZshEnvironmentDirectory()
    }

    private func writeZshEnvironmentDirectory() throws -> URL {
        removeZshEnvironmentDirectory()

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NiceTextEditor", isDirectory: true)
            .appendingPathComponent("zshenv-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let zshenvURL = directory.appendingPathComponent(".zshenv")
        let startupFileURL = try ensureWorksheetStartupFile()
        let contents = """
        # Generated by NiceTextEditor.
        source \(shellQuotedPath(startupFileURL.path))
        """

        try contents.write(to: zshenvURL, atomically: true, encoding: .utf8)
        zshEnvironmentDirectory = directory
        return directory
    }

    private func ensureWorksheetStartupFile() throws -> URL {
        let directory = try applicationSupportDirectory()
        let startupFileURL = directory.appendingPathComponent("WorksheetStartup.zsh")

        if !FileManager.default.fileExists(atPath: startupFileURL.path) {
            let contents = """
            # NiceTextEditor worksheet shell startup file
            #
            # This file is sourced before each document shell starts.
            # Use it for PATH, aliases, functions, exports, and shell options.
            #
            # Example:
            # export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            #
            # After editing this file, use Worksheet > Reset Document Shell
            # in open documents to apply changes there.
            
            """
            try contents.write(to: startupFileURL, atomically: true, encoding: .utf8)
        }

        return startupFileURL
    }

    private func applicationSupportDirectory() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appendingPathComponent("NiceTextEditor", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func removeZshEnvironmentDirectory() {
        guard let zshEnvironmentDirectory else { return }
        try? FileManager.default.removeItem(at: zshEnvironmentDirectory)
        self.zshEnvironmentDirectory = nil
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(String(decoding: data, as: UTF8.self))
        guard let pendingCommand else { return }
        guard let markerRange = outputBuffer.range(of: pendingCommand.marker) else { return }

        let output = String(outputBuffer[..<markerRange.lowerBound])
        outputBuffer.removeSubrange(outputBuffer.startIndex..<markerRange.upperBound)
        self.pendingCommand = nil
        pendingCommand.continuation.resume(returning: output)
    }

    private func writeTemporaryStandardInput(_ string: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NiceTextEditor", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("worksheet-stdin-\(UUID().uuidString).txt")
        try string.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func shellQuotedPath(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
