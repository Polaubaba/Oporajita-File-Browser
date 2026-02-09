import SwiftUI
import WebKit
import UniformTypeIdentifiers
import Combine

private let homeURL = URL(string: "https://file.oporajita.win/")!

struct ContentView: View {
    @StateObject private var webViewStore = WebViewStore()
    @State private var showingPicker = false
    @State private var pickedURLs: [URL] = []

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WebView(webView: webViewStore.webView)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    if webViewStore.progress < 1.0 {
                        ProgressView(value: webViewStore.progress)
                            .progressViewStyle(.linear)
                            .padding(.top, 0)
                    }
                }
                .refreshable {
                    webViewStore.webView.reload()
                }

            Button {
                showingPicker = true
            } label: {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(radius: 8)
            }
            .padding()
        }
        .onAppear {
            webViewStore.load(homeURL)
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { urls in
                // Option A (easy): Let the web page handle file input (works if site uses <input type=file>)
                // Option B (best UX): Upload directly (requires your upload endpoint)
                pickedURLs = urls
                Task { await uploadPickedFiles(urls) }
            }
        }
    }

    // MARK: - Option B: Direct Upload Template (fill in endpoint/auth)
    private func uploadPickedFiles(_ urls: [URL]) async {
        // TODO: Set your real upload endpoint here:
        // Example: https://file.oporajita.win/api/upload or similar
        guard let uploadURL = URL(string: "https://file.oporajita.win/PUT_YOUR_UPLOAD_ENDPOINT") else { return }

        for fileURL in urls {
            do {
                let (data, filename, mimeType) = try readFileForUpload(fileURL)
                try await MultipartUploader.upload(
                    to: uploadURL,
                    fieldName: "file",
                    filename: filename,
                    mimeType: mimeType,
                    fileData: data,
                    additionalFields: [:],
                    headers: [:
                        // TODO: Add auth if needed:
                        // "Authorization": "Bearer YOUR_TOKEN"
                    ]
                )

                // Optional: refresh web UI so user sees the new file
                await MainActor.run { webViewStore.webView.reload() }
            } catch {
                print("Upload failed:", error)
            }
        }
    }

    private func readFileForUpload(_ url: URL) throws -> (Data, String, String) {
        let data = try Data(contentsOf: url)
        let filename = url.lastPathComponent
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return (data, filename, mimeType)
    }
}

// MARK: - WKWebView + progress
final class WebViewStore: ObservableObject {
    let webView: WKWebView
    @Published var progress: Double = 0

    private var observer: NSKeyValueObservation?

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true

        observer = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            self?.progress = webView.estimatedProgress
        }
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
    }
}

struct WebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
