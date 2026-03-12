//
//  AppLockView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 10/03/26.
//

import SwiftUI

// MARK: - Root lock view

struct AppLockView: View {

    @ObservedObject var vm: AppLockViewModel
    var autoTriggerBiometric: Bool = true

    var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / brand mark
                lockHeader

                Spacer().frame(height: 40)

                // PIN dots or alphanumeric field
                if vm.isAlphanumeric {
                    alphanumericField
                        .padding(.horizontal, 40)
                } else {
                    PINDotsView(filledCount: vm.pinInput.count, total: AppLockViewModel.pinLength)
                        .modifier(ShakeModifier(trigger: vm.shouldShake))
                }

                // Status / error message
                statusLabel
                    .frame(height: 24)
                    .padding(.top, 16)

                Spacer().frame(height: 32)

                // Number pad (hidden in alphanumeric mode)
                if !vm.isAlphanumeric {
                    PINPadView(
                        onDigit: vm.appendDigit,
                        onDelete: vm.deleteLastDigit,
                        onBiometric: vm.showBiometric ? { Task { await vm.submitBiometric() } } : nil,
                        biometricIcon: vm.biometricIcon
                    )
                    .padding(.horizontal, 24)
                } else {
                    submitButton
                        .padding(.horizontal, 40)
                }

                Spacer().frame(height: 24)

                // Toggle alphanumeric / numeric
                //toggleModeButton

                Spacer()
            }
        }
        .task {
            if autoTriggerBiometric && vm.showBiometric {
                await vm.submitBiometric()
            }
        }
    }

    // MARK: - Sub-views

    private var lockHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppColors.primary)
                .accessibilityHidden(true)
            Text("MovoCash")
                .font(.title2.bold())
            Text("Enter your passcode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var alphanumericField: some View {
        SecureField("Enter passcode", text: $vm.alphanumericInput)
            .textContentType(.password)
            .keyboardType(.default)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .modifier(ShakeModifier(trigger: vm.shouldShake))
            .submitLabel(.go)
            .onSubmit { Task { await vm.submitPIN() } }
    }

    private var submitButton: some View {
        Button {
            Task { await vm.submitPIN() }
        } label: {
            Group {
                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Unlock")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(vm.alphanumericInput.isEmpty || vm.isLoading)
        .accessibilityLabel("Unlock with passcode")
    }

    private var statusLabel: some View {
        Text(vm.statusMessage)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .animation(.default, value: vm.statusMessage)
            .accessibilityLabel(vm.statusMessage.isEmpty ? "" : "Error: \(vm.statusMessage)")
    }

    private var toggleModeButton: some View {
        Button {
            vm.toggleInputMode()
        } label: {
            Text(vm.isAlphanumeric ? "Use 6-digit PIN" : "Use alphanumeric passcode")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(vm.isAlphanumeric ? "Switch to 6-digit PIN" : "Switch to alphanumeric passcode")
    }
}

// MARK: - PIN dots indicator

struct PINDotsView: View {
    let filledCount: Int
    let total: Int

    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < filledCount ? Color.primary : Color.clear)
                    .overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
                    .frame(width: 16, height: 16)
                    .animation(.spring(response: 0.2), value: filledCount)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filledCount) of \(total) digits entered")
    }
}

// MARK: - PIN pad

struct PINPadView: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    let onBiometric: (() -> Void)?
    let biometricIcon: String

    private let rows: [[String]] = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        ["bio","0","del"]
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { key in
                        PINKeyView(
                            key: key,
                            biometricIcon: biometricIcon,
                            showBiometric: onBiometric != nil,
                            onDigit: onDigit,
                            onDelete: onDelete,
                            onBiometric: onBiometric
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Individual PIN key

private struct PINKeyView: View {
    let key: String
    let biometricIcon: String
    let showBiometric: Bool
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    let onBiometric: (() -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button {
            handleTap()
        } label: {
            keyContent
                .frame(width: 76, height: 76)
                .background(
                    Circle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .opacity(isPressed ? 0.5 : 1.0)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .accessibilityLabel(accessibilityLabel)
        .opacity(keyOpacity)
    }

    @ViewBuilder
    private var keyContent: some View {
        switch key {
        case "del":
            Image(systemName: "delete.left")
                .font(.title3)
                .foregroundStyle(.primary)
        case "bio":
            if showBiometric {
                Image(systemName: biometricIcon)
                    .font(.title2)
                    .foregroundStyle(.primary)
            } else {
                Color.clear
            }
        default:
            Text(key)
                .font(.title.weight(.regular))
                .foregroundStyle(.primary)
        }
    }

    private var keyOpacity: Double {
        key == "bio" && !showBiometric ? 0 : 1
    }

    private var accessibilityLabel: String {
        switch key {
        case "del": return "Delete"
        case "bio": return showBiometric ? biometricIcon : ""
        default:    return key
        }
    }

    private func handleTap() {
        switch key {
        case "del": onDelete()
        case "bio": onBiometric?()
        default:    onDigit(key)
        }
    }
}

// MARK: - Shake animation modifier

struct ShakeModifier: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: trigger ? 8 : 0)
            .animation(
                trigger
                    ? .linear(duration: 0.05).repeatCount(6, autoreverses: true)
                    : .default,
                value: trigger
            )
    }
}
