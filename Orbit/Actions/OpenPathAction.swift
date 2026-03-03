import AppKit

struct OpenPathAction: OrbitAction {
    let id: String
    let name: String
    let path: String
    var subtitle: String? { path }

    var icon: ActionIcon {
        .sfSymbol(name: "folder.fill")
    }

    func execute() async {
        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        NSWorkspace.shared.open(url)
    }
}
