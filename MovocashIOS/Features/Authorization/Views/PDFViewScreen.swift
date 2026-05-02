//
//  PDFViewScreen.swift
//  MovocashIOS
//
//  Created by Vinu on 02/05/26.
//

import SwiftUI
import WebKit

struct PDFViewScreen: View {

    let documentType: DocumentType
    let onAccept: () -> Void

    @StateObject private var viewModel: PDFViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss

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
                PDFWebView(data: data)
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
            // Gradient fade over the PDF edge
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                Text("By tapping Accept, you agree to the above document.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

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
                    //.background(documentType.iconColor)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - WKWebView PDF Wrapper

private struct PDFWebView: UIViewRepresentable {

    let data: Data

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(
            data,
            mimeType: "application/pdf",
            characterEncodingName: "",
            baseURL: URL(string: "about:blank")!
        )
    }
}
