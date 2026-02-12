import SwiftUI
import WebKit
import Combine
import UniformTypeIdentifiers

private let homeURL = URL(string: "https://file.oporajita.win/")!

struct ContentView: View {
    @StateObject private var webViewStore = WebViewStore()

    // Game state
    private let emojis = ["😀","🚑","🤡","🩴","👟","💎","💉","🍕"]
    @State private var activeEmoji: String? = nil
    @State private var timeLeft: Int = 0
    @State private var showBlast: Bool = false
    @State private var gameRunning: Bool = false

    // Countdown timer
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            WebView(webView: webViewStore.webView)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    if webViewStore.progress < 1.0 {
                        ProgressView(value: webViewStore.progress)
                            .progressViewStyle(.linear)
                    }
                }
                .onAppear { webViewStore.load(homeURL) }

            // Countdown / blast overlay
            if gameRunning {
                Color.black.opacity(0.55).ignoresSafeArea()

                VStack(spacing: 18) {
                    Text(showBlast ? "💥" : (activeEmoji ?? ""))
                        .font(.system(size: 96))

                    if !showBlast {
                        Text("\(timeLeft)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    } else {
                        Text("Game over")
                            .font(.title2.weight(.semibold))
                    }
                }
                .padding()
            }

            // Bottom emoji bar
            VStack {
                Spacer()
                bottomBar
            }
        }
        .onReceive(ticker) { _ in
            guard gameRunning, !showBlast else { return }
            if timeLeft > 0 {
                timeLeft -= 1
            }
            if timeLeft <= 0 {
                finishGame()
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            ForEach(emojis, id: \.self) { e in
                Button {
                    startRandomGame()
                } label: {
                    Text(e)
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(gameRunning) // prevent re-trigger mid countdown
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.bottom, 18)
        .shadow(radius: 10)
    }

    private func startRandomGame() {
        // Choose random emoji (from list) + random time (3..10)
        activeEmoji = emojis.randomElement()
        timeLeft = Int.random(in: 3...10)
        showBlast = false
        gameRunning = true
    }

    private func finishGame() {
        showBlast = true

        // After showing 💥 for a moment, do the “close” behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // ✅ App Store-safe option:
            // Instead of closing the app, we can reload the page and end the overlay.
            webViewStore.webView.reload()
            gameRunning = false
            activeEmoji = nil

            // ⚠️ Dev-only hard close (NOT App Store safe):
            // hardCloseApp()
        }
    }

    // ⚠️ Not App Store safe. Use only for local testing.
    private func hardCloseApp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
            exit(0)
        }
    }
}

// MARK: - WebView + progress
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
