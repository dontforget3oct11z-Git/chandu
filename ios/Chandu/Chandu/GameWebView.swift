import SwiftUI
import WebKit

/// Shows the game page and hands it today's step total whenever it changes.
///
/// The page is downloaded from GitHub Pages on every launch (and whenever the app comes back to the
/// front), so game updates arrive without reinstalling. Offline, the last downloaded copy is used,
/// or the copy bundled in the app. The page is always loaded with the same base URL, so the saved
/// game stays the same online and offline.
struct GameWebView: UIViewRepresentable {
    static let pageURL = URL(string: "https://dontforget3oct11z-git.github.io/chandu/")!

    let steps: Int
    let day: String
    /// Bumped by the parent when the app becomes active, to check for a newer page.
    let refreshToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(
            WKUserScript(source: "window.CHANDU_NATIVE = true;", injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false
        context.coordinator.webView = webView
        context.coordinator.lastToken = refreshToken
        context.coordinator.showOfflineCopy()
        context.coordinator.refresh()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastToken != refreshToken {
            context.coordinator.lastToken = refreshToken
            context.coordinator.refresh()
        }
        context.coordinator.push(steps, day: day)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var lastToken = 0
        private var loaded = false
        private var pending: (Int, String)?
        private var lastSteps: (Int, String)?
        private var currentHTML: String?

        private var cacheFile: URL {
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("chandu-latest.html")
        }

        /// Shows the last downloaded page, or the one bundled with the app.
        func showOfflineCopy() {
            if let html = try? String(contentsOf: cacheFile, encoding: .utf8) {
                show(html)
            } else if let url = Bundle.main.url(forResource: "chandu", withExtension: "html"),
                      let html = try? String(contentsOf: url, encoding: .utf8) {
                show(html)
            }
        }

        /// Downloads the latest page and switches to it if it changed.
        func refresh() {
            var request = URLRequest(url: GameWebView.pageURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 8
            URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
                guard let self,
                      let data,
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let html = String(data: data, encoding: .utf8),
                      html.contains("chanduSetSteps") else { return }
                try? data.write(to: self.cacheFile, options: .atomic)
                DispatchQueue.main.async {
                    if html != self.currentHTML { self.show(html) }
                }
            }.resume()
        }

        private func show(_ html: String) {
            guard let webView else { return }
            currentHTML = html
            loaded = false
            webView.loadHTMLString(html, baseURL: GameWebView.pageURL)
        }

        func push(_ steps: Int, day: String) {
            pending = (steps, day)
            flush()
        }

        private func flush() {
            guard loaded, let latest = pending ?? lastSteps, let webView else { return }
            pending = nil
            lastSteps = latest
            let (steps, day) = latest
            webView.evaluateJavaScript("window.chanduSetSteps && window.chanduSetSteps(\(steps), \"\(day)\")")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            flush()   // a freshly loaded page gets the current step total right away
        }
    }
}
