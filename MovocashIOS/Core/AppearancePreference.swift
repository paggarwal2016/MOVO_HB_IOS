//
//  AppearancePreference.swift
//  MovocashIOS
//
//  Appearance preference model — system / light / dark.
//  Persisted via @AppStorage with key "appearancePreference".
//  Default: .system (follow iPhone setting).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Appearance

/// Three-way appearance preference.
/// - `system`  Follow the iPhone's appearance, including automatic
///             day/night switching.
/// - `light`   Always use the light palette.
/// - `dark`    Always use the dark palette (Void Silver).
enum Appearance: String, CaseIterable, Codable {
    case system
    case light
    case dark

    // MARK: Display

    var label: String {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    /// SF Symbol name for this option's row icon.
    var icon: String {
        switch self {
        case .system: "iphone"
        case .light:  "sun.max"
        case .dark:   "moon"
        }
    }

    /// Footer explanation shown in AppearanceSettingsView.
    var footer: String {
        switch self {
        case .system:
            "Matches your iPhone appearance, including automatic day and night switching."
        case .light:
            "Always use light appearance, regardless of your iPhone setting."
        case .dark:
            "Always use dark appearance, regardless of your iPhone setting."
        }
    }

    // MARK: SwiftUI bridge

    /// Maps to the argument accepted by `.preferredColorScheme(_:)`.
    /// `nil` means "follow the system" (no override).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    // MARK: UIKit bridge

    #if canImport(UIKit)
    /// Maps to `UIWindow.overrideUserInterfaceStyle`.
    /// `.unspecified` lets the window follow the device setting.
    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light:  .light
        case .dark:   .dark
        }
    }
    #endif

    // MARK: Static accessor

    /// Reads the live preference directly from UserDefaults.
    ///
    /// Use this from UIKit call sites (e.g. `ToastManager`, `SpinnerView`)
    /// that create overlay windows outside the SwiftUI environment and
    /// therefore cannot use `@AppStorage`. Reading on every window creation
    /// ensures each new presentation picks up the current value.
    static var current: Appearance {
        guard
            let raw = UserDefaults.standard.string(forKey: "appearancePreference"),
            let value = Appearance(rawValue: raw)
        else { return .system }
        return value
    }
}
