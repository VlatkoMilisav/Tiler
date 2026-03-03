import AppKit

/// Tracks global mouse/keyboard events and drives the grid overlay / window snapping.
///
/// State machine:
///   idle → (leftMouseDown) → dragging
///   dragging → (modifier key) → gridActive
///   gridActive → (mouseMoved / leftMouseDragged) → update selection
///   gridActive → (leftMouseUp) → snap + idle
class EventMonitor {
    private enum State {
        case idle
        case dragging
        case gridActive(window: AXUIElement?)
    }

    private var state: State = .idle
    private var monitors: [Any] = []
    private let grid: GridWindowController
    private var capturedWindow: AXUIElement?
    private var lastMovedFrame: CGRect?

    init(gridWindowController: GridWindowController) {
        self.grid = gridWindowController
    }

    func start() {
        let lmbDown = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self else { return }
            self.state = .dragging
        }

        let lmbUp = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self else { return }
            if case .gridActive = self.state {
                self.snapAndReset()
            } else {
                self.state = .idle
                self.capturedWindow = nil
            }
        }

        let flagsChanged = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let mod = Settings.activationModifier
            guard mod != .rightClick, mod != .space else { return }
            guard event.modifierFlags.contains(mod.flags) else { return }
            switch self.state {
            case .dragging:
                self.activateGrid()
            case .gridActive:
                // Re-pressing the trigger resets the start cell so the user can
                // re-draw the selection from the current cursor position.
                self.grid.setStartCell(at: NSEvent.mouseLocation)
            case .idle:
                break
            }
        }

        let rmbDown = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
            guard let self else { return }
            if Settings.activationModifier == .rightClick, case .dragging = self.state {
                self.activateGrid()
            }
        }

        let keyDown = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            guard Settings.activationModifier == .space, event.keyCode == 49 else { return }
            if case .dragging = self.state {
                self.activateGrid()
            }
        }

        let moved = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] _ in
            guard let self, case .gridActive(let window) = self.state else { return }
            self.grid.updateEndCell(at: NSEvent.mouseLocation)
            guard !self.grid.isConstrained,
                  self.grid.isMultiCellSelection,
                  let win = window,
                  let frame = self.grid.selectedWindowFrame(),
                  frame != self.lastMovedFrame else { return }
            self.lastMovedFrame = frame
            WindowMover.move(win, to: frame)
        }

        monitors = [lmbDown, lmbUp, flagsChanged, rmbDown, keyDown, moved].compactMap { $0 }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        state = .idle
        capturedWindow = nil
        lastMovedFrame = nil
    }

    // MARK: - Private

    private func activateGrid() {
        let mousePos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mousePos) }) else { return }
        // Use the frontmost app's focused window — this is always the window being
        // dragged, and is more reliable than a cursor-position AX hit-test which
        // can return nil if the cursor has drifted off the window mid-drag.
        let window = frontmostFocusedWindow() ?? WindowMover.windowElement(at: mousePos)
        capturedWindow = window
        let minSize = window.flatMap { WindowMover.minimumSize(of: $0) }
        grid.show(on: screen)
        grid.setWindowMinSize(minSize)
        grid.setStartCell(at: mousePos)
        state = .gridActive(window: window)
    }

    private func frontmostFocusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
        var win: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &win) == .success,
              let w = win as! AXUIElement? else { return nil }
        return w
    }

    private func snapAndReset() {
        guard case .gridActive(let window) = state else { return }

        if let win = window, let frame = grid.selectedWindowFrame() {
            if AXIsProcessTrusted() {
                WindowMover.move(win, to: frame)
                if let actual = WindowMover.actualFrame(of: win) {
                    grid.updateSelectionToMatch(actualFrame: actual)
                }
            } else {
                // Permissions were revoked (e.g. after a reinstall). Re-prompt so
                // the user knows to re-grant in System Settings → Accessibility.
                let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                AXIsProcessTrustedWithOptions(opts as CFDictionary)
            }
        }

        grid.hide()
        state = .idle
        capturedWindow = nil
        lastMovedFrame = nil
    }
}
