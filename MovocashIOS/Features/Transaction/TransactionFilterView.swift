//
//  TransactionFilterView.swift
//  MovocashIOS
//
//  Created by Vinu on 04/05/26.
//

import Foundation
import SwiftUI

// MARK: - TransactionFilterSheet

struct TransactionFilterView: View {

    @Binding var filter: TransactionFilter
    var showLast4: Bool
    var onApply:  () -> Void
    var onReset:  () -> Void
    var onCancel: () -> Void

    @State private var minSlider:  Double = 0
    @State private var maxSlider:  Double = 500
    @State private var fromDate:   Date?  = nil
    @State private var toDate:     Date?  = nil
    @State private var datePreset: DatePreset = .custom

    private enum DatePreset: String, CaseIterable {
        case today  = "Today"
        case days7  = "7 days"
        case days30 = "30 days"
        case days90 = "90 days"
        case custom = "Custom"
    }

    private let statusOptions: [(String, String)] = [
        ("All", ""), ("Pending", "Pending"), ("Settled", "Settled"), ("Failed", "Failed")
    ]

    private var activeCount: Int {
        var n = 0
        if !filter.transactionStatus.isEmpty                      { n += 1 }
        if !filter.merchantName.isEmpty                            { n += 1 }
        if !filter.last4.isEmpty                                  { n += 1 }
        if filter.amount != nil || minSlider > 0 || maxSlider < 500 { n += 1 }
        if fromDate != nil || toDate != nil                       { n += 1 }
        return n
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MovoBackground()

            VStack(spacing: 0) {
                header
                Divider().overlay(Color.movo.border)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.xxl) {
                        searchSection
                        dateSection
                        amountSection
                        statusSection
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xxl)
                    .padding(.bottom, 110)
                }

                bottomBar
            }
        }
        .onAppear { load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Text("Filter")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)

            if activeCount > 0 {
                Text("\(activeCount) active")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.accent)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.movo.accentTint, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
            }

            Spacer()

            Button("Reset", action: onReset)
                .buttonStyle(.plain)
                .textStyle(Typography.bodyCompact)
                .foregroundColor(Color.movo.accent)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Search

    private var searchSection: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.movo.textTertiary)
                .font(.system(size: 15))
            TextField("",
                      text: $filter.merchantName,
                      prompt: Text("Search by name or merchant")
                          .foregroundColor(Color.movo.textDisabled))
                .textStyle(Typography.caption)
                .foregroundColor(Color.movo.textPrimary)
                .tint(Color.movo.accent)
                .autocorrectionDisabled()
            if !filter.merchantName.isEmpty {
                Button { filter.merchantName = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.movo.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md + 2)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface)
                .overlay(RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        )
    }

    // MARK: - Date Range

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("DATE RANGE")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(DatePreset.allCases.filter { $0 != .custom }, id: \.self) { presetChip($0) }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: Spacing.md) {
                dateCard("FROM", date: $fromDate,
                         range: Date.distantPast...(toDate ?? Date()))
                dateCard("TO",   date: $toDate,
                         range: (fromDate ?? Date.distantPast)...Date())
            }
        }
    }

    private func presetChip(_ preset: DatePreset) -> some View {
        let selected = datePreset == preset
        return Button {
            datePreset = preset
            applyPreset(preset)
        } label: {
            Text(preset.rawValue)
                .textStyle(selected ? Typography.bodyCompact : Typography.caption)
                .foregroundColor(selected ? Color.movo.onAccent : Color.movo.textSecondary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm + 1)
                .background(
                    Capsule()
                        .fill(selected ? Color.movo.accent : Color.movo.elevated.opacity(0.6))
                        .overlay(Capsule().strokeBorder(
                            selected ? Color.movo.accentBorder : Color.movo.border,
                            lineWidth: Stroke.hairline))
                )
        }
        .buttonStyle(.plain)
    }

    private func dateCard(_ label: String, date: Binding<Date?>, range: ClosedRange<Date>? = nil) -> some View {
        let selection = Binding<Date>(
            get: { date.wrappedValue ?? Date() },
            set: { date.wrappedValue = $0; datePreset = .custom }
        )
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)
            Group {
                if let range {
                    DatePicker("", selection: selection, in: range, displayedComponents: .date)
                } else {
                    DatePicker("", selection: selection, displayedComponents: .date)
                }
            }
            .labelsHidden()
            .tint(Color.movo.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md + 2)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface)
                .overlay(RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        )
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                sectionHeader("AMOUNT")
                Spacer()
                Text("$\(Int(minSlider)) – $\(Int(maxSlider))\(maxSlider >= 500 ? "+" : "")")
                    .textStyle(Typography.bodyCompact)
                    .foregroundColor(Color.movo.textPrimary)
            }

            RangeSliderView(minValue: $minSlider, maxValue: $maxSlider, bounds: 0...500, step: 5)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

            HStack {
                Text("$0").textStyle(Typography.caption).foregroundColor(Color.movo.textDisabled)
                Spacer()
                Text("$500+").textStyle(Typography.caption).foregroundColor(Color.movo.textDisabled)
            }

            HStack(spacing: Spacing.md) {
                amountTextField
                if showLast4 { last4TextField }
            }
        }
    }

    private var amountTextField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("AMOUNT")
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)
            HStack(spacing: Spacing.xs) {
                Text("$")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
                TextField("",
                          text: Binding(
                            get: { filter.amount.map { "\(Int($0))" } ?? "" },
                            set: { filter.amount = $0.isEmpty ? nil : Double($0) }
                          ),
                          prompt: Text("0").foregroundColor(Color.movo.textDisabled))
                .keyboardType(.numberPad)
                .foregroundColor(Color.movo.textPrimary)
                .tint(Color.movo.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md + 2)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface)
                .overlay(RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        )
    }

    private var last4TextField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("CARD LAST 4")
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)
            HStack(spacing: Spacing.sm) {
                Image(systemName: "creditcard")
                    .foregroundColor(Color.movo.textTertiary)
                    .font(.system(size: 13))
                TextField("",
                          text: $filter.last4,
                          prompt: Text("1234").foregroundColor(Color.movo.textDisabled))
                    .keyboardType(.numberPad)
                    .foregroundColor(Color.movo.textPrimary)
                    .tint(Color.movo.accent)
                    .onChange(of: filter.last4) { v in
                        if v.count > 4 { filter.last4 = String(v.prefix(4)) }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md + 2)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface)
                .overlay(RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        )
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("STATUS")
            HStack(spacing: Spacing.sm) {
                ForEach(statusOptions, id: \.0) { label, value in
                    let selected = filter.transactionStatus == value
                    Button { filter.transactionStatus = value } label: {
                        Text(label)
                            .textStyle(selected ? Typography.bodyCompact : Typography.caption)
                            .foregroundColor(selected ? Color.movo.onAccent : Color.movo.textSecondary)
                            .padding(.horizontal, Spacing.md + 2)
                            .padding(.vertical, Spacing.sm + 1)
                            .background(
                                Capsule()
                                    .fill(selected ? Color.movo.accent : Color.movo.elevated.opacity(0.6))
                                    .overlay(Capsule().strokeBorder(
                                        selected ? Color.movo.accentBorder : Color.movo.border,
                                        lineWidth: Stroke.hairline))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: Spacing.md) {
            Button("Cancel", action: onCancel)
                .buttonStyle(OutlineButtonStyle())

            Button {
                commit()
                onApply()
            } label: {
                Text("Apply Filters")
            }
            .buttonStyle(MovoPrimaryButtonStyle())
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .background(
            Color.movo.background
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.movo.border).frame(height: Stroke.hairline)
                }
        )
    }

    // MARK: - Section Header

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.micro)
            .foregroundColor(Color.movo.textTertiary)
    }

    // MARK: - Helpers

    private func load() {
        minSlider = filter.minAmount ?? 0
        maxSlider = filter.maxAmount ?? 500
        fromDate  = filter.fromDate.isEmpty ? nil : DateFormatter.apiDate.date(from: filter.fromDate)
        toDate    = filter.toDate.isEmpty   ? nil : DateFormatter.apiDate.date(from: filter.toDate)
    }

    private func commit() {
        filter.minAmount = minSlider > 0   ? minSlider : nil
        filter.maxAmount = maxSlider < 500 ? maxSlider : nil
        filter.fromDate  = fromDate.map { DateFormatter.apiDate.string(from: $0) } ?? ""
        filter.toDate    = toDate.map   { DateFormatter.apiDate.string(from: $0) } ?? ""
    }

    private func applyPreset(_ preset: DatePreset) {
        let cal   = Calendar.current
        let today = Date()
        switch preset {
        case .today:
            fromDate = today;  toDate = today
        case .days7:
            fromDate = cal.date(byAdding: .day, value: -7,  to: today);  toDate = today
        case .days30:
            fromDate = cal.date(byAdding: .day, value: -30, to: today);  toDate = today
        case .days90:
            fromDate = cal.date(byAdding: .day, value: -90, to: today);  toDate = today
        case .custom:
            break
        }
    }
}

// MARK: - Range Slider

private struct RangeSliderView: View {
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let bounds: ClosedRange<Double>
    let step: Double

    @State private var minDragStart: Double? = nil
    @State private var maxDragStart: Double? = nil

    private let thumbDiameter: CGFloat = 24
    private let trackHeight:   CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let w    = proxy.size.width
            let span = bounds.upperBound - bounds.lowerBound
            let minX = fraction(minValue, span: span) * w
            let maxX = fraction(maxValue, span: span) * w

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.movo.elevated)
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.movo.accent)
                    .frame(width: max(0, maxX - minX), height: trackHeight)
                    .offset(x: minX)

                // Min thumb
                Circle()
                    .fill(Color.movo.surface)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: Color.movo.background.opacity(0.4), radius: 4, y: 2)
                    .overlay(Circle().strokeBorder(Color.movo.accent, lineWidth: Stroke.thin))
                    .offset(x: minX - thumbDiameter / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let start = minDragStart ?? minValue
                                if minDragStart == nil { minDragStart = minValue }
                                let startX = fraction(start, span: span) * w
                                let raw    = bounds.lowerBound + Double((startX + drag.translation.width) / w) * span
                                let stepped = (raw / step).rounded() * step
                                minValue = max(bounds.lowerBound, min(stepped, maxValue - step))
                            }
                            .onEnded { _ in minDragStart = nil }
                    )

                // Max thumb
                Circle()
                    .fill(Color.movo.surface)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: Color.movo.background.opacity(0.4), radius: 4, y: 2)
                    .overlay(Circle().strokeBorder(Color.movo.accent, lineWidth: Stroke.thin))
                    .offset(x: maxX - thumbDiameter / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let start = maxDragStart ?? maxValue
                                if maxDragStart == nil { maxDragStart = maxValue }
                                let startX = fraction(start, span: span) * w
                                let raw    = bounds.lowerBound + Double((startX + drag.translation.width) / w) * span
                                let stepped = (raw / step).rounded() * step
                                maxValue = min(bounds.upperBound, max(stepped, minValue + step))
                            }
                            .onEnded { _ in maxDragStart = nil }
                    )
            }
            .frame(height: thumbDiameter)
        }
        .frame(height: thumbDiameter)
    }

    private func fraction(_ value: Double, span: Double) -> CGFloat {
        CGFloat((value - bounds.lowerBound) / span)
    }
}

// MARK: - DateFormatter Helpers

private extension DateFormatter {
    static let apiDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
