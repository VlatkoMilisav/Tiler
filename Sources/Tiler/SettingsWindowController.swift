import AppKit
import ApplicationServices
import ServiceManagement

final class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private var profilePopUp     = NSPopUpButton()
    private var nameField        = NSTextField()
    private var columnsField     = NSTextField()
    private var columnsStepper   = NSStepper()
    private var rowsField        = NSTextField()
    private var rowsStepper      = NSStepper()
    private var colorWell            = NSColorWell()
    private var hideIconCheckbox      = NSButton()
    private var launchAtLoginCheckbox = NSButton()
    private var blurSlider           = NSSlider()
    private var addRemoveSeg         = NSSegmentedControl()
    private var triggerPopUp         = NSPopUpButton()
    private var accessibilityLabel      = NSTextField()
    private var accessibilityOpenBtn    = NSButton()
    private var accessibilityRefreshBtn = NSButton()

    var onIconVisibilityChange: ((Bool) -> Void)?

    // MARK: - Init

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 378),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tiler Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Show

    func showWindow() {
        reloadProfiles()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI construction

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        profilePopUp.target = self
        profilePopUp.action = #selector(profileSelected)
        profilePopUp.translatesAutoresizingMaskIntoConstraints = false
        profilePopUp.widthAnchor.constraint(equalToConstant: 140).isActive = true

        nameField    = editableTextField()
        columnsField = numericTextField()
        rowsField    = numericTextField()

        columnsStepper.minValue = 1
        columnsStepper.maxValue = 100
        columnsStepper.increment = 1
        columnsStepper.valueWraps = false
        columnsStepper.controlSize = .mini
        columnsStepper.target = self
        columnsStepper.action = #selector(columnsStepperChanged)

        rowsStepper.minValue = 1
        rowsStepper.maxValue = 100
        rowsStepper.increment = 1
        rowsStepper.valueWraps = false
        rowsStepper.controlSize = .mini
        rowsStepper.target = self
        rowsStepper.action = #selector(rowsStepperChanged)

        triggerPopUp.addItems(withTitles: Settings.ActivationModifier.allCases.map(\.title))
        triggerPopUp.selectItem(at: Settings.activationModifier.rawValue)
        triggerPopUp.target = self
        triggerPopUp.action = #selector(triggerChanged)

        blurSlider = NSSlider(value: Settings.overlayBlur, minValue: 0, maxValue: 1,
                              target: self, action: #selector(blurChanged))
        blurSlider.translatesAutoresizingMaskIntoConstraints = false
        blurSlider.widthAnchor.constraint(equalToConstant: 130).isActive = true

        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        colorWell.color  = Settings.gridColor
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 22).isActive = true

        hideIconCheckbox = NSButton(
            checkboxWithTitle: "Hide menu bar icon",
            target: self, action: #selector(hideIconToggled)
        )

        launchAtLoginCheckbox = NSButton(
            checkboxWithTitle: "Launch at login",
            target: self, action: #selector(launchAtLoginToggled)
        )

        addRemoveSeg = NSSegmentedControl(
            labels: ["+", "−"],
            trackingMode: .momentary,
            target: self,
            action: #selector(addRemoveTapped)
        )
        addRemoveSeg.setWidth(28, forSegment: 0)
        addRemoveSeg.setWidth(28, forSegment: 1)

        let doneBtn = button("Done", action: #selector(done))
        doneBtn.keyEquivalent = "\r"
        let quitBtn = button("Quit Tiler", action: #selector(quitApp))
        let infoBtn = button("About", action: #selector(openAbout))

        accessibilityLabel = NSTextField(labelWithString: "")
        accessibilityLabel.font = .systemFont(ofSize: 11)

        accessibilityOpenBtn = button("Settings", action: #selector(openAccessibilitySettings))
        accessibilityOpenBtn.controlSize = .small

        accessibilityRefreshBtn = button("↻", action: #selector(refreshAccessibilityStatus as () -> Void))
        accessibilityRefreshBtn.controlSize = .small
        accessibilityRefreshBtn.toolTip = "Refresh permission status"

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            row([label("Profile:"),    profilePopUp, addRemoveSeg]),
            row([label("Name: "),      nameField]),
            row([label("Columns:"),    columnsField, columnsStepper, label("Rows:"), rowsField, rowsStepper]),
            row([label("Trigger:"),    triggerPopUp]),
            row([label("Blur:     "),  blurSlider]),
            row([label("Selection Color:"), colorWell]),
            hideIconCheckbox,
            launchAtLoginCheckbox,
            row([accessibilityLabel, accessibilityOpenBtn, accessibilityRefreshBtn]),
            sep,
            row([quitBtn, flexSpacer(), infoBtn, doneBtn]),
        ])
        stack.orientation = .vertical
        stack.alignment   = .leading
        stack.spacing     = 10
        stack.edgeInsets  = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        sep.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        cv.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cv.topAnchor),
            stack.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
        ])

        cv.layoutSubtreeIfNeeded()
        let fit = cv.fittingSize
        window?.setContentSize(NSSize(width: fit.width + stack.edgeInsets.right, height: fit.height))
    }

    // MARK: - Data helpers

    private func reloadProfiles() {
        let profiles = Settings.profiles
        profilePopUp.removeAllItems()
        profilePopUp.addItems(withTitles: profiles.map(\.name))
        let idx = Settings.selectedProfileIndex
        profilePopUp.selectItem(at: idx)
        fillFields(from: profiles[idx])
        triggerPopUp.selectItem(at: Settings.activationModifier.rawValue)
        blurSlider.doubleValue = Settings.overlayBlur
        colorWell.color = Settings.gridColor
        hideIconCheckbox.state        = Settings.hideMenuBarIcon ? .on : .off
        launchAtLoginCheckbox.state   = SMAppService.mainApp.status == .enabled ? .on : .off
        refreshAccessibilityStatus()
    }

    @objc func refreshAccessibilityStatus() {
        let granted = AXIsProcessTrusted()
        accessibilityLabel.stringValue  = granted ? "Accessibility granted" : "Accessibility not granted"
        accessibilityLabel.textColor    = granted ? .labelColor : .systemOrange
        accessibilityOpenBtn.isHidden   = granted
    }

    private func fillFields(from profile: GridProfile) {
        nameField.stringValue      = profile.name
        columnsField.integerValue  = profile.columns
        columnsStepper.integerValue = profile.columns
        rowsField.integerValue     = profile.rows
        rowsStepper.integerValue   = profile.rows
    }

    private func profileFromFields() -> GridProfile {
        GridProfile(
            name:    nameField.stringValue.trimmingCharacters(in: .whitespaces),
            columns: max(1, columnsField.integerValue),
            rows:    max(1, rowsField.integerValue)
        )
    }

    // MARK: - Actions

    @objc private func profileSelected() {
        saveCurrentProfile()
        let idx = profilePopUp.indexOfSelectedItem
        Settings.selectedProfileIndex = idx
        fillFields(from: Settings.profiles[idx])
    }

    @objc private func addRemoveTapped() {
        switch addRemoveSeg.selectedSegment {
        case 0: // +
            var all = Settings.profiles
            all.append(GridProfile(name: "Custom", columns: 4, rows: 3))
            Settings.profiles = all
            Settings.selectedProfileIndex = all.count - 1
            reloadProfiles()
        case 1: // −
            var all = Settings.profiles
            guard all.count > 1 else { return }
            let idx = Settings.selectedProfileIndex
            all.remove(at: idx)
            Settings.profiles = all
            Settings.selectedProfileIndex = max(0, idx - 1)
            reloadProfiles()
        default: break
        }
    }

    private func saveCurrentProfile() {
        let updated = profileFromFields()
        var all = Settings.profiles
        let idx = Settings.selectedProfileIndex
        all[idx] = updated
        Settings.profiles = all
        profilePopUp.item(at: idx)?.title = updated.name
    }

    @objc private func columnsStepperChanged() {
        columnsField.integerValue = columnsStepper.integerValue
    }

    @objc private func rowsStepperChanged() {
        rowsField.integerValue = rowsStepper.integerValue
    }

    @objc private func triggerChanged() {
        Settings.activationModifier = Settings.ActivationModifier(rawValue: triggerPopUp.indexOfSelectedItem) ?? .option
    }

    @objc private func blurChanged() {
        Settings.overlayBlur = blurSlider.doubleValue
    }

    @objc private func colorChanged() {
        Settings.gridColor = colorWell.color
    }

    @objc private func hideIconToggled() {
        let hidden = hideIconCheckbox.state == .on
        Settings.hideMenuBarIcon = hidden
        onIconVisibilityChange?(hidden)
    }

    @objc private func launchAtLoginToggled() {
        if launchAtLoginCheckbox.state == .on {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    @objc private func done() {
        saveCurrentProfile()
        window?.orderOut(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func openAbout() {
        AboutWindowController.shared.showWindow()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: - Helpers

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func editableTextField() -> NSTextField {
        let tf = NSTextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.widthAnchor.constraint(equalToConstant: 140).isActive = true
        return tf
    }

    private func numericTextField() -> NSTextField {
        let tf = NSTextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.widthAnchor.constraint(equalToConstant: 48).isActive = true
        tf.formatter = {
            let f = NumberFormatter()
            f.allowsFloats = false
            f.minimum = 1
            f.maximum = 100
            return f
        }()
        return tf
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.alignment   = .centerY
        s.spacing     = 8
        return s
    }

    private func flexSpacer() -> NSView {
        let v = NSView()
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return v
    }

    private func fixedSpacer(_ width: CGFloat) -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: width).isActive = true
        return v
    }
}
