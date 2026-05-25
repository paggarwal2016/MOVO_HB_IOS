//
//  PayAnyoneContactPickerView.swift
//  MovocashIOS
//

import SwiftUI
import Contacts

struct PayAnyoneContactPickerView: View {

    let container: AppContainer
    let cards: [VCardListResponse]
    let accountBalance: Decimal
    let primaryLinkedCard: VCardListResponse?
    var onSuccess: () -> Void = {}

    @StateObject private var contactVM: ContactViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.openURL) private var openURL
    @SwiftUI.Environment(\.scenePhase) private var scenePhase

    @State private var authStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    @State private var selectedFrequent: ContactRecord? = nil
    @State private var showCreateContact = false
    @State private var showAllFrequents = false
    @State private var isInitialLoading = true
    @State private var loadTask: Task<Void, Never>?
    @State private var createContactTask: Task<Void, Never>?

    init(container: AppContainer, cards: [VCardListResponse], accountBalance: Decimal, primaryLinkedCard: VCardListResponse? = nil, onSuccess: @escaping () -> Void = {}) {
        self.container = container
        self.cards = cards
        self.accountBalance = accountBalance
        self.primaryLinkedCard = primaryLinkedCard
        self.onSuccess = onSuccess
        _contactVM = StateObject(wrappedValue: container.makeContactViewModel())
    }

    private var isAuthorized: Bool {
        if #available(iOS 18.0, *) {
            return authStatus == .authorized || authStatus == .limited
        }
        return authStatus == .authorized
    }

    private var isDenied: Bool {
        authStatus == .denied || authStatus == .restricted
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                MovoBackground()

                VStack(spacing: 0) {
                    navBar

                    if isInitialLoading {
                        Spacer()
                        SpinnerView()
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: Spacing.lg) {

                                if !contactVM.frequents.isEmpty {
                                    frequentsSection
                                }

                                contactsListCard

                                if !isAuthorized {
                                    permissionCard
                                        .padding(.horizontal, Spacing.lg)
                                }
                            }
                            .padding(.top, Spacing.md)
                            .padding(.bottom, Spacing.xxxl)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .navigationDestination(for: ContactRecord.self) { contact in
                QuickTransferView(
                    contact: contact,
                    container: container,
                    cards: cards,
                    primaryLinkedCard: primaryLinkedCard,
                    onSuccess: { onSuccess(); dismiss() }
                )
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedFrequent != nil },
                set: { if !$0 { selectedFrequent = nil } }
            )) {
                if let contact = selectedFrequent {
                    QuickTransferView(
                        contact: contact,
                        container: container,
                        cards: cards,
                        primaryLinkedCard: primaryLinkedCard,
                        onSuccess: { onSuccess(); dismiss() }
                    )
                }
            }
            .sheet(isPresented: $showCreateContact) {
                AddContactSheet(container: contactVM, countryCode: "+1", onSave: { data in
                    createContactTask = Task {
                        let success = await contactVM.createContact(
                            nickname: data.nickname,
                            phoneNumber: data.phoneE164
                        )
                        guard !Task.isCancelled else { return }
                        contactVM.clear()
                        showCreateContact = false
                        if success {
                            ToastManager.shared.show(
                                "\(data.nickname) added to contacts",
                                style: .success,
                                position: .bottom
                            )
                        }
                    }
                }, onCancel: { showCreateContact = false })
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.movo.surface)
            }
            .sheet(isPresented: $showAllFrequents) {
                AllFrequentsView(
                    contactVM: contactVM,
                    container: container,
                    cards: cards,
                    accountBalance: accountBalance,
                    primaryLinkedCard: primaryLinkedCard,
                    onSuccess: { onSuccess(); dismiss() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .blur(radius: showCreateContact ? 3 : 0)
            .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
                loadTask?.cancel()
                loadTask = nil
                createContactTask?.cancel()
                createContactTask = nil
                isInitialLoading = false
                showCreateContact = false
                showAllFrequents = false
                selectedFrequent = nil
                dismiss()
            }
            .onAppear {
                authStatus = CNContactStore.authorizationStatus(for: .contacts)
                loadTask = Task {
                    await contactVM.loadApiContacts()
                    await contactVM.loadFrequent()
                    await contactVM.loadFavourites()
                    if isAuthorized { await contactVM.load() }
                    guard !Task.isCancelled else { return }
                    isInitialLoading = false
                }
            }
            .onChange(of: scenePhase) { newPhase in
                guard newPhase == .active else { return }
                authStatus = CNContactStore.authorizationStatus(for: .contacts)
                if isAuthorized && contactVM.contacts.isEmpty {
                    Task { await contactVM.load() }
                }
            }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            CircularNavButton(systemName: "xmark") { dismiss() }
            Spacer()
            Text("Pay Anyone")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            CircularNavButton(systemName: "plus") { showCreateContact = true }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Frequents

    private var frequentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Eyebrow("RECENT PAY")
                Spacer()
                Button("See all") { showAllFrequents = true }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.movo.accent)
            }
            .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm + 2) {
                    ForEach(contactVM.frequents) { contact in
                        frequentCell(contact)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xs)
            }
        }
    }

    private func frequentCell(_ contact: RecordContact) -> some View {
        Button {
            selectedFrequent = ContactRecord(
                id: contact.id,
                isFav: false,
                nickname: contact.nickname,
                createdAt: Date(),
                phoneNumber: contact.phoneNumber,
                isAdded: false,
                updatedAt: Date()
            )
        } label: {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.movo.elevated, Color.movo.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Circle().strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                    Text(String(contact.nickname?.prefix(1) ?? "?"))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.movo.textPrimary)
                }
                .frame(width: 56, height: 56)

                Text((contact.nickname?.split(separator: " ").first.map(String.init) ?? contact.nickname) ?? "")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color.movo.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contacts List (search + favourites + all contacts)

    private var contactsListCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.movo.textDisabled)
                TextField("", text: $contactVM.search,
                          prompt: Text("Search contacts").foregroundColor(Color.movo.textDisabled))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.movo.textPrimary)
                    .autocorrectionDisabled()
                if !contactVM.search.isEmpty {
                    Button { contactVM.search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.movo.textDisabled)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.movo.elevated)
                    .overlay(RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.sm)

            // Favourites section
            if !contactVM.filteredFavourites.isEmpty {
                sectionLabel("FAVOURITES")
                ForEach(contactVM.filteredFavourites) { contact in
                    NavigationLink(value: contact) { favouriteRow(contact) }
                        .buttonStyle(.plain)
                    rowDivider(isLast: contact.id == contactVM.filteredFavourites.last?.id)
                }
            }

            // apiContacts + device contacts
            if !contactVM.filteredContacts.isEmpty {
                sectionLabel("CONTACTS")
                ForEach(contactVM.filteredContacts) { contact in
                    NavigationLink(value: contact) { contactRow(contact) }
                        .buttonStyle(.plain)
                    rowDivider(isLast: contact.id == contactVM.filteredContacts.last?.id)
                }
            } else if contactVM.filteredFavourites.isEmpty {
                Text(contactVM.search.isEmpty ? "No contacts found" : "No results for \"\(contactVM.search)\"")
                    .font(.system(size: 13))
                    .foregroundColor(Color.movo.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            }

            Spacer().frame(height: Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.elevated, lineWidth: Stroke.hairline))
        )
        .padding(.horizontal, Spacing.lg)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(Color.movo.textTertiary)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
    }

    @ViewBuilder
    private func rowDivider(isLast: Bool) -> some View {
        if !isLast {
            Rectangle()
                .fill(Color.movo.elevated)
                .frame(height: Stroke.hairline)
                .padding(.horizontal, Spacing.lg)
        }
    }

    private func contactRow(_ contact: ContactRecord) -> some View {
        HStack(spacing: Spacing.md) {
            contactAvatar(initials: contact.initials, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(contact.nickname ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.movo.textPrimary)
                    if contact.isAdded {
                        Text("MOVO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.movo.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.movo.accent.opacity(0.15)))
                    }
                }
                Text(contact.phoneNumber ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(Color.movo.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
    }

    private func favouriteRow(_ contact: ContactRecord) -> some View {
        HStack(spacing: Spacing.md) {
            contactAvatar(initials: contact.initials, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(contact.nickname ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.movo.textPrimary)
                    if contact.isAdded {
                        Text("MOVO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.movo.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.movo.accent.opacity(0.15)))
                    }
                }
                Text(contact.phoneNumber ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(Color.movo.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
    }

    private func contactAvatar(initials: String, size: CGFloat) -> some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundColor(Color.movo.textPrimary)
            .frame(width: size, height: size)
            .background(Color.movo.elevated, in: Circle())
            .overlay(Circle().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
    }

    // MARK: - Permission Card

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: Spacing.md + 2) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.movo.accentTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline)
                    )
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 18))
                    .foregroundColor(Color.movo.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Movo is better with friends")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.movo.textPrimary)

                Text("Find people you know already on Movo and send instantly.")
                    .font(.system(size: 12))
                    .foregroundColor(Color.movo.textTertiary)
                    .lineSpacing(1.5)
                    .padding(.bottom, Spacing.sm + 2)

                Button(action: isDenied ? openSettings : enableContacts) {
                    Text(isDenied ? "Open Settings" : "Enable Contacts")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.movo.onAccent)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.button)
                                .fill(Color.movo.accent)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline)
                )
        )
    }

    // MARK: - Actions

    private func enableContacts() {
        Task {
            await contactVM.load()
            authStatus = CNContactStore.authorizationStatus(for: .contacts)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
