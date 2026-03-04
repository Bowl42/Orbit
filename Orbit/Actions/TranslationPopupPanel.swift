import AppKit
import SwiftUI
import Translation

// MARK: - Panel

final class TranslationPopupPanel: NSPanel {

    private var mouseMonitor: Any?

    init(sourceText: String, at screenPoint: CGPoint) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        worksWhenModal = true

        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .stationary]

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        animationBehavior = .utilityWindow

        let view = TranslationPopupView(sourceText: sourceText) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingView(rootView: view.ignoresSafeArea())
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = hosting

        // Position near mouse, clamped to screen
        let size = CGSize(width: 320, height: 200)
        var origin = CGPoint(x: screenPoint.x + 12, y: screenPoint.y - size.height - 12)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(screenPoint) }) ?? NSScreen.main {
            let vis = screen.visibleFrame
            if origin.x + size.width > vis.maxX { origin.x = screenPoint.x - size.width - 12 }
            if origin.y < vis.minY { origin.y = screenPoint.y + 12 }
            origin.x = max(origin.x, vis.minX)
        }
        setFrame(NSRect(origin: origin, size: size), display: false)
        orderFront(nil)

        // Dismiss on click outside
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            let loc = NSEvent.mouseLocation
            if !self.frame.contains(loc) {
                self.dismiss()
            }
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            dismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    func dismiss() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.orderOut(nil)
            }
        })
    }
}

// MARK: - SwiftUI Content

private struct TranslationPopupView: View {
    let sourceText: String
    let onDismiss: () -> Void

    @State private var translatedText: String = ""
    @State private var isTranslating = true
    @State private var errorMessage: String?
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var showSource = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "translate")
                    .foregroundStyle(.secondary)
                Text("Translation")
                    .font(.headline)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if isTranslating {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            } else {
                // Source (collapsible)
                DisclosureGroup(isExpanded: $showSource) {
                    Text(sourceText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(4)
                } label: {
                    Text("Original")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Result
                Text(translatedText)
                    .font(.body)
                    .textSelection(.enabled)

                // Copy button
                HStack {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translatedText, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(width: 320, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Detect language direction
            let containsCJK = sourceText.unicodeScalars.contains {
                let v = $0.value
                return (0x4E00...0x9FFF).contains(v) ||    // CJK Unified
                       (0x3400...0x4DBF).contains(v) ||    // CJK Extension A
                       (0x3000...0x303F).contains(v) ||    // CJK Symbols
                       (0x3040...0x309F).contains(v) ||    // Hiragana
                       (0x30A0...0x30FF).contains(v) ||    // Katakana
                       (0xAC00...0xD7AF).contains(v)       // Hangul
            }
            let source: Locale.Language = containsCJK ? .init(identifier: "zh-Hans") : .init(identifier: "en")
            let target: Locale.Language = containsCJK ? .init(identifier: "en") : .init(identifier: "zh-Hans")
            translationConfig = .init(source: source, target: target)
        }
        .translationTask(translationConfig) { session in
            nonisolated(unsafe) let s = session
            do {
                let response = try await s.translate(sourceText)
                await MainActor.run {
                    translatedText = response.targetText
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isTranslating = false
                }
            }
        }
    }
}
