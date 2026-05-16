# MovoCash iOS — Libraries & SDKs Reference
**Last Updated:** April 2026

---

## Third-Party Libraries (Swift Package Manager)

| Library | Version | Source | Used For |
|---------|---------|--------|---------|
| **MobileBankingSDK** | ≥ 1.5.0 | Herring Bank (private) | KYC / identity verification flow |
| **Firebase iOS SDK** | ≥ 12.11.0 | github.com/firebase/firebase-ios-sdk | Analytics, crash reporting, push notifications |
| **Plaid Link iOS** | ≥ 6.0.4 | github.com/plaid/plaid-link-ios-spm | Bank account linking for ACH transfers |

### Firebase — Products in Use

| Firebase Product | Import | Purpose |
|-----------------|--------|---------|
| `FirebaseCore` | `AppDelegate.swift` | SDK initialization on app launch |
| `FirebaseAnalytics` | `AnalyticsManager.swift` | Event tracking, user identification |
| `FirebaseCrashlytics` | `AppDelegate.swift` | Crash and error reporting |
| `FirebaseMessaging` | `AppDelegate.swift`, `PushManager.swift` | FCM token management, push delivery |

### MobileBankingSDK — Usage

| File | What it does |
|------|-------------|
| `KYCManager.swift` | Configures SDK, launches KYC flow as a UIViewController |
| `KYCEnum.swift` | Imports `User` and error types from SDK |
| `PlaidService.swift` | Uses SDK types for ACH/Plaid integration |
| `PlaidAchViewModel.swift` | ViewModel for Plaid-linked ACH operations |
| `PlaidLinkManager.swift` | Wraps SDK + LinkKit for bank account selection |

### Plaid Link — Usage

| File | What it does |
|------|-------------|
| `PlaidLinkManager.swift` | Presents Plaid Link sheet, handles bank account selection callback |

---

## Apple Frameworks

### UI & Navigation

| Framework | Import | Used In | Purpose |
|-----------|--------|---------|---------|
| `SwiftUI` | Most feature files | Views, ViewModels | All UI rendering |
| `UIKit` | AppDelegate, some views/managers | Lifecycle, UIViewController bridging | Legacy interop, KYC SDK presentation |
| `Combine` | ViewModels, managers | Reactive state publishing | `@Published`, `ObservableObject`, pipelines |

### Security & Cryptography

| Framework | Import | Used In | Purpose |
|-----------|--------|---------|---------|
| `Security` | `KeychainManager`, `PasscodeManager`, `AppLockManager`, `SSLPinning` | Keychain CRUD, Secure Enclave keys, SSL | Token storage, PIN key storage, cert pinning |
| `LocalAuthentication` | `BiometricManager`, `KeychainManager`, `RSAKeyManager` | Biometric evaluation, Keychain auth | Face ID / Touch ID prompts |
| `CryptoKit` | `PasscodeManager`, `AnalyticsManager`, `RSAKeyManager` | Hashing, key generation | SHA-256 (analytics ID), EC key generation |
| `CommonCrypto` | `PasscodeManager` | PBKDF2 derivation | PIN hash (310,000 iterations, NIST SP 800-63B) |

### Networking & System

| Framework | Import | Used In | Purpose |
|-----------|--------|---------|---------|
| `Foundation` | Everywhere | URLSession, Codable, actors | Core runtime, HTTP, JSON |
| `Network` | `NetworkMonitor` | Reachability | NWPathMonitor for online/offline detection |
| `UserNotifications` | `AppDelegate`, `PushManager` | Push permission, foreground display | APNs + FCM notification handling |
| `MachO` | `JailbreakDetector` | Security check | Detect modified binaries / jailbreak |

### Utilities

| Framework | Import | Used In | Purpose |
|-----------|--------|---------|---------|
| `os` | `SecureLogger` | Structured logging | `os.Logger` (privacy-safe, system-level logs) |
| `Contacts` | `ContactsManager` | Quick transfer contact picker | Read device contacts for P2P transfers |

### Testing

| Framework | Import | Used In | Purpose |
|-----------|--------|---------|---------|
| `XCTest` | UI test files | `MovocashIOSUITests` | UI test runner |
| `Testing` | Unit test file | `MovocashIOSTests` | Swift Testing framework (Xcode 16+) |

---

## Summary — Count

| Category | Count |
|----------|-------|
| Third-party SPM packages | 3 |
| Firebase products used | 4 |
| Apple frameworks used | 13 |
| **Total dependencies** | **17** |

---

## Notes

- **No CocoaPods, no Carthage.** All dependencies are managed through Swift Package Manager only.
- **No third-party UI libraries.** All UI is built with native SwiftUI and UIKit.
- **No third-party networking libraries.** `URLSession` is used directly inside `NetworkService`.
- **No third-party keychain wrappers.** `Security` framework is used directly in `KeychainManager` and `PasscodeManager`.
- `BlinkIDUX` (Microblink document scanner, v7.3.1) is referenced in older integration documentation but is **not present** in the current `project.pbxproj` package list. KYC is now handled entirely by `MobileBankingSDK`.
