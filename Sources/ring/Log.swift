import Foundation

private let logPath = "/tmp/ring.log"
private let logQueue = DispatchQueue(label: "ring.log")

func log(_ message: String) {
    let line = "[\(timestamp())] \(message)\n"
    logQueue.sync {
        if let fh = FileHandle(forWritingAtPath: logPath) {
            fh.seekToEndOfFile()
            fh.write(line.data(using: .utf8)!)
            fh.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
    }
}

private func timestamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f.string(from: Date())
}
