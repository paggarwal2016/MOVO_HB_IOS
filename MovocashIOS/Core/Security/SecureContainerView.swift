//
//  SecureContainerView.swift
//  MovocashIOS
//
//  Screenshot / screen-recording prevention for SwiftUI content.
//
//  Content hosted inside a UITextField's secure-entry canvas is rendered
//  normally on screen, but iOS excludes that canvas from screenshots and
//  screen / AirPlay recordings — captured pixels come out black.
//
//  The content is re-hosted in a child UIHostingController placed inside the
//  secure canvas. Re-hosting starts a fresh SwiftUI environment, so the
//  presenting context's `dismiss` (used by sheet close buttons) does not carry
//  across automatically. The system `\.dismiss` value cannot be re-injected
//  (it is get-only), so `.secured()` forwards it through the custom
//  `\.securedDismiss` environment value instead. Sheet content should close via
//  `securedDismiss` (falling back to the standard `dismiss`) — see usage below.
//
//      @Environment(\.dismiss) private var dismiss
//      @Environment(\.securedDismiss) private var securedDismiss
//      ...
//      Button("Close") { (securedDismiss ?? dismiss)() }
//
//  If the private secure canvas can't be located (e.g. a future iOS changes the
//  internals), the content is added normally so the app keeps working without
//  blanking.
//

import UIKit
import SwiftUI

// MARK: - Forwarded dismiss

private struct SecuredDismissKey: EnvironmentKey {
    static let defaultValue: DismissAction? = nil
}

extension EnvironmentValues {
    /// The presenting context's dismiss action, forwarded across the
    /// `.secured()` re-hosting boundary. `nil` outside a secured container.
    var securedDismiss: DismissAction? {
        get { self[SecuredDismissKey.self] }
        set { self[SecuredDismissKey.self] = newValue }
    }
}

// MARK: - UIKit secure container

final class SecureContainerView: UIView {

    /// Hosts protected content. Present regardless of whether the secure canvas
    /// was found.
    let contentHost = UIView()

    private let secureTextField = UITextField()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        secureTextField.isSecureTextEntry = true
        secureTextField.isUserInteractionEnabled = false

        contentHost.translatesAutoresizingMaskIntoConstraints = false
        contentHost.backgroundColor = .clear

        if let secureCanvas = locateSecureCanvas() {
            secureCanvas.translatesAutoresizingMaskIntoConstraints = false
            secureCanvas.subviews.forEach { $0.removeFromSuperview() }

            addSubview(secureCanvas)
            pin(secureCanvas, to: self)

            secureCanvas.addSubview(contentHost)
            pin(contentHost, to: secureCanvas)
        } else {
            addSubview(contentHost)
            pin(contentHost, to: self)
        }
    }

    /// Finds the private "canvas" view that iOS blanks during capture.
    private func locateSecureCanvas() -> UIView? {
        if let view = secureTextField.layer.sublayers?.first?.delegate as? UIView {
            return view
        }
        return secureTextField.subviews.first {
            type(of: $0).description().contains("CanvasView")
        }
    }

    private func pin(_ view: UIView, to container: UIView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}

// MARK: - SwiftUI bridge

private struct SecuredView<Content: View>: UIViewRepresentable {

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> SecureContainerView {
        let container = SecureContainerView()
        let hostView = context.coordinator.hostingController.view!
        hostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.backgroundColor = .clear

        container.contentHost.addSubview(hostView)
        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: container.contentHost.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: container.contentHost.bottomAnchor),
            hostView.leadingAnchor.constraint(equalTo: container.contentHost.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: container.contentHost.trailingAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: SecureContainerView, context: Context) {
        context.coordinator.hostingController.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: content))
    }

    final class Coordinator {
        let hostingController: UIHostingController<Content>
        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
    }
}

private struct SecuredModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    /// Whether to forward the presenting context's `dismiss` across the
    /// re-hosting boundary. Only meaningful when `.secured()` directly wraps a
    /// sheet / cover's content. At the app root there is nothing to dismiss, so
    /// forwarding there would inject a no-op `dismiss` that propagates to every
    /// descendant and shadows their real `dismiss` — breaking sheet/nav close.
    let forwardDismiss: Bool

    func body(content: Content) -> some View {
        if forwardDismiss {
            // Forward the presenting context's dismiss into the re-hosted
            // content via the custom key, applied inline so it survives
            // re-hosting.
            SecuredView { content.environment(\.securedDismiss, dismiss) }
                .ignoresSafeArea()
        } else {
            // Root usage: clear any inherited value so descendants fall back to
            // their own `\.dismiss`.
            SecuredView { content.environment(\.securedDismiss, nil) }
                .ignoresSafeArea()
        }
    }
}

extension View {
    /// Excludes the view from screenshots and screen recordings (captured as
    /// black). Apply to a screen root, or to a sheet / cover's content.
    ///
    /// Re-hosts the content, so a sheet's close button must dismiss via
    /// `@Environment(\.securedDismiss)` (falling back to `\.dismiss`); see the
    /// file header. Views relying on `@EnvironmentObject` from an ancestor must
    /// receive those dependencies explicitly rather than through the environment.
    ///
    /// - Parameter forwardDismiss: Forward the presenting context's `dismiss`
    ///   into the re-hosted content. Keep `true` when securing a sheet / cover's
    ///   content. Pass `false` at the app root (or any non-dismissable root),
    ///   where forwarding a no-op dismiss would otherwise shadow every
    ///   descendant's real `dismiss`.
    func secured(forwardDismiss: Bool = true) -> some View {
        modifier(SecuredModifier(forwardDismiss: forwardDismiss))
    }
}
