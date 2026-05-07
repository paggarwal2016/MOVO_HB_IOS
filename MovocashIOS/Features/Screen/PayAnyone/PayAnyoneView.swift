//
//  PayAnyoneView.swift
//  MovocashIOS
//
//  Created by Vinu on 05/05/26.
//

import Foundation
import SwiftUI
import Combine
import Contacts

struct PayAnyoneView: View {
    
    @StateObject private var contactVM: ContactViewModel
    @StateObject private var savingVM: SavingsAccountViewModel
    @EnvironmentObject private var container: AppContainer
    @SwiftUI.Environment(\.scenePhase) private var scenePhase
    @SwiftUI.Environment(\.openURL) private var openURL
    
    @State private var nickname: String = ""
    @State private var phoneNumber: String = ""
    @State private var authStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    @State private var showAddContact = false
    
    init(container: AppContainer) {
        _contactVM = StateObject(wrappedValue: container.makeContactViewModel())
        _savingVM = StateObject(wrappedValue: container.makeSavingsAccountViewModel())
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
                        orDivider
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        contactsSection
                            .padding(.horizontal, 14)
                            .padding(.bottom, 18)
                    }
                    Spacer().frame(height: 80)
                }
            }
            
            if showAddContact {
                ZStack {
                    
                    // Dim background
                    Color.black.opacity(0.50)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showAddContact = false
                            }
                        }
                    
                    // Center Card
                    addContactView
                        .background(Color.movo.background)
                        .frame(maxWidth: 360)
                        .padding(.horizontal, 20)
                }
                .zIndex(10)
            }
                    
            if contactVM.state == .loading && !hasAnyData {
                SpinnerView()
            }
        }
        .background(Color.movo.background)
        .preferredColorScheme(.dark)
        .navigationDestination(for: ContactRecord.self) { contact in
            QuickTransferView(contact: contact, container: container)
        }
        .onAppear {
            Task {
                async let savings: Void = savingVM.loadAccounts()
                async let apiContacts: Void = contactVM.loadApiContacts()
                async let favourites: Void = contactVM.loadFavourites()
                async let frequent: Void = contactVM.loadFrequent()
                _ = await (savings, apiContacts, favourites, frequent)
            }
            if isAuthorized {
                Task { await contactVM.load() }
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
    
    private var addContactView: some View {
        AddContactCardView(
            nickname: $nickname,
            phoneNumber: $phoneNumber,
            isLoading: contactVM.state == .loading,
            isFormValid: isFormValid,
            onAdd: {
                let digits = PhoneFormatter1.formatUS(phoneNumber)
                
                Task {
                    let success = await contactVM.createContact(
                        nickname: nickname.trimmingCharacters(in: .whitespaces),
                        phoneNumber: "+1\(PhoneFormatter1.rawDigits(digits))"
                    )
                    
                    if success {
                        nickname = ""
                        phoneNumber = ""
                        showAddContact = false
                    }
                }
            },
            onCancel: {
                showAddContact = false
            }
        )
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
        VStack(spacing: 8) {
            Text("Send to anyone,\neven your nan")
                .font(Typography.sectionTitle.font)
                .foregroundColor(Color.movo.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text("Add someone you pay often or pick from your contacts.")
                .font(Typography.caption.font)
                .foregroundColor(Color.movo.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
    
    private var addContactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD NEW CONTACT")
                .font(Typography.eyebrow.font)
                .tracking(0.8)
                .foregroundColor(Color.movo.textTertiary)
            
            TextField("", text: $nickname,
                      prompt: Text("Nickname (e.g., Mom, Roommate)")
                .foregroundColor(Color.movo.textDisabled))
            .font(Typography.subtitle.font)
            .foregroundColor(Color.movo.textPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.movo.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.movo.elevated, lineWidth: 0.5))
            )
            
            HStack(spacing: 10) {
                Text("+1")
                    .font(Typography.subtitle.font)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.trailing, 10)
                    .overlay(
                        Rectangle()
                            .fill(Color.movo.elevated)
                            .frame(width: 0.5)
                            .padding(.vertical, 4),
                        alignment: .trailing
                    )
                TextField("", text: $phoneNumber,
                          prompt: Text("(555) 000-0000")
                    .foregroundColor(Color.movo.textDisabled))
                .font(Typography.subtitle.font)
                .foregroundColor(Color.movo.textPrimary)
                .keyboardType(.phonePad)
                .onChange(of: phoneNumber) { newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(10))
                    let formatted = formatUSPhone(digits)
                    if phoneNumber != formatted { phoneNumber = formatted }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.movo.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.movo.accentBorder, lineWidth: 0.5))
            )
            
            HStack(spacing: 8) {
                Button {
                    nickname = ""
                    phoneNumber = ""
                } label: {
                    Text("Cancel")
                        .font(Typography.button.font)
                        .foregroundColor(Color.movo.textSecondary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.movo.elevated.opacity(0.6))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.movo.elevated, lineWidth: 0.5))
                        )
                }
                
                Button(action: addContact) {
                    Group {
                        if contactVM.state == .loading {
                            ProgressView().tint(Color.movo.background).scaleEffect(0.8)
                        } else {
                            Text("Add Contact").font(Typography.button.font).foregroundColor(Color.movo.background)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isFormValid ? Color.movo.accent : Color.movo.accent.opacity(0.35))
                    )
                }
                .disabled(!isFormValid || contactVM.state == .loading)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.movo.elevated.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.movo.elevated, lineWidth: 0.5))
        )
    }
    
    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.movo.elevated).frame(height: 0.5)
            Text("OR PICK FROM")
                .font(Typography.micro.font)
                .tracking(1.2)
                .foregroundColor(Color.movo.textTertiary)
            Rectangle().fill(Color.movo.elevated).frame(height: 0.5)
        }
    }
    
    @ViewBuilder
    private var contactsSection: some View {
        if hasAnyData {
            contactsListCard
        } else {
            permissionCard
        }
    }
    
    // MARK: - Permission Card
    
    private var permissionCard: some View {
        VStack(spacing: 14) {
            ContactsPermissionIllustration()
                .frame(width: 200, height: 100)
            
            VStack(spacing: 6) {
                Text("Movo is better with friends")
                    .font(Typography.cardTitle.font)
                    .foregroundColor(Color.movo.textPrimary)
                Text(isDenied
                     ? "Contact access was denied. Open Settings to allow Movo to read your contacts."
                     : "Grant access to your contacts to find people on Movo and send money instantly.")
                .font(Typography.captionSmall.font)
                .foregroundColor(Color.movo.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
            }
            
            Button(action: isDenied ? openSettings : enableContacts) {
                Text(isDenied ? "Open Settings" : "Enable Contacts")
                    .font(Typography.button.font)
                    .foregroundColor(Color.movo.background)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 200)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.movo.accent))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.movo.elevated, lineWidth: 0.5))
        )
    }
    
    // MARK: - Contacts List
    
    private var contactsLoadingCard: some View {
        VStack {
            ProgressView().tint(Color.movo.accent).scaleEffect(1.2).padding(.vertical, 40)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.movo.elevated, lineWidth: 0.5))
        )
    }
    
    private var contactsListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(Color.movo.textDisabled)
                TextField("", text: $contactVM.search,
                          prompt: Text("Search contacts").foregroundColor(Color.movo.textDisabled))
                .font(Typography.subtitle.font)
                .foregroundColor(Color.movo.textPrimary)
                .autocorrectionDisabled()
                if !contactVM.search.isEmpty {
                    Button { contactVM.search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Color.movo.textDisabled)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.movo.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.movo.elevated, lineWidth: 0.5))
            )
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Favourites
            if !contactVM.filteredFavourites.isEmpty {
                Text("FAVOURITES")
                    .font(Typography.eyebrow.font)
                    .tracking(0.8)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                ForEach(contactVM.filteredFavourites) { contact in
                    NavigationLink(value: contact) { contactRow(contact) }
                        .buttonStyle(.plain)
                    if contact.id != contactVM.filteredFavourites.last?.id {
                        Rectangle().fill(Color.movo.elevated).frame(height: 0.5).padding(.horizontal, 14)
                    }
                }
                Rectangle().fill(Color.movo.elevated).frame(height: 0.5).padding(.horizontal, 14)
            }
            
            // All contacts
            if !contactVM.filteredContacts.isEmpty {
                Text("ALL CONTACTS")
                    .font(Typography.eyebrow.font)
                    .tracking(0.8)
                    .foregroundColor(Color.movo.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                ForEach(contactVM.filteredContacts) { contact in
                    NavigationLink(value: contact) { contactRow(contact) }
                        .buttonStyle(.plain)
                    if contact.id != contactVM.filteredContacts.last?.id {
                        Rectangle().fill(Color.movo.elevated).frame(height: 0.5).padding(.horizontal, 14)
                    }
                }
            }
            Spacer().frame(height: 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.movo.surface.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.movo.elevated, lineWidth: 0.5))
        )
        .padding(.leading, Spacing.lg)
        .padding(.trailing, Spacing.lg)
    }
    
    private func contactAvatar(initials: String, size: CGFloat) -> some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.35, weight: .semibold))
            .foregroundColor(Color.movo.textPrimary)
            .frame(width: size, height: size)
            .background(Color.movo.elevated, in: Circle())
            .overlay(Circle().strokeBorder(Color.movo.accentBorder, lineWidth: 0.5))
    }
    
    private func contactRow(_ contact: ContactRecord) -> some View {
        HStack(spacing: 12) {
            contactAvatar(initials: contact.initials, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(contact.nickname ?? "")
                        .font(Typography.bodyCompact.font)
                        .foregroundColor(Color.movo.textPrimary)
                    if contact.isAdded {
                        Text("MOVO")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color.movo.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.movo.accent.opacity(0.15))
                            )
                    }
                }
                Text(contact.phoneNumber ?? "")
                    .font(Typography.captionSmall.font)
                    .foregroundColor(Color.movo.textTertiary)
            }
            Spacer()
            Button {
                Task { await contactVM.toggleFavourite(contact) }
            } label: {
                Image(systemName: contactVM.isFavorite(contact) ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(contactVM.isFavorite(contact) ? Color.movo.accent : Color.movo.textDisabled)
            }
            .buttonStyle(.plain)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.movo.textDisabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
    
    private func enableContacts() {
        Task {
            await contactVM.load()
            authStatus = CNContactStore.authorizationStatus(for: .contacts)
        }
    }
    
    private func openSettings() {
        if let url = URL(string: "app-settings:") { openURL(url) }
    }
    
    private func formatUSPhone(_ digits: String) -> String {
        switch digits.count {
        case 0:       return ""
        case 1...3:   return "(\(digits)"
        case 4...6:   return "(\(digits.prefix(3))) \(digits.dropFirst(3))"
        default:      return "(\(digits.prefix(3))) \(digits.dropFirst(3).prefix(3))-\(digits.dropFirst(6))"
        }
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
                Text(savingVM.accountList.map { "$\($0.data.totalAvailableBalance.toCurrencyString())" } ?? "$0.00")
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundColor(Color.movo.textPrimary)
                    .tracking(-0.5)
            }
            Spacer()
            Button(action: { withAnimation { showAddContact = true } }) {
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
                Eyebrow("Frequent")
                Spacer()
                Button(action: {}) {
                    Text("See all")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(Color.movo.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm + 2) {
                    ForEach(contactVM.mergedContacts) { contact in
                        QuickContactCell(contact: contact) {
                            //vm.selectContact(contact)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xs)
            }
        }
    }
    
    private struct QuickContactCell: View {
        let contact: ContactRecord
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
                            .strokeBorder(
                                contact.isOnMovo ? Color.movo.accent : Color.movo.border,
                                lineWidth: Stroke.hairline
                            )
                        Text(contact.initials)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color.movo.textPrimary)
                    }
                    .frame(width: 56, height: 56)
                    .overlay(
                        contact.isOnMovo
                        ? Circle()
                            .strokeBorder(Color.movo.accentSoft, lineWidth: 3)
                            .padding(-3)
                        : nil
                    )
                    
                    Text((contact.nickname?.split(separator: " ").first.map(String.init) ?? contact.nickname) ?? "")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(Color.movo.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 64)
            }
            .buttonStyle(.plain)
        }
    }
    
}
