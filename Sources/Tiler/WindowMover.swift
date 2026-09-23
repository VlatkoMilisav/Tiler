import AppKit
import ApplicationServices

struct WindowMover {
    // MARK: - Find window under cursor

    /// Returns the AXUIElement for the window at the given NSScreen-coordinate point.
    static func windowElement(at screenPoint: CGPoint) -> AXUIElement? {
        let quartzPoint = toQuartz(screenPoint)

        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(quartzPoint.x), Float(quartzPoint.y), &element) == .success,
              let el = element else { return nil }

        // Fast path: element is a window or has a direct kAXWindowAttribute (crosses process boundaries)
        if let win = windowAncestor(of: el) { return win }

        // Fallback for apps like Firefox whose content lives in a child process:
        // get the PID from the element and ask the app for its focused window.
        var pid: pid_t = 0
        guard AXUIElementGetPid(el, &pid) == .success else { return nil }

        let app = AXUIElementCreateApplication(pid)

        var focusedWin: AnyObject?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWin) == .success,
           let win = focusedWin as! AXUIElement? {
            return win
        }

        var windows: AnyObject?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows) == .success,
           let winList = windows as? [AXUIElement],
           let first = winList.first {
            return first
        }

        return nil
    }

    // MARK: - Move & resize

    /// Moves and resizes `window` to `frame` (NSScreen coordinates, bottom-left origin).
    static func move(_ window: AXUIElement, to frame: CGRect) {
        let axY = primaryScreenHeight - (frame.minY + frame.height)

        var position = CGPoint(x: frame.minX, y: axY)
        var size = CGSize(width: frame.width, height: frame.height)
        guard let posValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return }

        withEnhancedUIDisabled(for: window) {
            // Size → position → size: the first resize keeps the move from being clamped
            // at the screen edge, the second one fixes any size clamped at the old position.
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    /// With AXEnhancedUserInterface on (set by VoiceOver and some AX clients), apps like
    /// Firefox and Chromium animate or partially ignore AX frame changes. Turn it off
    /// for the duration of the move and restore it afterwards.
    private static func withEnhancedUIDisabled(for window: AXUIElement, _ body: () -> Void) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return body() }
        let app = AXUIElementCreateApplication(pid)
        let attr = "AXEnhancedUserInterface" as CFString

        var raw: AnyObject?
        let wasEnabled = AXUIElementCopyAttributeValue(app, attr, &raw) == .success
            && (raw as? Bool) == true
        if wasEnabled { AXUIElementSetAttributeValue(app, attr, false as CFTypeRef) }
        body()
        if wasEnabled { AXUIElementSetAttributeValue(app, attr, true as CFTypeRef) }
    }

    // MARK: - Read minimum size

    static func minimumSize(of window: AXUIElement) -> CGSize? {
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(window, "AXMinSize" as CFString, &raw) == .success,
              let val = raw as! AXValue?,
              case var size = CGSize.zero,
              AXValueGetValue(val, .cgSize, &size) else { return nil }
        return size
    }

    // MARK: - Read actual frame

    /// Returns the real frame of `window` in NSScreen coordinates after the OS
    /// has applied minimum-size constraints.
    static func actualFrame(of window: AXUIElement) -> CGRect? {
        var posRaw: AnyObject?
        var sizeRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRaw) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString,     &sizeRaw) == .success,
              let posVal  = posRaw as! AXValue?,
              let sizeVal = sizeRaw as! AXValue?
        else { return nil }

        var position = CGPoint.zero
        var size     = CGSize.zero
        guard AXValueGetValue(posVal, .cgPoint, &position),
              AXValueGetValue(sizeVal, .cgSize,  &size)
        else { return nil }

        let nsY = primaryScreenHeight - position.y - size.height
        return CGRect(x: position.x, y: nsY, width: size.width, height: size.height)
    }

    // MARK: - Private helpers

    /// Height of the primary screen (index 0), used for Quartz ↔ NSScreen coordinate conversion.
    /// Falls back to 0 if no screens are available (should never happen on a running Mac).
    private static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    private static func toQuartz(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    private static func windowAncestor(of element: AXUIElement) -> AXUIElement? {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if (role as? String) == kAXWindowRole as String { return element }

        var win: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &win) == .success,
           let winEl = win as! AXUIElement? {
            return winEl
        }

        var parent: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent) == .success,
              let parentEl = parent as! AXUIElement? else { return nil }

        return windowAncestor(of: parentEl)
    }
}
