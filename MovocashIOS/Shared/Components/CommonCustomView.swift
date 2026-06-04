//
//  CommonCustomView.swift
//  MovocashIOS
//
//  Created by Vinu on 04/06/26.
//

import SwiftUI


// MARK: - Reusable Sheet Header

struct CustomSheetHeader: View {
    
    // MARK: Config
    
    let title: String
    let subtitle: String
    
    var systemImage: String = "person.badge.plus"
    
    var iconTint: Color = .blue
    var iconBackground: Color = .blue.opacity(0.12)
    
    var showsCloseButton: Bool = true
    
    var horizontalPadding: CGFloat = 24
    var topPadding: CGFloat = 28
    var bottomPadding: CGFloat = 18
    
    var closeAction: (() -> Void)?
    
    // MARK: UI
    
    var body: some View {
        
        HStack(alignment: .top, spacing: 16) {
            
            // MARK: Icon
            
            ZStack {
                
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                iconTint.opacity(0.18),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            .frame(width: 44, height: 44)
            
            
            // MARK: Content
            
            VStack(alignment: .leading, spacing: 4) {
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.movo.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.movo.textTertiary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 12)
            
            
            // MARK: Close
            
            if showsCloseButton {
                
                Button {
                    closeAction?()
                } label: {
                    
                    ZStack {

                        Circle()
                            .fill(Color.movo.elevated)

                        Circle()
                            .stroke(
                                Color.movo.border,
                                lineWidth: Stroke.hairline
                            )

                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.movo.textPrimary)
                    }
                    .frame(width: 32, height: 32)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }
}


// MARK: - Reusable Custom TextField

struct CustomTextField: View {
    
    @Binding var text: String

    var placeholder: String = "Nickname (e.g., Mom, Roommate)"
    var keyboardType: UIKeyboardType = .default
    var cornerRadius: CGFloat = Radius.lg
    var height: CGFloat = 50

    var body: some View {

        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textStyle(Typography.body)
            .foregroundColor(Color.movo.textPrimary)
            .tint(Color.movo.accent)
            .padding(.horizontal, Spacing.lg)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.movo.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.thin)
                    )
            )
    }
}


// MARK: - Reusable USA Phone Field

struct CustomPhoneField: View {
    
    @Binding var phoneNumber: String
    
    var countryCode: String = "+1"
    var placeholder: String = "(555) 000-0000"

    var cornerRadius: CGFloat = Radius.lg
    var height: CGFloat = 50

    var body: some View {

        HStack(spacing: Spacing.md) {

            Text(countryCode)
                .textStyle(Typography.body)
                .foregroundColor(Color.movo.textPrimary)

            Rectangle()
                .fill(Color.movo.border)
                .frame(width: Stroke.thin, height: 24)

            TextField(placeholder, text: $phoneNumber)
                .keyboardType(.numberPad)
                .textStyle(Typography.body)
                .foregroundColor(Color.movo.textPrimary)
                .tint(Color.movo.accent)
                .onChange(of: phoneNumber) { value in
                    phoneNumber = formatUSPhone(value)
                }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.movo.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.thin)
                )
        )
    }
    
    // MARK: - USA Format

    private func formatUSPhone(_ value: String) -> String {

        let digits = value.filter(\.isNumber)
        let limited = String(digits.prefix(10))

        switch limited.count {

        case 0:
            return ""

        case 1...3:
            return "(\(limited)"

        case 4...6:
            let area = limited.prefix(3)
            let middle = limited.dropFirst(3)
            return "(\(area)) \(middle)"

        default:
            let area = limited.prefix(3)
            let middle = limited.dropFirst(3).prefix(3)
            let last = limited.dropFirst(6)
            return "(\(area)) \(middle)-\(last)"
        }
    }
}


// MARK: - Reusable Amount Input Display

/// Large "$0.00" style amount entry. The visible text is rendered manually so the
/// dollar / cents portions can be styled independently; an invisible decimal-pad
/// `TextField` overlay captures the actual input. `amountFocused` is owned by the
/// caller so it can drive placeholder logic and keyboard dismissal.
struct AmountInputDisplay: View {

    @Binding var amountText: String
    var amountFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("$")
                .textStyle(Typography.amountPrefix)
                .foregroundColor(Color.movo.textSecondary)
                .baselineOffset(25)

            let parts = amountText.split(separator: ".")
            Text(parts.first.map(String.init) ?? "0")
                .textStyle(Typography.amountInput)
                .monospacedDigit()
                .foregroundColor(Color.movo.textPrimary)

            Text(".\(parts.count > 1 ? String(parts[1]) : "00")")
                .textStyle(Typography.amountPrefix)
                .monospacedDigit()
                .foregroundColor(Color.movo.textSecondary)
                .baselineOffset(25)
        }
        .contentShape(Rectangle())
        .onTapGesture { amountFocused.wrappedValue = true }
        .overlay(
            TextField("", text: $amountText)
                .keyboardType(.decimalPad)
                .focused(amountFocused)
                .opacity(0)
        )
    }
}


// MARK: - Reusable Amount Preset Chips

/// Row of tappable amount chips (e.g. $10 / $25 / $50 / $100). A preset whose value
/// is `nil` acts as a "max" chip and is resolved against `maxValue`; pass `maxValue`
/// only when a balance-backed max chip is needed.
struct AmountPresetChips: View {

    let presets: [(String, Double?)]
    @Binding var amountText: String
    var amountFocused: FocusState<Bool>.Binding
    var maxValue: Double? = nil

    private var amount: Double { Double(amountText) ?? 0 }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(presets, id: \.0) { label, value in
                let selected = isSelected(value)
                Button { apply(value) } label: {
                    Text(label)
                        .textStyle(Typography.body)
                        .foregroundColor(selected ? Color.movo.accent : Color.movo.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            Capsule()
                                .fill(selected ? Color.movo.accentTint : Color.movo.elevated)
                                .overlay(
                                    Capsule().strokeBorder(
                                        selected ? Color.movo.accentBorder : Color.clear,
                                        lineWidth: Stroke.hairline
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ value: Double?) -> Bool {
        guard amount > 0 else { return false }
        if let value { return amount == value }
        guard let maxValue else { return false }
        return amount == maxValue && !amountText.isEmpty
    }

    private func apply(_ value: Double?) {
        amountFocused.wrappedValue = false
        if let value {
            amountText = formatAmount(value)
        } else if let maxValue {
            amountText = formatAmount(maxValue)
        }
    }

    private func formatAmount(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : "\(value)"
    }
}


// MARK: - Reusable Amount Entry Section

/// Combines the amount display, an optional "available" caption, and the preset
/// chips. Used anywhere a user enters a dollar amount. Pass `availableText` /
/// `maxValue` only when a funding source (card/balance) backs the entry.
struct AmountEntrySection: View {

    @Binding var amountText: String
    var amountFocused: FocusState<Bool>.Binding
    var availableText: String? = nil
    var presets: [(String, Double?)] = [("$10", 10), ("$25", 25), ("$50", 50), ("$100", 100)]
    var maxValue: Double? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            AmountInputDisplay(amountText: $amountText, amountFocused: amountFocused)

            if let availableText {
                Text(availableText)
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
            }

            AmountPresetChips(
                presets: presets,
                amountText: $amountText,
                amountFocused: amountFocused,
                maxValue: maxValue
            )
        }
    }
}


// MARK: - Reusable Pay Action Button

/// Full-width capsule action button used to submit a payment. The label reads
/// "<title> $<amount>" when `amount > 0`, otherwise just "<title>". Styling tracks
/// `isEnabled`; the actual side effects (dismiss keyboard, send, etc.) live in the
/// caller-supplied `action`.
struct PayActionButton: View {

    var title: String = "Pay"
    var amount: Double = 0
    var systemImage: String = "arrow.up.forward"
    var isEnabled: Bool
    var action: () -> Void

    private var label: String {
        amount > 0 ? "\(title) $\(String(format: "%.2f", amount))" : title
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .textStyle(Typography.buttonLarge)
            }
            .foregroundColor(isEnabled ? Color.movo.onAccent : Color.movo.textDisabled)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule().fill(isEnabled ? Color.movo.accent : Color.movo.elevated)
            )
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}


// MARK: - Reusable Note Card

/// Single-line note field with a leading icon, used for optional transfer memos.
struct NoteCard: View {

    @Binding var text: String
    var prompt: String = "What's it for? (optional)"
    var systemImage: String = "bubble.left"

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.movo.textDisabled)

            TextField("", text: $text,
                      prompt: Text(prompt)
                          .foregroundColor(Color.movo.textDisabled))
                .textStyle(Typography.subtitle)
                .foregroundColor(Color.movo.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.movo.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
    }
}
