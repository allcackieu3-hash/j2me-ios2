import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)
        setupWebView()
        loadLocalContent()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .clear
        webView.isOpaque = false

        view.addSubview(webView)
    }

    private func loadLocalContent() {
        // 1. Try finding index.html in Web folder reference
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            let baseDir = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: baseDir)
            return
        }

        // 2. Try finding index.html in root bundle
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: Bundle.main.bundleURL)
            return
        }

        // 3. Fallback: Direct HTML if bundle path resolution fails
        let fallbackHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { background: #0d0e12; color: #fff; font-family: -apple-system, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
                h1 { color: #ff2a5f; margin-bottom: 8px; }
                p { color: #94a3b8; font-size: 14px; max-width: 80%; }
                .btn { background: #ff2a5f; color: #fff; border: none; padding: 12px 24px; border-radius: 8px; font-weight: bold; margin-top: 16px; }
            </style>
        </head>
        <body>
            <h1>J2ME DECADE iOS</h1>
            <p>Hệ thống đã khởi động thành công trên iPhone của bạn.</p>
            <button class="btn" onclick="location.reload()">Tải Lại Giao Diện</button>
        </body>
        </html>
        """
        webView.loadHTMLString(fallbackHTML, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Provisional navigation failed: \(error.localizedDescription)")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
