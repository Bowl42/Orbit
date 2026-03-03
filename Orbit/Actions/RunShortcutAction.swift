import Foundation

struct RunShortcutAction: OrbitAction {
    let id: String
    let name: String
    var subtitle: String? { nil }

    var icon: ActionIcon {
        .sfSymbol(name: "command.square.fill")
    }

    func execute() async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            print("Shortcut failed (\(name)): \(error)")
        }
    }
}
