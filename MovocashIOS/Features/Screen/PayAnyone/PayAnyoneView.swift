//
//  PayAnyoneView.swift
//  MovocashIOS
//
//  Created by Movo Developer on 05/05/26.
//

import Foundation
import SwiftUI
import Combine

struct PayAnyoneView: View {
    
    @StateObject private var contactVM: ContactViewModel
    @StateObject private var cardVM: VCardViewModel
    @StateObject private var payeeFlow: PayeeTransferModel
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @SwiftUI.Environment(\.openURL) private var openURL
    
    let cards: [VCardListResponse]
    let primaryLinkedCard: VCardListResponse?
    /// Title shown in the nav bar — passed from the tab's MENU label.
    let screenTitle: String
    @ObservedObject private var primaryCardStore: PrimaryCardStore
    @Binding var selectedTab: Tab

    private var effectivePrimary: VCardListResponse? { primaryCardStore.card ?? primaryLinkedCard }
    
    @State private var nickname: String = ""
    @State private var phoneNumber: String = ""
    @State private var showCreateContactScreen = false
    @State private var showAllFrequents = false
    @State private var isInitialLoading = true
    /// Drives the native `CNContactPickerViewController` (limited-access "Use Phone Contacts").
    @State private var showSystemPicker = false
    /// True between tapping "Use Phone Contacts" and the picker finishing presenting —
    /// shows a loader during the picker's launch delay.
    @State private var isOpeningPicker = false
    
    /// True while the create-contact API call is in flight — shows the spinner.
    @State private var isCreatingContact = false
    
    /// Collapsible-section state for the contacts list. Default expanded.
    @State private var favouritesExpanded = true
    @State private var allContactsExpanded = true
    
    init(container: AppContainer, selectedTab: Binding<Tab>, cards: [VCardListResponse], primaryLinkedCard: VCardListResponse? = nil, screenTitle: String = "Pay Anyone") {
        _contactVM = StateObject(wrappedValue: container.makeContactViewModel())
        _cardVM = StateObject(wrappedValue: container.makeVCardViewModel())
        _payeeFlow = StateObject(wrappedValue: PayeeTransferModel(container: container))
        _selectedTab = selectedTab
        self.cards = cards
        self.primaryLinkedCard = primaryLinkedCard
        self.screenTitle = screenTitle
        _primaryCardStore = ObservedObject(wrappedValue: container.primaryCardStore)
    }
    
    private var isFormValid: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        phoneNumber.filter(\.isNumber).count >= 10
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
                            
                        } else {
                            heroIllustration
                                .padding(.top, 18)
                                .padding(.bottom, 12)
                            introBlock
                                .padding(.bottom, 18)
                            
                            addContactView
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                        }
                    }
                    
                    Spacer().frame(height: 20)
                }
            }
            
            StatusBarScrim()
            
            if isInitialLoading || isCreatingContact || isOpeningPicker {
                SpinnerView()
            }
        }
        .blur(radius: showCreateContactScreen ? 3 : 0)
        .animation(.easeInOut(duration: 0.25), value: showCreateContactScreen)
        .background(Color.movo.background)
        // Hosts the native contact picker; presents when `showSystemPicker` flips true.
        .background {
            PhoneContactPicker(
                isPresented: $showSystemPicker,
                onPresented: { isOpeningPicker = false }
            ) { name, phone in
                handlePickedContact(name: name, phone: phone)
            }
        }
        .payeeTransferFlow(payeeFlow, container: container, cards: cards, primaryLinkedCard: effectivePrimary, onSuccess: { handleTransferSuccess() }, onCancel: { reloadContacts() })
        .fullScreenCover(isPresented: $showAllFrequents) {
            AllFrequentsView(contactVM: contactVM, container: container, cards: cards, primaryLinkedCard: effectivePrimary)
        }
        .onAppear {
            Task {
                await contactVM.loadApiContacts()
                await contactVM.loadFavourites()
                await contactVM.loadFrequent()
                isInitialLoading = false
            }
        }
        .fullScreenCover(isPresented: $showCreateContactScreen, onDismiss: { payeeFlow.popupDidDismiss(); reloadContacts() }) {
            AddContactSheet(container: contactVM, payeeFlow: payeeFlow, isSubmitting: $isCreatingContact, countryCode: "+1", onSave: { data in
                Task {
                    isCreatingContact = true
                    let created = await contactVM.createContact(
                        nickname: data.nickname,
                        phoneNumber: data.phoneE164
                    )
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
                    isCreatingContact = false
                }
            }, onContinue: {
                contactVM.clear()
                showCreateContactScreen = false
            }, onOpenSettings: openSettings)
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
            QuickPayHeroIllustration()
                .frame(width: 200, height: 140)
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
    
    /// The "Search contacts" field. Extracted so it can be reused both inside
    /// `contactsListCard` and as a standalone field in the empty state.
    private var searchField: some View {
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
    }
    
    /// Standalone search bar shown in the empty state, so "Search contacts" is
    /// visible as its own clean field rather than the top of an empty list card.
    private var searchBar: some View {
        searchField
            .padding(.horizontal, Spacing.lg)
    }
    
    private var contactsListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            searchField
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.sm)
            
            // Favourites
            if !contactVM.filteredFavourites.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { favouritesExpanded.toggle() }
                } label: {
                    sectionHeader(title: "FAVOURITES", isExpanded: favouritesExpanded)
                }
                .buttonStyle(.plain)
                if favouritesExpanded {
                    ForEach(contactVM.filteredFavourites) { contact in
                        Button { payeeFlow.tap(contact) } label: { contactRow(contact) }
                            .buttonStyle(.plain)
                        if contact.id != contactVM.filteredFavourites.last?.id {
                            Rectangle().fill(Color.movo.border)
                                .frame(height: Stroke.hairline)
                                .padding(.horizontal, Spacing.lg)
                        }
                    }
                }
                Rectangle().fill(Color.movo.border)
                    .frame(height: Stroke.hairline)
                    .padding(.horizontal, Spacing.lg)
            }
            
            // All contacts — backend (API) contacts only. The device address book is
            // not loaded; device contacts are pulled in one at a time via the picker.
            if !contactVM.filteredContacts.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { allContactsExpanded.toggle() }
                } label: {
                    sectionHeader(title: "ALL CONTACTS", isExpanded: allContactsExpanded)
                }
                .buttonStyle(.plain)
                if allContactsExpanded {
                    ForEach(contactVM.filteredContacts) { contact in
                        Button { payeeFlow.tap(contact) } label: { contactRow(contact) }
                            .buttonStyle(.plain)
                        if contact.id != contactVM.filteredContacts.last?.id {
                            Rectangle().fill(Color.movo.border)
                                .frame(height: Stroke.hairline)
                                .padding(.horizontal, Spacing.lg)
                        }
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
    
    /// Collapsible-section header: eyebrow title with a chevron that rotates
    /// to point right when the section is collapsed.
    private func sectionHeader(title: String, isExpanded: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
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
            contactAvatar(initials: contact.avatarInitial, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .textStyle(Typography.bodyCompact)
                    .foregroundColor(Color.movo.textPrimary)
                if contact.hasNickname {
                    Text(contact.phoneNumber ?? "")
                        .textStyle(Typography.caption)
                        .foregroundColor(Color.movo.textTertiary)
                }
            }
            Spacer()
            Button {
                Task { await contactVM.toggleFavourite(contact) }
            } label: {
                Image(systemName: contactVM.isFavorite(contact) ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(contactVM.isFavorite(contact) ? Color.movo.accent : Color.movo.textDisabled)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            MovoChevron(.disclosure, color: Color.movo.textDisabled)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
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
    
    /// Handles a contact picked from the native system picker: first saves it to the
    /// backend via `createContact` (POST → `ContactAPI.create`), then — on success —
    /// continues into the payee transfer flow, same as tapping a saved contact row.
    /// Falls back to the phone number as the nickname when the device contact has no name.
    private func handlePickedContact(name: String, phone: String) {
        let national = PhoneNumberValidator.sanitize(phone)
        let e164 = national.isEmpty ? phone : "+1\(national)"
        let nickname = name.isEmpty ? e164 : name
        Task {
            isCreatingContact = true
            let created = await contactVM.createContact(nickname: nickname, phoneNumber: e164)
            guard created else { isCreatingContact = false; return }
            // Hand off to the transfer flow BEFORE clearing the create loader: `tap`
            // sets `isChecking` synchronously, so its spinner is already showing when
            // this one drops — a single continuous loader with no flicker between the
            // create and check-intent calls.
            payeeFlow.tap(ContactRecord(
                id: e164,
                isFav: false,
                nickname: name.isEmpty ? nil : name,
                createdAt: Date(),
                phoneNumber: e164,
                isAdded: true,
                updatedAt: Date()
            ))
            isCreatingContact = false
        }
    }
    
    private func refreshPrimaryCard() {
        Task { _ = try? await cardVM.fetchPrimaryCard() }
    }
    
    /// Runs only after a successful Quick Transfer when the user lands back on this
    /// screen (Success screen dismissed). Refreshes the Primary Card balance via the
    /// API and reloads Frequents so the just-paid contact appears.
    private func handleTransferSuccess() {
        refreshPrimaryCard()
        Task { await contactVM.loadFrequent()
            await contactVM.loadApiContacts() }
    }
    
    /// Reloads the backend contact lists. Called when the enroll confirmation popup is
    /// cancelled so a contact just saved via `createContact` (POST → `ContactAPI.create`)
    /// is reflected in the list even though the transfer wasn't completed.
    private func reloadContacts() {
        Task {
            await contactVM.loadApiContacts()
            await contactVM.loadFavourites()
        }
    }
    
    /// Presents the native system contact picker. Works regardless of the app's
    /// Contacts permission — the picker runs out-of-process and returns just the one
    /// contact the user selects. `isOpeningPicker` shows a loader during the launch delay.
    private func presentSystemPicker() {
        isOpeningPicker = true
        showSystemPicker = true
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
            Text(screenTitle)
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

//private struct PayAnyoneHeroIllustration: View {
//    var body: some View {
//        Canvas { context, size in
//            let scaleX = size.width / 130.0
//            let scaleY = size.height / 90.0
//            
//            // Left figure (dim)
//            drawFigure(context: context,
//                       at: CGPoint(x: 20 * scaleX, y: 28 * scaleY),
//                       scale: scaleX,
//                       color: Color.movo.textTertiary,
//                       lineWidth: 1.0)
//            
//            // Right figure (bright)
//            drawFigure(context: context,
//                       at: CGPoint(x: 105 * scaleX, y: 32 * scaleY),
//                       scale: scaleX,
//                       color: Color.movo.textPrimary,
//                       lineWidth: 1.1)
//            
//            // Flying bill (rotated)
//            drawBill(context: context,
//                     at: CGPoint(x: 50 * scaleX, y: 8 * scaleY),
//                     scale: scaleX)
//            
//            // Motion arc
//            var arcPath = Path()
//            arcPath.move(to: CGPoint(x: 36 * scaleX, y: 28 * scaleY))
//            arcPath.addQuadCurve(
//                to: CGPoint(x: 92 * scaleX, y: 28 * scaleY),
//                control: CGPoint(x: 65 * scaleX, y: -2 * scaleY)
//            )
//            context.stroke(
//                arcPath,
//                with: .color(Color.movo.accent.opacity(0.55)),
//                style: StrokeStyle(lineWidth: 0.7, dash: [2, 2.5])
//            )
//        }
//    }
//    
//    private func drawFigure(context: GraphicsContext, at center: CGPoint, scale: CGFloat,
//                            color: Color, lineWidth: CGFloat) {
//        // Head (circle)
//        let head = Path(ellipseIn: CGRect(x: center.x - 9 * scale,
//                                          y: center.y - 9 * scale,
//                                          width: 18 * scale,
//                                          height: 18 * scale))
//        context.stroke(head, with: .color(color), lineWidth: lineWidth)
//        
//        // Body (rounded rect / U-shape)
//        var body = Path()
//        body.move(to: CGPoint(x: center.x - 14 * scale, y: center.y + 38 * scale))
//        body.addQuadCurve(
//            to: CGPoint(x: center.x, y: center.y + 16 * scale),
//            control: CGPoint(x: center.x - 14 * scale, y: center.y + 16 * scale)
//        )
//        body.addQuadCurve(
//            to: CGPoint(x: center.x + 14 * scale, y: center.y + 38 * scale),
//            control: CGPoint(x: center.x + 14 * scale, y: center.y + 16 * scale)
//        )
//        context.stroke(body, with: .color(color),
//                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
//    }
//    
//    private func drawBill(context: GraphicsContext, at origin: CGPoint, scale: CGFloat) {
//        var ctx = context
//        ctx.translateBy(x: origin.x, y: origin.y)
//        ctx.rotate(by: .degrees(-12))
//        
//        let billRect = CGRect(x: 0, y: 0, width: 32 * scale, height: 18 * scale)
//        let bill = Path(roundedRect: billRect, cornerRadius: 2 * scale)
//        ctx.fill(bill, with: .color(Color.movo.surface))
//        ctx.stroke(bill, with: .color(Color.movo.accent), lineWidth: 1.0)
//        
//        // $ circle
//        let dollarCircle = Path(ellipseIn: CGRect(x: 11.5 * scale, y: 4.5 * scale,
//                                                  width: 9 * scale, height: 9 * scale))
//        ctx.stroke(dollarCircle, with: .color(Color.movo.accent), lineWidth: 0.8)
//        
//        // $ text
//        let dollarText = Text("$")
//            .font(.system(size: 7 * scale, weight: .semibold))
//            .foregroundColor(Color.movo.accent)
//        ctx.draw(dollarText, at: CGPoint(x: 16 * scale, y: 9 * scale))
//    }
//}

// MARK: - Quick Pay / Send Money Illustration (line-art)

struct QuickPayHeroIllustration: View {

    /// Virtual design canvas (pts). All coordinates below are in this space;
    /// GeometryReader scales them uniformly into whatever frame the parent sets.
    private let design = CGSize(width: 140, height: 100)

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / design.width,
                            geo.size.height / design.height)
            let ox = (geo.size.width  - design.width  * scale) / 2
            let oy = (geo.size.height - design.height * scale) / 2

            ZStack {
                // Canvas: glow, arcs, figure strokes, card stroke + magstripe
                Canvas { context, size in
                    var ctx = context
                    ctx.translateBy(x: ox, y: oy)
                    ctx.scaleBy(x: scale, y: scale)

                    drawGlow(ctx)
                    drawArc(ctx, from: CGPoint(x: 70, y: 28), to: CGPoint(x: 28, y: 56),
                            control: CGPoint(x: 36, y: 8))
                    drawArc(ctx, from: CGPoint(x: 70, y: 28), to: CGPoint(x: 112, y: 56),
                            control: CGPoint(x: 104, y: 8))
                    drawFigure(ctx, center: CGPoint(x: 26, y: 76), dim: true)
                    drawFigure(ctx, center: CGPoint(x: 114, y: 76), dim: false)
                    drawCard(ctx, center: CGPoint(x: 70, y: 26))
                }

                // MV symbol overlaid at card centre, scaled + rotated with the card
                let mvSize: CGFloat = 18 * scale
                MovoMVSymbol(
                    bodyStyle: Color.movo.heritageGreenLine,
                    accent: Color.movo.heritageGreenLine.opacity(0.55)
                )
                .frame(width: mvSize, height: mvSize)
                .rotationEffect(.degrees(-8))
                .position(x: ox + 70 * scale, y: oy + 26 * scale)
            }
        }
    }

    // MARK: - Background glow

    private func drawGlow(_ ctx: GraphicsContext) {
        let glow = Path(ellipseIn: CGRect(x: 22, y: 10, width: 96, height: 68))
        ctx.fill(glow, with: .color(Color.movo.accent.opacity(0.06)))
    }

    // MARK: - Money-flow arc (card → figure)

    private func drawArc(_ ctx: GraphicsContext,
                         from: CGPoint, to: CGPoint, control: CGPoint) {
        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: control)
        ctx.stroke(
            path,
            with: .color(Color.movo.heritageGreenLine.opacity(0.42)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [2, 4])
        )
    }

    // MARK: - Line-art figure (round head + two-curve shoulder bust)

    private func drawFigure(_ ctx: GraphicsContext,
                             center: CGPoint, dim: Bool) {
        let cx   = center.x
        let cy   = center.y          // base of figure (bottom of shoulders)
        let r: CGFloat = 7
        let headY = cy - 32          // head centre Y
        let silver = Color.movo.silverTint
        let opacity: Double = dim ? 0.42 : 0.88

        // Head — stroke-only circle
        let head = Path(ellipseIn: CGRect(x: cx - r, y: headY - r,
                                          width: r * 2, height: r * 2))
        ctx.stroke(head, with: .color(silver.opacity(opacity)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Shoulders — two-curve open arch (stroke only, no fill)
        var shoulders = Path()
        shoulders.move(to: CGPoint(x: cx - 13, y: cy))
        shoulders.addQuadCurve(
            to:      CGPoint(x: cx,       y: cy - 18),
            control: CGPoint(x: cx - 13,  y: cy - 18)
        )
        shoulders.addQuadCurve(
            to:      CGPoint(x: cx + 13, y: cy),
            control: CGPoint(x: cx + 13, y: cy - 18)
        )
        ctx.stroke(shoulders, with: .color(silver.opacity(opacity)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Payment card (stroke-only, no fill)

    private func drawCard(_ ctx: GraphicsContext, center: CGPoint) {
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .degrees(-8))

        let w: CGFloat = 44
        let h: CGFloat = 28
        let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)

        // Card outline — stroke only, no fill
        let outline = Path(roundedRect: rect, cornerRadius: 5)
        c.stroke(outline,
                 with: .color(Color.movo.heritageGreenLine),
                 style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
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
                let bal = Decimal(effectivePrimary?.savingsAccountAvailableBalance ?? effectivePrimary?.savingsAccountBalance ?? 0)
                BalanceText(amount: bal, dollarSize: 33, centsSize: 23, centsOpacity: 1.0)
            }
            Spacer()
            Button(action: { withAnimation { showCreateContactScreen = true } }) {
                HStack(spacing: 6) {
                    Text("Add MOVO Recipient")
                        .textStyle(Typography.button)
                }
            }
            .frame(width: 150)
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
                Eyebrow("SEND AGAIN WITH MOVO")
                Spacer()
                if contactVM.frequents.count >= 5 {
                    Button(action: { showAllFrequents = true }) {
                        Eyebrow("SEE ALL")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm + 2) {
                    ForEach(contactVM.frequents) { contact in
                        QuickContactCell(contact: contact) {
                            payeeFlow.tap(ContactRecord(
                                id: contact.id,
                                isFav: false,
                                nickname: contact.nickname,
                                createdAt: Date(),
                                phoneNumber: contact.phoneNumber,
                                isAdded: false,
                                updatedAt: Date()
                            ))
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
    }
}
