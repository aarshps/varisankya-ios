import Foundation
import Combine
import SwiftUI

/// Mirrors Android PreferenceHelper, storing user preferences in UserDefaults.
/// Exposes an @Observable wrapper so SwiftUI views auto-refresh on changes.
@Observable
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard
    private let usageDefaults = UserDefaults(suiteName: "DropdownPrefs") ?? .standard

    // MARK: Keys
    private enum Key {
        static let hapticsEnabled = "haptics_enabled"
        static let notifHour = "notification_hour"
        static let notifMinute = "notification_minute"
        static let notifDays = "notification_days"
        static let useGoogleFont = "use_google_font"
        static let biometricEnabled = "biometric_enabled"
        static let defaultPaymentView = "default_payment_view"
        static let paymentViewMode = "payment_view_mode"
        static let currency = "app_currency"
        static let appearance = "appearance_mode"  // system/light/dark
        static let onboardedNotifications = "notif_perm_requested"
    }

    // MARK: Currency
    var currency: String {
        get { defaults.string(forKey: Key.currency) ?? "INR" }
        set { defaults.set(newValue, forKey: Key.currency) }
    }

    // MARK: Haptics
    var hapticsEnabled: Bool {
        get { defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hapticsEnabled) }
    }

    // MARK: Font (system vs Google Sans Flex-equivalent rounded)
    var useGoogleFont: Bool {
        get { defaults.object(forKey: Key.useGoogleFont) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.useGoogleFont) }
    }

    // MARK: Biometric (Face ID / Touch ID)
    var biometricEnabled: Bool {
        get { defaults.bool(forKey: Key.biometricEnabled) }
        set { defaults.set(newValue, forKey: Key.biometricEnabled) }
    }

    // MARK: Notification time
    var notificationHour: Int {
        get { defaults.object(forKey: Key.notifHour) as? Int ?? 8 }
        set { defaults.set(newValue, forKey: Key.notifHour) }
    }
    var notificationMinute: Int {
        get { defaults.object(forKey: Key.notifMinute) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: Key.notifMinute) }
    }
    func setNotificationTime(hour: Int, minute: Int) {
        notificationHour = hour
        notificationMinute = minute
    }

    var notificationDays: Int {
        get { defaults.object(forKey: Key.notifDays) as? Int ?? 7 }
        set { defaults.set(newValue, forKey: Key.notifDays) }
    }

    // MARK: Payment view (chart vs list)
    var defaultPaymentView: String {
        get { defaults.string(forKey: Key.defaultPaymentView) ?? "chart" }
        set { defaults.set(newValue, forKey: Key.defaultPaymentView) }
    }
    var paymentViewMode: String {
        get { defaults.string(forKey: Key.paymentViewMode) ?? defaultPaymentView }
        set { defaults.set(newValue, forKey: Key.paymentViewMode) }
    }

    // MARK: Appearance
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }
    var appearance: Appearance {
        get { Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "system") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.appearance) }
    }

    // MARK: Personalization — usage-weighted dropdown ordering
    func recordUsage(prefix: String, value: String) {
        let key = "\(prefix)_\(value)"
        let count = usageDefaults.integer(forKey: key)
        usageDefaults.set(count + 1, forKey: key)
    }

    func personalized(prefix: String, defaultList: [String]) -> [String] {
        let counts = defaultList.map { (value: $0, count: usageDefaults.integer(forKey: "\(prefix)_\($0)")) }
        return counts.sorted { $0.count > $1.count }.map(\.value)
    }

    // MARK: Notification permission gating
    var notificationPermissionRequested: Bool {
        get { defaults.bool(forKey: Key.onboardedNotifications) }
        set { defaults.set(newValue, forKey: Key.onboardedNotifications) }
    }
}
