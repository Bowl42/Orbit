import AppKit

struct OpenURLAction: OrbitAction {
    let id: String
    let name: String
    let urlString: String
    var subtitle: String? { urlString }

    var icon: ActionIcon {
        .sfSymbol(name: "globe")
    }

    func execute() async {
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
