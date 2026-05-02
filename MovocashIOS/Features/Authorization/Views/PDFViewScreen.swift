//
//  PDFViewScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 02/05/26.
//

import SwiftUI
import PDFKit

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
            VStack(spacing: 0) {
                docHeader
                Divider()
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if viewModel.state == .loading {
                SpinnerView()
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.state != .loading {
                bottomBar
            }
        }
        .background(Color(.systemBackground))
        .task { await viewModel.loadPDF(for: documentType) }
    }
}

// MARK: - Document Header

private extension PDFViewScreen {

    var docHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(documentType.iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: documentType.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(documentType.iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(documentType.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Please read carefully before accepting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Content

private extension PDFViewScreen {

    var contentArea: some View {
        ZStack {
            if let data = viewModel.data {
                PDFKitView(data: data) {
                    hasReachedEnd = true
                }
            } else if viewModel.state != .loading {
                EmptyStateView(
                    image: "doc.fill",
                    title: "Document Unavailable",
                    description: "Unable to load this document.\nPlease try again later."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Bottom Bar

private extension PDFViewScreen {

    var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                Text(hasReachedEnd
                     ? "By tapping Accept, you agree to the above document."
                     : "Scroll to the end to accept this document.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .animation(.easeInOut, value: hasReachedEnd)

                Button {
                    onAccept()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Accept & Continue")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(hasReachedEnd ? Color.primary : Color(.systemGray3))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .animation(.easeInOut, value: hasReachedEnd)
                }
                .buttonStyle(.plain)
                .disabled(!hasReachedEnd)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - PDFKit View

private struct PDFKitView: UIViewRepresentable {

    let data: Data
    let onReachEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReachEnd: onReachEnd)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor.systemBackground

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        if let document = PDFDocument(data: data) {
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
