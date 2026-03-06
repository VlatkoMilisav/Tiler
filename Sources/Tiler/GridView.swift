import AppKit

class GridView: NSView {
    var columns: Int = Settings.columns
    var rows: Int = Settings.rows

    private(set) var startCell: (col: Int, row: Int)?
    private(set) var endCell: (col: Int, row: Int)?
    var isConstrained: Bool = false

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let cellW = bounds.width / CGFloat(columns)
        let cellH = bounds.height / CGFloat(rows)

        // Selection highlight
        if let start = startCell, let end = endCell {
            let minCol = min(start.col, end.col)
            let maxCol = max(start.col, end.col)
            let minRow = min(start.row, end.row)
            let maxRow = max(start.row, end.row)

            let selRect = CGRect(
                x: CGFloat(minCol) * cellW,
                y: CGFloat(minRow) * cellH,
                width: CGFloat(maxCol - minCol + 1) * cellW,
                height: CGFloat(maxRow - minRow + 1) * cellH
            )

            let cornerRadius: CGFloat = 10
            let accentColor: NSColor = isConstrained ? .systemGray : Settings.gridColor

            // 1. Outer glow — expanded rounded rect at 10% alpha
            let glowRect = selRect.insetBy(dx: -4, dy: -4)
            let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: cornerRadius + 4, yRadius: cornerRadius + 4)
            accentColor.withAlphaComponent(0.10).setFill()
            glowPath.fill()

            // 2. Clipped glass body — vertical gradient fill
            NSGraphicsContext.saveGraphicsState()
            let bodyClip = NSBezierPath(roundedRect: selRect, xRadius: cornerRadius, yRadius: cornerRadius)
            bodyClip.setClip()

            let bodyGradient = NSGradient(
                colors: [
                    accentColor.withAlphaComponent(0.45),
                    accentColor.withAlphaComponent(0.18)
                ],
                atLocations: [0.0, 1.0],
                colorSpace: .genericRGB
            )
            // NSGradient draws top→bottom when angle is 270° (from top)
            bodyGradient?.draw(in: selRect, angle: 270)

            // 3. Specular sheen — white gradient over top 35% of rect
            let sheenHeight = selRect.height * 0.35
            let sheenRect = CGRect(
                x: selRect.minX,
                y: selRect.maxY - sheenHeight,
                width: selRect.width,
                height: sheenHeight
            )
            let sheenGradient = NSGradient(
                colors: [
                    NSColor.white.withAlphaComponent(0.18),
                    NSColor.clear
                ],
                atLocations: [0.0, 1.0],
                colorSpace: .genericRGB
            )
            sheenGradient?.draw(in: sheenRect, angle: 270)

            NSGraphicsContext.restoreGraphicsState()

            // 4. Border — 1.5px rounded rect inset by 0.75pt
            let borderPath = NSBezierPath(roundedRect: selRect.insetBy(dx: 0.75, dy: 0.75), xRadius: cornerRadius, yRadius: cornerRadius)
            borderPath.lineWidth = 1.5
            accentColor.withAlphaComponent(0.90).setStroke()
            borderPath.stroke()

            // 5. Inner highlight line — 1px horizontal line 1pt below the top edge
            NSGraphicsContext.saveGraphicsState()
            let innerClip = NSBezierPath(roundedRect: selRect, xRadius: cornerRadius, yRadius: cornerRadius)
            innerClip.setClip()

            let lineY = selRect.maxY - 1
            let highlightLine = NSBezierPath()
            highlightLine.lineWidth = 1
            highlightLine.move(to: CGPoint(x: selRect.minX + cornerRadius, y: lineY))
            highlightLine.line(to: CGPoint(x: selRect.maxX - cornerRadius, y: lineY))
            NSColor.white.withAlphaComponent(0.30).setStroke()
            highlightLine.stroke()

            NSGraphicsContext.restoreGraphicsState()
        }

        // Grid lines — 0.5px accent color at 0.25 alpha
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 0.5
        Settings.gridColor.withAlphaComponent(0.25).setStroke()

        for col in 0...columns {
            let x = CGFloat(col) * cellW
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.line(to: CGPoint(x: x, y: bounds.height))
        }
        for row in 0...rows {
            let y = CGFloat(row) * cellH
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.line(to: CGPoint(x: bounds.width, y: y))
        }
        gridPath.stroke()
    }

    func cell(at viewPoint: CGPoint) -> (col: Int, row: Int) {
        let col = max(0, min(columns - 1, Int(viewPoint.x / (bounds.width / CGFloat(columns)))))
        let row = max(0, min(rows - 1, Int(viewPoint.y / (bounds.height / CGFloat(rows)))))
        return (col, row)
    }

    func frameFor(start: (col: Int, row: Int), end: (col: Int, row: Int), screenFrame: CGRect) -> CGRect {
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)

        let cellW = screenFrame.width / CGFloat(columns)
        let cellH = screenFrame.height / CGFloat(rows)

        // Returns frame in NSScreen coordinates (bottom-left origin)
        return CGRect(
            x: screenFrame.minX + CGFloat(minCol) * cellW,
            y: screenFrame.minY + CGFloat(minRow) * cellH,
            width: CGFloat(maxCol - minCol + 1) * cellW,
            height: CGFloat(maxRow - minRow + 1) * cellH
        )
    }

    func updateSelection(start: (col: Int, row: Int)?, end: (col: Int, row: Int)?) {
        startCell = start
        endCell = end
        needsDisplay = true
    }
}
