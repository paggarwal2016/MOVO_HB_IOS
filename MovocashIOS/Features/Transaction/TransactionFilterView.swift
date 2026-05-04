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
        if minSlider > 0 || maxSlider < 500   { n += 1 }
        if fromDate != nil || toDate != nil   { n += 1 }
        return n
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.app.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // Header
                HStack {
                    Text("Filter")
                        .font(Font.montserrat(.bold, size: 22))
                        .foregroundStyle(.white)
                    if activeCount > 0 {
                        Text("\(activeCount) active")
                            .font(AppFont.activityName)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.2), in: Capsule())
                    }
                    Spacer()
                    Button("Reset", action: onReset)
                        .font(Font.montserrat(.semiBold, size: 14))
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
                        if showLast4 { last4Section }
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
                .foregroundStyle((AppColor.secondaryText))
                .font(.system(size: 15))
            TextField("", text: $filter.merchantName,
                      prompt: Text("Search by name or merchant").foregroundColor(.white.opacity(0.6)))
                .font(AppFont.activityName)
                .foregroundStyle(AppColor.white)
                .tint(AppColor.white)
                .autocorrectionDisabled()
            if !filter.merchantName.isEmpty {
                Button { filter.merchantName = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.secondaryText)
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
                .font(Font.montserrat(selected ? .semiBold : .regular, size: 13))
                .foregroundStyle(selected ? AppColor.app : Color.white)
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
                .font(AppFont.eyebrow)
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
                    .font(Font.montserrat(.semiBold, size: 13))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Text("Min")
                        .font(AppFont.body)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28, alignment: .leading)
                    Slider(value: $minSlider, in: 0...500, step: 5)
                        .tint(.white)
                        .onChange(of: minSlider) { v in
                            if v > maxSlider { minSlider = maxSlider }
                        }
                }
                HStack(spacing: 10) {
                    Text("Max")
                        .font(AppFont.body)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28, alignment: .leading)
                    Slider(value: $maxSlider, in: 0...500, step: 5)
                        .tint(.white)
                        .onChange(of: maxSlider) { v in
                            if v < minSlider { maxSlider = minSlider }
                        }
                }
            }

            HStack {
                Text("$0").font(AppFont.body).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("$500+").font(AppFont.body).foregroundStyle(.white.opacity(0.4))
            }
        }
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
                            .font(Font.montserrat(selected ? .semiBold : .regular, size: 13))
                            .foregroundStyle(selected ? AppColor.app : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(selected ? Color.white : Color.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Card Last 4

    private var last4Section: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("CARD LAST 4")
            HStack(spacing: 10) {
                Image(systemName: "creditcard")
                    .foregroundStyle(.white.opacity(0.5))
                TextField("", text: $filter.last4,
                          prompt: Text("e.g. 1234").foregroundColor(.white.opacity(0.6)))
                    .keyboardType(.numberPad)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .onChange(of: filter.last4) { v in
                        if v.count > 4 { filter.last4 = String(v.prefix(4)) }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .font(Font.montserrat(.semiBold, size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

            Button {
                commit()
                onApply()
            } label: {
                Text("Apply Filters")
                    .font(Font.montserrat(.semiBold, size: 16))
                    .foregroundStyle(AppColor.app)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColor.app)
    }

    // MARK: - Section Header

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppFont.sectionHeader)
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


// MARK: - DateFormatter Helpers

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    static let apiDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
