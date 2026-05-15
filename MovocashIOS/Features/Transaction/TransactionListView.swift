//
//  TransactionListView.swift
//  MovocashIOS
//
//  Created by Vinu on 04/05/26.
//

import SwiftUI

// MARK: - Transaction Mode

enum TransactionMode {
    case individual
    case common
}

// MARK: - TransactionListView

struct TransactionListView: View {
    
    @StateObject private var transactionVM: TransactionViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    
    private let accountId: Int
    private let mode: TransactionMode
    @State private var activeFilter:    TransactionFilter
    @State private var pendingFilter:   TransactionFilter
    @State private var showFilterSheet  = false
    @State private var activeChipFilter: TransactionChipFilter = .all
    
    init(container: AppContainer, accountId: Int, mode: TransactionMode = .common) {
        self.accountId = accountId
        self.mode = mode
        _transactionVM = StateObject(wrappedValue: container.makeTransactionViewModel())
        let base = TransactionFilter(accountId: accountId)
        _activeFilter  = State(initialValue: base)
        _pendingFilter = State(initialValue: base)
    }
    
    // MARK: - Computed
    
    private var chipFilteredTransactions: [TransactionItem] {
        guard activeChipFilter != .all else { return transactionVM.filteredTransactions }
        return transactionVM.filteredTransactions.filter { activeChipFilter.matches($0) }
    }
    
    private var displayGroups: [(label: String, date: Date, items: [TransactionItem])] {
        let calendar  = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        let grouped = Dictionary(grouping: chipFilteredTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped.map { date, items in
            let label: String
            if calendar.isDateInToday(date)          { label = "Today" }
            else if calendar.isDateInYesterday(date) { label = "Yesterday" }
            else                                     { label = formatter.string(from: date) }
            return (label: label, date: date, items: items.sorted { $0.date > $1.date })
        }
        .sorted { $0.date > $1.date }
    }
    
    private var totalMoneyIn: Decimal {
        transactionVM.transactions.filter { $0.isCredit }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalMoneyOut: Decimal {
        transactionVM.transactions.filter { !$0.isCredit }.reduce(0) { $0 + $1.amount }
    }
    
    private var moneyInCount:  Int { transactionVM.transactions.filter { $0.isCredit }.count }
    private var moneyOutCount: Int { transactionVM.transactions.filter { !$0.isCredit }.count }
    
    private var activeFilterCount: Int {
        var n = 0
        if !activeFilter.transactionStatus.isEmpty                    { n += 1 }
        if !activeFilter.merchantName.isEmpty                          { n += 1 }
        if !activeFilter.last4.isEmpty                                { n += 1 }
        if activeFilter.minAmount != nil || activeFilter.maxAmount != nil { n += 1 }
        if !activeFilter.fromDate.isEmpty || !activeFilter.toDate.isEmpty { n += 1 }
        return n
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            MovoBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    navBar
                    monthSummary
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg - 2)
                    searchAndFilterRow
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                    filterChipsRow
                        .padding(.bottom, Spacing.md - 2)
                    
                    transactionContent
                }
            }
        }
        .background(Color.movo.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFilterSheet) {
            TransactionFilterView(filter: $pendingFilter, showLast4: mode == .common) {
                activeFilter = pendingFilter
                Task { await transactionVM.loadTransactionsFiltered(filter: activeFilter) }
                showFilterSheet = false
            } onReset: {
                pendingFilter = TransactionFilter(accountId: accountId)
                activeFilter  = pendingFilter
                Task { await transactionVM.loadTransactionsFiltered(filter: activeFilter) }
                showFilterSheet = false
            } onCancel: {
                showFilterSheet = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task { await transactionVM.loadTransactionsFiltered(filter: activeFilter) }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            showFilterSheet = false
            dismiss()
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var transactionContent: some View {
        if transactionVM.state == .loading && transactionVM.transactions.isEmpty {
            loadingSkeleton
        } else if displayGroups.isEmpty {
            emptyState
        } else {
            transactionList
        }
    }
    
    // MARK: - Transaction List
    
    @ViewBuilder
    private func dayTotalsLabel(for items: [TransactionItem]) -> some View {
        let f: NumberFormatter = {
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            nf.minimumFractionDigits = 2
            nf.maximumFractionDigits = 2
            return nf
        }()
        let totalOut = items.filter { !$0.isCredit }.reduce(Decimal(0)) { $0 + $1.amount }
        let totalIn  = items.filter {  $0.isCredit }.reduce(Decimal(0)) { $0 + $1.amount }
        
        HStack(spacing: 5) {
            if totalOut > 0 {
                Text("−$\(f.string(from: NSDecimalNumber(decimal: totalOut)) ?? "0.00")")
                    .font(.system(size: 10, weight: .regular).monospacedDigit())
                    .foregroundColor(Color.movo.textDisabled)
            }
            if totalOut > 0 && totalIn > 0 {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundColor(Color.movo.textDisabled)
            }
            if totalIn > 0 {
                Text("+$\(f.string(from: NSDecimalNumber(decimal: totalIn)) ?? "0.00")")
                    .font(.system(size: 10, weight: .regular).monospacedDigit())
                    .foregroundColor(Color.movo.textDisabled)
            }
        }
    }
    
    private var transactionList: some View {
        LazyVStack(spacing: Spacing.lg) {
            ForEach(displayGroups, id: \.date) { group in
                VStack(spacing: Spacing.sm) {
                    // Section header — scrolls with content
                    HStack {
                        Text(group.label.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(Color.movo.textTertiary)
                        Spacer()
                        dayTotalsLabel(for: group.items)
                    }
                    .padding(.horizontal, Spacing.lg)
                    
                    // Grouped card
                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            TransactionRow(item: item, action: {})
                            
                            if index < group.items.count - 1 {
                                Rectangle()
                                    .fill(Color.movo.border)
                                    .frame(height: Stroke.hairline)
                                    .padding(.leading, Spacing.md + 2 + 38 + Spacing.md)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Radius.heroCard)
                            .fill(Color.movo.surface.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.heroCard)
                            .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.heroCard))
                    .padding(.horizontal, Spacing.lg)
                }
            }
        }
        .padding(.bottom, Spacing.md)
    }
    
    // MARK: - Transaction Row
    
    private struct TransactionRow: View {
        let item:   TransactionItem
        let action: () -> Void
        
        private var isPending: Bool { item.status.lowercased() == "pending" }
        private var isFailed:  Bool {
            item.status.lowercased() == "failed" || item.status.lowercased() == "declined"
        }
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: Spacing.md) {
                    iconView
                        .frame(width: 38, height: 38)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.title)
                                .textStyle(Typography.bodyCompact)
                                .foregroundColor(isFailed ? Color.movo.textTertiary : Color.movo.textPrimary)
                                .lineLimit(1)
                                .strikethrough(isFailed, color: Color.movo.textDisabled)
                            
                            statusPill
                        }
                        
                        Text(combinedSubtitle)
                            .textStyle(Typography.caption)
                            .foregroundColor(Color.movo.textTertiary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    amountView
                }
                .padding(.horizontal, Spacing.md + 2)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
        }
        
        // MARK: Icon
        
        @ViewBuilder
        private var iconView: some View {
            ZStack {
                Circle()
                    .fill(iconBackground)
                Circle()
                    .strokeBorder(iconBorderColor,
                                  style: StrokeStyle(
                                    lineWidth: iconBorderWidth,
                                    dash: isPending ? [3, 2] : []
                                  ))
                Image(systemName: iconSystemName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(iconForeground)
            }
        }
        
        private var iconSystemName: String {
            switch item.type {
            case .deposit:  return "arrow.down"
            case .withdraw: return "arrow.up"
            case .payment:  return "bag"
            case .transfer: return "arrow.left.arrow.right"
            case .unknown:  return "questionmark"
            }
        }
        
        private var iconBackground: AnyShapeStyle {
            if item.type == .deposit {
                return AnyShapeStyle(LinearGradient(
                    colors: [Color.movo.accentTint, Color.movo.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            }
            return AnyShapeStyle(LinearGradient(
                colors: [Color.movo.elevated, Color.movo.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
        
        private var iconForeground: Color {
            if isFailed  { return Color.movo.danger }
            if isPending { return Color.movo.warning }
            return item.type == .deposit ? Color.movo.accent : Color.movo.textSecondary
        }
        
        private var iconBorderColor: Color {
            if isFailed  { return Color.movo.danger.opacity(0.5) }
            if isPending { return Color.movo.warning }
            return item.type == .deposit ? Color.movo.accent : Color.movo.borderStrong
        }
        
        private var iconBorderWidth: CGFloat { isPending ? Stroke.thin : Stroke.hairline }
        
        // MARK: Status Pill
        
        @ViewBuilder
        private var statusPill: some View {
            if isPending {
                StatusPill("Pending", variant: .warning)
                    .scaleEffect(0.85)
                    .frame(height: 14)
            } else if isFailed {
                StatusPill("Failed", variant: .danger)
                    .scaleEffect(0.85)
                    .frame(height: 14)
            }
        }
        
        // MARK: Subtitle
        
        private var combinedSubtitle: String {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            let time = f.string(from: item.date)
            return item.subtitle.isEmpty ? time : "\(item.subtitle) · \(time)"
        }
        
        // MARK: Amount
        
        private var amountView: some View {
            Text(item.amountFormatted)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundColor(isFailed ? Color.movo.textDisabled : (item.isCredit ? Color.movo.accent : Color.movo.textPrimary))
                .strikethrough(isFailed, color: Color.movo.textDisabled)
        }
    }
    
    
    
    
    
    
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        let noFilters = transactionVM.searchText.isEmpty
        && !activeFilter.hasActiveFilters
        && activeChipFilter == .all
        return VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(Color.movo.textTertiary)
            
            VStack(spacing: Spacing.sm) {
                Text(noFilters ? "No transactions yet" : "No results found")
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)
                Text(noFilters
                     ? "Your transactions will appear here once activity begins."
                     : "Try adjusting your search or clearing the filters.")
                .font(Typography.caption.font)
                .foregroundColor(Color.movo.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.huge)
            }
            
            if activeFilter.hasActiveFilters || activeChipFilter != .all {
                Button {
                    activeFilter      = TransactionFilter(accountId: accountId)
                    pendingFilter     = activeFilter
                    activeChipFilter  = .all
                    Task { await transactionVM.loadTransactionsFiltered(filter: activeFilter) }
                } label: {
                    Text("Clear Filters")
                        .font(Typography.button.font)
                        .foregroundColor(Color.movo.background)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.md)
                        .background(Color.movo.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
    
    // MARK: - Loading Skeleton
    
    private var loadingSkeleton: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color.movo.elevated)
                        .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.movo.elevated)
                            .frame(width: 130, height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.movo.surface)
                            .frame(width: 85, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.movo.elevated)
                        .frame(width: 55, height: 12)
                }
                .padding(.horizontal, Spacing.md + 2)
                .padding(.vertical, 13)
                .padding(.horizontal, Spacing.lg)
            }
        }
        .allowsHitTesting(false)
    }
    
}

// MARK: - Extension: Nav, Summary, Search, Filter

extension TransactionListView {
    
    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "chevron.left") { dismiss() }
            Spacer()
            Text("Transactions")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg - 2)
        .padding(.bottom, Spacing.md)
    }
    
    private var monthSummary: some View {
        HStack(spacing: Spacing.lg) {
            SummaryCell(label: "Money in · \(moneyInCount)",
                        value: totalMoneyIn,
                        isInflow: true)
            Rectangle()
                .fill(Color.movo.border)
                .frame(width: Stroke.hairline, height: 36)
            SummaryCell(label: "Money out · \(moneyOutCount)",
                        value: totalMoneyOut,
                        isInflow: false)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
    }
    
    private var searchAndFilterRow: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.movo.textTertiary)
                
                TextField("",
                          text: $transactionVM.searchText,
                          prompt: Text("Search transactions, merchants…")
                    .foregroundColor(Color.movo.textDisabled))
                .textStyle(Typography.bodyCompact)
                .foregroundColor(Color.movo.textPrimary)
                .focused($searchFocused)
            }
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.movo.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .strokeBorder(searchFocused ? Color.movo.accentBorder : Color.movo.border,
                                          lineWidth: Stroke.hairline)
                    )
            )
            
            FilterIconButton(activeCount: activeFilterCount) {
                pendingFilter   = activeFilter
                showFilterSheet = true
            }
        }
    }
    
    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TransactionChipFilter.allCases) { chip in
                    FilterChip(
                        filter:   chip,
                        isActive: activeChipFilter == chip,
                        count:    chip == .all ? transactionVM.totalCount : nil,
                        action:   { activeChipFilter = chip }
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }
    
    // MARK: - Nested Views
    
    private struct FilterChip: View {
        let filter:   TransactionChipFilter
        let isActive: Bool
        let count:    Int?
        let action:   () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 5) {
                    if let icon = filter.systemIcon {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .medium))
                    }
                    Text(filter.label)
                        .font(.system(size: 11, weight: .medium))
                    
                    if let count {
                        Text("\(count)")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(isActive ? Color.movo.accent : Color.movo.accent.opacity(0.15))
                            )
                            .foregroundColor(isActive ? Color.movo.background : Color.movo.accent)
                    }
                }
                .foregroundColor(isActive ? Color.movo.accent : Color.movo.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? Color.movo.accentTint : Color.movo.elevated.opacity(0.6))
                        .overlay(
                            Capsule().strokeBorder(
                                isActive ? Color.movo.accentBorder : Color.movo.border,
                                lineWidth: Stroke.hairline
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private struct SummaryCell: View {
        let label:    String
        let value:    Decimal
        let isInflow: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                Eyebrow(label)
                Text(formattedValue)
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundColor(isInflow ? Color.movo.accent : Color.movo.textPrimary)
                    .tracking(-0.2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        private var formattedValue: String {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            let abs = NSDecimalNumber(decimal: Swift.abs(value))
            let prefix = isInflow ? "+" : "−"
            return "\(prefix)$\(f.string(from: abs) ?? "0.00")"
        }
    }
    
    private struct FilterIconButton: View {
        let activeCount: Int
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.movo.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.button)
                            .fill(Color.movo.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.button)
                                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                            )
                    )
                    .overlay(alignment: .topTrailing) {
                        if activeCount > 0 {
                            Text("\(activeCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color.movo.background)
                                .frame(width: 14, height: 14)
                                .background(
                                    Circle()
                                        .fill(Color.movo.accent)
                                        .overlay(Circle().strokeBorder(Color.movo.background, lineWidth: 1.5))
                                )
                                .offset(x: 4, y: -4)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Chip Filter

enum TransactionChipFilter: String, CaseIterable, Identifiable, Sendable {
    case all, moneyIn, moneyOut, pending, settled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:     return "All"
        case .moneyIn: return "Money in"
        case .moneyOut: return "Money out"
        case .pending:  return "Pending"
        case .settled:  return "Settled"
        }
    }

    var systemIcon: String? {
        switch self {
        case .moneyIn:  return "arrow.down.left"
        case .moneyOut: return "arrow.up.right"
        default:        return nil
        }
    }

    func matches(_ item: TransactionItem) -> Bool {
        switch self {
        case .all:      return true
        case .moneyIn:  return item.isCredit
        case .moneyOut: return !item.isCredit
        case .pending:  return item.status.lowercased() == "pending"
        case .settled:
            let s = item.status.lowercased()
            return s != "pending" && s != "failed" && s != "declined"
        }
    }
}
