//
//  PDFViewScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 02/05/26.
//

import SwiftUI
import PDFKit
import WebKit

struct PDFViewScreen: View {

    let documentType: DocumentType
    let onAccept: () -> Void

    @StateObject private var viewModel: PDFViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var hasReachedEnd = false

    init(documentType: DocumentType, container: AppContainer, onAccept: @escaping () -> Void) {
        self.documentType = documentType
        self.onAccept     = onAccept
        _viewModel = StateObject(wrappedValue: container.makePDFViewModel())
    }

    var body: some View {
        ZStack {
            MovoBackground()
            AmbientGlowView()

            VStack(spacing: 0) {
                docHeader
                Rectangle()
                    .fill(Color.movo.textTertiary.opacity(0.10))
                    .frame(height: DesignTokens.Stroke.hairline)
                contentArea
                if viewModel.state != .loading {
                    bottomBar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if viewModel.state == .loading {
                SpinnerView()
            }
        }
        .background(Color.clear)
        .task { await viewModel.loadPDF(for: documentType) }
    }
}

// MARK: - Document Header

private extension PDFViewScreen {

    var docHeader: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            documentIllustration()
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                        .fill(Color.movo.textTertiary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                        .strokeBorder(Color.movo.textTertiary.opacity(0.14), lineWidth: DesignTokens.Stroke.hairline)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(documentType.title)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Color.movo.textPrimary)
                Text("Please read carefully before accepting")
                    .textStyle(Typography.caption)
                    .foregroundStyle(Color.movo.textTertiary)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.movo.surface)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.movo.borderStrong.opacity(0.18), lineWidth: DesignTokens.Stroke.hairline)
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.movo.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.bottom, DesignTokens.Spacing.md)
    }

    @ViewBuilder
    func documentIllustration(
        stroke: Color = Color.movo.textTertiary,
        accent: Color = Color.movo.textPrimary
    ) -> some View {
        switch documentType {
        case .privacy:
            ShieldKeyholeIcon(stroke: stroke, accent: accent)
        case .herringPrivacy:
            HerringShieldIcon(stroke: stroke, accent: accent)
        case .tos:
            DocumentLinesIcon(stroke: stroke, accent: accent)
        case .cardholderAgreement:
            SignatureIcon(stroke: stroke, accent: accent)
        }
    }
}

// MARK: - Content

private extension PDFViewScreen {

    var contentArea: some View {
        ZStack {
            if let url = viewModel.pdfURL {
                if url.pathExtension.lowercased() == "html" {
                    WebKitView(url: url) {
                        hasReachedEnd = true
                    }
                } else {
                    PDFKitView(pdfURL: url) {
                        hasReachedEnd = true
                    }
                }
            } else if viewModel.state != .loading {
                pdfUnavailableState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var pdfUnavailableState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "doc.fill")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.movo.textTertiary)
            VStack(spacing: 6) {
                Text("Document Unavailable")
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Color.movo.textPrimary)
                Text("Unable to load this document.\nPlease try again later.")
                    .textStyle(Typography.body)
                    .foregroundStyle(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }
}

// MARK: - Bottom Bar

private extension PDFViewScreen {

    var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.movo.background.opacity(0), Color.movo.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            VStack(spacing: DesignTokens.Spacing.sm + 2) {
                Text(hasReachedEnd
                     ? "By tapping Accept, you agree to the above document."
                     : "Scroll to the end to accept this document.")
                    .textStyle(Typography.caption)
                    .foregroundStyle(Color.movo.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .animation(.easeInOut(duration: DesignTokens.Motion.fast), value: hasReachedEnd)

                Button {
                    onAccept()
                    dismiss()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Accept & continue")
                            .textStyle(Typography.buttonLarge)
                    }
                    .foregroundStyle(
                        hasReachedEnd
                        ? Color.movo.onAccent
                        : Color.movo.accent.opacity(0.55)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                            .fill(hasReachedEnd ? Color.movo.accent : Color.movo.accent.opacity(0.22))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                            .strokeBorder(
                                hasReachedEnd ? Color.clear : Color.movo.accent.opacity(0.35),
                                lineWidth: DesignTokens.Stroke.thin
                            )
                    )
                    .animation(.easeInOut(duration: DesignTokens.Motion.standard), value: hasReachedEnd)
                }
                .buttonStyle(.plain)
                .disabled(!hasReachedEnd)
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .padding(.bottom, DesignTokens.Spacing.xxxl)
            .background(Color.movo.background)
        }
    }
}

// MARK: - WebKit View (HTML documents)

private struct WebKitView: UIViewRepresentable {

    let url: URL
    let onReachEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReachEnd: onReachEnd)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "scrollEnd")

        let scrollScript = WKUserScript(
            source: """
            window.addEventListener('scroll', function() {
                if (window.scrollY + window.innerHeight >= document.body.scrollHeight - 50) {
                    window.webkit.messageHandlers.scrollEnd.postMessage('end');
                }
            });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(scrollScript)

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor(Color.movo.background)
        webView.isOpaque = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let onReachEnd: () -> Void
        private var didFire = false

        init(onReachEnd: @escaping () -> Void) {
            self.onReachEnd = onReachEnd
        }

        func signalEnd() {
            guard !didFire else { return }
            didFire = true
            onReachEnd()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollEnd" { signalEnd() }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Signal end immediately for pages short enough to fit without scrolling.
            webView.evaluateJavaScript("document.body.scrollHeight <= window.innerHeight") { result, _ in
                if let fits = result as? Bool, fits {
                    DispatchQueue.main.async { self.signalEnd() }
                }
            }
        }
    }
}

// MARK: - PDFKit View

private struct PDFKitView: UIViewRepresentable {

    let pdfURL: URL?
        
    let onReachEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReachEnd: onReachEnd)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor(Color.movo.background)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        if let document = PDFDocument(url: pdfURL!) {
            pdfView.document = document
            // Single-page docs never trigger PDFViewPageChangedNotification on scroll,
            // so signal end after the current render pass completes.
            if document.pageCount <= 1 {
                DispatchQueue.main.async { context.coordinator.signalEnd() }
            }
        }
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {}

    // MARK: Coordinator

    final class Coordinator: NSObject {
        private let onReachEnd: () -> Void
        private var didFire = false

        init(onReachEnd: @escaping () -> Void) {
            self.onReachEnd = onReachEnd
        }

        func signalEnd() {
            guard !didFire else { return }
            didFire = true
            onReachEnd()
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let document = pdfView.document,
                  let currentPage = pdfView.currentPage,
                  let lastPage = document.page(at: document.pageCount - 1),
                  currentPage == lastPage else { return }
            signalEnd()
        }
    }
}
