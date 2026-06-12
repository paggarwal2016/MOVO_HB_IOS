//
//  PayAnyoneContactPickerView.swift
//  MovocashIOS
//

import SwiftUI
import Contacts

struct PayAnyoneContactPickerView: View {

    let container: AppContainer
    let cards: [VCardListResponse]
    let primaryLinkedCard: VCardListResponse?
    /// Navigation title, supplied by the caller from the dashboard PAYANYONE
    /// section (API-driven). Defaults to "Pay Anyone".
    let title: String
    var onSuccess: () -> Void = {}

    @StateObject private var contactVM: ContactViewModel
    @StateObject private var payeeFlow: PayeeTransferModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.openURL) private var openURL
    @SwiftUI.Environment(\.scenePhase) private var scenePhase

    @State private var authStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    @State private var showCreateContact = false
    @State private var showAllFrequents = false
    @State private var isInitialLoading = true
    @State private var loadTask: Task<Void, Never>?
    @State private var createContactTask: Task<Void, Never>?

    /// True while the create-contact API call is in flight — shows the spinner.
    @State private var isCreatingContact = false

    /// Collapsible-section state for the contacts list. Default expanded.
    @State private var favouritesExpanded = true
    @State private var contactsExpanded = true

    init(container: AppContainer, cards: [VCardListResponse], primaryLinkedCard: VCardListResponse? = nil, title: String = "Pay Anyone", onSuccess: @escaping () -> Void = {}) {
        self.container = container
        self.cards = cards
        self.primaryLinkedCard = primaryLinkedCard
        self.title = title
        self.onSuccess = onSuccess
        _contactVM = StateObject(wrappedValue: container.makeContactViewModel())
        _payeeFlow = StateObject(wrappedValue: PayeeTransferModel(container: container))
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
                
                if !isInitialLoading {
                    VStack(spacing: 0) {
                        navBar
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
                if isInitialLoading || isCreatingContact {
                    SpinnerView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .payeeTransferFlow(
                payeeFlow,
                container: container,
                cards: cards,
                primaryLinkedCard: primaryLinkedCard,
                onSuccess: { onSuccess() }
            )
            .fullScreenCover(isPresented: $showCreateContact, onDismiss: { payeeFlow.popupDidDismiss() }) {
                AddContactSheet(container: contactVM, payeeFlow: payeeFlow, isSubmitting: $isCreatingContact, countryCode: "+1", onSave: { data in
                    // The sheet stays open while we create the contact and run
                    // check-intent. On success the model raises the in-sheet enroll
                    // popup; on failure the sheet stays open (error toast shows).
                    createContactTask = Task {
                        isCreatingContact = true
                        let created = await contactVM.createContact(
                            nickname: data.nickname,
                            phoneNumber: data.phoneE164
                        )
                        guard !Task.isCancelled else { return }
                        guard created else { isCreatingContact = false; return }
                        await payeeFlow.prepareConfirmation(for: ContactRecord(
                            id: data.phoneE164,
                            isFav: false,
                            nickname: data.nickname,
                            createdAt: Date(),
                            phoneNumber: data.phoneE164,
                            isAdded: true,
                            updatedAt: Date()
                        ))
                        guard !Task.isCancelled else { return }
                        isCreatingContact = false
                    }
                }, onContinue: {
                    // Continue tapped in the enroll popup — dismiss this sheet; the
                    // transfer is presented from onDismiss via popupDidDismiss().
                    contactVM.clear()
                    showCreateContact = false
                })
            }
            .fullScreenCover(isPresented: $showAllFrequents) {
                AllFrequentsView(
                    contactVM: contactVM,
                    container: container,
                    cards: cards,
                    primaryLinkedCard: primaryLinkedCard,
                    onSuccess: { onSuccess(); dismiss() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
                loadTask?.cancel()
                loadTask = nil
                createContactTask?.cancel()
                createContactTask = nil
                isCreatingContact = false
                payeeFlow.reset()
                isInitialLoading = false
                showCreateContact = false
                showAllFrequents = false
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
            Text(title)
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
            Button { showCreateContact = true } label: {
                CircleIconAvatar(systemName: "plus", size: 32, tint: .neutral)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Frequents

    private var frequentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Eyebrow("SEND AGAIN WITH MOVO")
                Spacer()
                Button(action: { showAllFrequents = true }) {
                    Text("SEE ALL")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.accent)
                }
                .buttonStyle(.plain)
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
            payeeFlow.tap(ContactRecord(
                id: contact.id,
                isFav: false,
                nickname: contact.nickname,
                createdAt: Date(),
                phoneNumber: contact.phoneNumber,
                isAdded: false,
                updatedAt: Date()
            ))
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
                    Text(contact.avatarInitial)
                        .textStyle(Typography.cardTitle)
                        .foregroundColor(Color.movo.textPrimary)
                }
                .frame(width: 56, height: 56)

                Text(contact.compactLabel)
                    .textStyle(Typography.captionSmall)
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
                    .textStyle(Typography.body)
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
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { favouritesExpanded.toggle() }
                } label: {
                    sectionHeader("FAVOURITES", isExpanded: favouritesExpanded)
                }
                .buttonStyle(.plain)
                if favouritesExpanded {
                    ForEach(contactVM.filteredFavourites) { contact in
                        Button { payeeFlow.tap(contact) } label: { favouriteRow(contact) }
                            .buttonStyle(.plain)
                        rowDivider(isLast: contact.id == contactVM.filteredFavourites.last?.id)
                    }
                }
            }

            // apiContacts + device contacts
            if !contactVM.filteredContacts.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { contactsExpanded.toggle() }
                } label: {
                    sectionHeader("CONTACTS", isExpanded: contactsExpanded)
                }
                .buttonStyle(.plain)
                if contactsExpanded {
                    ForEach(contactVM.filteredContacts) { contact in
                        Button { payeeFlow.tap(contact) } label: { contactRow(contact) }
                            .buttonStyle(.plain)
                        rowDivider(isLast: contact.id == contactVM.filteredContacts.last?.id)
                    }
                }
            } else if contactVM.filteredFavourites.isEmpty {
                Text(contactVM.search.isEmpty ? "No contacts found" : "No results for \"\(contactVM.search)\"")
                    .textStyle(Typography.caption)
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
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        )
        .padding(.horizontal, Spacing.lg)
    }

    /// Collapsible-section header: eyebrow title with a chevron that rotates to
    /// point right when the section is collapsed.
    private func sectionHeader(_ text: String, isExpanded: Bool) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .textStyle(Typography.eyebrow)
                .foregroundColor(Color.movo.textTertiary)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    @ViewBuilder
    private func rowDivider(isLast: Bool) -> some View {
        if !isLast {
            Rectangle()
                .fill(Color.movo.border)
                .frame(height: Stroke.hairline)
                .padding(.horizontal, Spacing.lg)
        }
    }

    private func contactRow(_ contact: ContactRecord) -> some View {
        let hasNickname = !(contact.nickname ?? "").isEmpty
        return HStack(spacing: Spacing.md) {
            rowAvatar(for: contact, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                // Nickname when present; otherwise fall back to the mobile number.
                Text(hasNickname ? (contact.nickname ?? "") : (contact.phoneNumber ?? ""))
                    .textStyle(Typography.bodyCompact)
                    .foregroundColor(Color.movo.textPrimary)
                // Secondary phone line is redundant when the primary already shows it.
                if hasNickname {
                    Text(contact.phoneNumber ?? "")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private func favouriteRow(_ contact: ContactRecord) -> some View {
        let hasNickname = !(contact.nickname ?? "").isEmpty
        return HStack(spacing: Spacing.md) {
            rowAvatar(for: contact, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                // Nickname when present; otherwise fall back to the mobile number.
                Text(hasNickname ? (contact.nickname ?? "") : (contact.phoneNumber ?? ""))
                    .textStyle(Typography.bodyCompact)
                    .foregroundColor(Color.movo.textPrimary)
                // Secondary phone line is redundant when the primary already shows it.
                if hasNickname {
                    Text(contact.phoneNumber ?? "")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    /// Row avatar: nickname initial when present, otherwise the first local
    /// digit of the phone number.
    private func rowAvatar(for contact: ContactRecord, size: CGFloat) -> some View {
        contactAvatar(initials: contact.avatarInitial, size: size)
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
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)

                Text("Find people you know already on Movo and send instantly.")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
                    .lineSpacing(1.5)
                    .padding(.bottom, Spacing.sm + 2)

                Button(action: isDenied ? openSettings : enableContacts) {
                    Text(isDenied ? "Open Settings" : "Enable Contacts")
                }
                .buttonStyle(MovoPrimaryButtonStyle())
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
