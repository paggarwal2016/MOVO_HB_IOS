//
//  JailbreakDetector.swift
//  MovocashIOS
//
//  Created by Movo Developer on 20/02/26.
//

import Foundation
import MachO
import Darwin

actor JailbreakDetector {

    static let shared = JailbreakDetector()
    private init() {}

    // Cached — a device does not become un-jailbroken between checks.
    private var _cached: Bool?

    var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if let cached = _cached { return cached }
        let result = runChecks()
        _cached = result
        return result
        #endif
    }

    // MARK: - Aggregator

    private func runChecks() -> Bool {
        checkSuspiciousPaths()
            || canWriteOutsideSandbox()
            || checkSymbolicLinks()
            || checkInjectedLibraries()
            || checkDebugger()
    }

    // MARK: - Suspicious Path Detection
    // Uses lstat(2) instead of FileManager to reduce the hook surface area.

    private func checkSuspiciousPaths() -> Bool {
        let paths: [String] = [
            // Jailbreak app stores
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Installer.app",
            "/Applications/Unc0ver.app",
            "/Applications/checkra1n.app",

            // Hooking frameworks (MobileSubstrate, Substitute, libhooker)
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries",
            "/usr/lib/libsubstitute.dylib",
            "/usr/lib/libhooker.dylib",
            "/usr/lib/TweakInject.dylib",
            "/usr/lib/substrate",

            // Common jailbreak binaries
            "/bin/bash",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/usr/bin/cycript",

            // Package manager artefacts
            "/etc/apt",
            "/var/lib/cydia",
            "/var/lib/apt",
            "/var/cache/apt",
            "/var/stash",

            // Palera1n / rootful bootstrap artefacts
            "/private/preboot/procursus",
            "/private/var/mobileLibrary/SBSettingsThemes",

            // Generic private-filesystem artefacts
            "/private/var/lib/apt",
            "/private/etc/apt",
            "/private/var/stash",
            "/private/var/lib/cydia",
        ]

        var st = stat()
        for path in paths where lstat(path, &st) == 0 {
            SecureLogger.warning("JailbreakDetector: suspicious path — \(path)", category: .security)
            return true
        }
        return false
    }

    // MARK: - Sandbox Write Check
    // Uses open(2) directly to reduce the FileManager hook surface.
    // Targets /private/ root — outside every app sandbox on stock iOS.

    private func canWriteOutsideSandbox() -> Bool {
        let path = "/private/jb_probe_\(arc4random()).tmp"
        let fd = Darwin.open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return false }
        Darwin.close(fd)
        Darwin.unlink(path)
        SecureLogger.warning("JailbreakDetector: write outside sandbox succeeded", category: .security)
        return true
    }

    // MARK: - Symbolic Link Detection
    // On rootful jailbreaks (Palera1n, Checkra1n), /Applications is replaced with
    // a symlink. On stock iOS it is always a real directory.
    // Only /Applications is checked — other system paths (/Library/Ringtones,
    // /usr/share, etc.) can legitimately be symlinks on stock iOS and must not
    // be used as jailbreak signals.

    private func checkSymbolicLinks() -> Bool {
        var st = stat()
        if lstat("/Applications", &st) == 0, (st.st_mode & S_IFMT) == S_IFLNK {
            SecureLogger.warning("JailbreakDetector: /Applications is a symlink", category: .security)
            return true
        }
        return false
    }

    // MARK: - Injected Library Detection
    // Scans the dyld image list for known hooking and instrumentation libraries.
    // DYLD environment variable checks are intentionally omitted: on stock iOS the
    // sandbox blocks DYLD injection entirely, and Xcode itself sets DYLD_INSERT_LIBRARIES
    // when debugging on a real device — making that check a reliable false-positive source.

    private func checkInjectedLibraries() -> Bool {
        let patterns: [String] = [
            "frida",            // FridaGadget / frida-agent / frida-gadget
            "mobilesubstrate",
            "libsubstitute",
            "substrate",
            "substrateInserter",
            "libhooker",
            "cycript",
            "cynject",
            "sslkillswitch",
            "tweakinject",
            "substitute",
        ]

        for i in 0..<_dyld_image_count() {
            guard let raw = _dyld_get_image_name(i) else { continue }
            let name = String(cString: raw).lowercased()
            if patterns.contains(where: { name.contains($0) }) {
                SecureLogger.warning("JailbreakDetector: suspicious dylib loaded — \(name)", category: .security)
                return true
            }
        }

        return false
    }

    // MARK: - Debugger Detection
    // Reads the P_TRACED flag from the kernel process table via sysctl.
    // Skipped in DEBUG builds so Xcode attaches normally during development.

    private func checkDebugger() -> Bool {
        #if DEBUG
        return false
        #else
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return false }
        // P_TRACED = 0x00000800 — set by the kernel when a debugger is attached.
        if (Int32(info.kp_proc.p_flag) & 0x00000800) != 0 {
            SecureLogger.warning("JailbreakDetector: debugger attached (P_TRACED)", category: .security)
            return true
        }
        return false
        #endif
    }
}
