import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var eventMonitor: EventMonitor?
    private var gridWindowController: GridWindowController?

    // Submenus rebuilt on open
    private let profileSubmenu = NSMenu()
    private let triggerSubmenu = NSMenu()

    // Custom-view controls refreshed on open
    private let hideIconMenuItem = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        setupStatusBar()
        UpdateChecker.checkInBackground()

        let gwc = GridWindowController()
        gridWindowController = gwc
        eventMonitor = EventMonitor(gridWindowController: gwc)
        eventMonitor?.start()

        SettingsWindowController.shared.onIconVisibilityChange = { [weak self] hidden in
            self?.applyIconVisibility(hidden: hidden)
        }

        applyIconVisibility(hidden: Settings.hideMenuBarIcon)
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "grid", accessibilityDescription: "Tiler")

        profileSubmenu.delegate = self
        triggerSubmenu.delegate = self

        let profileMenuItem = NSMenuItem(title: "Profile", action: nil, keyEquivalent: "")
        profileMenuItem.submenu = profileSubmenu

        let triggerMenuItem = NSMenuItem(title: "Trigger key", action: nil, keyEquivalent: "")
        triggerMenuItem.submenu = triggerSubmenu

        hideIconMenuItem.title = "Hide menu bar icon"
        hideIconMenuItem.target = self
        hideIconMenuItem.action = #selector(toggleHideIcon)

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        menu.addItem(profileMenuItem)
        menu.addItem(.separator())
        menu.addItem(triggerMenuItem)
        menu.addItem(hideIconMenuItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Tiler", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        switch menu {
        case profileSubmenu:   rebuildProfileSubmenu()
        case triggerSubmenu:   rebuildTriggerSubmenu()
        case statusItem?.menu: refreshMenuValues()
        default: break
        }
    }

    // MARK: - Rebuild submenus

    private func rebuildProfileSubmenu() {
        profileSubmenu.removeAllItems()
        for (i, profile) in Settings.profiles.enumerated() {
            let item = NSMenuItem(title: profile.name, action: #selector(profileChosen(_:)), keyEquivalent: "")
            item.target = self
            item.tag   = i
            item.state = (i == Settings.selectedProfileIndex) ? .on : .off
            profileSubmenu.addItem(item)
        }
    }

    private func rebuildTriggerSubmenu() {
        triggerSubmenu.removeAllItems()
        for mod in Settings.ActivationModifier.allCases {
            let item = NSMenuItem(title: mod.title, action: #selector(triggerChosen(_:)), keyEquivalent: "")
            item.target = self
            item.tag   = mod.rawValue
            item.state = (mod == Settings.activationModifier) ? .on : .off
            triggerSubmenu.addItem(item)
        }
    }

    // MARK: - Refresh / save

    private func refreshMenuValues() {
        hideIconMenuItem.state = Settings.hideMenuBarIcon ? .on : .off
    }

    // MARK: - Actions

    @objc private func profileChosen(_ sender: NSMenuItem) {
        Settings.selectedProfileIndex = sender.tag
    }

    @objc private func triggerChosen(_ sender: NSMenuItem) {
        Settings.activationModifier = Settings.ActivationModifier(rawValue: sender.tag) ?? .option
    }

    @objc private func toggleHideIcon() {
        let hidden = !Settings.hideMenuBarIcon
        Settings.hideMenuBarIcon = hidden
        hideIconMenuItem.state = hidden ? .on : .off
        applyIconVisibility(hidden: hidden)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        SettingsWindowController.shared.showWindow()
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Retry event tap creation in case accessibility was just granted.
        // start() is a no-op if the tap is already running.
        eventMonitor?.start()
        SettingsWindowController.shared.refreshAccessibilityStatus()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func applyIconVisibility(hidden: Bool) {
        statusItem?.isVisible = !hidden
        NSApp.setActivationPolicy(hidden ? .prohibited : .accessory)
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

}
