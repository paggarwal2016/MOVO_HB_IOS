# MovoCash iOS — Engineering Status Document
**Last Updated:** April 2026  
**Platform:** iOS (Swift 5.9+, SwiftUI, iOS 15+)  
**Architecture Pattern:** MVVM + Layered Architecture + Dependency Injection

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Layer-by-Layer Breakdown](#3-layer-by-layer-breakdown)
4. [Completed Implementations](#4-completed-implementations)
5. [In-Progress Work](#5-in-progress-work)
6. [Known Gaps](#6-known-gaps)
7. [Future Plans — CI/CD & Infrastructure](#7-future-plans--cicd--infrastructure)
8. [Future Plans — Product Features](#8-future-plans--product-features)
9. [Security Posture](#9-security-posture)
10. [Dependency Map](#10-dependency-map)

---

## 1. Project Overview

MovoCash is a mobile banking app (iOS-first) built on top of Herring Bank's Consumer API. The app is a **presentation layer only** — it collects user input, renders account data, and handles device-specific features (camera, biometrics, Apple Pay, push notifications). All business logic and banking orchestration lives in the **Movo Skinny Processor** (Python middleware).

```
iOS App  →  Skinny Processor (Python, port 8003)  →  Herring Bank Consumer API
```

The app is currently in active development. Core infrastructure is production-ready. Feature screens are at varying levels of completion.

---

## 2. System Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      MovoCash iOS App                    │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │   Views  │  │ViewModels│  │ Services │  │ Models │  │
│  │(SwiftUI) │→ │  (MVVM)  │→ │(Network/ │  │(Codable│  │
│  │          │  │          │  │ Keychain)│  │/Sendab.)│  │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │              Core Infrastructure                    │ │
│  │  Security │ Network │ Analytics │ Config │ Logging  │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         │  HTTPS + JWT
                         ▼
┌─────────────────────────────────────────────────────────┐
│           Movo Skinny Processor (Python)                 │
│     API Orchestration · Business Rules · HyperBIN       │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│         Herring Bank Consumer API v2.21.0                │
│  Auth · KYC/CIP · Cards · Transactions · ACH · Balances │
└─────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Responsibility | Key Rule |
|-------|---------------|----------|
| **Views** | Rendering, user interaction | No business logic, no networking |
| **ViewModels** | UI state, user intents | No UIKit imports; UI-agnostic |
| **Services** | Networking, Keychain, KYC SDK | Stateless where possible; protocol-backed |
| **Core** | Security, Logging, Config, Network primitives | Shared infrastructure |
| **Models** | Data structures | `Codable`, `Sendable`, no logic |

### Concurrency Model

All concurrency uses Swift's structured concurrency (`async/await`). No completion handlers remain in new code.

- `NetworkService` — `actor` (prevents token-refresh race conditions)
- `AuthManager` — `actor` (serializes JWT reads/writes)
- `SecureLogger` — `actor` (safe concurrent logging)
- `AppLockManager` — `@MainActor` (all UI state on main thread)
- ViewModels — `@MainActor` via `ObservableObject`

### Dependency Injection

All dependencies are assembled in `AppContainer.swift` at app startup. Views receive ViewModels via `@StateObject`. ViewModels receive services via initialiser injection. No view or ViewModel reaches for a singleton directly.

```
AppContainer
├── makeAuthViewModel()      → AuthViewModel(network, keychain, authManager, ...)
├── makeUserViewModel()      → UserViewModel(network, alertManager, analytics)
├── makeKYCViewModel()       → KYCViewModel(kycManager, alertManager, analytics)
├── makeVCardViewModel()     → VCardViewModel(network, alertManager)
├── makeSavingsAccountVM()   → SavingsAccountViewModel(network, alertManager)
├── makeTransactionVM()      → TransactionViewModel(network, alertManager)
├── makeACHViewModel()       → ACHViewModel(network, alertManager)
└── makeAppLockViewModel()   → AppLockViewModel(lockManager)
```

---

## 3. Layer-by-Layer Breakdown

### 3.1 App Entry Point

**Files:** `MovocashIOSApp.swift`, `AppDelegate.swift`

- `MovocashIOSApp` is the SwiftUI app root. It builds the `AppContainer`, injects all environment objects, and applies global view modifiers (network banner, toast, alert).
- `AppDelegate` handles Firebase init, FCM token management, and APNs passthrough. Deep link routing from push taps is stubbed for future work.

### 3.2 Navigation & Root State

**Files:** `RootView.swift`, `AppState.swift`, `SplashScreen.swift`

The full navigation flow is driven by `AppState.flow` (an `AuthFlow` enum):

```
Splash (session restore attempt)
  ├── Restored   → Home (lock overlay handles unlock)
  ├── Not logged → Choice → Phone → OTP
  │                              └── New user → Passcode → Biometrics → KYC → Home
  │                              └── Returning → Passcode → Biometrics → Home
  └── Keychain locked → Choice (device was rebooted, needs unlock)
```

The lock overlay (`AppLockView`) is a z-stacked layer over the entire app. It is suppressed during the KYC flow to prevent the system biometric prompt and the KYC camera from conflicting.

### 3.3 Network Layer

**Files:** `NetworkService.swift`, `Endpoint.swift`, `RequestBuilder.swift`, `HeaderProvider.swift`, `NetworkError.swift`, API files

`NetworkService` is the single HTTP client. Key behaviours:

- **Retry logic:** Up to 3 attempts. 5xx and 429 use exponential backoff (200ms → 400ms with jitter). 401 triggers a token refresh once, then retries. Other errors throw immediately.
- **Token refresh:** Concurrent callers are parked in a waiter queue while a single refresh is in flight. This prevents multiple simultaneous refresh calls.
- **Jailbreak gate:** Every request checks `JailbreakDetector` first. Compromised devices get a `securityViolation` error.
- **SSL pinning:** `SecureSessionDelegate` exists but is not yet wired to the `URLSession`. This is a known gap.

API endpoints are defined in 7 files, each grouping a domain:

| File | Endpoints |
|------|-----------|
| `AuthAPI.swift` | OTP request, SMS token, refresh, RSA enroll/token/nonce |
| `UserAPI.swift` | Profile get, profile delete |
| `TransactionAPI.swift` | Transaction list, transaction detail |
| `VCardAPI.swift` | Virtual card CRUD |
| `SavingsAccountAPI.swift` | Savings account CRUD |
| `AchAPI.swift` | ACH transfer operations |
| `RewardAPI.swift` | Reward points |

### 3.4 Security Layer

**Files:** `AppLockManager.swift`, `KeychainManager.swift`, `AuthManager.swift`, `PasscodeManager.swift`, `BiometricManager.swift`, `JailbreakDetector.swift`, `ScreenSecurityManager.swift`, `RSAKeyManager.swift`

The security layer covers four concerns:

**App Lock (Passcode + Biometric)**
- `AppLockManager` owns the `LockState` machine: `.unlocked`, `.locked`, `.sensitiveChallenge(actionID)`.
- Background timeout: 30 seconds. App entering background records a timestamp; if it returns after 30s, it locks.
- Progressive lockout on wrong passcode: 30s → 5 min → 15 min → force OTP login (after 4 rounds of 3 wrong attempts each).
- Lockout state is persisted to Keychain so force-quitting the app between attempts cannot reset the counter.
- Biometric uses `LocalAuthentication.framework` via `BiometricManager`. Face ID, Touch ID, and Optic ID are all handled.
- Passcode is stored as a PBKDF2-HMAC-SHA256 hash (310,000 iterations, per NIST SP 800-63B 2023) with a random 32-byte salt.
- Biometric enrollment stores an EC-P256 private key in the Secure Enclave with `.biometryCurrentSet` access control.

**Token Storage (Keychain)**
- `KeychainManager` provides two protection tiers:
  - `.backgroundSafe` — `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (refresh token)
  - `.userPresence` — `.biometryCurrentSet` access control (sensitive items, requires biometric to read)
- Biometric prompt text is passed per-call via `biometricPrompt: String?`.

**Device Security**
- `JailbreakDetector` blocks API calls on compromised devices.
- `ScreenSecurityManager` prevents screenshots and screen recording on sensitive views.

**RSA Key Backup (In Progress)**
- `RSAKeyManager` exists for server-side biometric-enhanced auth. Not yet wired into the auth flow.

### 3.5 KYC Layer

**Files:** `KYCManager.swift`, `KYCViewModel.swift`, `KYCEnum.swift`, `PickDocumentView.swift`

KYC uses the `MobileBankingSDK` (Herring's iOS SDK) for identity verification. The flow:

```
PickDocumentView → user selects ID type
    ↓
KYCManager.configureSDK(officeId:) → initializes SDK with JWT + base URL
    ↓
KYCManager.start() → presents SDK as UIViewController overlay
    ↓
User completes identity verification inside SDK
    ↓
KYCManager returns User object or throws KYCError
    ↓
RootView routes to Home on success
```

`KYCManager.start()` uses `withCheckedThrowingContinuation` to bridge the UIKit-based SDK callback into `async/await`.

### 3.6 Push Notifications & Analytics

**Files:** `PushManager.swift`, `AnalyticsManager.swift`, `AnalyticsEvent.swift`

- **FCM:** Token registration, topic subscriptions (transactions, alerts, promotions, market_updates), badge management, foreground/background notification routing.
- **Analytics:** Firebase Analytics. User identity is a SHA-256 hash of the JWT `sub` claim — never PII. Events cover auth lifecycle, KYC, biometric, lock/unlock, suspicious activity, rewards.
- **Privacy:** `SecureLogger` auto-redacts JWTs, auth headers, card numbers, emails, and sensitive JSON keys from all log output. Production builds emit no log output.

---

## 4. Completed Implementations

### Authentication Flow
- [x] Phone number input with US formatting (+1 XXX-XXX-XXXX)
- [x] OTP request via `POST /auth/messenger-otp`
- [x] OTP verification via `POST /auth/token-sms` → returns access + refresh tokens
- [x] JWT stored in Keychain; access token cached in `AuthManager` actor
- [x] Token refresh via `POST /auth/refresh-token` (triggered on 401)
- [x] Silent RSA nonce + token enrollment (`GET /auth/rsa-nonce`, `POST /auth/rsa-token`)
- [x] Session restore on app launch (reads Keychain, checks JWT expiry)
- [x] Force logout when refresh fails (routes back to phone screen)

### App Lock / Biometric
- [x] 6-digit PIN setup and verify (PBKDF2 hashing)
- [x] Face ID / Touch ID enrollment (Secure Enclave key)
- [x] Auto-lock on background (30s timeout)
- [x] Auto-trigger biometric on foreground
- [x] Progressive lockout (30s → 5m → 15m → force OTP)
- [x] Lockout state persisted (survives force-quit)
- [x] Passcode change flow
- [x] Security settings view (enable/disable biometrics)
- [x] Sensitive action challenge (re-auth before critical operations)

### KYC
- [x] `MobileBankingSDK` integrated via SPM
- [x] `KYCManager` wraps SDK with async/await
- [x] Document picker screen (pre-KYC document type selection)
- [x] KYC success/failure routing from `RootView`
- [x] KYC session cleared on logout

### Network Infrastructure
- [x] Actor-based `NetworkService` with retry + backoff
- [x] Token refresh with waiter queue (no race conditions)
- [x] Jailbreak gate on every request
- [x] Comprehensive `NetworkError` mapping
- [x] `Endpoint` protocol (all API endpoints defined)
- [x] Debug request/response logging (DEBUG builds only)

### Push Notifications
- [x] FCM token registration and refresh
- [x] Topic subscriptions (transactions, alerts, promotions)
- [x] Token deleted + topics unsubscribed on logout
- [x] Foreground notification display
- [x] Background notification handling
- [x] Badge count management

### Analytics
- [x] Firebase Analytics initialized
- [x] Privacy-safe identity (hashed sub claim, never PII)
- [x] Auth events (login, logout, OTP sent/verified, session expired)
- [x] KYC events (started, completed, abandoned)
- [x] Lock events (biometric enrolled, revoked, auth, lockout)
- [x] Suspicious activity events (wrong passcode, biometric fail)

### Home Screens (Structure)
- [x] Tab bar (Dashboard, Accounts, Profile)
- [x] Virtual card display and skeleton loader
- [x] Savings account list with balance card
- [x] Transaction list with skeleton
- [x] Internal transfer view
- [x] ACH fund account form
- [x] Profile view with logout

### Dependency Injection
- [x] `AppContainer` assembles all dependencies at startup
- [x] All ViewModels receive dependencies via init (no singleton access in VMs)
- [x] Protocol-based abstractions for all services (testable)

---

## 5. In-Progress Work

### ACH / Bank Linking (Plaid)
- `PlaidLinkManager.swift` and `PlaidAchViewModel.swift` exist but are not fully wired.
- The ACH API endpoints (`AchAPI.swift`) are defined.
- The UI form (`ACHFundView`) is scaffolded.
- **Remaining:** Complete Plaid Link callback handling, wire public token exchange, connect to `ACHViewModel`.

### RSA Backup Authentication
- `RSAKeyManager.swift` generates and stores RSA key pairs.
- `AuthAPI` has RSA nonce and token endpoints.
- `AuthViewModel.enrollRSASilently()` is called after OTP but not yet robustly tested.
- **Remaining:** End-to-end test of RSA fallback when biometric is unavailable.

### Home Feature Polish
- Individual feature views (virtual card detail, savings account detail, rewards) are scaffolded but need final UI polish and edge-case handling.
- The `RewardViewModel` and `ContactViewModel` are complete but the corresponding views need integration.

### SSL Certificate Pinning
- `SecureSessionDelegate` (in `SSLPinning.swift`) contains the URLSession delegate hook.
- Not yet wired to the live `NetworkService` URLSession.
- **Remaining:** Obtain server leaf/intermediate certificates, bundle in app, enable in `NetworkService`.

---

## 6. Known Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| **Unit tests** | No coverage on any service, ViewModel, or utility | Critical |
| **SSL pinning** | MITM attacks possible on untrusted networks | High |
| **Deep link routing** | Push notification taps do not navigate to specific screens | Medium |
| **Offline queue** | Failed API calls (no internet) are dropped silently | Medium |
| **Bill Pay** | Not available in Herring Consumer API — needs product decision | Medium |
| **Profile Picture** | Not available in Consumer API — defer or proxy via middleware | Low |
| **UI tests** | No automated end-to-end test for auth or KYC flows | Medium |
| **Biometric JWT persistence** | Access token lost on app restart; users must re-OTP | Medium |

---

## 7. Future Plans — CI/CD & Infrastructure

### 7.1 Proposed CI/CD Pipeline

The recommended pipeline uses **GitHub Actions** with **Fastlane**.

```
┌──────────────────────────────────────────────────────────┐
│                   Pull Request Trigger                    │
│                                                          │
│  1. Lint (SwiftLint)                                     │
│  2. Unit Tests (xcodebuild test)                         │
│  3. Build for Simulator (verify clean build)             │
│  4. Code Coverage Report                                 │
│                                                          │
│                   Merge to main                          │
│                                                          │
│  5. Archive (xcodebuild archive)                         │
│  6. Export IPA (ExportOptions.plist)                     │
│  7. Upload to TestFlight (Fastlane deliver / pilot)      │
│  8. Notify Slack (#mobile-releases)                      │
└──────────────────────────────────────────────────────────┘
```

**Key Tools:**
| Tool | Purpose |
|------|---------|
| **GitHub Actions** | CI runner (free tier sufficient for current scale) |
| **Fastlane** | Build, archive, TestFlight upload automation |
| **SwiftLint** | Enforce code style (configured via `.swiftlint.yml`) |
| **Xcode Cloud** | Alternative to GitHub Actions — native Apple CI, no Mac runner needed |
| **Codecov** | Code coverage tracking and PR annotations |

**Secrets Required in CI:**
- Apple ID + App-specific password (for TestFlight)
- Provisioning profiles + signing certificates (via Fastlane `match`)
- Firebase `GoogleService-Info.plist` (injected at build time, not committed)
- `HERRING_BASE_URL` and `HERRING_OFFICE_ID` (per environment)

### 7.2 Fastlane Setup (Recommended Lanes)

```ruby
# Fastfile outline
lane :test do
  run_tests(scheme: "MovocashIOS", devices: ["iPhone 15"])
end

lane :beta do
  increment_build_number
  build_app(scheme: "MovocashIOS", export_method: "app-store")
  upload_to_testflight(skip_waiting_for_build_processing: true)
end

lane :release do
  ensure_git_status_clean
  increment_version_number(bump_type: "minor")
  build_app(scheme: "MovocashIOS", export_method: "app-store")
  upload_to_app_store(submit_for_review: false)
end
```

### 7.3 Code Signing Strategy

Use **Fastlane Match** with a private GitHub repo to store certificates:
- `match(type: "development")` — developer certs for testing
- `match(type: "appstore")` — distribution certs for TestFlight/App Store
- All team members run `fastlane match` to sync their local environment
- CI uses a read-only Match API key

### 7.4 Environment Management

Three target environments, toggled by build scheme:

| Scheme | Environment | API Base URL |
|--------|-------------|-------------|
| `MovocashIOS-Dev` | `.qa` | `https://api-qa.herringbank.com` |
| `MovocashIOS-Staging` | `.staging` (to add) | TBD |
| `MovocashIOS-Release` | `.production` | `https://api.mobile-banking-qa.herringbank.com` |

`Environment.swift` already supports this — just requires additional Xcode schemes and `xcconfig` files per environment.

### 7.5 Monitoring & Crash Reporting

| Tool | Purpose | Status |
|------|---------|--------|
| **Firebase Crashlytics** | Crash reporting (dependency present) | Needs `Crashlytics.crashlytics().record()` calls |
| **Firebase Performance** | Network latency and screen render times | Not yet added |
| **Firebase Remote Config** | Feature flags without App Store update | Not yet added |

### 7.6 TestFlight Distribution

- Internal testers: developers + QA (immediate distribution, no review)
- External testers: beta users (Apple review required, up to 10,000 users)
- Phased rollout: 1% → 5% → 20% → 100% for production releases

---

## 8. Future Plans — Product Features

### Near Term (Next Sprint)
1. **Biometric JWT persistence** — Store Herring JWT in Keychain after biometric unlock so users skip OTP on app restart. (See `docs/` for detailed proposal.)
2. **SSL certificate pinning** — Wire `SecureSessionDelegate` to `NetworkService`. Obtain and bundle server certs.
3. **Unit tests** — Priority order: `NetworkService`, `AuthViewModel`, `AppLockManager`, `SessionManager`, `PasscodeManager`.
4. **Plaid ACH completion** — Finish bank linking flow, connect public token exchange to backend.

### Medium Term
5. **Deep link routing** — Implement `DeepLinkRouter` so push notification taps navigate to the correct screen (e.g., transaction detail).
6. **Bill Pay alternative** — Product decision: defer, or build a proxy endpoint in the Skinny Processor.
7. **Profile picture** — Store in Skinny Processor or middleware; Consumer API has no endpoint.
8. **Rewards redemption UI** — `RewardViewModel` is complete; the redemption flow view needs to be built.
9. **Offline handling** — Queue failed mutations (transfers, ACH) and retry on reconnect.
10. **Transaction search & filters** — Backend supports filters; UI currently shows flat list.

### Long Term
11. **Android app** — Same Skinny Processor, same API. Kotlin + Jetpack Compose. Begins after iOS MVP ships.
12. **Apple Pay provisioning** — `HerringWalletProvisioning.swift` is scaffolded; needs PassKit entitlement and device test.
13. **Google Pay / Samsung Pay** — Parallel to Apple Pay via the `provision` endpoint (provider enum already defined).
14. **Biometric-step-up for payments** — Use `sensitiveChallenge(actionID:)` to require re-authentication before ACH transfers above a threshold.
15. **Remote Config / Feature Flags** — Firebase Remote Config to enable/disable features per segment without releases.

---

## 9. Security Posture

### What is in place

| Control | Implementation | Status |
|---------|---------------|--------|
| Transport security | HTTPS enforced (ATS) | Active |
| Token storage | Keychain (`AfterFirstUnlock`, biometric-gated tiers) | Active |
| PIN storage | PBKDF2-SHA256, 310,000 iterations, random salt | Active |
| Biometric key | Secure Enclave, `.biometryCurrentSet` | Active |
| Jailbreak detection | Pre-request check in `NetworkService` | Active |
| Screen recording protection | `ScreenSecurityManager` on sensitive views | Active |
| Log redaction | `SecureLogger` auto-redacts tokens, card numbers, emails | Active |
| Progressive lockout | 3 attempts → lockout, 4 rounds → force OTP | Active |
| Biometric lockout persisted | Keychain (survives force-quit) | Active |
| SSL pinning | `SecureSessionDelegate` stub present | **Not active** |
| Certificate transparency | Not implemented | Gap |
| Biometric JWT restore | Not implemented | Gap |

### Authentication Token Lifecycle

```
OTP Login
  ↓ POST /auth/token-sms
  ↓ Returns: { accessToken (JWT, 15min), refreshToken (opaque, 90 days) }
  ↓ accessToken → AuthManager actor (in-memory) + Keychain (.backgroundSafe)
  ↓ refreshToken → Keychain (.backgroundSafe)

API call with expired accessToken
  ↓ 401 response
  ↓ NetworkService calls POST /auth/refresh-token
  ↓ New accessToken stored in AuthManager + Keychain
  ↓ Original request retried

Refresh token expired / invalid
  ↓ SessionManager.forceLogout()
  ↓ Both tokens deleted from Keychain
  ↓ User routed to phone login screen
```

---

## 10. Dependency Map

### Swift Package Manager Dependencies

| Package | Purpose | Version |
|---------|---------|---------|
| **MobileBankingSDK** (Herring) | KYC identity verification | Latest stable |
| **Firebase iOS SDK** | Analytics, Crashlytics, FCM | ~11.x |
| **PlaidLink** | Bank account linking (ACH) | Latest stable |
| **BlinkIDUX** | Document scanning (mentioned in integration guides) | 7.3.1 |

### Native Apple Frameworks Used

| Framework | Usage |
|-----------|-------|
| `SwiftUI` | All UI |
| `LocalAuthentication` | Face ID / Touch ID |
| `Security` (Keychain API) | Token + PIN storage |
| `CryptoKit` | Hashing, key derivation |
| `CommonCrypto` | PBKDF2 |
| `Network` | NWPathMonitor for reachability |
| `PassKit` | Apple Pay provisioning (planned) |
| `Contacts` | Quick transfer contact list |
| `UserNotifications` | Push notification handling |

### File Count by Layer

| Layer | File Count | Status |
|-------|-----------|--------|
| App (entry, delegate) | 2 | Complete |
| Core / Network | 14 | 95% complete |
| Core / Security | 10 | 95% complete |
| Core / Config + Utilities | 6 | Complete |
| Core / Extensions | 6 | Complete |
| Core / Reachability | 2 | Complete |
| Features / Auth | 8 | Complete |
| Features / Home | 25+ | 60-70% complete |
| Features / BiometricPasscode | 5 | Complete |
| Features / Launch | 3 | Complete |
| Features / ViewModels | 10 | 85% complete |
| Features / Models | 15 | Complete |
| KYC | 7 | 85% complete |
| FCM + Analytics | 6 | Complete |
| Shared Components | 14 | Complete |
| Tests | 3 | 5% (stubs only) |
| **Total** | **~136** | **~82% overall** |

---

## Appendix — Key File Locations

| Concern | File |
|---------|------|
| App entry point | `MovocashIOS/App/MovocashIOSApp.swift` |
| Dependency assembly | `MovocashIOS/App/AppContainer.swift` |
| Root navigation | `MovocashIOS/Features/Launch/RootView.swift` |
| Global state | `MovocashIOS/Features/Launch/AppState.swift` |
| HTTP client | `MovocashIOS/Core/Network/NetworkService.swift` |
| Auth flow VM | `MovocashIOS/Features/Authorization/ViewModels/AuthViewModel.swift` |
| Session lifecycle | `MovocashIOS/Features/SessionManager.swift` |
| App lock | `MovocashIOS/Core/Security/AppLockManager.swift` |
| PIN hashing | `MovocashIOS/Core/Security/BiometricPasscode/PasscodeManager.swift` |
| Biometric eval | `MovocashIOS/Core/Security/BiometricPasscode/BiometricManager.swift` |
| Token storage | `MovocashIOS/Core/Security/KeychainManager.swift` |
| KYC SDK wrapper | `MovocashIOS/KYC/KYCManager.swift` |
| Analytics | `MovocashIOS/FCM/Analytics/AnalyticsManager.swift` |
| Push notifications | `MovocashIOS/FCM/PushManager.swift` |
| Environment config | `MovocashIOS/Core/Config/Environment.swift` |
| Secure logging | `MovocashIOS/Core/Utilities/SecureLogger.swift` |
