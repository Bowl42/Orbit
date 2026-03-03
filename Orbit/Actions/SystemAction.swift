import Foundation

struct SystemAction: OrbitAction {
    let id: String
    let kind: OrbitConfig.SystemActionKind
    var name: String { kind.displayName }
    var subtitle: String? { nil }

    var icon: ActionIcon {
        .sfSymbol(name: kind.sfSymbolName)
    }

    func execute() async {
        let process = Process()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        switch kind {
        case .lockScreen:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
        case .toggleDnd:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", "Toggle Do Not Disturb"]
        case .screenshot:
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i"]
        case .sleepDisplay:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
        case .emptyTrash:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"Finder\" to empty trash"]
        }

        do {
            try process.run()
        } catch {
            print("System action failed (\(kind.rawValue)): \(error)")
        }
    }
}
