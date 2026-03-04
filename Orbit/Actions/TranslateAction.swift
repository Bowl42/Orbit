import AppKit
import ApplicationServices

struct TranslateAction: OrbitAction {
    let id: String
    let name: String = "Translate"
    var subtitle: String? { "Translate selected text" }

    var icon: ActionIcon {
        .sfSymbol(name: "translate")
    }

    func execute() async {
        let text = await getSelectedText()
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        await showPopup(text: text)
    }

    // MARK: - Get Selected Text

    @MainActor
    private func getSelectedText() -> String? {
        // Try Accessibility API first
        if let text = getSelectedTextViaAccessibility() {
            return text
        }
        // Fallback: simulate Cmd+C
        return getSelectedTextViaClipboard()
    }

    private func getSelectedTextViaAccessibility() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, let element = focusedElement else { return nil }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
        guard textResult == .success, let text = selectedText as? String, !text.isEmpty else { return nil }
        return text
    }

    private func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        // Save current clipboard
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> (NSPasteboard.PasteboardType, Data)? in
            guard let type = item.types.first, let data = item.data(forType: type) else { return nil }
            return (type, data)
        } ?? []

        pasteboard.clearContents()

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c'
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Brief wait for clipboard to populate
        Thread.sleep(forTimeInterval: 0.1)

        let text = pasteboard.string(forType: .string)

        // Restore clipboard
        pasteboard.clearContents()
        for (type, data) in savedItems {
            pasteboard.setData(data, forType: type)
        }

        return text
    }

    // MARK: - Show Popup

    @MainActor
    private func showPopup(text: String) {
        let mouseLocation = NSEvent.mouseLocation
        _ = TranslationPopupPanel(sourceText: text, at: mouseLocation)
    }
}
