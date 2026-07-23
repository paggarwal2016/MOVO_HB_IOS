//
//  RelockLog.swift
//  MovocashIOS
//
//  File-based diagnostic logger for the background→foreground relock flow.
//  Writes to Documents/relock.log, append-only, with fractional-second ISO8601
//  timestamps. Thread-safe via a dedicated serial DispatchQueue — called from
//  scenePhase handlers, NotificationCenter callbacks, and detached Tasks.
//
//  Usage:
//    RelockLog.log("message")      — timestamped entry
//    RelockLog.mark("LABEL")       — ──── LABEL ──── separator (use per cycle)
//    RelockLog.shared.clear()      — truncate the file
//    RelockLog.shared.share(from:) — AirDrop/Message the file off-device
//
//  REMOVE before shipping. This file is diagnostic-only.
//

import Foundation
import UIKit

final class RelockLog {

    static let shared = RelockLog()
    private init() {}

    // MARK: - Static convenience (no import / singleton boilerplate at call sites)

    static func log(_ message: String) { shared._log(message) }
    static func mark(_ label: String)  { shared._mark(label)  }

    // MARK: - Public API

    /// Full path to the log file. Hand this to the user or use share(from:).
    var path: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("relock.log")
    }

    /// Truncate the log file (e.g. at app launch before a repro run).
    func clear() {
        let p = path
        queue.async {
            try? "".write(to: p, atomically: true, encoding: .utf8)
        }
    }

    /// Present a share sheet so the file can be AirDropped or Messaged off the device.
    @MainActor
    func share(from viewController: UIViewController) {
        let url = path
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        viewController.present(vc, animated: true)
    }

    // MARK: - Private

    private let queue = DispatchQueue(label: "com.movo.relocklog", qos: .utility)

    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func _log(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        write(line)
    }

    private func _mark(_ label: String) {
        let line = "\(formatter.string(from: Date())) ──── \(label) ────\n"
        write(line)
    }

    /// Flush-per-line write: open → seek-to-end → write → close each call so the
    /// last entry survives a hang. Falls back to atomic write if the file is new.
    private func write(_ line: String) {
        let p = path
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: p.path) {
                guard let handle = try? FileHandle(forWritingTo: p) else { return }
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: p, options: .atomic)
            }
        }
    }
}
