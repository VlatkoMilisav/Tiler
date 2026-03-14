import AppKit
import CoreGraphics

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
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let grid: GridWindowController
    private var capturedWindow: AXUIElement?
    private var lastMovedFrame: CGRect?

    init(gridWindowController: GridWindowController) {
        self.grid = gridWindowController
    }

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartIfNeeded()
        }
    }

    private func restartIfNeeded() {
        guard let tap = eventTap else {
            stop()
            start()
            return
        }
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func stop() {
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
        state = .idle
        capturedWindow = nil
        lastMovedFrame = nil
    }

    // MARK: - Event dispatch

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            state = .dragging

        case .leftMouseUp:
            if case .gridActive = state {
                snapAndReset()
            } else {
                state = .idle
                capturedWindow = nil
            }

        case .flagsChanged:
            let mod = Settings.activationModifier
            guard mod != .rightClick, mod != .space else { return }
            let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
            guard flags.contains(mod.flags) else { return }
            switch state {
            case .dragging:
                activateGrid()
            case .gridActive:
                grid.setStartCell(at: NSEvent.mouseLocation)
            case .idle:
                break
            }

        case .rightMouseDown:
            guard Settings.activationModifier == .rightClick else { return }
            switch state {
            case .dragging:
                activateGrid()
            case .gridActive:
                grid.hide()
                state = .dragging
                lastMovedFrame = nil
            case .idle:
                break
            }

        case .keyDown:
            guard Settings.activationModifier == .space else { return }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            guard keyCode == 49, !isRepeat else { return }
            switch state {
            case .dragging:
                activateGrid()
            case .gridActive:
                grid.hide()
                state = .dragging
                lastMovedFrame = nil
            case .idle:
                break
            }

        case .mouseMoved, .leftMouseDragged:
            guard case .gridActive(let window) = state else { return }
            grid.updateEndCell(at: NSEvent.mouseLocation)
            guard Settings.liveResize,
                  !grid.isConstrained,
                  grid.isMultiCellSelection,
                  let win = window,
                  let frame = grid.selectedWindowFrame(),
                  frame != lastMovedFrame else { return }
            lastMovedFrame = frame
            WindowMover.move(win, to: frame)

        default:
            break
        }
    }

    // MARK: - Private

    private func activateGrid() {
        let mousePos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mousePos) }) else { return }
        // Prefer the window under the cursor — this correctly identifies which of
        // multiple same-app windows the user is dragging. Fall back to the
        // focused window if the cursor has already drifted off the window.
        let window = WindowMover.windowElement(at: mousePos) ?? frontmostFocusedWindow()
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
