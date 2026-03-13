import AppKit

final class AboutWindowController: NSWindowController {

    static let shared = AboutWindowController()

    private var checkUpdatesBtn = NSButton()
    private var statusLabel = NSTextField()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Tiler"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func showWindow() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let nameLabel = NSTextField(labelWithString: "Tiler")
        nameLabel.font = .boldSystemFont(ofSize: 18)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let descLabel = NSTextField(wrappingLabelWithString: "Snap windows to a grid by drawing on an overlay.")
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.alignment = .center

        let githubBtn = NSButton(title: "GitHub", target: self, action: #selector(openGitHub))
        githubBtn.bezelStyle = .rounded
        githubBtn.isBordered = false
        githubBtn.font = .systemFont(ofSize: 12)
        githubBtn.contentTintColor = .controlAccentColor

        checkUpdatesBtn = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdates))
        checkUpdatesBtn.bezelStyle = .rounded

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center

        let stack = NSStackView(views: [icon, nameLabel, versionLabel, descLabel, githubBtn, checkUpdatesBtn, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        cv.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cv.topAnchor),
            stack.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
        ])
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/VlatkoMilisav/Tiler")!)
    }

    @objc private func checkForUpdates() {
        checkUpdatesBtn.isEnabled = false
        checkUpdatesBtn.title = "Checking…"
        statusLabel.stringValue = ""
        UpdateChecker.checkManually { [weak self] status in
            self?.checkUpdatesBtn.isEnabled = true
            self?.checkUpdatesBtn.title = "Check for Updates"
            self?.statusLabel.stringValue = status
        }
    }
}
