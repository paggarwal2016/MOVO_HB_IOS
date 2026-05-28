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
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(onReachEnd: onReachEnd)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "scrollEnd")

        // Script A: inject CSS token variables derived from MovoTheme (light + dark blocks)
        // and set the initial data-theme attribute. Must run at document start so variables
        // are available before any HTML content is parsed.
        controller.addUserScript(makeTokenScript(scheme: colorScheme))

        // Script B: inject terms-layout.css from the app bundle as a <style> element.
        if let layoutScript = makeLayoutCSSScript() {
            controller.addUserScript(layoutScript)
        }

        // Script C: collapse table rows whose leading cells are empty so the
        // content cell spans the full row width instead of sitting in column 3.
        controller.addUserScript(makeTableCollapseScript())

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
        webView.isOpaque = false
        webView.backgroundColor = .clear
        // Use the adaptive background token so UIScrollView can infer a contrasting
        // indicator color. .clear prevents the system from choosing the right indicator style.
        webView.scrollView.backgroundColor = MovoTheme.color.background.uiColor
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update the data-theme attribute when the system color scheme changes — no reload needed.
        let theme = colorScheme == .dark ? "dark" : "light"
        webView.evaluateJavaScript(
            "document.documentElement.setAttribute('data-theme', '\(theme)')",
            completionHandler: nil
        )
    }

    // MARK: - Style script builders

    /// Builds Script A: a <style> block containing :root (light) and [data-theme="dark"]
    /// variable declarations pulled directly from MovoTheme.color, plus static typography
    /// and spacing constants. Sets the initial data-theme attribute on <html>.
    private func makeTokenScript(scheme: ColorScheme) -> WKUserScript {
        let c = MovoTheme.color

        func hex(_ v: UInt32) -> String { String(format: "#%06X", v) }
        func rgba(_ v: UInt32, alpha: Double) -> String {
            "rgba(\((v >> 16) & 0xFF), \((v >> 8) & 0xFF), \(v & 0xFF), \(alpha))"
        }

        let css = """
        :root {
          --bg: \(hex(c.background.lightHex));
          --surface: \(hex(c.surface.lightHex));
          --elevated: \(hex(c.elevated.lightHex));
          --fg: \(hex(c.textPrimary.lightHex));
          --fg-secondary: \(hex(c.textSecondary.lightHex));
          --fg-tertiary: \(hex(c.textTertiary.lightHex));
          --fg-disabled: \(hex(c.textDisabled.lightHex));
          --accent: \(hex(c.accent.lightHex));
          --accent-tint: \(rgba(c.accent.lightHex, alpha: 0.12));
          --danger: \(hex(c.danger.lightHex));
          --warning: \(hex(c.warning.lightHex));
          --border: \(hex(c.border.lightHex));
          --border-strong: \(hex(c.borderStrong.lightHex));
          --font-body: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
          --font-display: -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --size-h1: 26px; --size-h2: 22px; --size-h3: 18px; --size-h4: 16px;
          --size-body: 16px; /* intentionally overrides Typography.body (14pt) for long-form reading */
          --size-caption: 12px; --size-eyebrow: 10px;
          --track-h1: -0.5px; --track-h2: -0.4px; --track-h3: -0.2px; --track-eyebrow: 0.8px;
          --weight-regular: 400; --weight-medium: 500; --weight-semi: 600; --weight-bold: 700;
          --line-body: 1.55; /* intentionally overrides TextStyle.lineHeight (1.2) for long-form reading */
          --line-heading: 1.25;
          --space-xs: 4px; --space-sm: 8px; --space-md: 12px; --space-lg: 16px;
          --space-xl: 20px; --space-xxl: 24px; --space-xxxl: 32px;
          --radius-md: 10px; --radius-lg: 12px;
          --stroke-hairline: 0.5px;
        }
        [data-theme="dark"] {
          --bg: \(hex(c.background.darkHex));
          --surface: \(hex(c.surface.darkHex));
          --elevated: \(hex(c.elevated.darkHex));
          --fg: \(hex(c.textPrimary.darkHex));
          --fg-secondary: \(hex(c.textSecondary.darkHex));
          --fg-tertiary: \(hex(c.textTertiary.darkHex));
          --fg-disabled: \(hex(c.textDisabled.darkHex));
          --accent: \(hex(c.accent.darkHex));
          --accent-tint: \(rgba(c.accent.darkHex, alpha: 0.18));
          --danger: \(hex(c.danger.darkHex));
          --warning: \(hex(c.warning.darkHex));
          --border: \(hex(c.border.darkHex));
          --border-strong: \(hex(c.borderStrong.darkHex));
        }
        """

        // Escape backticks and backslashes before embedding in the JS template literal.
        let escapedCSS = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        let initialTheme = scheme == .dark ? "dark" : "light"
        // Inline style values applied directly on <html> so the first paint frame
        // already has the correct background — no white flash while CSS cascade resolves.
        let initialBg  = hex(scheme == .dark ? c.background.darkHex    : c.background.lightHex)
        let initialFg  = hex(scheme == .dark ? c.textSecondary.darkHex  : c.textSecondary.lightHex)

        let source = """
        (function() {
          var s = document.createElement('style');
          s.textContent = `\(escapedCSS)`;
          document.documentElement.appendChild(s);
          document.documentElement.style.backgroundColor = '\(initialBg)';
          document.documentElement.style.color = '\(initialFg)';
          document.documentElement.setAttribute('data-theme', '\(initialTheme)');
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// Builds Script B: loads terms-layout.css from the main bundle and injects it
    /// as a <style> element at document start. Returns nil if the file is not in the bundle.
    private func makeLayoutCSSScript() -> WKUserScript? {
        guard let cssURL = Bundle.main.url(forResource: "terms-layout", withExtension: "css"),
              let raw = try? String(contentsOf: cssURL, encoding: .utf8) else { return nil }

        // Escape backticks and backslashes before embedding in the JS template literal.
        let escapedCSS = raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        let source = """
        (function() {
          var s = document.createElement('style');
          s.textContent = `\(escapedCSS)`;
          document.documentElement.appendChild(s);
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// Builds Script C: runs after the DOM is ready and collapses table rows where
    /// leading cells are empty. Removes those empty cells and spans the first content
    /// cell across all vacated columns so it fills the full row width.
    private func makeTableCollapseScript() -> WKUserScript {
        let source = """
        (function() {
          document.querySelectorAll('tr').forEach(function(row) {
            var cells = Array.prototype.slice.call(row.cells);
            if (cells.length < 2) return;
            var emptyCount = 0;
            for (var i = 0; i < cells.length - 1; i++) {
              if (cells[i].textContent.trim() === '') {
                emptyCount++;
              } else {
                break;
              }
            }
            if (emptyCount === 0) return;
            for (var i = 0; i < emptyCount; i++) {
              row.removeChild(cells[i]);
            }
            cells[emptyCount].colSpan = emptyCount + 1;
          });
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }

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
