import AppKit

class GridWindowController {
    private var panel: NSPanel?
    private var gridView: GridView?
    private var vev: NSVisualEffectView?
    private(set) var activeScreen: NSScreen?
    private var windowMinSize: CGSize?

    var isVisible: Bool { panel?.isVisible ?? false }
    var isConstrained: Bool { gridView?.isConstrained ?? false }
    var isMultiCellSelection: Bool {
        guard let s = gridView?.startCell, let e = gridView?.endCell else { return false }
        return s.col != e.col || s.row != e.row
    }

    func setWindowMinSize(_ size: CGSize?) {
        windowMinSize = size
    }

    func show(on screen: NSScreen) {
        activeScreen = screen

        if panel == nil {
            let p = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.level = .screenSaver
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            // Root content view — plain, fully transparent
            let root = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
            root.autoresizingMask = [.width, .height]

            // Blur layer — sibling of gridView so its alpha doesn't affect the grid
            let effectView = NSVisualEffectView(frame: root.bounds)
            effectView.autoresizingMask = [.width, .height]
            effectView.material = .hudWindow
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.appearance = NSAppearance(named: .darkAqua)
            root.addSubview(effectView)

            // Grid layer — drawn on top, always fully opaque
            let gv = GridView(frame: root.bounds)
            gv.autoresizingMask = [.width, .height]
            root.addSubview(gv)

            p.contentView = root
            panel = p
            gridView = gv
            vev = effectView
        } else {
            panel?.setFrame(screen.frame, display: false)
            vev?.frame = CGRect(origin: .zero, size: screen.frame.size)
            let gv = gridView!
            gv.columns = Settings.columns
            gv.rows = Settings.rows
            gv.frame = CGRect(origin: .zero, size: screen.frame.size)
        }

        vev?.alphaValue = CGFloat(Settings.overlayBlur)
        gridView?.updateSelection(start: nil, end: nil)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        gridView?.isConstrained = false
        gridView?.updateSelection(start: nil, end: nil)
        activeScreen = nil
        windowMinSize = nil
    }

    func setStartCell(at screenPoint: CGPoint) {
        guard let screen = activeScreen, let gv = gridView else { return }
        let vp = viewPoint(from: screenPoint, screen: screen)
        let cell = gv.cell(at: vp)
        gv.updateSelection(start: cell, end: cell)
    }

    func updateEndCell(at screenPoint: CGPoint) {
        guard let screen = activeScreen, let gv = gridView else { return }
        let vp = viewPoint(from: screenPoint, screen: screen)
        let cell = gv.cell(at: vp)

        if let minSize = windowMinSize, let start = gv.startCell {
            let targetFrame = gv.frameFor(start: start, end: cell, screenFrame: screen.frame)
            gv.isConstrained = targetFrame.width < minSize.width || targetFrame.height < minSize.height
        } else {
            gv.isConstrained = false
        }

        gv.updateSelection(start: gv.startCell ?? cell, end: cell)
    }

    /// After the OS clamps a window to its minimum size, call this to snap the
    /// grid highlight back to the cells that the actual frame covers.
    func updateSelectionToMatch(actualFrame: CGRect) {
        guard let screen = activeScreen, let gv = gridView else { return }
        let cellW = screen.frame.width  / CGFloat(gv.columns)
        let cellH = screen.frame.height / CGFloat(gv.rows)

        let minCol = max(0, min(gv.columns - 1, Int((actualFrame.minX - screen.frame.minX) / cellW)))
        let minRow = max(0, min(gv.rows    - 1, Int((actualFrame.minY - screen.frame.minY) / cellH)))
        let maxCol = max(minCol, min(gv.columns - 1, Int((actualFrame.maxX - screen.frame.minX - 1) / cellW)))
        let maxRow = max(minRow, min(gv.rows    - 1, Int((actualFrame.maxY - screen.frame.minY - 1) / cellH)))

        gv.updateSelection(start: (col: minCol, row: minRow), end: (col: maxCol, row: maxRow))
    }

    func selectedWindowFrame() -> CGRect? {
        guard let screen = activeScreen,
              let gv = gridView,
              let start = gv.startCell,
              let end = gv.endCell else { return nil }
        return gv.frameFor(start: start, end: end, screenFrame: screen.frame)
    }

    // MARK: - Private

    private func viewPoint(from screenPoint: CGPoint, screen: NSScreen) -> CGPoint {
        return CGPoint(
            x: screenPoint.x - screen.frame.minX,
            y: screenPoint.y - screen.frame.minY
        )
    }
}
