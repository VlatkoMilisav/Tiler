import AppKit

struct Settings {

    // MARK: - Profiles

    static var profiles: [GridProfile] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "profiles"),
                  let decoded = try? JSONDecoder().decode([GridProfile].self, from: data),
                  !decoded.isEmpty
            else { return GridProfile.defaults }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "profiles")
            }
        }
    }

    static var selectedProfileIndex: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "selectedProfileIndex")
            return max(0, min(v, profiles.count - 1))
        }
        set { UserDefaults.standard.set(newValue, forKey: "selectedProfileIndex") }
    }

    static var activeProfile: GridProfile {
        get { profiles[selectedProfileIndex] }
        set {
            var all = profiles
            all[selectedProfileIndex] = newValue
            profiles = all
        }
    }

    // MARK: - Grid size (derived from active profile)

    static var columns: Int { activeProfile.columns }
    static var rows: Int    { activeProfile.rows }

    // MARK: - Activation modifier

    enum ActivationModifier: Int, CaseIterable {
        case option = 0, control, shift, command, rightClick, space

        var flags: NSEvent.ModifierFlags {
            switch self {
            case .option:    return .option
            case .control:   return .control
            case .shift:     return .shift
            case .command:   return .command
            case .rightClick: return []
            case .space:     return []
            }
        }

        var title: String {
            switch self {
            case .option:    return "⌥ Option"
            case .control:   return "⌃ Control"
            case .shift:     return "⇧ Shift"
            case .command:   return "⌘ Command"
            case .rightClick: return "Right-click"
            case .space:     return "Space"
            }
        }
    }

    static var activationModifier: ActivationModifier {
        get { ActivationModifier(rawValue: UserDefaults.standard.integer(forKey: "activationModifier")) ?? .option }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "activationModifier") }
    }

    // MARK: - Overlay blur (0 = off, 1 = full)

    static var overlayBlur: Double {
        get {
            guard UserDefaults.standard.object(forKey: "overlayBlur") != nil else { return 0 }
            return UserDefaults.standard.double(forKey: "overlayBlur")
        }
        set { UserDefaults.standard.set(newValue, forKey: "overlayBlur") }
    }

    // MARK: - Menu bar icon

    static var hideMenuBarIcon: Bool {
        get { UserDefaults.standard.bool(forKey: "hideMenuBarIcon") }
        set { UserDefaults.standard.set(newValue, forKey: "hideMenuBarIcon") }
    }

    // MARK: - Live resize

    static var liveResize: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "liveResize") != nil else { return false }
            return UserDefaults.standard.bool(forKey: "liveResize")
        }
        set { UserDefaults.standard.set(newValue, forKey: "liveResize") }
    }

    // MARK: - Grid color

    static var gridColor: NSColor {
        get {
            guard let data = UserDefaults.standard.data(forKey: "gridColor"),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            else { return NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1) }
            return color
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue,
                                                            requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: "gridColor")
            }
        }
    }
}
