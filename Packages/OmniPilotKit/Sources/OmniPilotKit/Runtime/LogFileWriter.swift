import Foundation

/// Appends log lines to a single rotating file under `~/Library/Logs`.
public final class LogFileWriter: @unchecked Sendable {
    public let fileURL: URL

    private let queue = DispatchQueue(label: "com.drofyn.omnipilot.logfile")
    private let maxBytes: Int
    private let formatter: ISO8601DateFormatter

    public init(fileURL: URL, maxBytes: Int = 2 * 1024 * 1024) {
        self.fileURL = fileURL
        self.maxBytes = maxBytes
        self.formatter = ISO8601DateFormatter()

        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    public func append(_ line: String, at date: Date = Date()) {
        queue.async { [weak self] in
            guard let self else { return }
            self.rotateIfNeeded()
            let entry = "[\(self.formatter.string(from: date))] \(line)\n"
            guard let data = entry.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }
    }

    public func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            try? "".write(to: self.fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func rotateIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int,
              size > maxBytes else { return }
        let backup = fileURL.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: fileURL, to: backup)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }
}
