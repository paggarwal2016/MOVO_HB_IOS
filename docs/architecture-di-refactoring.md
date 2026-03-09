# Architecture DI Refactoring

## Purpose

Eliminate direct singleton access from Views, ViewModels, and Services. Enforce proper MVVM separation with constructor injection throughout the dependency graph.

## Problems Addressed

### Phase 1: View Layer (4 Views with business logic + singleton access)
| View | Violations |
|------|-----------|
| `OTPScreen` | Session management, KYC config, navigation logic, 3 singleton accesses |
| `PhoneNumberScreen` | Phone validation logic, 2 `AlertManager.shared` accesses |
| `KYCLauncherView` | KYC orchestration, no ViewModel, 2 singleton accesses |
| `UserHeaderView` | Logout via `AppContainer.shared.sessionManager` |

### Phase 2: Service + ViewModel Layer (5 additional issues)
| Component | Violation |
|-----------|-----------|
| `KYCLauncherView` | Direct `AppContainer.shared.makeKYCViewModel()` instead of injection |
| `NetworkService.refreshToken()` | `KeychainManager.shared` + `AppContainer.shared.sessionManager` |
| `KYCManager.configureSDK()` | `AuthManager.shared.getAccessToken()` |
| `SessionManager.logout()` | `KYCManager.shared.clearSession()` |
| ViewModels (`AuthViewModel`, `KYCViewModel`, `SessionManager`) | `AlertManager.shared.showError()` |

## New Protocols

### `KYCManagerProtocol` (in `KYCManager.swift`)
- Methods: `configureSDK(officeId:)`, `start()`, `clearSession()`, `updateToken(_:)`
- Enables mocking KYC SDK for unit tests

### `AlertManagerProtocol` (in `AlertManager.swift`)
- Methods: `showError(_:onDismiss:)`, `showConfirmation(title:message:onConfirm:onCancel:)`
- Protocol extension provides `showError(_:)` convenience (nil onDismiss default)
- Decouples ViewModels from the concrete alert presentation system

## New ViewModel

### `KYCViewModel` (in `KYCViewModel.swift`)
- Dependencies: `KYCManagerProtocol`, `AlertManagerProtocol`
- Method: `startVerification(appState:)` — handles KYC flow, navigation, error display

## Service Layer Fixes

### `NetworkService` — Constructor Injection
- Accepts `keychain: KeychainManagerProtocol` and `authManager: AuthManagerProtocol` via init
- `refreshToken()` uses injected deps for reading/storing tokens directly
- Eliminates circular dependency on `AppContainer.shared.sessionManager`
- `static let shared` self-wires with defaults (singleton bootstrapping)

### `KYCManager` — Constructor Injection
- Accepts `authManager: AuthManagerProtocol` via init
- `configureSDK()` uses `self.authManager` instead of `AuthManager.shared`

### `SessionManager` — Constructor Injection
- New deps: `kycManager: KYCManagerProtocol`, `alertManager: AlertManagerProtocol`
- `logout()` uses `self.kycManager.clearSession()`
- `forceLogout()` uses `self.alertManager.showError()`

### `AuthViewModel` — Constructor Injection
- New dep: `alertManager: AlertManagerProtocol`
- All 3 `AlertManager.shared.showError()` calls replaced with `self.alertManager.showError()`

## DI Container (`AppContainer`)

```
AppContainer
├── keychain: KeychainManagerProtocol    (KeychainManager.shared)
├── authManager: AuthManagerProtocol     (AuthManager.shared)
├── alertManager: AlertManagerProtocol   (AlertManager.shared)
├── network: NetworkServiceProtocol      (NetworkService.shared)
├── kycManager: KYCManagerProtocol       (KYCManager.shared)
└── sessionManager: SessionManager       (created with injected deps)

Factory Methods:
├── makeAuthViewModel() → injects all 6 deps
└── makeKYCViewModel()  → injects kycManager + alertManager
```

## EnvironmentObject Flow

```
MovocashIOSApp
└── RootView (composition root — only place AppContainer.shared is accessed)
    ├── .environmentObject(authVM)          → AuthViewModel
    ├── .environmentObject(kycVM)           → KYCViewModel
    └── .environmentObject(sessionManager)  → SessionManager
        ├── PhoneNumberScreen  → uses authVM via @EnvironmentObject
        ├── OTPScreen          → uses authVM via @ObservedObject
        ├── KYCLauncherView    → uses kycVM via @EnvironmentObject
        └── UserHeaderView     → uses sessionManager via @EnvironmentObject
```

## Key Files Modified

| File | Change |
|------|--------|
| `MovocashIOS/Shared/Components/AlertManager.swift` | Added `AlertManagerProtocol` |
| `MovocashIOS/Core/Network/NetworkService.swift` | Constructor injection for keychain + authManager |
| `MovocashIOS/KYC/KYCManager.swift` | Added `KYCManagerProtocol`, constructor injection for authManager |
| `MovocashIOS/KYC/KYCViewModel.swift` | New file |
| `MovocashIOS/Features/SessionManager.swift` | Constructor injection for kycManager + alertManager |
| `MovocashIOS/Features/Authorization/ViewModels/AuthViewModel.swift` | Constructor injection for alertManager + 2 new methods |
| `MovocashIOS/Features/AppContainer.swift` | Wires all dependencies, updated factories |
| `MovocashIOS/Features/Authorization/Views/OTPScreen.swift` | Simplified to single ViewModel call |
| `MovocashIOS/Features/Authorization/Views/PhoneNumberScreen.swift` | Simplified to single ViewModel call |
| `MovocashIOS/KYC/KYCLauncherView.swift` | Uses @EnvironmentObject KYCViewModel |
| `MovocashIOS/Features/Home/UserHeaderView.swift` | Uses @EnvironmentObject SessionManager |
| `MovocashIOS/Features/Launch/RootView.swift` | Creates + injects all EnvironmentObjects |

## Remaining Singleton References (Acceptable)

These singleton accesses remain and are intentional:

| Location | Singleton | Justification |
|----------|-----------|---------------|
| `RootView.swift` | `AppContainer.shared` | Composition root — this IS the DI entry point |
| `NetworkService.swift` static init | `KeychainManager.shared`, `AuthManager.shared` | Singleton self-wiring (bootstrapping) |
| `KYCManager.swift` static init | `AuthManager.shared` | Singleton self-wiring (bootstrapping) |
| `AlertManager.swift` GlobalAlertModifier | `AlertManager.shared` | SwiftUI modifier needs concrete singleton |
| `HeaderProvider.swift` | `AuthManager.shared`, `DeviceManager.shared` | Static utility at infrastructure level |
| `ScreenSecurityManager.swift` | `AuthManager.shared` | Infrastructure security component |
| `DeviceManager.swift` | `KeychainManager.shared` | Infrastructure singleton self-wiring |
| `MovocashIOSApp.swift` | `AppLockManager.shared` | App entry point (composition root) |

## Verification

Grep audits confirm:
- Zero Views access `AlertManager.shared`, `KYCManager.shared`, or `AppContainer.shared` (except RootView as composition root)
- Zero ViewModels access `AlertManager.shared` — all use injected `alertManager`
- Zero Services use cross-singleton method calls — all use constructor-injected deps
- `AppContainer.shared` appears only in `RootView.swift` (composition root)
