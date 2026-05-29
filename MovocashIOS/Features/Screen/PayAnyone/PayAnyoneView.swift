//
//  PayAnyoneView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/05/26.
//

import Foundation
import SwiftUI
import Combine
import Contacts

struct PayAnyoneView: View {
    
    @StateObject private var contactVM: ContactViewModel
    @StateObject private var cardVM: VCardViewModel
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @SwiftUI.Environment(\.scenePhase) private var scenePhase
    @SwiftUI.Environment(\.openURL) private var openURL

    let cards: [VCardListResponse]
    let primaryLinkedCard: VCardListResponse?

    @State private var localPrimaryCard: VCardListResponse?
    @Binding var selectedTab: Tab

    @State private var nickname: String = ""
    @State private var phoneNumber: String = ""
    @State private var authStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    @State private var showCreateContactScreen = false
    @State private var selectedFrequent: ContactRecord? = nil
    @State private var showAllFrequents = false
    @State private var isInitialLoading = true

    /// Newly added contact, drives the full-screen success cover.
    @State private var addedContact: AddedContact? = nil
    /// True while the create-contact API call is in flight — shows the spinner.
    @State private var isCreatingContact = false
    /// Contact to open in QuickTransferView once the success cover dismisses
    /// (set when the user taps "Quick send"). Deferring to onDismiss avoids a
    /// present/dismiss race between the cover and the navigation push.
    @State private var pendingQuickSendContact: ContactRecord? = nil

    /// Lightweight payload for the success cover.
    private struct AddedContact: Identifiable {
        let id = UUID()
        let nickname: String
        let phoneE164: String
    }

    init(container: AppContainer, selectedTab: Binding<Tab>, cards: [VCardListResponse], primaryLinkedCard: VCardListResponse? = nil) {
        _contactVM = StateObject(wrappedValue: container.makeContactViewModel())
        _cardVM = StateObject(wrappedValue: container.makeVCardViewModel())
        _selectedTab = selectedTab
        self.cards = cards
        self.primaryLinkedCard = primaryLinkedCard
        _localPrimaryCard = State(initialValue: primaryLinkedCard)
    }
    
    private var isFormValid: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        phoneNumber.filter(\.isNumber).count >= 10
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
    
    private var hasAnyData: Bool {
        !contactVM.mergedContacts.isEmpty ||
        !contactVM.favourites.isEmpty ||
        !contactVM.frequents.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MovoBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if !isInitialLoading {
                        navBar
                            .padding(.bottom, Spacing.lg)
                        if hasAnyData {
                            balanceCard
                                .padding(.horizontal, Spacing.lg)
                                .padding(.bottom, Spacing.lg)

                            if contactVM.frequents.count > 0 {
                                frequentContactsSection
                                    .padding(.bottom, Spacing.lg)
                            }

                            contactsListCard
                                .padding(.bottom, Spacing.lg)

                            if !isAuthorized {
                                orDivider
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)

                                permissionCompactCard
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 18)
                            }

                        } else {
                            heroIllustration
                                .padding(.top, 18)
                                .padding(.bottom, 12)
                            introBlock
                                .padding(.bottom, 18)

                            addContactView
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                            orDivider
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                            contactsSection
                                .padding(.horizontal, 14)
                                .padding(.bottom, 18)
                        }
                    }

                    Spacer().frame(height: 20)
                }
            }

            StatusBarScrim()

            if isInitialLoading || isCreatingContact {
                SpinnerView()
            }
        }
        .blur(radius: showCreateContactScreen ? 3 : 0)
        .animation(.easeInOut(duration: 0.25), value: showCreateContactScreen)
        .background(Color.movo.background)
        .navigationDestination(for: ContactRecord.self) { contact in
            QuickTransferView(contact: contact, container: container, cards: cards, primaryLinkedCard: localPrimaryCard, onSuccess: { refreshPrimaryCard() })
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedFrequent != nil },
            set: { if !$0 { selectedFrequent = nil } }
        )) {
            if let contact = selectedFrequent {
                QuickTransferView(contact: contact, container: container, cards: cards, primaryLinkedCard: localPrimaryCard, onSuccess: { refreshPrimaryCard() })
            }
        }
        .sheet(isPresented: $showAllFrequents) {
            AllFrequentsView(contactVM: contactVM, container: container, cards: cards, primaryLinkedCard: localPrimaryCard)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: primaryLinkedCard?.id) { _ in
            localPrimaryCard = primaryLinkedCard
        }
        .onAppear {
            // Resolve permission status synchronously before async work begins
            authStatus = CNContactStore.authorizationStatus(for: .contacts)
            Task {
                await contactVM.loadApiContacts()
                await contactVM.loadFavourites()
                await contactVM.loadFrequent()
                if isAuthorized {
                    await contactVM.load()
                }
                isInitialLoading = false
                // Silently refresh primary card balance only when there is
                // contact data to display (balance card is visible).
                if hasAnyData {
                    refreshPrimaryCard()
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            authStatus = CNContactStore.authorizationStatus(for: .contacts)
            if isAuthorized && contactVM.contacts.isEmpty {
                Task { await contactVM.load() }
            }
        }
        .sheet(isPresented: $showCreateContactScreen) {
            AddContactSheet(container: contactVM, countryCode: "+1", onSave: { data in
                // Sheet dismisses itself immediately; this view owns the async
                // work and the spinner. Shows the success cover on completion.
                Task {
                    isCreatingContact = true
                    let success = await contactVM.createContact(
                        nickname: data.nickname,
                        phoneNumber: data.phoneE164
                    )
                    contactVM.clear()
                    isCreatingContact = false
                    if success {
                        addedContact = AddedContact(
                            nickname: data.nickname,
                            phoneE164: data.phoneE164
                        )
                    }
                }
            })
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.movo.cardSurface)
        }
        // MARK: - Contact added success
        // Shown after the add sheet closes. "Quick send" defers the transfer
        // navigation to onDismiss so the cover fully closes first.
        .fullScreenCover(item: $addedContact, onDismiss: {
            if let contact = pendingQuickSendContact {
                pendingQuickSendContact = nil
                selectedFrequent = contact
            }
        }) { added in
            ContactAddedSuccess(
                name: added.nickname,
                phone: added.phoneE164,
                onQuickSend: {
                    pendingQuickSendContact = ContactRecord(
                        id: added.phoneE164,
                        isFav: false,
                        nickname: added.nickname,
                        createdAt: Date(),
                        phoneNumber: added.phoneE164,
                        isAdded: true,
                        updatedAt: Date()
                    )
                    addedContact = nil
                },
                onMaybeLater: { addedContact = nil }
            )
        }
    }
    
    private var addContactView: some View {
        AddContactActionCard(action: {
            showCreateContactScreen = true
        })
    }
    
    // MARK: - Sections
    
    private var heroIllustration: some View {
        HStack {
            Spacer()
            PayAnyoneHeroIllustration()
                .frame(width: 130, height: 90)
            Spacer()
        }
    }
    
    private var introBlock: some View {
        VStack(spacing: Spacing.sm) {
            Text("Send to spend")
                .textStyle(Typography.sectionTitle)
                .foregroundColor(Color.movo.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text("Add someone you pay often or pick from your contacts.")
                .textStyle(Typography.caption)
                .foregroundColor(Color.movo.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xxl)
    }
    
    
    private var orDivider: some View {
        HStack(spacing: Spacing.md) {
            Rectangle().fill(Color.movo.border).frame(height: Stroke.hairline)
            Text("OR PICK FROM")
                .textStyle(Typography.micro)
                .foregroundColor(Color.movo.textTertiary)
            Rectangle().fill(Color.movo.border).frame(height: Stroke.hairline)
        }
    }
    
    @ViewBuilder
    private var contactsSection: some View {
        if hasAnyData {
            contactsListCard
        } else {
            permissionCompactCard
        }
    }
    
    // MARK: - Permission Card
    
    private var permissionCompactCard: some View {
        
        HStack(alignment: .top, spacing: Spacing.md + 2) {
            
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.movo.accentTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .strokeBorder(Color.movo.accentBorder,
                                          lineWidth: Stroke.hairline)
                    )
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color.movo.accent)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Movo is better with friends")
                    .textStyle(Typography.cardTitle)
                    .foregroundColor(Color.movo.textPrimary)
                
                Text("Find people you know already on Movo and send instantly.")
                    .textStyle(Typography.captionSmall)
                    .foregroundColor(Color.movo.textTertiary)
                    .lineSpacing(1.5)
                    .padding(.bottom, Spacing.sm + 2)
                
                Button(action: isDenied ? openSettings : enableContacts) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Enable Contacts")
                            .textStyle(Typography.button)
                    }
                }
                .buttonStyle(MovoCompactButtonStyle())
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
    
    
    
    
    
    // MARK: - Contacts List
    
    private var contactsLoadingCard: some View {
        VStack {
            ProgressView().tint(Color.movo.accent).scaleEffect(1.2).padding(.vertical, 40)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: Radius.heroCard)
                    .strokeBorder(Color.movo.border, lineWidth: Stroke.hairline))
        )
    }
    
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
                        Image(systemName: "xmark.circle.fill").foregroundColor(Color.movo.textDisabled)
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
            
            // Favourites
            if !contactVM.filteredFavourites.isEmpty {
                Text("FAVOURITES")
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xs)
                ForEach(contactVM.filteredFavourites) { contact in
                    NavigationLink(value: contact) { contactRow(contact) }
                        .buttonStyle(.plain)
                    if contact.id != contactVM.filteredFavourites.last?.id {
                        Rectangle().fill(Color.movo.border)
                            .frame(height: Stroke.hairline)
                            .padding(.horizontal, Spacing.lg)
                    }
                }
                Rectangle().fill(Color.movo.border)
                    .frame(height: Stroke.hairline)
                    .padding(.horizontal, Spacing.lg)
            }
            
            // All contacts
            if !contactVM.filteredContacts.isEmpty {
                Text("ALL CONTACTS")
                    .textStyle(Typography.eyebrow)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xs)
                ForEach(contactVM.filteredContacts) { contact in
                    NavigationLink(value: contact) { contactRow(contact) }
                        .buttonStyle(.plain)
                    if contact.id != contactVM.filteredContacts.last?.id {
                        Rectangle().fill(Color.movo.border)
                            .frame(height: Stroke.hairline)
                            .padding(.horizontal, Spacing.lg)
                    }
                }
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

    private func contactAvatar(initials: String, size: CGFloat) -> some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundColor(Color.movo.textPrimary)
            .frame(width: size, height: size)
            .background(Color.movo.elevated, in: Circle())
            .overlay(Circle().strokeBorder(Color.movo.accentBorder, lineWidth: Stroke.hairline))
    }
    
    private func contactRow(_ contact: ContactRecord) -> some View {
        HStack(spacing: Spacing.md) {
            contactAvatar(initials: contact.initials, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(contact.nickname ?? "")
                        .textStyle(Typography.bodyCompact)
                        .foregroundColor(Color.movo.textPrimary)
                    if contact.isAdded {
                        Text("MOVO")
                            .textStyle(Typography.micro)
                            .foregroundColor(Color.movo.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.movo.accent.opacity(0.15)))
                    }
                }
                Text(contact.phoneNumber ?? "")
                    .textStyle(Typography.caption)
                    .foregroundColor(Color.movo.textTertiary)
            }
            Spacer()
            Button {
                Task { await contactVM.toggleFavourite(contact) }
            } label: {
                Image(systemName: contactVM.isFavorite(contact) ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(contactVM.isFavorite(contact) ? Color.movo.accent : Color.movo.textDisabled)
            }
            .buttonStyle(.plain)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
    
    // MARK: - Actions
    
    private func addContact() {
        Task {
            let digits = phoneNumber.filter(\.isNumber)
            let success = await contactVM.createContact(
                nickname: nickname.trimmingCharacters(in: .whitespaces),
                phoneNumber: "+1\(digits)"
            )
            if success {
                nickname = ""
                phoneNumber = ""
            }
        }
    }
    
    private func refreshPrimaryCard() {
        Task {
            guard let updated = try? await cardVM.fetchPrimaryCard() else { return }
            localPrimaryCard = updated
        }
    }

    private func enableContacts() {
        Task {
            await contactVM.load()
            authStatus = CNContactStore.authorizationStatus(for: .contacts)
        }
    }
    
    private func openSettings() {
        lockManager.notifyWillOpenPermissionSettings()
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
    
    private var navBar: some View {
        HStack {
            Spacer()
            Text("Pay Anyone")
                .textStyle(Typography.cardTitle)
                .foregroundColor(Color.movo.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg - 2)
        .padding(.bottom, Spacing.md)
    }
}

// MARK: - Hero Illustration (two figures + flying bill)

private struct PayAnyoneHeroIllustration: View {
    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 130.0
            let scaleY = size.height / 90.0
            
            // Left figure (dim)
            drawFigure(context: context,
                       at: CGPoint(x: 20 * scaleX, y: 28 * scaleY),
                       scale: scaleX,
                       color: Color.movo.textTertiary,
                       lineWidth: 1.0)
            
            // Right figure (bright)
            drawFigure(context: context,
                       at: CGPoint(x: 105 * scaleX, y: 32 * scaleY),
                       scale: scaleX,
                       color: Color.movo.textPrimary,
                       lineWidth: 1.1)
            
            // Flying bill (rotated)
            drawBill(context: context,
                     at: CGPoint(x: 50 * scaleX, y: 8 * scaleY),
                     scale: scaleX)
            
            // Motion arc
            var arcPath = Path()
            arcPath.move(to: CGPoint(x: 36 * scaleX, y: 28 * scaleY))
            arcPath.addQuadCurve(
                to: CGPoint(x: 92 * scaleX, y: 28 * scaleY),
                control: CGPoint(x: 65 * scaleX, y: -2 * scaleY)
            )
            context.stroke(
                arcPath,
                with: .color(Color.movo.accent.opacity(0.55)),
                style: StrokeStyle(lineWidth: 0.7, dash: [2, 2.5])
            )
        }
    }
    
    private func drawFigure(context: GraphicsContext, at center: CGPoint, scale: CGFloat,
                            color: Color, lineWidth: CGFloat) {
        // Head (circle)
        let head = Path(ellipseIn: CGRect(x: center.x - 9 * scale,
                                          y: center.y - 9 * scale,
                                          width: 18 * scale,
                                          height: 18 * scale))
        context.stroke(head, with: .color(color), lineWidth: lineWidth)
        
        // Body (rounded rect / U-shape)
        var body = Path()
        body.move(to: CGPoint(x: center.x - 14 * scale, y: center.y + 38 * scale))
        body.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + 16 * scale),
            control: CGPoint(x: center.x - 14 * scale, y: center.y + 16 * scale)
        )
        body.addQuadCurve(
            to: CGPoint(x: center.x + 14 * scale, y: center.y + 38 * scale),
            control: CGPoint(x: center.x + 14 * scale, y: center.y + 16 * scale)
        )
        context.stroke(body, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    private func drawBill(context: GraphicsContext, at origin: CGPoint, scale: CGFloat) {
        var ctx = context
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.rotate(by: .degrees(-12))
        
        let billRect = CGRect(x: 0, y: 0, width: 32 * scale, height: 18 * scale)
        let bill = Path(roundedRect: billRect, cornerRadius: 2 * scale)
        ctx.fill(bill, with: .color(Color.movo.surface))
        ctx.stroke(bill, with: .color(Color.movo.accent), lineWidth: 1.0)
        
        // $ circle
        let dollarCircle = Path(ellipseIn: CGRect(x: 11.5 * scale, y: 4.5 * scale,
                                                  width: 9 * scale, height: 9 * scale))
        ctx.stroke(dollarCircle, with: .color(Color.movo.accent), lineWidth: 0.8)
        
        // $ text
        let dollarText = Text("$")
            .font(.system(size: 7 * scale, weight: .semibold))
            .foregroundColor(Color.movo.accent)
        ctx.draw(dollarText, at: CGPoint(x: 16 * scale, y: 9 * scale))
    }
}

// MARK: - Contacts Permission Illustration

private struct ContactsPermissionIllustration: View {
    var body: some View {
        ZStack {
            // Halo background
            Circle()
                .stroke(Color.movo.accentBorder.opacity(0.4),
                        style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                .background(Circle().fill(Color.movo.accent.opacity(0.04)))
                .frame(width: 88, height: 88)
            
            // Phone body in center
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.movo.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.movo.textPrimary, lineWidth: 1)
                    )
                    .frame(width: 40, height: 62)
                
                // Inner screen with contact list
                VStack(spacing: 5) {
                    contactRow(highlighted: false)
                    contactRow(highlighted: true)
                    contactRow(highlighted: false)
                }
                .padding(.horizontal, 4)
                .frame(width: 34, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color.movo.elevated, Color.movo.background],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
            }
            
            // Floating avatars positioned around
            FloatingAvatar(size: 20, accent: false)
                .offset(x: -62, y: -26)
            FloatingAvatar(size: 20, accent: true, withMovoDot: true)
                .offset(x: 60, y: -20)
            FloatingAvatar(size: 18, accent: true)
                .offset(x: -54, y: 28)
            FloatingAvatar(size: 18, accent: false)
                .offset(x: 55, y: 30)
        }
    }
    
    private func contactRow(highlighted: Bool) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(highlighted ? Color.movo.accent : Color.movo.textTertiary.opacity(0.7))
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(highlighted ? Color.movo.textPrimary : Color.movo.textTertiary.opacity(0.7))
                    .frame(width: 16, height: 2)
                RoundedRectangle(cornerRadius: 0.7)
                    .fill(Color.movo.textTertiary)
                    .frame(width: 10, height: 1.5)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct FloatingAvatar: View {
    let size: CGFloat
    let accent: Bool
    var withMovoDot: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.movo.elevated)
                .overlay(
                    Circle()
                        .strokeBorder(accent ? Color.movo.accent : Color.movo.textTertiary,
                                      lineWidth: accent ? 0.9 : 0.8)
                )
                .frame(width: size, height: size)
            
            // Mini person icon inside
            VStack(spacing: 1) {
                Circle()
                    .strokeBorder(accent ? Color.movo.accent : Color.movo.textTertiary,
                                  lineWidth: 0.7)
                    .frame(width: size * 0.3, height: size * 0.3)
                Capsule()
                    .strokeBorder(accent ? Color.movo.accent : Color.movo.textTertiary,
                                  lineWidth: 0.7)
                    .frame(width: size * 0.5, height: size * 0.25)
                    .clipShape(Rectangle().offset(y: -size * 0.06))
            }
            
            if withMovoDot {
                Circle()
                    .fill(Color.movo.accent)
                    .overlay(Circle().strokeBorder(Color.movo.background, lineWidth: 0.5))
                    .frame(width: 4, height: 4)
                    .offset(x: size * 0.35, y: -size * 0.35)
            }
        }
    }
}


extension PayAnyoneView {
    
    private var balanceCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Eyebrow("Available to send")
                Text(localPrimaryCard?.displayBalance ?? "$ 0.00")
                    .textStyle(Typography.sectionTitle)
                    .monospacedDigit()
                    .foregroundColor(Color.movo.textPrimary)
            }
            Spacer()
            Button(action: { withAnimation { showCreateContactScreen = true } }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .heavy))
                    Text("Add Contact")
                        .textStyle(Typography.button)
                }
            }
            .frame(width: 120)
            .buttonStyle(MovoCompactButtonStyle())
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.heroCard)
                .fill(LinearGradient(
                    colors: [Color.movo.elevated, Color.movo.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.heroCard)
                        .strokeBorder(Color.movo.borderStrong, lineWidth: Stroke.hairline)
                )
        )
    }
    
    private var frequentContactsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Eyebrow("RECENT PAY")
                Spacer()
                //        if contactVM.frequents.count >= 10 {
                Button(action: { showAllFrequents = true }) {
                    Text("See all")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textSecondary)
                }
                .buttonStyle(.plain)
                //       }
            }
            .padding(.horizontal, Spacing.lg)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm + 2) {
                    ForEach(contactVM.frequents) { contact in
                        QuickContactCell(contact: contact) {
                            selectedFrequent = ContactRecord(
                                id: contact.id,
                                isFav: false,
                                nickname: contact.nickname,
                                createdAt: Date(),
                                phoneNumber: contact.phoneNumber,
                                isAdded: false,
                                updatedAt: Date()
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xs)
            }
        }
    }
    
    private struct QuickContactCell: View {
        let contact: RecordContact
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.movo.elevated, Color.movo.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Circle()
                            .strokeBorder( Color.movo.border,
                                           lineWidth: Stroke.hairline
                            )
                        Text("\(contact.nickname?.prefix(1) ?? "")")
                            .textStyle(Typography.cardTitle)
                            .foregroundColor(Color.movo.textPrimary)
                    }
                    .frame(width: 56, height: 56)
                    
                    Text((contact.nickname?.split(separator: " ").first.map(String.init) ?? contact.nickname) ?? "")
                        .textStyle(Typography.captionSmall)
                        .foregroundColor(Color.movo.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 64)
            }
            .buttonStyle(.plain)
        }
    }
}
