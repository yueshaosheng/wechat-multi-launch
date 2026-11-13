import Foundation
import Combine

// Drives the embedded WeChat-Multi-Launch.command non-interactively: the GUI
// collects the choices, feeds them to the script's stdin, and turns its
// coloured console output into progress and a live log.
final class ScriptRunner: ObservableObject {
    enum State { case idle, running, success, failed, partial }

    @Published var state: State = .idle
    @Published var log: String = ""
    @Published var progress: Double = 0
    @Published var statusText: String = ""
    @Published var exitCode: Int32 = 0

    private var process: Process?
    private let ansi = try! NSRegularExpression(pattern: "\u{001B}\\[[0-9;]*[A-Za-z]|\u{001B}c")
    private let cloneMarker = try! NSRegularExpression(pattern: "(?:Building|正在构建) WeChat([0-9])\\.app")
    private let stepMarker = try! NSRegularExpression(pattern: "\\[([0-9])/7\\]")

    private var scriptURL: URL? {
        Bundle.main.url(forResource: "WeChat-Multi-Launch", withExtension: "command")
    }

    func run(language: Int, total: Int, iconChoice: String) {
        guard let scriptURL else {
            state = .failed
            log = "Missing bundled script."
            return
        }
        log = ""
        progress = 0
        exitCode = 0
        statusText = ""
        state = .running

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = [scriptURL.path]
        proc.currentDirectoryURL = scriptURL.deletingLastPathComponent()

        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        proc.standardInput = input
        proc.standardOutput = output
        proc.standardError = error

        let ingest: (Data) -> Void = { [weak self] data in
            guard let self, let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            let clean = self.stripANSI(text)
            DispatchQueue.main.async {
                self.log += clean
                self.updateProgress(total: total)
                self.updateStatus()
            }
        }
        output.fileHandleForReading.readabilityHandler = { ingest($0.availableData) }
        error.fileHandleForReading.readabilityHandler = { ingest($0.availableData) }

        proc.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                guard let self else { return }
                self.exitCode = finished.terminationStatus
                switch finished.terminationStatus {
                case 0:
                    self.state = .success
                    self.progress = 1
                case 2:
                    self.state = .partial
                default:
                    self.state = .failed
                }
                self.process = nil
            }
        }

        do {
            try proc.run()
        } catch {
            state = .failed
            log += "Could not start the script: \(error.localizedDescription)\n"
            return
        }
        process = proc

        // Language, total, icon choice, confirm, then the closing Return prompt.
        let answers = "\(language)\n\(total)\n\(iconChoice)\ny\n\n"
        input.fileHandleForWriting.write(Data(answers.utf8))
        input.fileHandleForWriting.closeFile()
    }

    func cancel() {
        process?.terminate()
    }

    private func stripANSI(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return ansi.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private func updateProgress(total: Int) {
        let copies = max(1, total - 1)
        let clone = lastInt(cloneMarker, in: log) ?? 2
        let step = lastInt(stepMarker, in: log) ?? 0
        let done = Double((clone - 2) * 6 + min(step, 6))
        progress = min(0.99, done / Double(copies * 6 + 1))
    }

    private func updateStatus() {
        let lines = log.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        statusText = lines.last(where: { !$0.isEmpty }) ?? ""
    }

    private func lastInt(_ regex: NSRegularExpression, in text: String) -> Int? {
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard let last = matches.last, last.numberOfRanges > 1,
              let r = Range(last.range(at: 1), in: text) else { return nil }
        return Int(text[r])
    }
}