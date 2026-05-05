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
        if !filter.transactionStatus.isEmpty  { n += 1 }
        if !filter.merchantName.isEmpty        { n += 1 }
        if !filter.last4.isEmpty              { n += 1 }
        if filter.amount != nil || minSlider > 0 || maxSlider < 500 { n += 1 }
        if fromDate != nil || toDate != nil   { n += 1 }
        return n
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.movo.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Filter")
                        .font(Typography.sectionTitle.font)
                        .foregroundStyle(.white)
                    if activeCount > 0 {
                        Text("\(activeCount) active")
                            .font(Typography.caption.font)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.2), in: Capsule())
                    }
                    Spacer()
                    Button("Reset", action: onReset)
                        .font(Typography.body.font)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        searchSection
                        dateSection
                        amountSection
                        statusSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 110)
                }

                bottomBar
            }
        }
        .onAppear { load() }
    }

    // MARK: - Search

    private var searchSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle((Color.movo.textTertiary))
                .font(.system(size: 15))
            TextField("", text: $filter.merchantName,
                      prompt: Text("Search by name or merchant").foregroundColor(.white.opacity(0.6)))
                .font(Typography.caption.font)
                .foregroundStyle(Color.movo.textPrimary)
                .tint(Color.movo.textPrimary)
                .autocorrectionDisabled()
            if !filter.merchantName.isEmpty {
                Button { filter.merchantName = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.movo.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Date Range

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DATE RANGE")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DatePreset.allCases.filter { $0 != .custom }, id: \.self) { presetChip($0) }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 12) {
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
                .font(selected ? Typography.bodyCompact.font : Typography.subtitle.font)
                .foregroundStyle(selected ? Color.movo.background : Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(selected ? Color.white : Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func dateCard(_ label: String, date: Binding<Date?>, range: ClosedRange<Date>? = nil) -> some View {
        let selection = Binding<Date>(
            get: { date.wrappedValue ?? Date() },
            set: { date.wrappedValue = $0; datePreset = .custom }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typography.eyebrow.font)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)
            Group {
                if let range {
                    DatePicker("", selection: selection, in: range, displayedComponents: .date)
                } else {
                    DatePicker("", selection: selection, displayedComponents: .date)
                }
            }
            .labelsHidden()
            .colorScheme(.dark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("AMOUNT")
                Spacer()
                Text("$\(Int(minSlider)) – $\(Int(maxSlider))\(maxSlider >= 500 ? "+" : "")")
                    .font(Typography.bodyCompact.font)
                    .foregroundStyle(.white)
            }

            RangeSliderView(minValue: $minSlider, maxValue: $maxSlider, bounds: 0...500, step: 5)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            HStack {
                Text("$0").font(Typography.caption.font).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("$500+").font(Typography.caption.font).foregroundStyle(.white.opacity(0.4))
            }
            
            HStack(spacing: 12) {
                amountTextField
                if showLast4 { last4TextField }
            }
        }
    }

    private var amountTextField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AMOUNT")
                .font(Typography.eyebrow.font)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)
            HStack(spacing: 4) {
                Text("$")
                    .font(Typography.caption.font)
                    .foregroundStyle(.white.opacity(0.6))
                TextField("", text: Binding(
                    get: { filter.amount.map { "\(Int($0))" } ?? "" },
                    set: { str in
                        filter.amount = str.isEmpty ? nil : Double(str)
                    }
                ), prompt: Text("Exact").foregroundColor(.white.opacity(0.5)))
                .keyboardType(.numberPad)
                .foregroundStyle(.white)
                .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var last4TextField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CARD LAST 4")
                .font(Typography.eyebrow.font)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)
            HStack(spacing: 6) {
                Image(systemName: "creditcard")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.system(size: 13))
                TextField("", text: $filter.last4,
                          prompt: Text("1234").foregroundColor(.white.opacity(0.5)))
                    .keyboardType(.numberPad)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .onChange(of: filter.last4) { v in
                        if v.count > 4 { filter.last4 = String(v.prefix(4)) }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("STATUS")
            HStack(spacing: 8) {
                ForEach(statusOptions, id: \.0) { label, value in
                    let selected = filter.transactionStatus == value
                    Button { filter.transactionStatus = value } label: {
                        Text(label)
                            .font(selected ? Typography.bodyCompact.font : Typography.subtitle.font)
                            .foregroundStyle(selected ? Color.movo.background : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(selected ? Color.white : Color.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .font(Typography.buttonLarge.font)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

            Button {
                commit()
                onApply()
            } label: {
                Text("Apply Filters")
                    .font(Typography.buttonLarge.font)
                    .foregroundStyle(Color.movo.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.movo.background)
    }

    // MARK: - Section Header

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Typography.micro.font)
            .foregroundStyle(.white.opacity(0.5))
            .tracking(0.8)
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
            fromDate = today
            toDate   = today
        case .days7:
            fromDate = cal.date(byAdding: .day, value: -7,  to: today)
            toDate   = today
        case .days30:
            fromDate = cal.date(byAdding: .day, value: -30, to: today)
            toDate   = today
        case .days90:
            fromDate = cal.date(byAdding: .day, value: -90, to: today)
            toDate   = today
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

    private let thumbDiameter: CGFloat = 26
    private let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let span = bounds.upperBound - bounds.lowerBound
            let minX = fraction(minValue, span: span) * w
            let maxX = fraction(maxValue, span: span) * w

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, maxX - minX), height: trackHeight)
                    .offset(x: minX)

                // Min thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .offset(x: minX - thumbDiameter / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let start = minDragStart ?? minValue
                                if minDragStart == nil { minDragStart = minValue }
                                let startX = fraction(start, span: span) * w
                                let raw = bounds.lowerBound + Double((startX + drag.translation.width) / w) * span
                                let stepped = (raw / step).rounded() * step
                                minValue = max(bounds.lowerBound, min(stepped, maxValue - step))
                            }
                            .onEnded { _ in minDragStart = nil }
                    )

                // Max thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .offset(x: maxX - thumbDiameter / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let start = maxDragStart ?? maxValue
                                if maxDragStart == nil { maxDragStart = maxValue }
                                let startX = fraction(start, span: span) * w
                                let raw = bounds.lowerBound + Double((startX + drag.translation.width) / w) * span
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
    static let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    static let apiDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
