import Foundation

struct ShellCommandAction: OrbitAction {
    let id: String
    let name: String
    let command: String
    var subtitle: String? { command }

    var icon: ActionIcon {
        .sfSymbol(name: "terminal.fill")
    }

    func execute() async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            print("Shell command failed: \(error)")
        }
    }
}
